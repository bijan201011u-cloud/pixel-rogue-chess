class_name ChessRules
## Complete chess rules: legal move generation (castling, en passant,
## promotion, double push), check / checkmate / stalemate detection,
## make/undo with full state restore. Pure logic, no rendering.

const WHITE := 1
const BLACK := -1

const FLAG_NORMAL := 0
const FLAG_DOUBLE := 1
const FLAG_EP := 2
const FLAG_CASTLE_K := 3
const FLAG_CASTLE_Q := 4

const KNIGHT_OFFSETS := [[1, 2], [2, 1], [2, -1], [1, -2], [-1, -2], [-2, -1], [-2, 1], [-1, 2]]
const KING_OFFSETS := [[1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1], [0, -1], [1, -1]]
const DIAG_DIRS := [[1, 1], [1, -1], [-1, 1], [-1, -1]]
const ORTHO_DIRS := [[1, 0], [-1, 0], [0, 1], [0, -1]]


static func create_initial_state() -> ChessState:
	var s := ChessState.new()
	var back := [ChessState.ROOK, ChessState.KNIGHT, ChessState.BISHOP, ChessState.QUEEN,
			ChessState.KING, ChessState.BISHOP, ChessState.KNIGHT, ChessState.ROOK]
	for x in 8:
		s.board[x] = -back[x]
		s.board[8 + x] = -ChessState.PAWN
		s.board[48 + x] = ChessState.PAWN
		s.board[56 + x] = back[x]
	s.turn = ChessState.WHITE
	s.castling = {"wk": true, "wq": true, "bk": true, "bq": true}
	s.ep_square = -1
	s.corrupted = []
	return s


static func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < 8 and y >= 0 and y < 8


# ------------------------------------------------------------------ move gen

static func _add_move(moves: Array, state: ChessState, from: int, to: int,
		piece: int, cap: int, cap_sq: int, flag: int, promo: int) -> void:
	# Boss CORRUPTION: white pieces may never land on a corrupted square.
	if piece > 0 and state.corrupted.has(to):
		return
	moves.append({
		"from": from, "to": to, "piece": piece, "cap": cap,
		"cap_sq": cap_sq, "flag": flag, "promo": promo,
	})


static func generate_pseudo_moves(state: ChessState, from: int) -> Array:
	var moves: Array = []
	var piece: int = state.board[from]
	if piece == 0:
		return moves
	var x := from % 8
	var y := from >> 3
	var t := absi(piece)
	match t:
		ChessState.PAWN:
			_gen_pawn(moves, state, from, x, y)
		ChessState.KNIGHT:
			for o in KNIGHT_OFFSETS:
				var nx: int = x + o[0]
				var ny: int = y + o[1]
				if in_bounds(nx, ny):
					_try_step(moves, state, from, ny * 8 + nx)
		ChessState.BISHOP:
			_gen_slides(moves, state, from, DIAG_DIRS)
		ChessState.ROOK:
			_gen_slides(moves, state, from, ORTHO_DIRS)
		ChessState.QUEEN:
			_gen_slides(moves, state, from, DIAG_DIRS)
			_gen_slides(moves, state, from, ORTHO_DIRS)
		ChessState.KING:
			for o in KING_OFFSETS:
				var nx: int = x + o[0]
				var ny: int = y + o[1]
				if in_bounds(nx, ny):
					_try_step(moves, state, from, ny * 8 + nx)
			_gen_castles(moves, state, from)
	return moves


static func _try_step(moves: Array, state: ChessState, from: int, to: int) -> void:
	var piece: int = state.board[from]
	var target: int = state.board[to]
	if target == 0:
		_add_move(moves, state, from, to, piece, 0, to, FLAG_NORMAL, 0)
	elif (target > 0) != (piece > 0):
		_add_move(moves, state, from, to, piece, target, to, FLAG_NORMAL, 0)


