class_name GameView
extends Node2D

var state: GameState
var art: OriginalArt
var _hero_sprites: Dictionary = {}
var _pop_sprites: Dictionary = {}
var _bomb_sprites: Dictionary = {}
var _flame_sprites: Dictionary = {}
var _brick_sprites: Dictionary = {}
var _item_sprites: Dictionary = {}
var _special_sprites: Dictionary = {}
var _target_sprites: Dictionary = {}
var _retiring_items: Array[PickupView] = []
var _trails: Array[Dictionary] = []
var _rocket_ages: Dictionary = {}
var _presentation_tick := 0
var _last_state_tick := 0
var _last_event_tick := -1
var _hit_smoke: Array[Dictionary] = []
var _motion_positions: Dictionary = {}
var frozen := false:
	set(value):
		# Resume at the last accepted position, never at a pre-pause endpoint.
		if frozen != value:capture_positions()
		frozen = value
		for hero in _hero_sprites.values():
			hero.frozen = value

func _ready() -> void:
	if art == null:
		art = OriginalArt.new()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for y in SimRules.ROWS:
		for x in SimRules.COLUMNS:
			var at := Vector2i(x,y)
			var floor := art.sprite(231, state.floor_style)
			floor.position += Vector2(at) * 30
			floor.z_index = -100
			add_child(floor)
			var cell := state.cell_at(at)
			if cell.kind != GameState.Kind.FLOOR:
				if x in [6,7] and y in [5,6]:
					continue
				var brick := art.sprite(195, cell.style if state.generated else 1)
				brick.position += Vector2(at) * 30
				brick.z_index = OriginalArt.depth(at)
				add_child(brick)
				_brick_sprites[at] = brick
	var center := art.sprite(195, state.center_style)
	center.position += Vector2(6,5) * 30
	center.z_index = OriginalArt.depth(Vector2i(6,6))
	add_child(center)
	for actor in state.heroes:
		var hero := HeroView.new()
		hero.art = art
		hero.actor = actor
		hero.pointer_enabled = state.generated and actor.controller == HeroState.Controller.HUMAN
		add_child(hero)
		_hero_sprites[actor.id] = hero
		var target := art.sprite(317)
		target.z_index = -40
		add_child(target)
		_target_sprites[actor.id] = target
	sync_view()

func capture_positions() -> void:
	for hero in _hero_sprites.values():
		hero.capture()
	for node in _motion_positions:
		_motion_positions[node].previous = _motion_positions[node].current

func _process(_delta: float) -> void:
	_render_motion(Engine.get_physics_interpolation_fraction())

func _render_motion(fraction: float) -> void:
	for node in _motion_positions.keys():
		if not is_instance_valid(node):
			_motion_positions.erase(node)
			continue
		var motion: Dictionary = _motion_positions[node]
		node.position = motion.current if frozen else motion.previous.lerp(motion.current, fraction)

func _set_motion(node: Node2D, at: Vector2) -> void:
	if not _motion_positions.has(node):
		_motion_positions[node] = {"previous":at, "current":at}
	else:
		_motion_positions[node].current = at
	# Initial placement and headless synchronization do not depend on _process.
	node.position = at

