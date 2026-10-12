extends SceneTree
## Runs shared input fixtures through accepted GameState; no expected traces.

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var path := "res://tests/fixtures/core_scenarios.json"
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var scenarios := {}
	for fixture in config.scenarios:
		var state := GameState.new()
		var map := PackedStringArray()
		for y in 13:
			map.append("...............")
		state.setup(map)
		for other in state.heroes:
			other.alive = false
		var actor := state.heroes[0]
		actor.alive = true
		actor.shield = 999
		var origin := Vector2i(8,6) if fixture.explosion == null else Vector2i(fixture.explosion[0],fixture.explosion[1])
		if fixture.explosion != null:
			actor.cell = origin
			var place := PlayerCommands.new()
			place.request_bomb()
			state.tick([place])
			state.bombs[0].fuse = 1
			state.tick([])
		actor.cell = Vector2i(fixture.cell[0],fixture.cell[1])
		actor.shield = fixture.shield
		actor.armor = fixture.armor
		actor.lives = 3
		actor.bombs_available = 3
		actor.bomb_capacity = 3
		actor.special_weapon = fixture.weapon
		actor.special_count = 3 if fixture.weapon == "mine" else 0
		var was_fire := false
		var samples := []
		for tick in fixture.commands.size():
			var input: Array = fixture.commands[tick]
			var command := PlayerCommands.new()
			command.direction = Vector2i.ZERO if input[0] < 0 else SimRules.direction(input[0])
			command.bomb_requested = input[1]
			command.bomb_released = was_fire and not input[1]
			was_fire = input[1]
			state.tick([command])
			var bombs := ""
			var mines := ""
			for y in 13:
				for x in 15:
					var at := Vector2i(x,y)
					var bomb: BombState = state.cell_at(at).bomb
					if bomb != null:
						bombs += "%d,%d,%d;" % [x,y,bomb.fuse]
					for special in state.specials:
						if special.kind == "mine" and special.origin == at:
							mines += "%d,%d;" % [x,y]
			var pixels := actor.pixel_position()
			var rounded := actor.rounded_cell()
			samples.append({"tick":tick,"cellX":actor.cell.x,"cellY":actor.cell.y,
				"pixelXTwips":roundi(pixels.x*20),"pixelYTwips":roundi(pixels.y*20),
				"roundedX":rounded.x,"roundedY":rounded.y,"moving":actor.moving,
				"moveRemaining":actor.ticks_remaining if actor.moving else 0,
				"prevFire":actor.prev_fire,"fireReady":actor.fire_ready,
				"bombsAvailable":actor.bombs_available,"bombs":bombs,
				"specialCount":actor.special_count,"mines":mines,"life":actor.lives,
				"armor":actor.armor,"shieldTicks":actor.shield,
				"originEnergy":state.cell_at(origin).energy,"probeEnergy":state.cell_at(Vector2i(9,6)).energy})
		scenarios[fixture.name] = samples
	var output := OS.get_environment("BOMB_IT_CORE_TRACE")
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file == null:
		push_error("Cannot write core reference capture")
		quit(1)
		return
	file.store_string(JSON.stringify({"source":"godot-rebuild","runtime":Engine.get_version_info().string,
		"profile":config.profile,"fps":int(config.fps),"tick_origin":config.tick_origin,
		"configuration_sha256":FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text(),"scenarios":scenarios},"  "))
	print("CORE_REFERENCE_CAPTURE_OK")
	quit()
