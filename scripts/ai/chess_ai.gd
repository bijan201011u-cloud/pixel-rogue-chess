class_name ChessAI
## Negamax search with alpha-beta pruning and capture-first move ordering.
## Evaluation: material + light piece-square terms. Pure static logic that
## operates on its own (cloned) state, so it can run on a worker thread.

const MATE := 1000000
const PIECE_VALUES := {
	ChessState.PAWN: 100, ChessState.KNIGHT: 300, ChessState.BISHOP: 310,
	ChessState.ROOK: 500, ChessState.QUEEN: 900, ChessState.KING: 0,
}


static func evaluate(state: ChessState) -> int:
	var score := 0
	var b: Array = state.board
	for sq in 64:
		var v: int = b[sq]
		if v == 0:
			continue
		var t := absi(v)
		var white := v > 0
		var x := sq % 8
		var y := sq >> 3
		var bonus := 0
		match t:
			ChessState.PAWN:
				var adv := (6 - y) if white else (y - 1)
				bonus = adv * adv * 3
				if x >= 2 and x <= 5:
					bonus += 6
			ChessState.KNIGHT:
				bonus = _center_bonus(x, y) * 6
			ChessState.BISHOP:
				bonus = _center_bonus(x, y) * 4
			ChessState.QUEEN:
				bonus = _center_bonus(x, y) * 2
			ChessState.KING:
				if (white and y == 7) or (not white and y == 0):
					bonus = 12
		score += (PIECE_VALUES[t] + bonus) * (1 if white else -1)
	return score


static func _center_bonus(x: int, y: int) -> int:
	var dx := absi(x * 2 - 7)
	var dy := absi(y * 2 - 7)
	return (14 - dx - dy) >> 1


static func _move_order_score(move: Dictionary) -> int:
	var s := 0
	if move["cap"] != 0:
		s = 10 * PIECE_VALUES[absi(move["cap"])] - PIECE_VALUES[absi(move["piece"])]
	if move["promo"] != 0:
		s += PIECE_VALUES[move["promo"]]
	return s


## Returns [{"move": Dictionary, "score": int}, ...] sorted best-first from
## the perspective of the side to move.
## avoid_white_pawn_caps: used by the IRON PAWNS upgrade to exclude root moves
## that capture a white pawn.
static func search_root(state: ChessState, depth: int, jitter := 0.0,
		avoid_white_pawn_caps := false) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var moves := ChessRules.all_legal_moves(state)
	if avoid_white_pawn_caps:
		var filtered: Array = moves.filter(func(m): return m["cap"] != ChessState.PAWN)
		if not filtered.is_empty():
			moves = filtered
	moves.sort_custom(func(a, b): return _move_order_score(a) > _move_order_score(b))
	var results: Array = []
	var alpha := -MATE * 2
	for move in moves:
		var undo := ChessRules.make_move(state, move)
		var score: int
		if ChessRules.all_legal_moves(state).is_empty():
			score = MATE - 1 if ChessRules.in_check(state, state.turn) else 0
		else:
			score = -_negamax(state, depth - 1, -MATE * 2, -alpha, 1)
		ChessRules.undo_move(state, undo)
		if jitter > 0.0:
			score += int(rng.randf_range(-jitter, jitter) * 100.0)
		results.append({"move": move, "score": score})
		if score > alpha:
			alpha = score
	results.sort_custom(func(a, b): return a["score"] > b["score"])
	return results


static func _negamax(state: ChessState, depth: int, alpha: int, beta: int, ply: int) -> int:
	if depth <= 0:
		return state.turn * evaluate(state)
	var moves := ChessRules.all_legal_moves(state)
	if moves.is_empty():
		return (-MATE + ply) if ChessRules.in_check(state, state.turn) else 0
	moves.sort_custom(func(a, b): return _move_order_score(a) > _move_order_score(b))
	var best := -MATE * 2
	for move in moves:
		var undo := ChessRules.make_move(state, move)
		var score := -_negamax(state, depth - 1, -beta, -alpha, ply + 1)
		ChessRules.undo_move(state, undo)
		if score > best:
			best = score
		if best > alpha:
			alpha = best
		if alpha >= beta:
			break
	return best


static func get_best_move(state: ChessState, depth: int, jitter := 0.0) -> Dictionary:
	var ranked := search_root(state, depth, jitter)
	if ranked.is_empty():
		return {}
	return ranked[0]["move"]
