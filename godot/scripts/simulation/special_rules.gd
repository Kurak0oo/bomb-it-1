class_name SpecialRules
extends RefCounted

const WEAPONS: Array[String] = ["rocket","mine","grenade","gas","ice","fire"]

static func place(state: GameState, hero: HeroState) -> bool:
	if hero.special_count <= 0 or not hero.fire_ready or hero.moving or state.cell_at(hero.cell).bomb != null:
		return false
	for existing in state.specials:
		if existing.origin == hero.cell and existing.kind == hero.special_weapon:
			return false
	var weapon := SpecialState.new(hero.special_weapon, hero)
	if weapon.kind == "grenade":
		weapon.cell += weapon.direction * 2
		var cell := state.cell_at(weapon.cell)
		if cell == null or cell.kind == GameState.Kind.SOLID:
			return false
	if weapon.kind in ["ice","fire"]:
		var cell := state.cell_at(hero.cell + weapon.direction)
		if cell == null or cell.kind == GameState.Kind.SOLID:
			return false
		if weapon.kind == "ice" and (cell.kind != GameState.Kind.FLOOR or cell.bomb != null):
			return false
	state.specials.append(weapon)
	state.register_callback(weapon)
	hero.special_count -= 1
	if hero.controller == HeroState.Controller.HUMAN:
		hero.fire_ready = false
	state.events.append(weapon.kind)
	return true

static func pulse(state: GameState, at: Vector2i, owner: int) -> void:
	var cell := state.cell_at(at)
	if cell == null or cell.kind == GameState.Kind.SOLID:
		return
	cell.kind = GameState.Kind.FLOOR
	cell.energy += 1
	cell.energy_owner = owner
	var effect := SpecialState.new("pulse", state.heroes[owner])
	# Created during this pass, outside its snapshot; next pass is update one.
	effect.just_placed = false
	effect.cell = at
	effect.origin = at
	effect.position = Vector2(at) * 30
	state.specials.append(effect)
	state.register_callback(effect)
	state.events.append("explode")

static func tick_weapon(state: GameState, weapon: SpecialState) -> void:
	if weapon.just_placed:
		weapon.just_placed = false
		return
	weapon.age += 1
	match weapon.kind:
		"pulse":
			if weapon.age >= 10:
				state.cell_at(weapon.cell).energy -= 1
				state.specials.erase(weapon)
		"grenade":
			# Nested grenade body symbols 307/308/309 have 19 timeline frames.
			if weapon.age >= 19:
				pulse(state, weapon.cell, weapon.owner_id)
				for i in 4:
					pulse(state, weapon.cell + SimRules.direction(i), weapon.owner_id)
				state.specials.erase(weapon)
		"rocket":
			weapon.position += Vector2(weapon.direction) * weapon.age
			weapon.cell = Vector2i(roundi(weapon.position.x / 30), roundi(weapon.position.y / 30))
			var hit := false
			for hero in state.heroes:
				if hero.alive and hero.id != weapon.owner_id and hero.pixel_position().distance_squared_to(weapon.position) < 225:
					hit = true
			var cell := state.cell_at(weapon.cell)
			if hit:
				pulse(state, weapon.cell, weapon.owner_id)
			elif cell == null or cell.kind == GameState.Kind.SOLID:
				pulse(state, weapon.cell - weapon.direction, weapon.owner_id)
				hit = true
			elif cell.kind != GameState.Kind.FLOOR or cell.bomb != null:
				pulse(state, weapon.cell, weapon.owner_id)
				hit = true
			if hit:
				# The original creates smoke before checking impact/removal.
				state.presentation_events.append({"kind":"rocket_impact_smoke", "position":weapon.position, "direction":weapon.direction, "tick":state.tick_number})
				state.specials.erase(weapon)
		"mine", "gas":
			var hit := false
			for hero in state.heroes:
				if not hero.alive or hero.id == weapon.owner_id:
					continue
				var distance: float = hero.pixel_position().distance_squared_to(weapon.position)
				if weapon.kind == "mine" and distance < 225:
					hit = true
				elif weapon.kind == "gas" and is_zero_approx(distance):
					hero.slow_ticks = 600
					hit = true
			if state.cell_at(weapon.cell).energy > 0:
				hit = true
			if hit:
				if weapon.kind == "mine":
					pulse(state, weapon.cell, weapon.owner_id)
				state.specials.erase(weapon)
		"ice", "fire":
			_tick_ray(state, weapon)

static func _tick_ray(state: GameState, weapon: SpecialState) -> void:
	if weapon.age <= 12 and weapon.age % 4 == 0 and not weapon.growth_stopped:
		var at := weapon.origin + weapon.direction * (weapon.age / 4)
		var cell := state.cell_at(at)
		var allowed := cell != null and cell.kind != GameState.Kind.SOLID
		if allowed and weapon.kind == "ice":
			allowed = cell.kind == GameState.Kind.FLOOR and cell.bomb == null
		if allowed:
			weapon.painted.append(at)
			weapon.born.append(weapon.age)
			if weapon.kind == "fire":
				if cell.bomb != null and cell.bomb.slide_ticks == 0:
					state._explode(cell.bomb)
				if cell.kind == GameState.Kind.BRICK:
					state._break_brick(cell, at, weapon.owner_id)
				cell.energy += 1
				cell.energy_owner = weapon.owner_id
			else:
				cell.kind = GameState.Kind.BRICK
		else:
			weapon.age = 12
			weapon.growth_stopped = true
	if weapon.kind == "ice":
		for i in weapon.painted.size():
			if weapon.age - weapon.born[i] >= 40:
				continue
			for hero in state.heroes:
				if hero.alive and hero.pixel_position().distance_squared_to(Vector2(weapon.painted[i]) * 30) < 100:
					hero.stop_ticks = 300
	if weapon.age > 48:
		for at in weapon.painted:
			var cell := state.cell_at(at)
			if weapon.kind == "ice":
				cell.kind = GameState.Kind.FLOOR
			else:
				cell.energy -= 1
		state.specials.erase(weapon)