func sync_view() -> void:
	_presentation_tick += maxi(0, state.tick_number - _last_state_tick)
	_last_state_tick = state.tick_number
	if _last_event_tick != state.tick_number:
		_last_event_tick = state.tick_number
		for event in state.presentation_events:
			if event.kind == "surviving_hit":
				var smoke := art.sprite(279, 20)
				smoke.position += event.position
				smoke.z_index = 2500
				add_child(smoke)
				_hit_smoke.append({"node":smoke, "born":_presentation_tick})
			elif event.kind == "rocket_impact_smoke":
				_spawn_rocket_smoke(event.position, SimRules.direction_index(event.direction))
	for at in _brick_sprites:
		_brick_sprites[at].visible = state.cell_at(at).kind != GameState.Kind.FLOOR
	_prune(_pop_sprites, state.pops)
	for pop in state.pops:
		if not _pop_sprites.has(pop):
			var sprite := art.sprite(248)
			sprite.position += Vector2(pop.cell) * 30
			sprite.z_index = OriginalArt.depth(pop.cell)
			add_child(sprite)
			_pop_sprites[pop] = sprite
		_pop_sprites[pop].texture = art.frame(248, 12 - pop.ticks)
		# Source frame 11 removes the clip. State keeps its accepted lifetime;
		# the final exported transparent frame is no longer a visible effect.
		_pop_sprites[pop].visible = 12 - pop.ticks < 11
	_prune(_bomb_sprites, state.bombs)
	for bomb in state.bombs:
		if not _bomb_sprites.has(bomb):
			var sprite := art.sprite(371)
			add_child(sprite)
			_bomb_sprites[bomb] = sprite
		var sprite: Sprite2D = _bomb_sprites[bomb]
		sprite.texture = art.frame(371, (SimRules.FUSE_TICKS - bomb.fuse) % 40 + 1)
		var at := Vector2(bomb.cell)
		if bomb.slide_ticks > 0:
			at = Vector2(bomb.previous_cell).lerp(at, 1.0 - bomb.slide_ticks / 2.0)
		_set_motion(sprite, at * 30 + art.offset(371))
		sprite.z_index = OriginalArt.depth(bomb.cell, -5)
	_prune(_flame_sprites, state.explosions)
	for blast in state.explosions:
		if not _flame_sprites.has(blast):
			var group := Node2D.new()
			group.z_index = -50
			add_child(group)
			_flame_sprites[blast] = group
		var group: Node2D = _flame_sprites[blast]
		# Flash stores each `_alpha -= 20` assignment in 8.8 precision.
		# Quantization accumulates (256,204,152,100,48), independently of energy.
		var fade_steps := roundi((100.0 - blast.alpha) / 20.0)
		group.modulate.a = (256 - 52 * fade_steps) / 256.0
		for n in range(group.get_child_count(), blast.painted.size()):
			var holder := Node2D.new()
			holder.position = Vector2(blast.painted[n]) * 30 + Vector2(15,15)
			if blast.dir_of[n] >= 0:
				holder.rotation_degrees = SimRules.flame_degrees(blast.dir_of[n])
			var sprite := art.sprite(273, state.heroes[blast.owner_id].character_id + blast.style_of[n] * 4)
			holder.add_child(sprite)
			group.add_child(holder)
	for y in SimRules.ROWS:
		for x in SimRules.COLUMNS:
			var at := Vector2i(x,y)
			var item := state.cell_at(at).item
			if _item_sprites.has(at) and _item_sprites[at].kind != item:
				var retiring: PickupView = _item_sprites[at]
				retiring.removed = _presentation_tick
				_retiring_items.append(retiring)
				_item_sprites.erase(at)
			if item == "":
				continue
			if not _item_sprites.has(at):
				var number := ["life","glove","bomb","shield","power","shoe","rocket","mine","grenade","gas","ice","fire"].find(item) + 1
				var sprite := PickupView.new()
				sprite.art = art
				sprite.symbol = 326
				sprite.kind = item
				sprite.variant = number
				sprite.born = _presentation_tick
				sprite.position = Vector2(at) * 30
				sprite.z_index = OriginalArt.depth(at, -6)
				add_child(sprite)
				_item_sprites[at] = sprite
			_item_sprites[at].animate(_presentation_tick)
	for hero in _hero_sprites.values():
		hero.sync(state.tick_number)
	for actor in state.heroes:
		var target: Sprite2D = _target_sprites[actor.id]
		var at := actor.cell + SimRules.direction(actor.facing) * 2
		var cell := state.cell_at(at)
		target.visible = actor.alive and actor.special_weapon == "grenade" and actor.special_count > 0 and not actor.moving and cell != null and cell.kind == GameState.Kind.FLOOR
		target.position = Vector2(at) * 30 + art.offset(317)
	_sync_specials()
	_animate_transients()

func present_timeout_loss() -> void:
	for hero in _hero_sprites.values():
		if hero.actor.controller == HeroState.Controller.HUMAN:
			hero.present_timeout_death()
			_target_sprites[hero.actor.id].visible = false

func advance_presentation() -> void:
	_presentation_tick += 1
	for hero in _hero_sprites.values():
		hero.advance_presentation()
	_animate_transients()