static func _gen_slides(moves: Array, state: ChessState, from: int, dirs: Array) -> void:
	var piece: int = state.board[from]
	var x := from % 8
	var y := from >> 3
	for d in dirs:
		var nx: int = x + d[0]
		var ny: int = y + d[1]
		while in_bounds(nx, ny):
			var to: int = ny * 8 + nx
			var target: int = state.board[to]
			if target == 0:
				_add_move(moves, state, from, to, piece, 0, to, FLAG_NORMAL, 0)
			else:
				if (target > 0) != (piece > 0):
					_add_move(moves, state, from, to, piece, target, to, FLAG_NORMAL, 0)
				break
			nx += d[0]
			ny += d[1]


static func _gen_pawn(moves: Array, state: ChessState, from: int, x: int, y: int) -> void:
	var piece: int = state.board[from]
	var white := piece > 0
	var dir := -1 if white else 1
	var start_y := 6 if white else 1
	var promo_y := 0 if white else 7
	var ny: int = y + dir
	if not in_bounds(x, ny):
		return
	var one: int = ny * 8 + x
	# pushes
	if state.board[one] == 0:
		if ny == promo_y:
			for pr in [ChessState.QUEEN, ChessState.ROOK, ChessState.BISHOP, ChessState.KNIGHT]:
				_add_move(moves, state, from, one, piece, 0, one, FLAG_NORMAL, pr)
		else:
			_add_move(moves, state, from, one, piece, 0, one, FLAG_NORMAL, 0)
		if y == start_y:
			var two: int = (ny + dir) * 8 + x
			if state.board[two] == 0:
				_add_move(moves, state, from, two, piece, 0, two, FLAG_DOUBLE, 0)
	# captures
	for dx in [-1, 1]:
		var nx: int = x + dx
		if not in_bounds(nx, ny):
			continue
		var to: int = ny * 8 + nx
		var target: int = state.board[to]
		if target != 0 and (target > 0) != (piece > 0):
			if ny == promo_y:
				for pr in [ChessState.QUEEN, ChessState.ROOK, ChessState.BISHOP, ChessState.KNIGHT]:
					_add_move(moves, state, from, to, piece, target, to, FLAG_NORMAL, pr)
			else:
				_add_move(moves, state, from, to, piece, target, to, FLAG_NORMAL, 0)
		elif state.ep_square >= 0 and to == state.ep_square:
			var cap_sq: int = to - dir * 8
			_add_move(moves, state, from, to, piece, state.board[cap_sq], cap_sq, FLAG_EP, 0)


static func _gen_castles(moves: Array, state: ChessState, from: int) -> void:
	var piece: int = state.board[from]
	if piece != ChessState.KING and piece != -ChessState.KING:
		return
	var white := piece > 0
	if from != (60 if white else 4):
		return
	if is_square_attacked(state, from, -1 if white else 1):
		return
	if white:
		if state.castling.get("wk", false) and state.board[61] == 0 and state.board[62] == 0 \
				and state.board[63] == ChessState.ROOK \
				and not is_square_attacked(state, 61, -1) and not is_square_attacked(state, 62, -1):
			_add_move(moves, state, 60, 62, piece, 0, 62, FLAG_CASTLE_K, 0)
		if state.castling.get("wq", false) and state.board[59] == 0 and state.board[58] == 0 \
				and state.board[57] == 0 and state.board[56] == ChessState.ROOK \
				and not is_square_attacked(state, 59, -1) and not is_square_attacked(state, 58, -1):
			_add_move(moves, state, 60, 58, piece, 0, 58, FLAG_CASTLE_Q, 0)
	else:
		if state.castling.get("bk", false) and state.board[5] == 0 and state.board[6] == 0 \
				and state.board[7] == -ChessState.ROOK \
				and not is_square_attacked(state, 5, 1) and not is_square_attacked(state, 6, 1):
			_add_move(moves, state, 4, 6, piece, 0, 6, FLAG_CASTLE_K, 0)
		if state.castling.get("bq", false) and state.board[3] == 0 and state.board[2] == 0 \
				and state.board[1] == 0 and state.board[0] == -ChessState.ROOK \
				and not is_square_attacked(state, 3, 1) and not is_square_attacked(state, 2, 1):
			_add_move(moves, state, 4, 2, piece, 0, 2, FLAG_CASTLE_Q, 0)


