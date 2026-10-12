class_name GameState
extends RefCounted

enum Kind { FLOOR, BRICK, SOLID }

# Hand-authored 15×13 stand-in. Center 2×2 matches the original unbreakable block.
# S is only a marker; character spawn cells are defined in SimRules.
const MAP: PackedStringArray = [
	"BBBBBBBBBBBBBBB",
	"B.B.B.B.B.B.B.B",
	"B...B.B...B...B",
	"B..S....B...B.B",
	"B...B...B.B...B",
	"BB.BB.##..BB.BB",
	"B...B.##B.....B",
	"B.B...B...B.B.B",
	"B...B.B.B.....B",
	"B.B.B...B.B.B.B",
	"B.....B...B...B",
	"B.B.B.B.B.B.B.B",
	"BBBBBBBBBBBBBBB",
]

var cells: Array
var bombs: Array
var explosions: Array
var pops: Array
var heroes: Array[HeroState] = []
var rng := OriginalRng.new()
var difficulty := 1
var scene_style := 0
var floor_style := 1
var center_style := 52
var generated := false
var items_enabled := false
var tick_number := 0
# Ephemeral presentation events. Cleared once per authoritative simulation tick.
var events: Array[String] = []
var presentation_events: Array[Dictionary] = []
var specials: Array[SpecialState] = []
var special_choices: Array = []
var brick_styles: Array = []


func setup_round(seed_value: int, selected_character: int = 1, humans: int = 1, level: int = 1, second_character: int = 0) -> void:
	var rows := PackedStringArray()
	for y in SimRules.ROWS:
		rows.append("...............")
	setup(rows)
	rng = OriginalRng.new(seed_value)
	difficulty = level
	generated = true
	items_enabled = true
	special_choices = SpecialRules.WEAPONS.duplicate()
	rng.disorder(special_choices)
	var characters: Array[int] = [selected_character]
	if humans == 2 and second_character in [1,2,3,4] and second_character != selected_character:
		characters.append(second_character)
	for id in range(1, 5):
		if not characters.has(id):
			characters.append(id)
	for id in 4:
		heroes[id].character_id = characters[id]
		heroes[id].cell = SimRules.SPAWNS[characters[id] - 1]
		heroes[id].controller = HeroState.Controller.HUMAN if id < humans else HeroState.Controller.AI
		heroes[id].lives = 3 if id < humans else 1
		heroes[id].armor = level == 0 and id < humans
	BoardGenerator.generate(self, rng)


func setup_default() -> void:
	setup(MAP)
	for actor in heroes:
		_cell(actor.cell).kind = Kind.FLOOR
		for i in 4:
			var neighbor := _cell(actor.cell + SimRules.direction(i))
			if neighbor != null and neighbor.kind == Kind.BRICK:
				neighbor.kind = Kind.FLOOR


func setup(rows: PackedStringArray) -> void:
	generated = false
	items_enabled = false
	tick_number = 0
	events.clear()
	presentation_events.clear()
	specials.clear()
	cells = []
	bombs = []
	explosions = []
	pops = []
	heroes = []
	for id in 4:
		var actor := HeroState.new()
		actor.id = id
		actor.character_id = id + 1
		actor.controller = HeroState.Controller.HUMAN if id == 0 else HeroState.Controller.AI
		actor.cell = SimRules.SPAWNS[id]
		heroes.append(actor)
	for y in SimRules.ROWS:
		var row: Array = []
		var line := rows[y]
		for x in SimRules.COLUMNS:
			var cell := CellState.new()
			var ch := line[x]
			if ch == "#":
				cell.kind = Kind.SOLID
			elif ch == "B":
				cell.kind = Kind.BRICK
			else:
				cell.kind = Kind.FLOOR
			row.append(cell)
		cells.append(row)


func cell_at(at: Vector2i) -> CellState:
	return _cell(at)


# Hero (shield, step, maybe place) → explosions → bombs → damage → brick pops.
# A bomb's creation tick is not an active fuse tick. Growth runs before fuse,
# so a flame paints a cell and chains an already-active bomb in the same tick.
# This preserves the prototype order, not verified Flash callback scheduling.
# See reference/core-stabilization.md before changing boundary-tick behavior.
# Slots are stable, zero-based hero IDs. Missing commands mean idle, including AI
# slots until AI is ported. No rendering, input polling, or wall clock lives here.
func tick(commands: Array[PlayerCommands]) -> void:
	tick_number += 1
	events.clear()
	presentation_events.clear()
	for actor in heroes:
		var command := commands[actor.id] if actor.id < commands.size() else PlayerCommands.new()
		_tick_hero(actor, command)
	_tick_explosions()
	SpecialRules.tick(self)
	_tick_bombs()
	for actor in heroes:
		_tick_damage(actor)
	_tick_pops()


