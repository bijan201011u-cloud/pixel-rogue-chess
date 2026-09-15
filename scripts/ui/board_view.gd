class_name BoardView
extends Control
## Renders the 8x8 board (tiles, highlights, pieces) and converts taps to
## square indices. Pieces are persistent PieceView nodes keyed by square.
##
## ======================================================================
## AUTHORITATIVE COORDINATE SYSTEM  (the ONLY source of piece geometry)
## ======================================================================
## This control's own rect IS the board rectangle. Nothing else may define
## piece placement - no hard-coded pixels, no screen-space math, no
## per-piece offsets. Every node (tile, overlay, piece) is placed through
## the functions below, which derive everything from `size`:
##
##   square_size()               -> size / 8                       (per-square w/h)
##   get_square_rect(Vector2i)   -> Rect2  of that square
##   get_square_center(Vector2i) -> Vector2((x + 0.5) * w, (y + 0.5) * h)
##   sq_center(sq: int)          -> same, for the 0..63 engine indexing
##   square_at(local_pos)        -> inverse mapping for tap input
##
## Because sprites are normalized 180x180 canvases whose VISIBLE content is
## centered by contract, mapping the full canvas onto the square rect puts
## the visible piece center exactly on the square center. `debug_alignment`
## draws the mathematical center markers to prove it visually, and
## `validate_alignment()` reports the numeric deviation for all 64 squares.
## ======================================================================

signal square_tapped(sq: int)
signal move_finished

const SQUARES := 8
const MOVE_DUR := 0.22
const CAPTURE_DUR := 0.16
const ALIGN_EPSILON := 0.5   # px - validate_alignment() failure threshold

var preferred_cell := 120.0        # hint for the declared rect (min size)
var state: ChessState = null
var selected_sq := -1
var target_squares: Array = []
var check_sq := -1
var input_locked := false          # true while a move animation plays
var debug_alignment := false       # draws center markers + deviation report

var _piece_tex: Dictionary = {}
var _pieces: Dictionary = {}       # sq -> PieceView (persistent nodes)
var _hl_layer: Control
var _piece_layer: Control
var _fx_layer: Control
var _debug_layer: Control
var _corrupt_squares: Array = []
var _pending_anims := 0


func _ready() -> void:
        mouse_filter = Control.MOUSE_FILTER_STOP
        _load_piece_textures()
        _hl_layer = Control.new()
        _hl_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(_hl_layer)
        _piece_layer = Control.new()
        _piece_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(_piece_layer)
        _fx_layer = Control.new()
        _fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(_fx_layer)
        _debug_layer = DebugOverlay.new()
        _debug_layer.board = self
        _debug_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _debug_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        add_child(_debug_layer)
        # ANY layout change (window, DPI, container, orientation) re-glues
        # every node to the coordinate system. Pieces can never drift.
        resized.connect(_relayout)


func _load_piece_textures() -> void:
        _piece_tex = {
                ChessState.PAWN: load("res://assets/pixel/piece_w_pawn.png"),
                ChessState.KNIGHT: load("res://assets/pixel/piece_w_knight.png"),
                ChessState.BISHOP: load("res://assets/pixel/piece_w_bishop.png"),
                ChessState.ROOK: load("res://assets/pixel/piece_w_rook.png"),
                ChessState.QUEEN: load("res://assets/pixel/piece_w_queen.png"),
                ChessState.KING: load("res://assets/pixel/piece_w_king.png"),
                -ChessState.PAWN: load("res://assets/pixel/piece_b_pawn.png"),
                -ChessState.KNIGHT: load("res://assets/pixel/piece_b_knight.png"),
                -ChessState.BISHOP: load("res://assets/pixel/piece_b_bishop.png"),
                -ChessState.ROOK: load("res://assets/pixel/piece_b_rook.png"),
                -ChessState.QUEEN: load("res://assets/pixel/piece_b_queen.png"),
                -ChessState.KING: load("res://assets/pixel/piece_b_king.png"),
        }


## `cell_size` is only a PREFERRED square size used to declare this board's
## rect (custom_minimum_size) to its parent container. The authoritative
## geometry always comes from the ACTUAL control size after layout.
func setup(state_arg: ChessState, cell_size: float) -> void:
        state = state_arg
        preferred_cell = maxf(cell_size, 48.0)
        custom_minimum_size = Vector2(preferred_cell, preferred_cell) * float(SQUARES)
        size = custom_minimum_size
        if _tiles_node() == null:
                _build_tiles()
        refresh()


# ============================================================================
# 1. THE COORDINATE SYSTEM - board-local, derived from the control rect only
# ============================================================================

