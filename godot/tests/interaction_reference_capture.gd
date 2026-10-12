extends SceneTree
## Controlled state adapter; observations use the public simulation update.

func _init() -> void:
	call_deferred("run")

func install_bomb(state: GameState, spec: Dictionary, deferred: bool) -> void:
	var at := Vector2i(spec.cell[0],spec.cell[1])
	var bomb := BombState.new(at,int(spec.owner)-1)
	bomb.fuse = spec.fuse
	bomb.just_placed = deferred
	state.bombs.append(bomb)
	state.register_callback(bomb)
	state.cell_at(at).bomb = bomb
	state.heroes[bomb.owner_id].bombs_available -= 1

func run() -> void:
	var path := "res://tests/fixtures/interaction_scenarios.json"
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var scenarios := {}
	for fixture in config.scenarios:
		var state := GameState.new()
		var map := PackedStringArray()
		for y in 13:
			map.append("...............")
		state.setup(map)
		for i in 4:
			var actor: HeroState = state.heroes[i]
			var setup: Dictionary = fixture.actors[i]
			actor.controller = HeroState.Controller.HUMAN if i < 2 else HeroState.Controller.AI
			actor.alive = true
			actor.cell = Vector2i(setup.cell[0],setup.cell[1])
			actor.lives = setup.life
			actor.shield = setup.shield
			actor.armor = setup.armor
			actor.bomb_capacity = 4
			actor.bombs_available = 4
			actor.moving = true
			actor.direction = Vector2i.ZERO
			actor.ticks_remaining = 9999
			actor.step_duration = 9999
		for at in fixture.walls:
			state.cell_at(Vector2i(at[0],at[1])).kind = GameState.Kind.SOLID
		for bomb in fixture.bombs:
			install_bomb(state,bomb,false)
		for spec in fixture.weapons:
			var actor: HeroState = state.heroes[int(spec.owner)-1]
			var old_cell := actor.cell
			actor.cell = Vector2i(spec.cell[0],spec.cell[1])
			actor.moving = false
			actor.facing = spec.face
			actor.special_weapon = spec.kind
			actor.special_count = 3
			if not SpecialRules.place(state,actor):
				push_error("Fixture special rejected: " + fixture.name)
				quit(1)
				return
			state.specials.back().just_placed = false
			actor.cell = old_cell
			actor.moving = true
		var samples := []
		for tick in fixture.commands.size():
			for event in fixture.events:
				if event.tick == tick:
					install_bomb(state,event,true)
			state.tick([])
			var row := {"tick":tick,"energies":"","owners":"","bombs":"","rockets":"",
				"rocketCount":0,"mineCount":0,"gasCount":0,"grenadeCount":0,"fireCount":0,"iceCount":0}
			for i in 4:
				var actor: HeroState = state.heroes[i]
				var key := "hero%d" % (i+1)
				row[key+"Alive"] = actor.alive
				row[key+"Life"] = actor.lives
				row[key+"Armor"] = actor.armor if actor.alive else false
				row[key+"Shield"] = actor.shield if actor.alive else 0
				row[key+"Slow"] = actor.slow_ticks if actor.alive else 0
				row[key+"Stop"] = actor.stop_ticks if actor.alive else 0
				row[key+"Bombs"] = actor.bombs_available
				row[key+"Score"] = actor.score
			for y in 13:
				for x in 15:
					var cell: CellState = state.cell_at(Vector2i(x,y))
					if cell.energy > 0:
						row.energies += "%d,%d,%d,%d;" % [x,y,cell.energy,cell.energy_owner+1]
					if cell.energy_owner >= 0:
						row.owners += "%d,%d,%d;" % [x,y,cell.energy_owner+1]
					if cell.bomb != null:
						row.bombs += "%d,%d,%d,%d;" % [x,y,cell.bomb.owner_id+1,cell.bomb.fuse]
			for weapon in state.specials:
				if row.has(weapon.kind+"Count"):
					row[weapon.kind+"Count"] += 1
				if weapon.kind == "rocket":
					row.rockets += "%d,%d,%d;" % [weapon.owner_id+1,roundi(weapon.position.x*20),roundi(weapon.position.y*20)]
			samples.append(row)
		scenarios[fixture.name] = samples
	var file := FileAccess.open(OS.get_environment("BOMB_IT_CORE_TRACE"),FileAccess.WRITE)
	if file == null:
		push_error("Cannot write interaction reference capture")
		quit(1)
		return
	file.store_string(JSON.stringify({"source":"godot-rebuild","runtime":Engine.get_version_info().string,
		"profile":config.profile,"fps":int(config.fps),"tick_origin":config.tick_origin,
		"configuration_sha256":FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text(),"scenarios":scenarios},"  "))
	print("CORE_REFERENCE_CAPTURE_OK")
	quit()
