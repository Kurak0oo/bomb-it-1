extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(550, 400)
	RenderingServer.set_default_clear_color(Color.WHITE)
	var actor := HeroState.new()
	actor.alive = false
	actor.death_position = Vector2(240, 210)
	actor.death_ticks = 6
	var hero := HeroView.new()
	hero.actor = actor
	hero.art = OriginalArt.new()
	hero.frozen = true
	root.add_child(hero)
	await process_frame
	await RenderingServer.frame_post_draw
	var pixels := root.get_texture().get_image()
	# Original SWF frame seven: this interior eye pixel is gray (200/255).
	# Flash fades the overlapping body and eyes separately, not a flattened PNG.
	var eye := pixels.get_pixel(252, 200)
	var passed := eye.r > 0.74 and eye.r < 0.82 and absf(eye.r - eye.g) < 0.01
	if not passed:
		push_error("Death eye must composite over faded silhouette: " + str(eye))
	hero.free()
	if passed:
		print("DEATH_RENDER_OK")
	quit(0 if passed else 1)
