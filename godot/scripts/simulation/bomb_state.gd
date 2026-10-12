class_name BombState
extends RefCounted

var owner_id := 0
var cell := Vector2i.ZERO
var fuse := SimRules.FUSE_TICKS
var level := SimRules.BOMB_LEVEL
var just_placed := true
var slide_direction := Vector2i.ZERO
var slide_ticks := 0
var previous_cell := Vector2i.ZERO


func _init(at: Vector2i, owner: int = 0) -> void:
	cell = at
	owner_id = owner