# -------------------------------------------------------------------- attack

static func is_square_attacked(state: ChessState, sq: int, by: int) -> bool:
	var x := sq % 8
	var y := sq >> 3
	var b: Array = state.board
	# pawns: a white pawn on (x±1, y+1) attacks (x, y); black pawn from (x±1, y-1)
	var py: int = y + 1 if by == 1 else y - 1
	if py >= 0 and py < 8:
		var pawn_code: int = ChessState.PAWN if by == 1 else -ChessState.PAWN
		for dx in [-1, 1]:
			var nx: int = x + dx
			if nx >= 0 and nx < 8 and b[py * 8 + nx] == pawn_code:
				return true
	# knights
	for o in KNIGHT_OFFSETS:
		var nx: int = x + o[0]
		var ny: int = y + o[1]
		if in_bounds(nx, ny) and b[ny * 8 + nx] == ChessState.KNIGHT * by:
			return true
	# enemy king
	for o in KING_OFFSETS:
		var nx: int = x + o[0]
		var ny: int = y + o[1]
		if in_bounds(nx, ny) and b[ny * 8 + nx] == ChessState.KING * by:
			return true
	# sliders
	for kind in [[DIAG_DIRS, ChessState.BISHOP], [ORTHO_DIRS, ChessState.ROOK]]:
		for d in kind[0]:
			var nx: int = x + d[0]
			var ny: int = y + d[1]
			while in_bounds(nx, ny):
				var v: int = b[ny * 8 + nx]
				if v != 0:
					if v == kind[1] * by or v == ChessState.QUEEN * by:
						return true
					break
				nx += d[0]
				ny += d[1]
	return false


static func find_king(state: ChessState, color: int) -> int:
	var target: int = ChessState.KING * color
	for i in 64:
		if state.board[i] == target:
			return i
	return -1


static func in_check(state: ChessState, color: int) -> bool:
	var k := find_king(state, color)
	if k < 0:
		return false
	return is_square_attacked(state, k, -color)


# ---------------------------------------------------------------- make / undo

static func make_move(state: ChessState, move: Dictionary) -> Dictionary:
	var undo := {
		"from": move["from"], "to": move["to"],
		"piece": move["piece"], "cap": move["cap"], "cap_sq": move["cap_sq"],
		"flag": move["flag"],
		"castling": state.castling.duplicate(),
		"ep": state.ep_square, "halfmove": state.halfmove,
	}
	var b: Array = state.board
	var piece: int = move["piece"]
	var color := 1 if piece > 0 else -1
	b[move["from"]] = 0
	if move["promo"] != 0:
		b[move["to"]] = move["promo"] * color
	else:
		b[move["to"]] = piece
	match int(move["flag"]):
		FLAG_EP:
			b[move["cap_sq"]] = 0
		FLAG_CASTLE_K:
			if color == 1:
				b[63] = 0
				b[61] = ChessState.ROOK
			else:
				b[7] = 0
				b[5] = -ChessState.ROOK
		FLAG_CASTLE_Q:
			if color == 1:
				b[56] = 0
				b[59] = ChessState.ROOK
			else:
				b[0] = 0
				b[3] = -ChessState.ROOK
	# castling rights
	if piece == ChessState.KING:
		state.castling["wk"] = false
		state.castling["wq"] = false
	elif piece == -ChessState.KING:
		state.castling["bk"] = false
		state.castling["bq"] = false
	for corner in [[63, "wk"], [56, "wq"], [7, "bk"], [0, "bq"]]:
		if move["from"] == corner[0] or move["to"] == corner[0]:
			state.castling[corner[1]] = false
	# en passant target
	state.ep_square = (move["from"] + move["to"]) >> 1 if move["flag"] == FLAG_DOUBLE else -1
	# clocks
	if piece == ChessState.PAWN or piece == -ChessState.PAWN or move["cap"] != 0:
		state.halfmove = 0
	else:
		state.halfmove += 1
	if color == -1:
		state.fullmove += 1
	state.turn = -color
	return undo


