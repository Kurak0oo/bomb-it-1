class_name GameBoard
extends Node2D

enum Kind { FLOOR, BRICK, SOLID }

# Hand-authored 15×13 stand-in. Center 2×2 matches the original unbreakable block.
# S is only a marker; the hero always spawns at (3, 3) facing down.
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

const BUSH_CELL := Vector2i(6, 5)

var cells: Array
var bombs: Array
var explosions: Array
var pops: Array
var hero: Hero

var _view_ready := false
var _floor_root: Node2D
var _brick_root: Node2D
var _pop_root: Node2D
var _flame_root: Node2D
var _bomb_root: Node2D
var _hero_sprite: Sprite2D
var _brick_sprites: Dictionary


func _init() -> void:
	cells = []
	bombs = []
	explosions = []
	pops = []
	hero = Hero.new()
	_brick_sprites = {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if cells.is_empty():
		setup_default()
	_build_view()


func setup_default() -> void:
	setup(MAP)


func setup(rows: PackedStringArray) -> void:
	cells = []
	bombs = []
	explosions = []
	pops = []
	hero = Hero.new()
	for y in SimRules.ROWS:
		var row: Array = []
		var line := rows[y]
		for x in SimRules.COLUMNS:
			var cell := Cell.new()
			var ch := line[x]
			if ch == "#":
				cell.kind = Kind.SOLID
			elif ch == "B":
				cell.kind = Kind.BRICK
			else:
				cell.kind = Kind.FLOOR
			row.append(cell)
		cells.append(row)
	hero.cell = SimRules.SPAWN
	hero.facing = SimRules.FACING_DOWN


func cell_at(at: Vector2i) -> Cell:
	return _cell(at)


# Hero (shield, step, maybe place) → explosions → bombs → damage → brick pops.
# A bomb's creation tick is not an active fuse tick. Growth runs before fuse,
# so a flame paints a cell and chains an already-active bomb in the same tick.
func tick(commands: PlayerCommands) -> void:
	_tick_hero(commands)
	_tick_explosions()
	_tick_bombs()
	_tick_damage()
	_tick_pops()


func sync_view() -> void:
	if not _view_ready:
		return
	_sync_bricks()
	_sync_pops()
	_sync_flames()
	_sync_bombs()
	_sync_hero()


func _tick_hero(commands: PlayerCommands) -> void:
	hero.shielded_this_tick = hero.shield > 0
	if hero.shielded_this_tick:
		hero.shield -= 1
	if not hero.alive:
		return
	if hero.moving:
		hero.ticks_remaining -= 1
		if hero.ticks_remaining > 0:
			if commands.bomb_requested:
				hero.prev_fire = true
			return
		hero.cell += hero.direction
		hero.moving = false
	if commands.bomb_requested or hero.prev_fire:
		hero.prev_fire = false
		_place_bomb(hero.cell)
	if commands.direction != Vector2i.ZERO:
		_try_move(commands.direction)


func _try_move(dir: Vector2i) -> void:
	var index := SimRules.direction_index(dir)
	hero.facing = index
	hero.direction = dir
	var dest := hero.cell + dir
	if not _passable(dest):
		return
	hero.moving = true
	hero.ticks_remaining = SimRules.FRAMES_PER_TILE


func _passable(dest: Vector2i) -> bool:
	var cell := _cell(dest)
	if cell == null:
		return false
	if cell.kind != Kind.FLOOR:
		return false
	if cell.bomb != null:
		return false
	return true


func _place_bomb(at: Vector2i) -> bool:
	if hero.bombs_left <= 0:
		return false
	var cell := _cell(at)
	if cell == null or cell.bomb != null:
		return false
	var bomb := Bomb.new(at)
	bomb.level = hero.bomb_level
	cell.bomb = bomb
	bombs.append(bomb)
	hero.bombs_left -= 1
	return true


func _tick_explosions() -> void:
	var finished: Array = []
	for exp in explosions:
		var blast: Explosion = exp
		if blast.phase == Explosion.Phase.GROWING:
			_grow_explosion(blast)
		elif blast.phase == Explosion.Phase.LINGER:
			blast.linger -= 1
			if blast.linger <= 0:
				_clear_energy(blast)
				blast.phase = Explosion.Phase.FADE
				blast.alpha = 100.0
		elif blast.phase == Explosion.Phase.FADE:
			blast.alpha -= SimRules.FADE_STEP
			if blast.alpha < SimRules.FADE_REMOVE_BELOW:
				finished.append(blast)
	for blast in finished:
		explosions.erase(blast)


func _grow_explosion(blast: Explosion) -> void:
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
		blast.painted.append(at)
		if cell.kind == Kind.BRICK:
			blast.open[i] = false
			_break_brick(cell, at)
		var nxt := _cell(at + dir)
		if nxt == null or nxt.kind == Kind.SOLID or blast.exp_pos >= blast.level:
			blast.open[i] = false
		var style := Explosion.STYLE_ARM if blast.open[i] else Explosion.STYLE_TIP
		blast.style_of.append(style)
		blast.dir_of.append(i)
	if blast.exp_pos >= blast.level:
		blast.phase = Explosion.Phase.LINGER
		blast.linger = SimRules.LINGER_TICKS


func _clear_energy(blast: Explosion) -> void:
	for at in blast.painted:
		var cell := _cell(at)
		if cell != null:
			cell.energy -= 1


func _break_brick(cell: Cell, at: Vector2i) -> void:
	if cell.kind != Kind.BRICK:
		return
	cell.kind = Kind.FLOOR
	pops.append(Pop.new(at))


func _tick_bombs() -> void:
	var snapshot: Array = bombs.duplicate()
	for item in snapshot:
		var bomb: Bomb = item
		if not bombs.has(bomb):
			continue
		if bomb.just_placed:
			bomb.just_placed = false
			continue
		var cell := _cell(bomb.cell)
		bomb.fuse -= 1
		if cell != null and cell.energy > 0:
			bomb.fuse = 0
		if bomb.fuse <= 0:
			_explode(bomb)


func _explode(bomb: Bomb) -> void:
	var cell := _cell(bomb.cell)
	if cell == null:
		bombs.erase(bomb)
		return
	if cell.bomb == bomb:
		cell.bomb = null
	bombs.erase(bomb)
	hero.bombs_left += 1
	var blast := Explosion.new(bomb.cell, bomb.level)
	for i in 4:
		var nxt := _cell(bomb.cell + SimRules.direction(i))
		if nxt == null or nxt.kind == Kind.SOLID:
			blast.open[i] = false
	cell.energy += 1
	explosions.append(blast)


func _tick_damage() -> void:
	if not hero.alive or hero.shielded_this_tick:
		return
	var cell := _cell(hero.rounded_cell())
	if cell != null and cell.energy > 0:
		hero.alive = false
		hero.moving = false
		hero.ticks_remaining = 0


func _tick_pops() -> void:
	var keep: Array = []
	for item in pops:
		var pop: Pop = item
		pop.ticks -= 1
		if pop.ticks > 0:
			keep.append(pop)
	pops = keep


func _cell(at: Vector2i) -> Cell:
	if at.x < 0 or at.y < 0 or at.x >= SimRules.COLUMNS or at.y >= SimRules.ROWS:
		return null
	return cells[at.y][at.x]


func _build_view() -> void:
	_floor_root = Node2D.new()
	_brick_root = Node2D.new()
	_pop_root = Node2D.new()
	_flame_root = Node2D.new()
	_bomb_root = Node2D.new()
	add_child(_floor_root)
	add_child(_brick_root)
	add_child(_pop_root)
	add_child(_flame_root)
	add_child(_bomb_root)
	var floor_tex: Texture2D = load("res://art/floor.png")
	var brick_tex: Texture2D = load("res://art/brick.png")
	var bush_tex: Texture2D = load("res://art/bush.png")
	for y in SimRules.ROWS:
		for x in SimRules.COLUMNS:
			var at := Vector2i(x, y)
			var floor := Sprite2D.new()
			floor.texture = floor_tex
			floor.centered = false
			floor.region_enabled = true
			floor.region_rect = Rect2(0, 0, SimRules.TILE_SIZE, SimRules.TILE_SIZE)
			floor.position = Vector2(at) * float(SimRules.TILE_SIZE)
			_floor_root.add_child(floor)
			var cell := _cell(at)
			if cell.kind == Kind.BRICK:
				var brick := _sprite(brick_tex, false, _cell_top_left(at, Vector2(-12, -31)))
				_brick_root.add_child(brick)
				_brick_sprites[at] = brick
	var bush := _sprite(bush_tex, false, _cell_top_left(BUSH_CELL, Vector2(-1, -10)))
	_brick_root.add_child(bush)
	_hero_sprite = Sprite2D.new()
	_hero_sprite.centered = false
	_bomb_root.get_parent().add_child(_hero_sprite)
	_view_ready = true
	sync_view()


func _sync_bricks() -> void:
	for at in _brick_sprites:
		var spr: Sprite2D = _brick_sprites[at]
		spr.visible = _cell(at).kind == Kind.BRICK


func _sync_pops() -> void:
	_clear_children(_pop_root)
	var tex: Texture2D = load("res://art/brick_pop.png")
	for item in pops:
		var pop: Pop = item
		_pop_root.add_child(_sprite(tex, false, _cell_top_left(pop.cell, Vector2(-22, -20.5))))


func _sync_flames() -> void:
	_clear_children(_flame_root)
	var center: Texture2D = load("res://art/flame_center.png")
	var arm: Texture2D = load("res://art/flame_arm.png")
	var tip: Texture2D = load("res://art/flame_tip.png")
	for item in explosions:
		var blast: Explosion = item
		for n in blast.painted.size():
			var at: Vector2i = blast.painted[n]
			var style: int = blast.style_of[n]
			var tex := center
			if style == Explosion.STYLE_ARM:
				tex = arm
			elif style == Explosion.STYLE_TIP:
				tex = tip
			var spr := _sprite(tex, true, Vector2(at) * float(SimRules.TILE_SIZE) + Vector2(15, 15))
			var dir_i: int = blast.dir_of[n]
			if dir_i >= 0:
				spr.rotation = deg_to_rad(SimRules.flame_degrees(dir_i))
			spr.modulate.a = blast.alpha / 100.0
			_flame_root.add_child(spr)


func _sync_bombs() -> void:
	_clear_children(_bomb_root)
	var tex: Texture2D = load("res://art/bomb.png")
	for item in bombs:
		var bomb: Bomb = item
		_bomb_root.add_child(_sprite(tex, false, _cell_top_left(bomb.cell, Vector2(-0.5, -5.5))))


func _sync_hero() -> void:
	var frames := [
		"res://art/hero_left.png",
		"res://art/hero_up.png",
		"res://art/hero_right.png",
		"res://art/hero_down.png",
	]
	_hero_sprite.texture = load(frames[hero.facing])
	_hero_sprite.position = hero.pixel_position() + Vector2(-4, -23)
	_hero_sprite.visible = hero.alive
	if hero.alive and hero.shield > 0 and hero.shield % 2 == 1:
		_hero_sprite.modulate.a = 0.3
	else:
		_hero_sprite.modulate.a = 1.0


func _cell_top_left(at: Vector2i, center_offset: Vector2) -> Vector2:
	return Vector2(at) * float(SimRules.TILE_SIZE) + Vector2(15, 15) + center_offset


func _sprite(tex: Texture2D, centered: bool, pos: Vector2) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = centered
	spr.position = pos
	return spr


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.free()


class Cell:
	var kind := 0
	var energy := 0
	var bomb = null


class Pop:
	var cell := Vector2i.ZERO
	var ticks := SimRules.BRICK_POP_TICKS

	func _init(at: Vector2i) -> void:
		cell = at
		ticks = SimRules.BRICK_POP_TICKS