func _animate_transients() -> void:
	for i in range(_hit_smoke.size() - 1, -1, -1):
		var smoke: Dictionary = _hit_smoke[i]
		var frame_number: int = 20 + _presentation_tick - smoke.born
		if frame_number >= 36:
			smoke.node.free()
			_hit_smoke.remove_at(i)
		else:
			smoke.node.texture = art.frame(279, frame_number)
	for i in range(_retiring_items.size() - 1, -1, -1):
		if not _retiring_items[i].animate(_presentation_tick):
			_retiring_items[i].free()
			_retiring_items.remove_at(i)
	for i in range(_trails.size() - 1, -1, -1):
		var trail: Dictionary = _trails[i]
		var age: int = _presentation_tick - trail.born
		if age >= 21:
			trail.node.free()
			_trails.remove_at(i)
		else:
			trail.node.show_frame(trail.direction, age)

func _sync_specials() -> void:
	_prune(_special_sprites, state.specials)
	for weapon in _rocket_ages.keys():
		if not state.specials.has(weapon):
			_rocket_ages.erase(weapon)
	for weapon in state.specials:
		if not _special_sprites.has(weapon):
			var group := Node2D.new()
			add_child(group)
			_special_sprites[weapon] = group
		var group: Node2D = _special_sprites[weapon]
		group.z_index = OriginalArt.depth(weapon.cell, -5)
		if weapon.kind == "rocket":
			_set_motion(group, weapon.position)
			var direction := SimRules.direction_index(weapon.direction)
			if group.get_child_count() == 0:
				var rocket := OriginalTimeline.new()
				rocket.art = art
				rocket.symbol = 305
				group.add_child(rocket)
			group.get_child(0).show_frame(direction, weapon.age)
			if weapon.age > 0 and _rocket_ages.get(weapon, -1) != weapon.age:
				_spawn_rocket_smoke(weapon.position, direction)
			_rocket_ages[weapon] = weapon.age
			continue
		if weapon.kind in ["ice", "fire"]:
			for n in range(group.get_child_count(), weapon.painted.size()):
				var sprite := art.sprite(325 if weapon.kind == "ice" else 319)
				sprite.position += Vector2(weapon.painted[n]) * 30
				sprite.z_index = OriginalArt.depth(weapon.painted[n], 0 if weapon.kind == "ice" else -7)
				sprite.z_as_relative = false
				group.add_child(sprite)
			for n in group.get_child_count():
				var sprite: Sprite2D = group.get_child(n)
				var age: int = weapon.age - weapon.born[n]
				sprite.texture = art.frame(325 if weapon.kind == "ice" else 319, age + 1)
				sprite.visible = age < 40
			continue
		var symbol: int = {"rocket":305,"mine":306,"grenade":310,"gas":315,"pulse":248}[weapon.kind]
		var frame_number := weapon.age + 1
		_set_motion(group, weapon.position)
		var direction := SimRules.direction_index(weapon.direction)
		var offset := Vector2.ZERO
		var scale_x := 1.0
		if weapon.kind == "rocket":
			frame_number = direction + 1
		elif weapon.kind == "grenade":
			var data: Dictionary = art.manifest.grenade[direction]
			symbol = data.symbol
			offset = Vector2(data.x, data.y)
			scale_x = data.scale_x
			group.z_index = OriginalArt.depth(weapon.cell if weapon.age >= 9 else weapon.origin, -5)
		elif weapon.kind == "mine":
			frame_number = mini(frame_number, 60)
		elif weapon.kind == "gas":
			frame_number = mini(weapon.age + 1, 101)
		if group.get_child_count() == 0:
			group.add_child(art.sprite(symbol))
		var sprite: Sprite2D = group.get_child(0)
		sprite.texture = art.frame(symbol, frame_number)
		sprite.scale.x = scale_x
		sprite.position = offset + art.offset(symbol) * Vector2(scale_x,1)

func _spawn_rocket_smoke(at: Vector2, direction: int) -> void:
	var trail := OriginalTimeline.new()
	trail.art = art
	trail.symbol = 313
	trail.position = at
	trail.z_index = -45
	add_child(trail)
	_trails.append({"node":trail, "born":_presentation_tick, "direction":direction})

func _prune(sprites: Dictionary, active: Array) -> void:
	for key in sprites.keys():
		if not active.has(key):
			_motion_positions.erase(sprites[key])
			sprites[key].free()
			sprites.erase(key)