func _tick_hero(hero: HeroState, commands: PlayerCommands) -> void:
	if commands.bomb_released:
		hero.fire_ready = true
	if hero.slow_ticks > 0:
		hero.slow_ticks -= 1
	hero.shielded_this_tick = hero.shield > 0
	if hero.shielded_this_tick:
		hero.shield -= 1
	if not hero.alive:
		hero.death_ticks += 1
		return
	if hero.moving:
		hero.walk_frame += 1
		hero.ticks_remaining -= 1
		if hero.ticks_remaining > 0:
			if commands.bomb_requested:
				hero.prev_fire = true
			return
		hero.cell += hero.direction
		hero.moving = false
		_collect_item(hero)
	if hero.stop_ticks > 0:
		hero.stop_ticks -= 1
		return
	# Original human polling turns/starts movement before attempting fire.
	# Specials reject moving actors; ordinary bombs still use the current cell.
	if commands.direction != Vector2i.ZERO:
		_try_move(hero, commands.direction)
	if commands.bomb_requested or hero.prev_fire:
		hero.prev_fire = false
		if hero.special_count > 0:
			SpecialRules.place(self, hero)
		else:
			_place_bomb(hero, hero.cell)


func _try_move(hero: HeroState, dir: Vector2i) -> void:
	var index := SimRules.direction_index(dir)
	if index < 0:
		return
	hero.facing = index
	hero.direction = dir
	var dest := hero.cell + dir
	var destination := _cell(dest)
	if destination != null and destination.bomb != null and hero.glove:
		_push_bomb(destination.bomb, dir)
	if not _passable(dest):
		return
	hero.moving = true
	hero.step_duration = 20 if hero.slow_ticks > 0 else hero.speed_level
	hero.ticks_remaining = hero.step_duration


func _passable(dest: Vector2i) -> bool:
	var cell := _cell(dest)
	if cell == null:
		return false
	if cell.kind != Kind.FLOOR:
		return false
	if cell.bomb != null:
		return false
	return true


func _place_bomb(hero: HeroState, at: Vector2i) -> bool:
	if hero.bombs_available <= 0 or not hero.fire_ready:
		return false
	for special in specials:
		if special.origin == at and special.kind in ["rocket","mine","grenade","gas"]:
			return false
	var cell := _cell(at)
	if cell == null or cell.bomb != null:
		return false
	var bomb := BombState.new(at, hero.id)
	bomb.level = hero.bomb_level
	cell.bomb = bomb
	bombs.append(bomb)
	hero.bombs_available -= 1
	events.append("place")
	return true


func _tick_explosions() -> void:
	var finished: Array = []
	for exp in explosions:
		var blast: ExplosionState = exp
		if blast.phase == ExplosionState.Phase.GROWING:
			_grow_explosion(blast)
		elif blast.phase == ExplosionState.Phase.LINGER:
			blast.linger -= 1
			if blast.linger <= 0:
				_clear_energy(blast)
				blast.phase = ExplosionState.Phase.FADE
				blast.alpha = 100.0
		elif blast.phase == ExplosionState.Phase.FADE:
			blast.alpha -= SimRules.FADE_STEP
			if blast.alpha < SimRules.FADE_REMOVE_BELOW:
				finished.append(blast)
	for blast in finished:
		explosions.erase(blast)


func _grow_explosion(blast: ExplosionState) -> void:
	blast.exp_pos += 1
	for i in 4:
		if not blast.open[i]:
			continue
		var dir := SimRules.direction(i)
		var at: Vector2i = blast.origin + dir * blast.exp_pos
		var cell := _cell(at)
		if cell == null or cell.kind == Kind.SOLID:
			blast.open[i] = false
			continue
		cell.energy += 1
		cell.energy_owner = blast.owner_id
		blast.painted.append(at)
		if cell.kind == Kind.BRICK:
			blast.open[i] = false
			_break_brick(cell, at, blast.owner_id)
		var nxt := _cell(at + dir)
		if nxt == null or nxt.kind == Kind.SOLID or blast.exp_pos >= blast.level:
			blast.open[i] = false
		var style := ExplosionState.STYLE_ARM if blast.open[i] else ExplosionState.STYLE_TIP
		blast.style_of.append(style)
		blast.dir_of.append(i)
	if blast.exp_pos >= blast.level:
		blast.phase = ExplosionState.Phase.LINGER
		blast.linger = SimRules.LINGER_TICKS


func _clear_energy(blast: ExplosionState) -> void:
	for at in blast.painted:
		var cell := _cell(at)
		if cell != null:
			cell.energy -= 1


func _break_brick(cell: CellState, at: Vector2i, owner: int = 0) -> void:
	if cell.kind != Kind.BRICK:
		return
	cell.kind = Kind.FLOOR
	pops.append(Pop.new(at))
	if items_enabled:
		heroes[owner].score += [5,10,15][difficulty]
		heroes[owner].destruction_score += [5,10,15][difficulty]
		if rng.next(100) < 65:
			if rng.next(100) < 80:
				var roll := rng.next(100)
				cell.item = "life" if roll < 1 else "glove" if roll < 15 else "bomb" if roll < 40 else "shield" if roll < 50 else "power" if roll < 75 else "shoe"
			else:
				cell.item = special_choices[rng.next(2)]


