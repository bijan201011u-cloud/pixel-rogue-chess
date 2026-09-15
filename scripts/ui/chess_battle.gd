extends Control
## Chess battle: full chess + roguelike hooks. Two modes:
##   "ai"  - player (WHITE) vs AI (BLACK); captures grant tiered upgrades.
##   "pvp" - two players on one phone (hotseat), plain chess, no roguelike.
## Flow per move: commit move -> start AI compute thread IN PARALLEL ->
## play slide animation -> apply AI reply immediately -> player's turn.

const BOARD_MARGIN := 40.0
const AI_SAFETY_TIMEOUT := 20.0

var state: ChessState
var cfg: Dictionary = {}
var is_pvp: bool = false
var history: Array = []             # {"undo": Dictionary, "move": Dictionary}
var selected_sq := -1
var current_moves: Array = []       # legal move dicts for the selected piece
var ai_thinking := false
var game_over := false
var guard_fired := false            # royal guard changed the board (undo disabled)
var knight_inspire_active := false
var pending_promo: Array = []       # promo variants for the tapped destination
var overlay_open := false
var _ai_thread: Thread = null
var _exiting := false
var _anim_flag := false             # animation completion latch
var _ai_flag := false               # AI result latch
var _ai_ranked: Array = []
var _ai_waited := 0.0

var board_view: BoardView
var status_label: Label
var log_label: Label
var coin_label: Label
var up_row: HBoxContainer
var undo_btn: Button
var overlay: Control = null
var toast_box: VBoxContainer


func _ready() -> void:
        cfg = GameManager.pending_battle
        if cfg.is_empty():
                cfg = {"node_id": "b1", "label": "BATTLE 1", "is_boss": false, "mode": "ai",
                                "depth": 2, "jitter": 0.6, "blunder": 0.1, "base_coins": 10}
        is_pvp = String(cfg.get("mode", "ai")) == "pvp"
        state = ChessRules.create_initial_state()
        if not is_pvp:
                if bool(cfg.get("is_boss", false)):
                        _apply_corruption()
                if RunManager.has_upgrade("royal_decree") and state.board[55] == ChessState.PAWN:
                        state.board[55] = ChessState.QUEEN  # ROYAL DECREE extra Queen
                knight_inspire_active = RunManager.knight_inspire_battles > 0
                if knight_inspire_active:
                        RunManager.knight_inspire_battles -= 1
        _build_ui()
        board_view.setup(state, _compute_cell())
        board_view.debug_alignment = SaveManager.debug_alignment_enabled
        board_view.square_tapped.connect(_on_square_tapped)
        if not is_pvp and bool(cfg.get("is_boss", false)):
                _show_boss_intro()
        else:
                if not is_pvp:
                        var lucky := RunManager.begin_battle()
                        if lucky > 0:
                                _toast(I18n.fmt("fx_lucky_start", [lucky]), "", "res://assets/ui/icon_coin.png")
                _begin_player_turn()


func _exit_tree() -> void:
        _exiting = true
        if _ai_thread != null and _ai_thread.is_started():
                _ai_thread.wait_to_finish()
        _ai_thread = null


# ------------------------------------------------------------------ UI build

func _compute_cell() -> float:
        var vp := get_viewport_rect().size
        var by_cells := (vp.y - 640.0) / 8.0
        var bx_cells := (vp.x - BOARD_MARGIN * 2.0) / 8.0
        return clampf(minf(by_cells, bx_cells), 72.0, 150.0)