static func undo_move(state: ChessState, undo: Dictionary) -> void:
	var b: Array = state.board
	var piece: int = undo["piece"]
	var color := 1 if piece > 0 else -1
	b[undo["from"]] = piece
	b[undo["to"]] = 0 if undo["flag"] == FLAG_EP else undo["cap"]
	match int(undo["flag"]):
		FLAG_EP:
			b[undo["cap_sq"]] = undo["cap"]
		FLAG_CASTLE_K:
			if color == 1:
				b[61] = 0
				b[63] = ChessState.ROOK
			else:
				b[5] = 0
				b[7] = -ChessState.ROOK
		FLAG_CASTLE_Q:
			if color == 1:
				b[59] = 0
				b[56] = ChessState.ROOK
			else:
				b[3] = 0
				b[0] = -ChessState.ROOK
	state.castling = undo["castling"]
	state.ep_square = undo["ep"]
	state.halfmove = undo["halfmove"]
	if color == -1:
		state.fullmove -= 1
	state.turn = color


# ---------------------------------------------------------------- legality

static func legal_moves_from(state: ChessState, from: int) -> Array:
	var piece: int = state.board[from]
	if piece == 0:
		return []
	var color := 1 if piece > 0 else -1
	var result: Array = []
	for move in generate_pseudo_moves(state, from):
		var undo := make_move(state, move)
		var k := find_king(state, color)
		if not is_square_attacked(state, k, -color):
			result.append(move)
		undo_move(state, undo)
	return result


static func all_legal_moves(state: ChessState) -> Array:
	var result: Array = []
	var white_turn: bool = state.turn > 0
	for sq in 64:
		var piece: int = state.board[sq]
		if piece != 0 and (piece > 0) == white_turn:
			result.append_array(legal_moves_from(state, sq))
	return result


## Status of the side to move: "ongoing", "checkmate" or "stalemate".
static func get_status(state: ChessState) -> String:
	if all_legal_moves(state).is_empty():
		if in_check(state, state.turn):
			return "checkmate"
		return "stalemate"
	return "ongoing"


# ------------------------------------------------------------------ testing

## Move-count tree search used to verify rules correctness (perft numbers).
static func perft(state: ChessState, depth: int) -> int:
	if depth == 0:
		return 1
	var n := 0
	for move in all_legal_moves(state):
		var undo := make_move(state, move)
		n += perft(state, depth - 1)
		undo_move(state, undo)
	return n


static func state_from_fen(fen: String) -> ChessState:
	var s := ChessState.new()
	var parts := fen.split(" ", false)
	var rows: Array = parts[0].split("/")
	for r in rows.size():
		var x := 0
		for ch in rows[r]:
			if ch >= "1" and ch <= "8":
				x += int(ch)
			else:
				var t := 0
				match ch:
					"P": t = ChessState.PAWN
					"N": t = ChessState.KNIGHT
					"B": t = ChessState.BISHOP
					"R": t = ChessState.ROOK
					"Q": t = ChessState.QUEEN
					"K": t = ChessState.KING
					"p": t = -ChessState.PAWN
					"n": t = -ChessState.KNIGHT
					"b": t = -ChessState.BISHOP
					"r": t = -ChessState.ROOK
					"q": t = -ChessState.QUEEN
					"k": t = -ChessState.KING
				s.board[r * 8 + x] = t
				x += 1
	if parts.size() > 1:
		s.turn = 1 if parts[1] == "w" else -1
	if parts.size() > 2:
		s.castling = {
			"wk": parts[2].contains("K"), "wq": parts[2].contains("Q"),
			"bk": parts[2].contains("k"), "bq": parts[2].contains("q"),
		}
	if parts.size() > 3 and parts[3] != "-":
		var file := "abcdefgh".find(parts[3][0])
		var rank := int(parts[3][1])
		s.ep_square = (8 - rank) * 8 + file
	return s
