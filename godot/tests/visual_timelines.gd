extends SceneTree
## Render contact sheets from the same view classes used during play.
var art: OriginalArt
var page: Node2D

func _init() -> void:
	call_deferred("run")

func run() -> void:
	art = OriginalArt.new()
	RenderingServer.set_default_clear_color(Color("fff0fa"))
	page = Node2D.new()
	root.add_child(page)
	label("Recovered character death · 35 frames/sec", Vector2(15,8))
	var ages := [0,5,11,20,34]
	for column in ages.size():
		label("Frame %d" % (ages[column]+1), Vector2(96+column*88,34))
	for row in 4:
		label("Robot %d" % (row+1), Vector2(12,88+row*80))
		for column in ages.size():
			var actor := HeroState.new()
			actor.character_id = row + 1
			actor.alive = false
			actor.death_ticks = ages[column]
			actor.death_position = Vector2(106+column*88,100+row*80)
			var hero := HeroView.new()
			hero.actor = actor
			hero.art = art
			hero.frozen = true
			page.add_child(hero)
	await capture("death-timelines")
	page.free()
	page = Node2D.new()
	root.add_child(page)
	label("Recovered pickups · idle and removal", Vector2(15,8))
	var frames := [0,20,40,79,80,85,90,99]
	for column in frames.size():
		label(str(frames[column]+1), Vector2(60+column*60,36))
		for row in 2:
			var pickup := OriginalTimeline.new()
			pickup.art = art
			pickup.symbol = 326
			pickup.position = Vector2(50+column*60,78+row*58)
			page.add_child(pickup)
			pickup.show_frame(frames[column], 0, 3 if row == 0 else 10)
	label("Rocket directions · original exhaust and smoke", Vector2(15,195))
	for direction in 4:
		var at := Vector2(75+direction*130,280)
		var vector := Vector2(SimRules.direction(direction))
		for age in [18,12,6,0]:
			var smoke := OriginalTimeline.new()
			smoke.art = art
			smoke.symbol = 313
			smoke.position = at - vector * age * 1.5
			page.add_child(smoke)
			smoke.show_frame(direction, age)
		var rocket := OriginalTimeline.new()
		rocket.art = art
		rocket.symbol = 305
		rocket.position = at
		page.add_child(rocket)
		rocket.show_frame(direction, direction * 2)
		label(["Left","Up","Right","Down"][direction], Vector2(at.x,350))
	await capture("effect-timelines")
	page.free()
	print("VISUAL_TIMELINES_OK")
	quit()

func label(value: String, at: Vector2) -> void:
	var text := Label.new()
	text.text = value
	text.position = at
	text.add_theme_font_size_override("font_size", 12)
	text.add_theme_color_override("font_color", Color("572047"))
	page.add_child(text)

func capture(name_text: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../reference/qa-" + name_text + ".png"))