func _build_ui() -> void:
        UIKit.fullscreen_bg(self)

        # top bar
        var bar := PanelContainer.new()
        bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
        bar.add_theme_stylebox_override("panel", UIKit.panel_style())
        var h := HBoxContainer.new()
        h.add_theme_constant_override("separation", 12)
        bar.add_child(h)
        var title_text := String(cfg.get("label", "BATTLE"))
        if is_pvp:
                h.add_child(UIKit.icon("res://assets/ui/ui_sword.png", 56))
                title_text = I18n.t("pvp_title")
        else:
                h.add_child(UIKit.icon("res://assets/ui/icon_coin.png", 56))
                coin_label = UIKit.label(str(RunManager.coins), 38, UIKit.COL_GOLD)
                h.add_child(coin_label)
                h.add_child(UIKit.chip("x%.2f" % RunManager.multiplier(),
                                UIKit.COL_GOLD if RunManager.multiplier() > 1.0 else UIKit.COL_DIM))
                h.add_child(UIKit.hspace(12))
        var title := UIKit.label(title_text, 38,
                        UIKit.COL_BAD if bool(cfg.get("is_boss", false)) else UIKit.COL_TEXT)
        h.add_child(title)
        var spacer := Control.new()
        spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        h.add_child(spacer)
        if knight_inspire_active:
                h.add_child(UIKit.chip(I18n.t("fx_inspire_chip"), UIKit.COL_GOOD))
        add_child(bar)

        # toast layer (non-blocking, sits between status text and the board)
        toast_box = VBoxContainer.new()
        toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
        toast_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
        toast_box.offset_top = 188
        toast_box.offset_left = 120
        toast_box.offset_right = -120
        toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
        toast_box.add_theme_constant_override("separation", 8)
        add_child(toast_box)

        # status + board + bottom panel in a vertical stack
        var stack := VBoxContainer.new()
        stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        stack.offset_top = 120
        stack.add_theme_constant_override("separation", 10)
        add_child(stack)

        status_label = UIKit.label("", 40, UIKit.COL_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
        stack.add_child(status_label)

        var board_holder := CenterContainer.new()
        board_view = BoardView.new()
        board_holder.add_child(board_view)
        stack.add_child(board_holder)

        # active upgrades panel (AI mode only)
        if not is_pvp:
                var up_panel := PanelContainer.new()
                up_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
                up_panel.add_theme_stylebox_override("panel", UIKit.panel_style())
                up_row = HBoxContainer.new()
                up_row.add_theme_constant_override("separation", 10)
                up_panel.add_child(up_row)
                var holder := HBoxContainer.new()
                holder.alignment = BoxContainer.ALIGNMENT_CENTER
                holder.add_child(up_panel)
                stack.add_child(holder)

        log_label = UIKit.label("", 30, UIKit.COL_DIM, HORIZONTAL_ALIGNMENT_CENTER)
        log_label.custom_minimum_size = Vector2(0, 76)
        log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        stack.add_child(log_label)

        var btns := HBoxContainer.new()
        btns.alignment = BoxContainer.ALIGNMENT_CENTER
        btns.add_theme_constant_override("separation", 24)
        if not is_pvp:
                undo_btn = UIKit.button(I18n.t("b_undo"), 38, "secondary", Vector2(360, 104))
                undo_btn.pressed.connect(_on_undo_pressed)
                btns.add_child(undo_btn)
        var forfeit := UIKit.button(I18n.t("b_forfeit"), 38, "danger", Vector2(360, 104))
        forfeit.pressed.connect(_on_forfeit_pressed)
        btns.add_child(forfeit)
        stack.add_child(btns)

        if not is_pvp:
                RunManager.coins_changed.connect(_on_coins_changed)
                RunManager.upgrades_changed.connect(_refresh_upgrade_row)
                _refresh_upgrade_row()


func _apply_corruption() -> void:
        var empties: Array = []
        for sq in 64:
                if state.board[sq] == 0:
                        empties.append(sq)
        empties.shuffle()
        state.corrupted = empties.slice(0, mini(Balance.CORRUPTED_SQUARES, empties.size()))


# ----------------------------------------------------------------- helpers

func _set_status(text: String, is_alert := false) -> void:
        status_label.text = text
        status_label.add_theme_color_override("font_color", UIKit.COL_BAD if is_alert else UIKit.COL_GOLD)


func _log(text: String) -> void:
        log_label.text = text


func _refresh_check_indicator() -> void:
        if ChessRules.in_check(state, state.turn):
                board_view.set_check_square(ChessRules.find_king(state, state.turn))
        else:
                board_view.set_check_square(-1)


func _refresh_upgrade_row() -> void:
        if is_pvp or up_row == null:
                return
        for c in up_row.get_children():
                c.queue_free()
        if RunManager.upgrades.is_empty():
                up_row.add_child(UIKit.label(I18n.t("up_none"), 26, UIKit.COL_DIM))
                return
        up_row.add_child(UIKit.label(I18n.t("up_active"), 26, UIKit.COL_DIM))
        for id in RunManager.upgrades:
                var u: Dictionary = UpgradeDB.get_upgrade(id)
                if u.is_empty():
                        continue
                var slot := Control.new()
                slot.custom_minimum_size = Vector2(56, 56)
                var b := TextureButton.new()
                b.texture_normal = load(String(u["icon"]))
                b.ignore_texture_size = true
                b.stretch_mode = TextureButton.STRETCH_SCALE
                b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
                b.focus_mode = Control.FOCUS_NONE
                b.pressed.connect(_on_upgrade_info.bind(id))
                slot.add_child(b)
                if RunManager.stacks(id) > 1:
                        var badge := UIKit.label("x%d" % RunManager.stacks(id), 22, UIKit.COL_GOLD)
                        badge.position = Vector2(30, 30)
                        slot.add_child(badge)
                up_row.add_child(slot)


func _on_upgrade_info(id: String) -> void:
        var u: Dictionary = UpgradeDB.get_upgrade(id)
        if u.is_empty():
                return
        _toast(I18n.t(String(u["name_key"])), I18n.t(String(u["desc_key"])), String(u["icon"]))


func _on_coins_changed(coins: int) -> void:
        if coin_label != null:
                coin_label.text = str(coins)


## Non-blocking toast banner (upgrades, coin gains). Auto-removes itself.
func _toast(title: String, sub := "", icon_path := "", badge := "") -> void:
        if toast_box == null:
                return
        var panel := PanelContainer.new()
        panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
        panel.add_theme_stylebox_override("panel", UIKit.panel_style())
        panel.modulate = Color(1, 1, 1, 0)
        var h := HBoxContainer.new()
        h.mouse_filter = Control.MOUSE_FILTER_IGNORE
        h.add_theme_constant_override("separation", 14)
        panel.add_child(h)
        if icon_path != "":
                h.add_child(UIKit.icon(icon_path, 64))
        var v := VBoxContainer.new()
        v.mouse_filter = Control.MOUSE_FILTER_IGNORE
        v.add_theme_constant_override("separation", 2)
        h.add_child(v)
        v.add_child(UIKit.label(title, 30, UIKit.COL_GOLD))
        if sub != "":
                v.add_child(UIKit.label(sub, 26, UIKit.COL_TEXT))
        if badge != "":
                h.add_child(UIKit.chip(badge, UIKit.COL_GOLD))
        toast_box.add_child(panel)
        var tw := panel.create_tween()
        tw.tween_property(panel, "modulate:a", 1.0, 0.18)
        tw.tween_interval(1.7)
        tw.tween_property(panel, "modulate:a", 0.0, 0.35)
        tw.tween_callback(panel.queue_free)


# -------------------------------------------------------------- player turn

func _begin_player_turn() -> void:
        if game_over:
                return
        var legal := ChessRules.all_legal_moves(state)
        if legal.is_empty():
                if is_pvp:
                        _show_pvp_result(state.turn if ChessRules.in_check(state, state.turn) else 0)
                elif ChessRules.in_check(state, ChessState.WHITE):
                        _lose_battle(I18n.t("res_mate_lose"))
                else:
                        _lose_battle(I18n.t("res_stalemate_lose"))
                return
        _refresh_check_indicator()
        if is_pvp:
                var white_turn: bool = state.turn > 0
                if ChessRules.in_check(state, state.turn):
                        _set_status(I18n.t("b_check_white" if white_turn else "b_check_black"), true)
                else:
                        _set_status(I18n.t("b_white_turn" if white_turn else "b_black_turn"))
        else:
                if ChessRules.in_check(state, ChessState.WHITE):
                        _set_status(I18n.t("b_check_you"), true)
                else:
                        _set_status(I18n.t("b_your_turn"))
        _update_undo_button()
        board_view.refresh()


func _update_undo_button() -> void:
        if undo_btn == null:
                return
        undo_btn.text = "%s (%d)" % [I18n.t("b_undo"), RunManager.undo_tokens] \
                        if _can_undo() else I18n.t("b_undo")
        undo_btn.disabled = not _can_undo()


func _can_undo() -> bool:
        return not is_pvp and RunManager.undo_tokens > 0 \
                        and not guard_fired and not game_over and history.size() >= 2


func _on_square_tapped(sq: int) -> void:
        if game_over or ai_thinking or overlay_open or board_view.input_locked:
                return
        var piece: int = state.board[sq]
        if selected_sq == -1:
                if _owns(piece):
                        _select_piece(sq)
                elif piece != 0:
                        _log(I18n.t("b_enemy_piece") if not is_pvp else I18n.t("b_wrong_turn"))
                return
        if sq == selected_sq:
                _deselect()
                return
        if _owns(piece):
                _select_piece(sq)
                return
        var candidates: Array = current_moves.filter(func(m): return m["to"] == sq)
        if candidates.is_empty():
                _deselect()
                return
        var promo_moves: Array = candidates.filter(func(m): return m["promo"] != 0)
        if promo_moves.is_empty():
                _execute_player_move(candidates[0])
        else:
                _show_promotion_dialog(promo_moves)


## Does this piece belong to the side that may move now?
func _owns(piece: int) -> bool:
        if piece == 0:
                return false
        return piece > 0 if state.turn > 0 else piece < 0


func _select_piece(sq: int) -> void:
        current_moves = ChessRules.legal_moves_from(state, sq)
        selected_sq = sq
        board_view.set_selection(sq, current_moves.map(func(m): return m["to"]))
        if current_moves.is_empty():
                _log(I18n.t("b_no_moves"))
        else:
                _log(I18n.fmt("b_moves_hint", [current_moves.size()]))
        board_view.refresh()


func _deselect() -> void:
        selected_sq = -1
        current_moves = []
        board_view.clear_selection()
        board_view.refresh()


## Animate + wait (poll latch so a fast tween can never be missed).
func _animate_and_wait(move: Dictionary) -> void:
        _anim_flag = false
        board_view.move_finished.connect(func(): _anim_flag = true, CONNECT_ONE_SHOT)
        board_view.refresh()  # sync highlights/nodes with committed state
        board_view.animate_move(move)
        var guard := 0
        while not _anim_flag and guard < 600:
                guard += 1
                await get_tree().process_frame


# ------------------------------------------------------------- move commit

func _execute_player_move(move: Dictionary) -> void:
        var undo := ChessRules.make_move(state, move)
        history.append({"undo": undo, "move": move})
        AudioManager.play_sfx("move")
        _deselect()
        var status := ChessRules.get_status(state)
        var gains := {}
        if not is_pvp and int(move["cap"]) != 0:
                gains = RunManager.on_player_capture(int(move["cap"]), int(move["piece"]))
        board_view.refresh_highlights()
        _refresh_check_indicator()
        _update_undo_button()

        # start the AI search NOW, in parallel with the move animation
        if not is_pvp and status == "ongoing":
                _start_ai_compute()

        await _animate_and_wait(move)

        if not is_pvp:
                _announce_player_effects(move, gains)
        if status == "checkmate":
                if is_pvp:
                        _show_pvp_result(state.turn)  # the mated side
                elif ChessRules.in_check(state, ChessState.WHITE):
                        _lose_battle(I18n.t("res_mate_lose"))
                else:
                        _win_battle(I18n.t("res_mate_win"))
                return
        if status == "stalemate":
                if is_pvp:
                        _show_pvp_result(0)
                else:
                        _win_battle(I18n.t("res_stalemate_win"))
                return
        if is_pvp:
                _begin_player_turn()
                return
        # AI mode: await the (already running) search, then reply instantly
        var ranked := await _wait_ai_result()
        if _exiting or game_over:
                return
        await _execute_ai_move(ranked)


## Coins / upgrade toasts + log line for the player's move.
func _announce_player_effects(move: Dictionary, gains: Dictionary) -> void:
        var who := I18n.t("log_you")
        if int(move["cap"]) != 0:
                _log("%s: %s x%s" % [who, _sq_text(move), _piece_name(int(move["cap"]))])
        else:
                _log("%s: %s" % [who, _sq_text(move)])
        if gains.is_empty():
                return
        var lines: Array = []
        if knight_inspire_active and absi(int(move["piece"])) == ChessState.KNIGHT:
                var c2 := RunManager.gain_multiplied(Balance.KNIGHT_INSPIRE_COINS)
                lines.append(I18n.fmt("fx_knight_inspire", [c2]))
        if int(gains.get("coins", 0)) > 0:
                lines.append(I18n.fmt("cap_coins", [int(gains["coins"])]))
        var up_id := String(gains.get("upgrade", ""))
        if up_id != "":
                var u: Dictionary = UpgradeDB.get_upgrade(up_id)
                AudioManager.play_sfx("upgrade")
                _toast(I18n.fmt("cap_new_upgrade", [I18n.t(String(u["name_key"]))]),
                                " ".join(lines), String(u["icon"]))
        elif not lines.is_empty():
                _toast(" ".join(lines), "", "res://assets/ui/icon_coin.png")


# ----------------------------------------------------------------- AI turn

func _start_ai_compute() -> void:
        ai_thinking = true
        _ai_flag = false
        _ai_waited = 0.0
        _set_status(I18n.t("b_thinking"), true)
        if undo_btn != null:
                undo_btn.disabled = true
        var clone := state.duplicate()
        var depth := int(cfg.get("depth", 2))
        var jitter := float(cfg.get("jitter", 0.0)) + RunManager.mod_jitter
        _ai_thread = Thread.new()
        var err := _ai_thread.start(_ai_worker.bind(clone, depth, jitter))
        if err != OK:
                # Threadless builds (Web export without thread support):
                # fall back to a deferred synchronous compute on the main loop.
                call_deferred("_ai_worker", clone, depth, jitter)


func _ai_worker(search_state: ChessState, depth: float, jitter: float) -> void:
        var ranked := ChessAI.search_root(search_state, int(depth), jitter)
        call_deferred("_on_ai_computed", ranked)


func _on_ai_computed(ranked: Array) -> void:
        if _ai_thread != null and _ai_thread.is_started():
                _ai_thread.wait_to_finish()
        _ai_thread = null
        ai_thinking = false
        _ai_ranked = ranked
        _ai_flag = true


## Waits for the AI search that started during the player's animation.
func _wait_ai_result() -> Array:
        while not _ai_flag and _ai_waited < AI_SAFETY_TIMEOUT:
                await get_tree().process_frame
                _ai_waited += get_process_delta_time()
        if not _ai_flag:
                # safety net: never soft-lock; take a random legal move
                _ai_ranked = ChessRules.all_legal_moves(state).map(
                                func(m): return {"move": m, "score": 0})
        ai_thinking = false
        return _ai_ranked


func _execute_ai_move(ranked: Array) -> void:
        if ranked.is_empty():
                _begin_player_turn()
                return
        var chosen := _pick_ai_move(ranked)
        var undo := ChessRules.make_move(state, chosen)
        history.append({"undo": undo, "move": chosen})
        AudioManager.play_sfx("move")
        await _animate_and_wait(chosen)
        _log("%s: %s%s" % [I18n.t("log_enemy"), _sq_text(chosen),
                        " x%s" % _piece_name(int(chosen["cap"])) if int(chosen["cap"]) != 0 else ""])
        _refresh_check_indicator()
        board_view.refresh()
        _update_undo_button()
        var status := ChessRules.get_status(state)
        if status == "checkmate":
                if _try_royal_guard(chosen):
                        return
                _lose_battle(I18n.t("res_mate_lose"))
                return
        if status == "stalemate":
                _lose_battle(I18n.t("res_stalemate_lose"))
                return
        _begin_player_turn()


func _pick_ai_move(ranked: Array) -> Dictionary:
        var moves: Array = ranked.map(func(r): return r["move"])
        # IRON PAWNS: prevent the enemy's best move from capturing a white pawn.
        if RunManager.has_upgrade("iron_pawns") and not RunManager.iron_pawns_used \
                        and not moves.is_empty() and moves[0]["cap"] == ChessState.PAWN:
                var alt: Array = moves.filter(func(m): return m["cap"] != ChessState.PAWN)
                if not alt.is_empty():
                        RunManager.iron_pawns_used = true
                        _log(I18n.t("fx_iron_pawns"))
                        _refresh_upgrade_row()
                        moves = alt
        # blunder chance (weaker difficulties sometimes pick a worse move)
        var blunder := minf(float(cfg.get("blunder", 0.0)) + RunManager.mod_blunder, 0.5)
        if blunder > 0.0 and moves.size() > 1 and randf() < blunder:
                return moves[randi_range(1, mini(moves.size() - 1, 4))]
        return moves[0]


## Returns true if a save (ROYAL GUARD charge or PHOENIX FEATHER) rescued
## the player: the mating attacker is destroyed and the battle continues.
func _try_royal_guard(mate_move: Dictionary) -> bool:
        var phoenix := RunManager.guard_charges <= 0 \
                        and RunManager.has_upgrade("phoenix") and not RunManager.phoenix_used
        if RunManager.guard_charges <= 0 and not phoenix:
                return false
        var used_phoenix := phoenix
        if used_phoenix:
                RunManager.phoenix_used = true
        else:
                RunManager.guard_charges -= 1
        guard_fired = true
        var attacker: int = state.board[mate_move["to"]]
        state.board[mate_move["to"]] = 0
        board_view.animate_removal(int(mate_move["to"]))
        if used_phoenix:
                _log(I18n.fmt("fx_phoenix_fired", [_piece_name(attacker).to_lower()]))
        else:
                _log(I18n.fmt("fx_guard_fired", [_piece_name(attacker).to_lower()]))
        _refresh_check_indicator()
        board_view.refresh()
        _refresh_upgrade_row()
        if ChessRules.get_status(state) == "checkmate":
                return false  # still trapped (rare double-check corner) -> defeat
        _set_status(I18n.t("fx_guard_saved") if not used_phoenix else I18n.t("fx_phoenix_saved"),
                        true)
        _begin_player_turn()
        return true


# ------------------------------------------------------------ undo / forfeit

func _on_undo_pressed() -> void:
        if not _can_undo() or ai_thinking or game_over or overlay_open or board_view.input_locked:
                return
        var ai_rec: Dictionary = history.pop_back()
        ChessRules.undo_move(state, ai_rec["undo"])
        var pl_rec: Dictionary = history.pop_back()
        ChessRules.undo_move(state, pl_rec["undo"])
        RunManager.undo_tokens -= 1
        _deselect()
        _log(I18n.t("fx_second_chance"))
        _refresh_upgrade_row()
        _begin_player_turn()


func _on_forfeit_pressed() -> void:
        if game_over or overlay_open:
                return
        _push_overlay()
        var vbox := UIKit.modal(overlay)
        vbox.add_child(UIKit.title_label(I18n.t("b_forfeit_title"), 60))
        vbox.add_child(UIKit.para(I18n.t("b_forfeit_pvp") if is_pvp else I18n.t("b_forfeit_text"), 36))
        var row := HBoxContainer.new()
        row.alignment = BoxContainer.ALIGNMENT_CENTER
        row.add_theme_constant_override("separation", 20)
        vbox.add_child(row)
        var yes := UIKit.button(I18n.t("btn_yes"), 40, "danger", Vector2(300, 104))
        yes.pressed.connect(func():
                _close_overlay()
                if is_pvp:
                        GameManager.goto_main_menu()
                else:
                        _lose_battle(I18n.t("res_forfeit")))
        row.add_child(yes)
        var no := UIKit.button(I18n.t("btn_no"), 40, "primary", Vector2(300, 104))
        no.pressed.connect(_close_overlay)
        row.add_child(no)


# ----------------------------------------------------------------- promotion

func _show_promotion_dialog(promo_moves: Array) -> void:
        pending_promo = promo_moves
        _push_overlay()
        var white := state.turn > 0
        var vbox := UIKit.modal(overlay)
        vbox.add_child(UIKit.title_label(I18n.t("promo_title"), 64))
        vbox.add_child(UIKit.para(I18n.t("promo_text"), 34))
        var row := HBoxContainer.new()
        row.alignment = BoxContainer.ALIGNMENT_CENTER
        row.add_theme_constant_override("separation", 20)
        vbox.add_child(row)
        var color := "w" if white else "b"
        for pr in [ChessState.QUEEN, ChessState.ROOK, ChessState.BISHOP, ChessState.KNIGHT]:
                var b := Button.new()
                b.custom_minimum_size = Vector2(180, 180)
                b.focus_mode = Control.FOCUS_NONE
                var sb := UIKit.style_texture("res://assets/ui/panel.png", 8, 8)
                b.add_theme_stylebox_override("normal", sb)
                b.add_theme_stylebox_override("hover", sb)
                b.add_theme_stylebox_override("pressed", sb)
                var icon := UIKit.icon("res://assets/pixel/piece_%s_%s.png" % [color, _promo_file(pr)], 140)
                icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
                b.add_child(icon)
                b.pressed.connect(_on_promote.bind(pr))
                row.add_child(b)


func _promo_file(pr: int) -> String:
        match pr:
                ChessState.QUEEN: return "queen"
                ChessState.ROOK: return "rook"
                ChessState.BISHOP: return "bishop"
                _: return "knight"


func _on_promote(pr: int) -> void:
        for m in pending_promo:
                if m["promo"] == pr:
                        _close_overlay()
                        _execute_player_move(m)
                        return


func _close_overlay() -> void:
        overlay_open = false
        if overlay != null:
                overlay.queue_free()
                overlay = null


# --------------------------------------------------------------- win / lose

func _push_overlay() -> void:
        if overlay != null:
                overlay.queue_free()
        overlay = Control.new()
        overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        add_child(overlay)
        overlay_open = true


func _piece_name(piece: int) -> String:
        match absi(piece):
                ChessState.PAWN: return I18n.t("p_pawn")
                ChessState.KNIGHT: return I18n.t("p_knight")
                ChessState.BISHOP: return I18n.t("p_bishop")
                ChessState.ROOK: return I18n.t("p_rook")
                ChessState.QUEEN: return I18n.t("p_queen")
                _: return I18n.t("p_king")


func _sq_text(move: Dictionary) -> String:
        return "%s-%s" % [ChessState.sq_name(move["from"]), ChessState.sq_name(move["to"])]


func _win_battle(how: String) -> void:
        if game_over:
                return
        game_over = true
        AudioManager.play_sfx("win")
        board_view.clear_selection()
        _refresh_check_indicator()
        board_view.refresh()
        var is_boss := bool(cfg.get("is_boss", false))
        var bd := RunManager.on_battle_won(int(cfg.get("base_coins", 10)), is_boss)
        _set_status(I18n.t("boss_fallen") if is_boss else I18n.t("res_victory"),
                        false)
        var lines: Array = [how,
                        I18n.fmt("res_reward", [int(bd["base"])])]
        if float(bd["mult"]) > 1.0:
                lines.append(I18n.fmt("res_momentum", [float(bd["mult"])]))
        if float(bd["treasure"]) > 1.0:
                lines.append(I18n.t("res_treasure"))
        lines.append(I18n.fmt("res_total", [int(bd["total"])]))
        if not RunManager.upgrades_gained_battle.is_empty():
                lines.append(I18n.fmt("res_upgrades_battle",
                                [", ".join(PackedStringArray(RunManager.upgrades_gained_battle))]))
        if is_boss:
                lines.append("")
                lines.append(I18n.fmt("res_battles", [RunManager.battles_completed]))
                lines.append(I18n.fmt("res_coins_earned", [RunManager.coins_earned]))
                lines.append(I18n.fmt("res_upgrades", [RunManager.upgrades_text()]))
                _show_result(I18n.t("res_run_complete"), lines,
                                [["NEW RUN", _on_new_run], ["MAIN MENU", _on_main_menu]], "success")
        else:
                _show_result(I18n.t("res_victory"), lines, [["CONTINUE", _on_continue]], "success")


func _lose_battle(reason: String) -> void:
        if game_over:
                return
        game_over = true
        AudioManager.play_sfx("lose")
        board_view.clear_selection()
        board_view.refresh()
        _set_status(I18n.t("res_defeat"), true)
        var lines: Array = [reason, "",
                        I18n.fmt("res_battles", [RunManager.battles_completed]),
                        I18n.fmt("res_coins_earned", [RunManager.coins_earned]),
                        I18n.fmt("res_upgrades", [RunManager.upgrades_text()])]
        _show_result(I18n.t("res_run_failed"), lines,
                        [["NEW RUN", _on_new_run], ["MAIN MENU", _on_main_menu]], "danger")


## PvP end: mated = 1 white is mated (black wins), -1 black is mated
## (white wins), 0 stalemate -> draw.
func _show_pvp_result(mated: int) -> void:
        if game_over:
                return
        game_over = true
        board_view.clear_selection()
        _refresh_check_indicator()
        board_view.refresh()
        _set_status("", false)
        var title: String
        var line: String
        var style := "success"
        if mated == 1:
                title = I18n.t("res_black_wins")
                line = I18n.t("res_mate_neutral")
        elif mated == -1:
                title = I18n.t("res_white_wins")
                line = I18n.t("res_mate_neutral")
        else:
                title = I18n.t("res_draw")
                line = I18n.t("res_stalemate_neutral")
                style = "primary"
        _show_result(title, [line],
                        [["REMATCH", _on_rematch], ["MAIN MENU", _on_main_menu]], style)


func _show_result(title: String, lines: Array, buttons: Array, style: String) -> void:
        if overlay != null:
                overlay.queue_free()
        _push_overlay()
        var vbox := UIKit.modal(overlay)
        var crown_row := HBoxContainer.new()
        crown_row.alignment = BoxContainer.ALIGNMENT_CENTER
        crown_row.add_child(UIKit.icon(
                        "res://assets/ui/ui_crown.png" if style == "success" else "res://assets/ui/icon_x.png", 110))
        vbox.add_child(crown_row)
        vbox.add_child(UIKit.title_label(title, 72,
                        UIKit.COL_GOLD if style == "success" else UIKit.COL_BAD))
        for line in lines:
                vbox.add_child(UIKit.para(String(line), 36))
        vbox.add_child(UIKit.vspace(8))
        var row := HBoxContainer.new()
        row.alignment = BoxContainer.ALIGNMENT_CENTER
        row.add_theme_constant_override("separation", 20)
        vbox.add_child(row)
        for b in buttons:
                var key := String(b[0])
                var text := I18n.t("btn_new_run") if key == "NEW RUN" \
                                else I18n.t("btn_main_menu") if key == "MAIN MENU" \
                                else I18n.t("btn_rematch") if key == "REMATCH" \
                                else I18n.t("btn_continue")
                var st := style if key == "CONTINUE" else \
                                ("danger" if key == "MAIN MENU" else "primary")
                if key == "REMATCH":
                        st = "success"
                var btn := UIKit.button(text, 40, st, Vector2(380, 110))
                btn.pressed.connect(b[1])
                row.add_child(btn)


func _on_continue() -> void:
        GameManager.after_battle_victory()


func _on_new_run() -> void:
        GameManager.start_ai_run()


func _on_main_menu() -> void:
        GameManager.goto_main_menu()


func _on_rematch() -> void:
        GameManager.start_pvp()


# ------------------------------------------------------------------ boss

func _show_boss_intro() -> void:
        _push_overlay()
        UIKit.bg_image(overlay, "res://assets/ui/bg_boss.png", 0.45)
        var vbox := UIKit.modal(overlay)
        var icon_row := HBoxContainer.new()
        icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
        icon_row.add_child(UIKit.icon("res://assets/ui/boss_king.png", 180))
        vbox.add_child(icon_row)
        vbox.add_child(UIKit.title_label(I18n.t("boss_title"), 58, UIKit.COL_BAD))
        vbox.add_child(UIKit.para(I18n.fmt("boss_intro", [state.corrupted.size()]), 34))
        vbox.add_child(UIKit.vspace(6))
        board_view.set_corrupted(state.corrupted)
        board_view.refresh()
        var begin := UIKit.button(I18n.t("boss_begin"), 46, "danger", Vector2(620, 116))
        begin.pressed.connect(_on_boss_begin)
        var c := CenterContainer.new()
        c.add_child(begin)
        vbox.add_child(c)


func _on_boss_begin() -> void:
        _close_overlay()
        var lucky := RunManager.begin_battle()
        if lucky > 0:
                _toast(I18n.fmt("fx_lucky_start", [lucky]), "", "res://assets/ui/icon_coin.png")
        _begin_player_turn()
