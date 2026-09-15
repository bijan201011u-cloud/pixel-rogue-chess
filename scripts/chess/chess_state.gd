class_name ChessState
extends RefCounted
## Pure chess position data. UI-independent and thread-safe when duplicated.
## Board: Array of 64 ints. Positive = white, negative = black, 0 = empty.
## Index 0 = a8 (top-left), index 63 = h1 (bottom-right).
## Piece codes: 1=P 2=N 3=B 4=R 5=Q 6=K.

const PAWN := 1
const KNIGHT := 2
const BISHOP := 3
const ROOK := 4
const QUEEN := 5
const KING := 6

const WHITE := 1
const BLACK := -1

var board: Array = []
var turn: int = WHITE
var castling: Dictionary = {"wk": true, "wq": true, "bk": true, "bq": true}
var ep_square: int = -1
var halfmove: int = 0
var fullmove: int = 1
## Boss modifier: square indices that WHITE pieces may not enter.
var corrupted: Array = []


func _init() -> void:
	board.resize(64)
	for i in 64:
		board[i] = 0


func duplicate() -> ChessState:
	var s := ChessState.new()
	s.board = board.duplicate()
	s.turn = turn
	s.castling = castling.duplicate()
	s.ep_square = ep_square
	s.halfmove = halfmove
	s.fullmove = fullmove
	s.corrupted = corrupted.duplicate()
	return s


static func piece_type(piece: int) -> int:
	return absi(piece)


static func color_of(piece: int) -> int:
	return 1 if piece > 0 else -1


static func sq_name(sq: int) -> String:
	var files := "abcdefgh"
	return files[sq % 8] + str(8 - (sq >> 3))
