class_name Explosion
extends RefCounted

enum Phase { GROWING, LINGER, FADE }

const STYLE_CENTER := 0
const STYLE_ARM := 1
const STYLE_TIP := 2

var origin := Vector2i.ZERO
var level := SimRules.BOMB_LEVEL
var exp_pos := 0
var phase := Phase.GROWING
var linger := 0
var alpha := 100.0
var open: Array[bool]
var painted: Array[Vector2i]
var style_of: Array[int]
var dir_of: Array[int]


func _init(at: Vector2i, bomb_level: int) -> void:
	origin = at
	level = bomb_level
	open = [true, true, true, true]
	painted = [at]
	style_of = [STYLE_CENTER]
	dir_of = [-1]