func _tick_bombs() -> void:
	var snapshot: Array = bombs.duplicate()
	for item in snapshot:
		var bomb: BombState = item
		if not bombs.has(bomb):
			continue
		if bomb.just_placed:
			bomb.just_placed = false
			continue
		if bomb.slide_ticks > 0:
			bomb.slide_ticks -= 1
			if bomb.slide_ticks > 0:
				continue
			if _push_bomb(bomb, bomb.slide_direction):
				continue
			bomb.slide_direction = Vector2i.ZERO
			# Original pushing replaces the fuse handler and explodes on stopping.
			_explode(bomb)
			continue
		var cell := _cell(bomb.cell)
		bomb.fuse -= 1
		if cell != null and cell.energy > 0:
			bomb.fuse = 0
		if bomb.fuse <= 0:
			_explode(bomb)


func _explode(bomb: BombState) -> void:
	var cell := _cell(bomb.cell)
	if cell == null:
		bombs.erase(bomb)
		return
	if cell.bomb == bomb:
		cell.bomb = null
	bombs.erase(bomb)
	heroes[bomb.owner_id].bombs_available += 1
	var blast := ExplosionState.new(bomb.cell, bomb.level)
	blast.owner_id = bomb.owner_id
	for i in 4:
		var nxt := _cell(bomb.cell + SimRules.direction(i))
		if nxt == null or nxt.kind == Kind.SOLID:
			blast.open[i] = false
	cell.energy += 1
	cell.energy_owner = bomb.owner_id
	explosions.append(blast)
	events.append("explode")


func _tick_damage(hero: HeroState) -> void:
	if not hero.alive or hero.shielded_this_tick:
		return
	var cell := _cell(hero.rounded_cell())
	if cell != null and cell.energy > 0:
		if hero.armor:
			hero.armor = false
			hero.shield = 60
			return
		if cell.energy_owner >= 0 and cell.energy_owner != hero.id:
			heroes[cell.energy_owner].score += 1000
			heroes[cell.energy_owner].kill_score += 1000
		hero.lives -= 1
		if hero.controller == HeroState.Controller.AI and hero.lives > 0:
			hero.shield = 60
			presentation_events.append({"kind":"surviving_hit", "position":hero.pixel_position(), "actor_id":hero.id, "tick":tick_number})
			return
		hero.death_position = hero.pixel_position()
		hero.alive = false
		hero.moving = false
		hero.ticks_remaining = 0
		events.append("death")


func _push_bomb(bomb: BombState, dir: Vector2i) -> bool:
	if bomb.slide_ticks > 0 or not _passable(bomb.cell + dir):
		return false
	_cell(bomb.cell).bomb = null
	bomb.previous_cell = bomb.cell
	bomb.cell += dir
	_cell(bomb.cell).bomb = bomb
	bomb.slide_direction = dir
	bomb.slide_ticks = 2
	events.append("push")
	return true


func _collect_item(hero: HeroState) -> void:
	var cell := _cell(hero.cell)
	if cell.item == "" or (hero.controller == HeroState.Controller.AI and difficulty == 0):
		return
	match cell.item:
		"rocket", "mine", "grenade", "gas", "ice", "fire":
			if hero.controller == HeroState.Controller.AI and difficulty != 2:
				return
			hero.special_weapon = cell.item
			hero.special_count = 1 if cell.item == "ice" else 2
		"life": hero.lives += 1
		"glove": hero.glove = true
		"bomb":
			hero.bomb_capacity += 1
			hero.bombs_available += 1
		"shield": hero.armor = true
		"power": hero.bomb_level = mini(hero.bomb_level + 1, 10)
		"shoe":
			if hero.controller == HeroState.Controller.AI and difficulty != 2:
				return
			hero.speed_level = maxi(hero.speed_level - 1, 3)
	cell.item = ""
	hero.score += 100
	hero.destruction_score += 100
	events.append("pickup")


func _tick_pops() -> void:
	var keep: Array = []
	for item in pops:
		var pop: Pop = item
		pop.ticks -= 1
		if pop.ticks > 0:
			keep.append(pop)
	pops = keep


func _cell(at: Vector2i) -> CellState:
	if at.x < 0 or at.y < 0 or at.x >= SimRules.COLUMNS or at.y >= SimRules.ROWS:
		return null
	return cells[at.y][at.x]


class Pop:
	var cell := Vector2i.ZERO
	var ticks := SimRules.BRICK_POP_TICKS

	func _init(at: Vector2i) -> void:
		cell = at
		ticks = SimRules.BRICK_POP_TICKS
