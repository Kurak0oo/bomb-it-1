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
		if child in [236, 293]:
			number = variant
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
