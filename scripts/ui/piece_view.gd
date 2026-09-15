class_name PieceView
extends TextureRect
## ONE chess piece node. Its geometry is owned ENTIRELY by BoardView's
## authoritative coordinate system:
##
##   * `set_square_size()`  -> node fills exactly one board square and its
##                             pivot (transform origin for scale/rotate) is
##                             locked to the node's exact center, so capture
##                             shrink / any future scaling stays symmetric.
##   * `set_square_center()`-> places the node so that its TRUE visual center
##                             sits exactly on the calculated square-center.
##
## No manual pixel offsets are permitted anywhere. The full sprite canvas
## (normalized 180x180, visible content centered by contract) maps 1:1 onto
## the square, therefore the VISIBLE piece center == square center.
##
## IMPLEMENTATION NOTE: the node keeps its own authoritative copy of the
## geometry (`_square_center` / `_square_size`). Control.position/size
## getters are backed by a transform cache that can lag one frame behind a
## same-frame write; reading our fields is always exact and synchronous,
## which keeps validation, debug markers and post-animation snaps precise.
## ALL placement MUST go through set_square_center() - nothing else may
## move a piece.

var piece := 0            # signed piece code (ChessState)
var sq := -1              # square index 0..63 this node currently occupies

var _square_size := Vector2.ZERO
var _square_center := Vector2.ZERO


func _init(piece_arg := 0, sq_arg := -1) -> void:
	piece = piece_arg
	sq = sq_arg
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Resize the node to exactly one square and center the pivot.
func set_square_size(s: Vector2) -> void:
	_square_size = s
	size = s
	pivot_offset = s * 0.5


## Place the node so its exact center sits on `center` (board-local point).
func set_square_center(center: Vector2) -> void:
	_square_center = center
	position = center - _square_size * 0.5


## The node's current visual center - exact, synchronous truth.
func center_pos() -> Vector2:
	return _square_center


## Deviation between this node's visual center and an expected point.
func deviation_from(expected: Vector2) -> float:
	return (_square_center - expected).length()
