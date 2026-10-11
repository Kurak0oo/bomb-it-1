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
	var at := Vector2i(5,3)
	state.cell_at(at).item = "shoe"
	view.sync_view()
	var pickup: PickupView = view._item_sprites[at]
	var icon := pickup.layers[1]
	check(icon.texture == view.art.frame(293, 6), "pickup retains item identity inside nested timeline")
	check(icon.position.is_equal_approx(Vector2(15,-1.7) + view.art.offset(293)), "pickup begins at source frame-one transform")
	state.tick_number += 5
	view.sync_view()
	check(is_equal_approx(icon.position.y, -3.75 + view.art.offset(293).y), "pickup uses recovered frame-six bob")
	var before := icon.transform
	view.sync_view()
	check(icon.transform == before, "repeat synchronization does not advance animation")
	state.cell_at(at).item = ""
	view.sync_view()
	check(is_instance_valid(pickup) and view._retiring_items.size() == 1, "pickup removal plays instead of disappearing")
	check(is_equal_approx(icon.modulate.a, 0.90234375), "removal begins at original frame 81")
	for i in 20:
		view.advance_presentation()
	check(not is_instance_valid(pickup) and view._retiring_items.is_empty(), "removed pickup freed at original frame 101")
	for character in range(1,5):
		var actor := state.heroes[character - 1]
		actor.character_id = character
		actor.death_position = actor.pixel_position()
		actor.alive = false
		actor.death_ticks = 0
		view.sync_view()
		var hero: HeroView = view._hero_sprites[actor.id]
		check(hero.body.visible and hero.burst.visible and hero.smoke.visible, "death starts with hero, burst and smoke")
		for i in 5:
			hero.advance_presentation()
		check(not hero.body.visible and hero.death.layers[1].visible, "frame six swaps hero for silhouette")
		check(hero.death.layers[1].texture == view.art.frame(233 if character <= 2 else 235), "death silhouette matches source character body")
		check(is_equal_approx(hero.death.layers[1].modulate.a, 0.19921875), "death silhouette uses source fade")
		for i in 30:
			hero.advance_presentation()
		check(not hero.visible and actor.death_ticks == 0, "death completes without advancing authoritative state")
	var rocket := SpecialState.new("rocket", state.heroes[0])
	rocket.direction = Vector2i.RIGHT
	rocket.age = 1
	state.specials.append(rocket)
	view.sync_view()
	check(view._trails.size() == 1, "rocket emits original smoke timeline")
	view.sync_view()
	check(view._trails.size() == 1, "repeat synchronization cannot duplicate smoke")
	var rocket_view: OriginalTimeline = view._special_sprites[rocket].get_child(0)
	check(rocket_view.layers[0].texture == view.art.frame(304, 2), "rocket exhaust child advances independently")
	var projectile: Node2D = view._special_sprites[rocket]
	var start := rocket.position
	view.capture_positions()
	rocket.position += Vector2(20,0)
	view.sync_view()
	view._render_motion(0.5)
	check(projectile.position.is_equal_approx(start + Vector2(10,0)), "projectile rendering interpolates between simulation positions")
	check(rocket.position.is_equal_approx(start + Vector2(20,0)), "interpolation never changes projectile state")
	view.frozen = true
	view._render_motion(0.1)
	check(projectile.position == rocket.position, "pause renders latest position without interpolation drift")
	state.specials.clear()
	view.sync_view()
	check(view._trails.size() == 1, "rocket smoke survives its parent projectile")
	for i in 21:
		view.advance_presentation()
	check(view._trails.is_empty(), "smoke freed on source removal frame")
	view.free()
	if not failed:
		print("TIMELINE_OK")
	quit(1 if failed else 0)

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		print("FAIL: " + message)
