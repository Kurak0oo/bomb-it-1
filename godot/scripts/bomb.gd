class_name Bomb
extends RefCounted

var cell := Vector2i.ZERO
var fuse := SimRules.FUSE_TICKS
var level := SimRules.BOMB_LEVEL
var just_placed := true


func _init(at: Vector2i) -> void:
	cell = at