## Exact playable board rectangle (this control's rect), for reference.
func board_rect() -> Rect2:
        return Rect2(Vector2.ZERO, size)


## Per-square dimensions derived from the board rectangle.
func square_size() -> Vector2:
        return size / float(SQUARES)


## Rect of a square given as (col x, row y) - row 0 is the top rank.
func get_square_rect(square: Vector2i) -> Rect2:
        return Rect2(Vector2(square) * square_size(), square_size())


## THE conversion function every placement must use:
##   center_x = board_pos.x + (x + 0.5) * square_width
##   center_y = board_pos.y + (y + 0.5) * square_height
## (board-local, so board_pos is this control's origin = (0, 0))
func get_square_center(square: Vector2i) -> Vector2:
        var ss := square_size()
        return Vector2((square.x + 0.5) * ss.x, (square.y + 0.5) * ss.y)


## Same conversion for the engine's 0..63 square index (sq >> 3 = row).
func sq_center(sq: int) -> Vector2:
        return get_square_center(Vector2i(sq % SQUARES, sq >> 3))


func sq_rect(sq: int) -> Rect2:
        return get_square_rect(Vector2i(sq % SQUARES, sq >> 3))


static func sq_to_v2i(sq: int) -> Vector2i:
        return Vector2i(sq % SQUARES, sq >> 3)


## Inverse mapping (tap input): board-local point -> square index, or -1.
func square_at(local_pos: Vector2) -> int:
        var ss := square_size()
        if ss.x <= 0.0 or ss.y <= 0.0:
                return -1
        var fx := floori(local_pos.x / ss.x)
        var fy := floori(local_pos.y / ss.y)
        if fx < 0 or fx >= SQUARES or fy < 0 or fy >= SQUARES:
                return -1
        return fy * SQUARES + fx


# ============================================================================
# 2. LAYOUT / RELAYOUT - every node re-derived from `size` on ANY resize
# ============================================================================

func _notification(what: int) -> void:
        if what == NOTIFICATION_RESIZED:
                _relayout()


## Re-derive ALL node geometry from the (new) board rect. Heals any drift:
## tiles, corruption overlays, highlights, and every piece (size + pivot +
## exact square-center position).
func _relayout() -> void:
        if size.x <= 0.0 or size.y <= 0.0:
                return
        _relayout_tiles()
        _relayout_corruption()
        _rebuild_highlights()
        _relayout_pieces()
        if _debug_layer != null:
                _debug_layer.queue_redraw()


func _tiles_node() -> Control:
        for c in get_children():
                if c.has_meta("is_tiles"):
                        return c
        return null


func _build_tiles() -> void:
        var tiles := Control.new()
        tiles.set_meta("is_tiles", true)
        tiles.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(tiles)
        move_child(tiles, 0)
        for i in SQUARES * SQUARES:
                var x := i % SQUARES
                var y := i >> 3
                var tile := TextureRect.new()
                var light := (x + y) % 2 == 0  # a8 (0,0) must be a light square
                tile.texture = load("res://assets/pixel/tile_light.png" if light else "res://assets/pixel/tile_dark.png")
                tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                tile.stretch_mode = TextureRect.STRETCH_SCALE
                tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
                tiles.add_child(tile)
        _relayout_tiles()


func _relayout_tiles() -> void:
        var tiles := _tiles_node()
        if tiles == null:
                return
        var i := 0
        for tile in tiles.get_children():
                var r := sq_rect(i)
                tile.position = r.position
                tile.size = r.size
                i += 1


func _relayout_corruption() -> void:
        for node in _fx_layer.get_children():
                var idx: int = node.get_meta("sq", -1)
                if idx >= 0:
                        var r := sq_rect(idx)
                        node.position = r.position
                        node.size = r.size


func _relayout_pieces() -> void:
        for sq in _pieces.keys():
                var node: PieceView = _pieces[sq]
                node.set_square_size(square_size())
                node.set_square_center(sq_center(sq))   # exact snap, heals drift


# ============================================================================
# 3. STATE -> NODES RECONCILIATION
# ============================================================================

func set_corrupted(squares: Array) -> void:
        _corrupt_squares = squares.duplicate()
        _rebuild_corruption()


func _rebuild_corruption() -> void:
        for n in _fx_layer.get_children():
                n.queue_free()
        for sq in _corrupt_squares:
                var o := _make_overlay("res://assets/pixel/hl_corrupt.png", sq, 0.9)
                _fx_layer.add_child(o)


func set_selection(sel: int, targets: Array) -> void:
        selected_sq = sel
        target_squares = targets
        _rebuild_highlights()


