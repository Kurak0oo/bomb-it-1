class_name OriginalArt
extends RefCounted

var manifest: Dictionary
var textures: Dictionary = {}

func _init() -> void:
	manifest = JSON.parse_string(FileAccess.get_file_as_string("res://art/original/manifest.json"))
	for key in manifest:
		if not str(key).is_valid_int():
			continue
		var frames: Array[Texture2D] = []
		for i in int(manifest[key].frames):
			frames.append(load("res://art/original/%s/%d.%s" % [key, i + 1, manifest[key].get("extension", "png")]))
		textures[int(key)] = frames

func frame(symbol: int, number: int = 1) -> Texture2D:
	var frames: Array = textures[symbol]
	return frames[clampi(number - 1, 0, frames.size() - 1)]

func offset(symbol: int) -> Vector2:
	var point: Array = manifest[str(symbol)].offset
	return Vector2(point[0], point[1])

func sprite(symbol: int, number: int = 1) -> Sprite2D:
	var result := Sprite2D.new()
	result.centered = false
	result.texture = frame(symbol, number)
	result.position = offset(symbol)
	return result

static func depth(at: Vector2i, adjustment: int = 0) -> int:
	# Original calDepth(x,y,10). Fits inside Godot's ±4096 z-index range.
	return (at.y * SimRules.COLUMNS + (SimRules.COLUMNS - at.x)) * 10 + adjustment
