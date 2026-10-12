extends SceneTree

var failed := false


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var state := GameState.new()
	state.setup_default()
	var view := GameView.new()
	view.state = state
	root.add_child(view)
	var command := PlayerCommands.new()
	command.request_bomb()
	state.tick([command])
	view.sync_view()
	var bomb_sprite: Node = view._bomb_sprites[state.bombs[0]]
	view.sync_view()
	check(view._bomb_sprites[state.bombs[0]] == bomb_sprite, "bomb sprite persists across synchronization")
	check(state.bombs[0].fuse == 60, "synchronization does not advance simulation")
	check(view._hero_sprites.size() == 4, "view renders all four actors")
	state.bombs[0].fuse = 1
	state.tick([])
	view.sync_view()
	check(not is_instance_valid(bomb_sprite), "removed bomb sprite is freed")
	var blast: ExplosionState = state.explosions[0]
	var group: Node = view._flame_sprites[blast]
	check(group.get_child_count() == 1, "center appears first")
	state.tick([])
	view.sync_view()
	check(view._flame_sprites[blast] == group and group.get_child_count() == 5, "growth appends to persistent explosion")
	var first_flame := group.get_child(0)
	view.sync_view()
	check(group.get_child(0) == first_flame, "existing flames persist")
	for i in 15:
		state.tick([])
		view.sync_view()
	check(not is_instance_valid(group) and view._flame_sprites.is_empty(), "expired explosion view is freed")
	view.free()
	if not failed:
		print("VIEW_OK")
	quit(1 if failed else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		print("FAIL: " + message)