func clear_selection() -> void:
        selected_sq = -1
        target_squares = []
        _rebuild_highlights()


func set_check_square(sq: int) -> void:
        check_sq = sq
        _rebuild_highlights()


## Rebuild highlight overlays only (cheap, does not touch piece nodes).
func _rebuild_highlights() -> void:
        for n in _hl_layer.get_children():
                n.queue_free()
        if state == null:
                return
        if selected_sq >= 0:
                _hl_layer.add_child(_make_overlay("res://assets/pixel/hl_select.png", selected_sq))
        for sq in target_squares:
                var path := "res://assets/pixel/hl_capture.png" if state.board[sq] != 0 else "res://assets/pixel/hl_move.png"
                _hl_layer.add_child(_make_overlay(path, sq))
        if check_sq >= 0:
                _hl_layer.add_child(_make_overlay("res://assets/pixel/hl_check.png", check_sq))


## Public: rebuild only highlights (used right before move animations so the
## piece nodes keep their pre-move positions while the state is committed).
func refresh_highlights() -> void:
        _rebuild_highlights()


## Full instant reconcile of piece nodes + highlights from the state.
## Used on setup, undo, royal-guard removals, promotion, restarts, loads.
## Every existing node is re-snapped to the EXACT calculated square center,
## so floating-point / tween residue can never accumulate.
func refresh() -> void:
        if state == null:
                return
        _rebuild_highlights()
        _rebuild_corruption()
        # remove nodes whose square is now empty
        for sq in _pieces.keys():
                if state.board[sq] == 0:
                        _pieces[sq].queue_free()
                        _pieces.erase(sq)
        # create missing nodes / fix textures + exact positions (promotions,
        # undos, external state swaps -> everything snaps back to its square)
        for sq in SQUARES * SQUARES:
                var piece: int = state.board[sq]
                if piece == 0:
                        continue
                if _pieces.has(sq):
                        var node: PieceView = _pieces[sq]
                        if node.piece != piece:
                                node.texture = _piece_tex.get(piece)
                                node.piece = piece
                        _apply_square_geometry(node, sq)
                else:
                        _pieces[sq] = _spawn_piece(sq, piece)
        if _debug_layer != null:
                _debug_layer.queue_redraw()


## The ONE way a piece node is given geometry: size from the coordinate
## system, position from get_square_center(). Never offsets.
func _apply_square_geometry(node: PieceView, sq: int) -> void:
        node.sq = sq
        node.set_square_size(square_size())
        node.set_square_center(sq_center(sq))


func _spawn_piece(sq: int, piece: int) -> PieceView:
        var node := PieceView.new(piece, sq)
        node.texture = _piece_tex.get(piece)
        _apply_square_geometry(node, sq)
        _piece_layer.add_child(node)
        return node


## Explicit snap of every piece to its calculated center (validation tool).
## Returns the alignment report for the caller to assert on.
func snap_all_pieces() -> Dictionary:
        _relayout_pieces()
        return validate_alignment()


func _make_overlay(path: String, sq: int, alpha := 1.0) -> TextureRect:
        var o := TextureRect.new()
        o.texture = load(path)
        var r := sq_rect(sq)
        o.position = r.position
        o.size = r.size
        o.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        o.stretch_mode = TextureRect.STRETCH_SCALE
        o.modulate = Color(1, 1, 1, alpha)
        o.mouse_filter = Control.MOUSE_FILTER_IGNORE
        o.set_meta("sq", sq)
        return o


# ============================================================================
# 4. ANIMATED MOVES - always between two CALCULATED square centers
# ============================================================================

