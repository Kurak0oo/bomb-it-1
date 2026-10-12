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
	var grenade_profile := OS.get_cmdline_user_args().has("--grenade-account")
	var accounting_profile := OS.get_cmdline_user_args().has("--accounting-profile")
	var icewalk_profile := OS.get_cmdline_user_args().has("--icewalk-profile")
	var dispatch_profile := OS.get_cmdline_user_args().has("--dispatch-profile")
	var contact_profile := icewalk_profile or OS.get_cmdline_user_args().has("--contact-profile")
	var stem := "dispatch" if dispatch_profile else "icewalk" if icewalk_profile else "contact" if contact_profile else "grenadescore" if grenade_profile else "accounting" if accounting_profile else "interaction"
	var path := "res://tests/fixtures/%s_scenarios.json" % stem
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
		if fixture.has("controlled_actor"):
			state.heroes[int(fixture.controlled_actor)-1].moving = false
		var samples := []
		for tick in fixture.commands.size():
			for event in fixture.events:
				if event.tick == tick:
					install_bomb(state,event,true)
			var commands: Array[PlayerCommands] = []
			if fixture.has("controlled_actor"):
				for i in 4:
					commands.append(PlayerCommands.new())
				var dir := int(fixture.commands[tick][0])
				if dir >= 0:
					commands[int(fixture.controlled_actor)-1].direction = SimRules.direction(dir)
			state.tick(commands)
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
				if accounting_profile:
					row[key+"KillScore"] = actor.kill_score
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
			if contact_profile:
				var probe: HeroState = state.heroes[int(fixture.probe_actor)-1]
				row.probeCellX = probe.cell.x
				row.probeCellY = probe.cell.y
				row.probeXTwips = roundi(probe.pixel_position().x*20)
				row.probeYTwips = roundi(probe.pixel_position().y*20)
				row.probeMoving = probe.moving
			samples.append(row)
		scenarios[fixture.name] = samples
	var capture := {"source":"godot-rebuild","runtime":Engine.get_version_info().string,
        "profile":config.profile,"fps":int(config.fps),"tick_origin":config.tick_origin,
        "configuration_sha256":FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text(),"scenarios":scenarios}
	var output := OS.get_environment("BOMB_IT_CORE_TRACE")
	if output != "":
		var file := FileAccess.open(output,FileAccess.WRITE)
		if file == null:
			push_error("Cannot write interaction reference capture")
			quit(1)
			return
		file.store_string(JSON.stringify(capture,"  "))
	if OS.get_cmdline_user_args().has("--verify-reference"):
		var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/%s_original.json" % stem))
		if stem == "interaction" or reference.configuration_sha256 != capture.configuration_sha256 or reference.source != "original-swf-bytecode":
			push_error("Incompatible independent interaction reference")
			quit(1)
			return
		for name in scenarios:
			for tick in scenarios[name].size():
				for field in scenarios[name][tick]:
					if scenarios[name][tick][field] != reference.scenarios[name][tick][field]:
						print("FAIL: %s tick %d %s: source=%s rebuild=%s" % [name,tick,field,reference.scenarios[name][tick][field],scenarios[name][tick][field]])
						quit(1)
						return
	print("CORE_REFERENCE_CAPTURE_OK")
	quit()
