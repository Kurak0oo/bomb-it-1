class_name HeroView
extends Node2D

var art: OriginalArt
var actor: HeroState
var body: Sprite2D
var shadow: Sprite2D
var death: OriginalTimeline
var burst: Sprite2D
var smoke: Sprite2D
var weapon_indicator: WeaponIndicator
var player_pointer: OriginalTimeline
var pointer_enabled := false
var pointer_replaced := false
var pointer_age := 0
var death_age := -1
var previous := Vector2.ZERO
var current := Vector2.ZERO
var frozen := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	shadow = art.sprite(2)
	add_child(shadow)
	body = Sprite2D.new()
	body.centered = false
	add_child(body)
	death = OriginalTimeline.new()
	death.art = art
	death.symbol = 237
	add_child(death)
	burst = art.sprite(248)
	add_child(burst)
	smoke = art.sprite(279)
	smoke.z_as_relative = false
	smoke.z_index = 2500
	add_child(smoke)
	weapon_indicator = WeaponIndicator.new()
	weapon_indicator.art = art
	add_child(weapon_indicator)
	player_pointer = OriginalTimeline.new()
	player_pointer.art = art
	player_pointer.symbol = 210
	add_child(player_pointer)
	current = actor.pixel_position()
	previous = current
	sync()

func capture() -> void:
	previous = current

func sync(round_tick: int = -1) -> void:
	if round_tick >= 0:
		pointer_age = round_tick
	# Both dynamic clips occupy source depth 0. Equipping permanently replaces
	# the startup pointer, even when the weapon is exhausted before tick 150.
	pointer_replaced = pointer_replaced or actor.special_count > 0
	player_pointer.visible = pointer_enabled and not pointer_replaced and actor.alive and pointer_age < 150
	if player_pointer.visible:
		player_pointer.show_frame(pointer_age % 60, 0, actor.character_id + actor.id * 4)
	weapon_indicator.sync(actor)
	current = actor.pixel_position()
	z_index = OriginalArt.depth(actor.cell, -actor.id - 1)
	if actor.alive:
		death_age = -1
	else:
		death_age = maxi(death_age, actor.death_ticks)
	var data: Dictionary = art.manifest.heroes[str(actor.character_id)][actor.facing if actor.alive else 3]
	var symbol := int(data.symbol)
	var number := actor.walk_frame % 12 + 1 if actor.alive else death_age % 12 + 1
	body.texture = art.frame(symbol, number)
	body.scale.x = data.scale_x
	body.position = Vector2(data.x, data.y) + art.offset(symbol) * Vector2(data.scale_x, 1)
	body.visible = actor.alive or death_age < 5
	shadow.visible = body.visible
	death.visible = not actor.alive and death_age < 35
	burst.visible = not actor.alive and death_age < 11
	smoke.visible = not actor.alive and death_age < 35
	if not actor.alive:
		death.show_frame(death_age, death_age, actor.character_id)
		burst.texture = art.frame(248, death_age + 1)
		smoke.texture = art.frame(279, death_age + 1)
	visible = actor.alive or death_age < 35
	modulate.a = 0.3 if actor.alive and actor.shield > 0 and actor.shield % 2 == 1 else 1.0

func advance_presentation() -> void:
	# Finish the death clip after the round ends without ticking game state.
	if not actor.alive and death_age < 35:
		death_age += 1
		sync()

func _process(_delta: float) -> void:
	position = current if frozen else previous.lerp(current, Engine.get_physics_interpolation_fraction())