## ANIMATED MOVE. Call AFTER ChessRules.make_move() (state is already
## updated; node positions lag behind, which is exactly what we animate).
## The mover slides from the center of its source square to the center of
## the destination square - both points come from get_square_center();
## when the tween finishes, the piece is explicitly snapped onto the exact
## destination center (requirement: no floating-point/tween residue).
## Castling slides the rook the same way; en passant fades the pawn on its
## capture square; promotion swaps the texture when the pawn lands.
func animate_move(move: Dictionary) -> void:
        var from := int(move["from"])
        var to := int(move["to"])
        var flag := int(move["flag"])
        input_locked = true
        _pending_anims = 0

        var mover: PieceView = _pieces.get(from)
        _pieces.erase(from)

        # captured piece square: en passant takes on cap_sq, otherwise "to"
        var cap_sq := to
        if flag == ChessRules.FLAG_EP:
                cap_sq = int(move["cap_sq"])
        var captured: PieceView = _pieces.get(cap_sq)
        if captured != null and captured != mover:
                _pieces.erase(cap_sq)
                _fade_out(captured)

        if mover != null:
                _pieces[to] = mover
                mover.sq = to
                _piece_layer.move_child(mover, _piece_layer.get_child_count() - 1)
                var tw := _slide_piece(mover, to, MOVE_DUR)
                if int(move["promo"]) != 0:
                        var promo_piece := int(move["promo"]) * (1 if int(move["piece"]) > 0 else -1)
                        tw.tween_callback(_swap_texture.bind(mover, promo_piece))

        # castling: slide the rook between its two calculated centers as well
        if flag == ChessRules.FLAG_CASTLE_K or flag == ChessRules.FLAG_CASTLE_Q:
                var white := int(move["piece"]) > 0
                var rf: int
                var rt: int
                if flag == ChessRules.FLAG_CASTLE_K:
                        rf = 63 if white else 7
                        rt = 61 if white else 5
                else:
                        rf = 56 if white else 0
                        rt = 59 if white else 3
                var rook: PieceView = _pieces.get(rf)
                if rook != null:
                        _pieces.erase(rf)
                        _pieces[rt] = rook
                        rook.sq = rt
                        _piece_layer.move_child(rook, _piece_layer.get_child_count() - 1)
                        _slide_piece(rook, rt, MOVE_DUR + 0.06)
        if _pending_anims <= 0:
                _on_anim_done()


## Tween a node from its CURRENT visual center to the exact center of `to`.
## Returns the tween so callers can chain callbacks (promotion swap).
## ROBUSTNESS: Godot can emit `finished` before the MethodTweener's very
## last write on some frames. A `done` guard blocks any straggler
## interpolation write, and the finished handler re-snaps the piece onto
## the EXACT calculated destination center (recomputed at that moment),
## so the animation ALWAYS ends perfectly centered (no float/tween residue).
func _slide_piece(node: PieceView, to: int, dur: float) -> Tween:
        var start_c := node.center_pos()
        _pending_anims += 1
        var tw := create_tween()
        var end_c := sq_center(to)
        var done := [false]   # array -> captured by reference inside lambdas
        tw.tween_method(
                func(c: Vector2) -> void:
                        if not done[0]:
                                node.set_square_center(c),
                start_c, end_c, dur
        ).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
        tw.tween_callback(func() -> void:
                        if not done[0]:
                                node.set_square_center(end_c))
        tw.finished.connect(func() -> void:
                        done[0] = true
                        node.set_square_center(sq_center(to))   # exact final snap
                        _on_anim_done())
        return tw


func _swap_texture(node: PieceView, piece: int) -> void:
        node.texture = _piece_tex.get(piece)
        node.piece = piece


## Fade a node out (captures). Scaling pivots on the node center
## (pivot_offset == size/2), so the shrink is perfectly symmetric.
func _fade_out(node: PieceView) -> void:
        node.z_index = 5
        var tw := create_tween()
        tw.set_parallel(true)
        tw.tween_property(node, "modulate:a", 0.0, CAPTURE_DUR)
        tw.tween_property(node, "scale", Vector2(0.55, 0.55), CAPTURE_DUR) \
                        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        tw.chain().tween_callback(node.queue_free)


## Animated removal used by ROYAL GUARD / PHOENIX (attacker destroyed).
func animate_removal(sq: int) -> void:
        var node: PieceView = _pieces.get(sq)
        if node != null:
                _pieces.erase(sq)
                _fade_out(node)


func _on_anim_done() -> void:
        _pending_anims -= 1
        if _pending_anims > 0:
                return
        _pending_anims = 0
        input_locked = false
        # Belt & braces: every piece must sit exactly on its square center
        # after ANY animation (requirement 13/14).
        _relayout_pieces()
        if _debug_layer != null:
                _debug_layer.queue_redraw()
        move_finished.emit()


func _process(_delta: float) -> void:
        if debug_alignment and _debug_layer != null:
                _debug_layer.queue_redraw()   # markers track animations live


func _gui_input(event: InputEvent) -> void:
        if input_locked:
                return
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
                # inverse of get_square_center(): pure square_size() division
                var sq := square_at(event.position)
                if sq >= 0:
                        square_tapped.emit(sq)


# ============================================================================
# 5. ALIGNMENT VALIDATION (automated 64-square audit)
# ============================================================================

