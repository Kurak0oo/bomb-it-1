class_name SpecialState
extends RefCounted

var kind := ""
var owner_id := 0
var origin := Vector2i.ZERO
var cell := Vector2i.ZERO
var direction := Vector2i.ZERO
var position := Vector2.ZERO
var age := 0
var just_placed := true
var painted: Array[Vector2i] = []
var born: Array[int] = []
var growth_stopped := false

func _init(weapon: String, owner: HeroState) -> void:
	kind = weapon
	owner_id = owner.id
	origin = owner.cell
	cell = origin
	direction = SimRules.direction(owner.facing)
	position = Vector2(origin) * 30
