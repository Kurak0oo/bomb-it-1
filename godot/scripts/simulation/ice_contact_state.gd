class_name IceContactState
extends RefCounted

# Separate freezeEffect child: first callback follows birth; frame 40 removes it.
var position: Vector2
var age := 0

func _init(at: Vector2i) -> void:
	position = Vector2(at) * SimRules.TILE_SIZE

func tick(heroes: Array[HeroState], positions: Array[Vector2]) -> bool:
	age += 1
	if age >= 40:
		return false
	for hero in heroes:
		if hero.alive and positions[hero.id].distance_squared_to(position) < 100:
			hero.stop_ticks = 300
	return true