## For EVERY occupied square: expected center (coordinate system) vs the
## node's actual visual center. Returns {checked, max_dev, worst_sq,
## failures[], ok}. A run is only correct when max_dev <= ALIGN_EPSILON.
func validate_alignment() -> Dictionary:
        var failures: Array = []
        var max_dev := 0.0
        var worst := -1
        var checked := 0
        if state == null:
                return {"checked": 0, "max_dev": 0.0, "worst_sq": -1,
                                "failures": failures, "ok": true}
        for sq in SQUARES * SQUARES:
                if state.board[sq] == 0:
                        continue
                var node: PieceView = _pieces.get(sq)
                var expected := sq_center(sq)
                if node == null:
                        failures.append({"sq": sq, "error": "missing_node",
                                        "expected": expected})
                        continue
                var dev := node.deviation_from(expected)
                checked += 1
                if dev > max_dev:
                        max_dev = dev
                        worst = sq
                if dev > ALIGN_EPSILON:
                        failures.append({"sq": sq, "dev": dev, "expected": expected,
                                        "actual": node.center_pos()})
        return {"checked": checked, "max_dev": max_dev, "worst_sq": worst,
                        "failures": failures, "ok": failures.is_empty() and max_dev <= ALIGN_EPSILON}


## Human-readable report (debug log / tests output).
func alignment_report() -> String:
        var r := validate_alignment()
        var lines := ["ALIGNMENT: checked=%d max_dev=%.3fpx worst_sq=%d ok=%s"
                        % [r["checked"], r["max_dev"], r["worst_sq"], str(r["ok"])]]
        for f in r["failures"]:
                lines.append("  MISMATCH sq=%d dev=%.2fpx expected=%s actual=%s"
                                % [f["sq"], f.get("dev", -1.0), f.get("expected", Vector2.INF),
                                f.get("actual", Vector2.INF)])
        return "\n".join(lines)


# ============================================================================
# 6. DEBUG ALIGNMENT MODE - center markers drawn ON the board
# ============================================================================

class DebugOverlay:
        extends Control
        ## Draws, for all 64 squares, a cross + circle at the MATHEMATICAL
        ## center (from get_square_center) plus the calculated coordinates;
        ## for occupied squares a green dot marks the piece's actual pivot so
        ## any mismatch is instantly visible (green == centered).
        var board = null   # BoardView (untyped on purpose: inner-class self-ref)
        const FILES := "abcdefgh"

        func _draw() -> void:
                if board == null or not board.debug_alignment or board.size.x <= 0.0:
                        return
                var ss: Vector2 = board.square_size()
                var font := ThemeDB.fallback_font
                var len_c := maxf(7.0, ss.x * 0.16)
                var rep: Dictionary = board.validate_alignment()
                var n: int = board.SQUARES
                for x in n:
                        for y in n:
                                var sq := y * n + x
                                var c: Vector2 = board.get_square_center(Vector2i(x, y))
                                # exact mathematical center marker (cross + circle)
                                draw_line(c + Vector2(-len_c, 0), c + Vector2(len_c, 0),
                                                Color(1.0, 0.25, 0.25, 0.95), 2.0)
                                draw_line(c + Vector2(0, -len_c), c + Vector2(0, len_c),
                                                Color(1.0, 0.25, 0.25, 0.95), 2.0)
                                draw_arc(c, len_c * 0.6, 0.0, TAU, 24, Color(1, 1, 1, 0.7), 1.5)
                                # calculated center position label: chess coords + px
                                var txt := "%s%d (%d,%d)" % [FILES[x], n - y, roundi(c.x), roundi(c.y)]
                                draw_string(font, c + Vector2(len_c * 0.7, -len_c * 0.55), txt,
                                                HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 0.4, 0.95))
                                # piece pivot comparison: green = centered, orange = off
                                var node = board._pieces.get(sq)
                                if node != null:
                                        var actual: Vector2 = node.center_pos()
                                        var dev := actual.distance_to(c)
                                        var col := Color(0.2, 1.0, 0.3, 0.95) \
                                                        if dev <= board.ALIGN_EPSILON else Color(1.0, 0.6, 0.0, 1.0)
                                        draw_circle(actual, 4.0, col)
                                        if dev > board.ALIGN_EPSILON:
                                                draw_line(c, actual, Color(1.0, 0.6, 0.0, 0.9), 2.0)
                # summary line (top-left of the board)
                var summary := "ALIGN max_dev=%.2fpx ok=%s" % [rep["max_dev"], str(rep["ok"])]
                var ssz := font.get_string_size(summary, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
                draw_rect(Rect2(Vector2(8, 8), ssz + Vector2(16, 10)), Color(0, 0, 0, 0.65))
                draw_string(font, Vector2(16, 8 + ssz.y), summary,
                                HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
                                Color(0.4, 1.0, 0.5) if rep["ok"] else Color(1.0, 0.45, 0.3))
