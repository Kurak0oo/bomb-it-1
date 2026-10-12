class_name OriginalTimeline
extends Node2D
## Replays recovered display transforms only; never runs ActionScript game rules.

var art: OriginalArt
var symbol: int
var layers: Array[Sprite2D] = []

func _ready() -> void:
	for track in art.manifest.timelines[str(symbol)].tracks:
		var sprite := Sprite2D.new()
		sprite.centered = false
		add_child(sprite)
		layers.append(sprite)
		# Symbol 236 draws body and eyes at separate Flash display-list depths.
		# Keeping them separate preserves overlap when the parent alpha fades.
		if track.any(func(placement): return placement != null and placement.symbol == 236):
			var eyes := art.sprite(234)
			sprite.add_child(eyes)
	show_frame(0)

func show_frame(index: int, child_age: int = 0, variant: int = 1) -> void:
	var tracks: Array = art.manifest.timelines[str(symbol)].tracks
	for i in tracks.size():
		var track: Array = tracks[i]
		var sprite := layers[i]
		var placement: Variant = track[clampi(index, 0, track.size() - 1)]
		sprite.visible = placement != null
		if placement == null:
			continue
		var child: int = placement.symbol
		var number := 1
		if child == 236:
			child = 233 if variant <= 2 else 235
			var eyes: Sprite2D = sprite.get_child(0)
			eyes.position = art.offset(234) - art.offset(child)
		elif child == 293:
			number = variant
		elif child == 209:
			number = variant
		elif child == 200:
			number = (variant - 1) % 4 + 1
		elif child == 304:
			number = child_age % 8 + 1
		elif child == 312:
			number = child_age + 1
		var m: Array = placement.matrix
		var basis := Transform2D(Vector2(m[0],m[1]), Vector2(m[2],m[3]), Vector2(m[4],m[5]))
		basis.origin += basis.basis_xform(art.offset(child))
		sprite.transform = basis
		sprite.texture = art.frame(child, number)
		sprite.modulate.a = placement.alpha
