extends SceneTree
var failed := false
var physical_safe := Rect2()
var observations: Array = []
func _init() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value:
		failed = true
		push_error(message)
func finger(main: Node2D, id: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = id
	event.position = root.get_screen_transform() * main.touch.get_global_transform_with_canvas() * point
	event.pressed = pressed
	root.push_input(event,false)
func click(main: Node2D, point: Vector2) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = root.get_screen_transform() * main.get_global_transform_with_canvas() * point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,false)
func inspect_layout(main: Node2D, safe: Rect2, space: Transform2D = Transform2D.IDENTITY) -> Dictionary:
	var game: Rect2 = space * main.get_global_transform_with_canvas() * Rect2(0,0,550,400)
	var stick: Rect2 = space * main.touch.get_global_transform_with_canvas() * Rect2(main.touch._stick-Vector2.ONE*65,Vector2.ONE*130)
	var bomb: Rect2 = space * main.touch.get_global_transform_with_canvas() * Rect2(main.touch._bomb-Vector2.ONE*42,Vector2.ONE*84)
	check(safe.grow(0.01).encloses(game),"complete 550x400 game fits safe area")
	check(safe.grow(0.01).encloses(stick) and safe.grow(0.01).encloses(bomb),"all touch targets fit safe area")
	check(not game.intersects(stick) and not game.intersects(bomb),"touch targets never overlap HUD or arena")
	check(not stick.intersects(bomb),"touch targets remain separate")
	finger(main,7,main.touch._stick+Vector2(32,0),true)
	finger(main,8,main.touch._bomb,true)
	check(main.touch.direction == Vector2i.RIGHT and main.touch.bomb_held,"hit transforms work before draw")
	finger(main,7,main.touch._stick,false)
	finger(main,8,main.touch._bomb,false)
	return {"safe":rect_values(safe),"game":rect_values(game),"stick_hit":rect_values(stick),"bomb_hit":rect_values(bomb)}
func rect_values(rect: Rect2) -> Array:
	return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]
func screen_space() -> Transform2D:
	var mapping := root.get_screen_transform()
	mapping.origin += Vector2(root.position)
	return mapping
func run() -> void:
	root.size = Vector2i(550,400)
	var main = load("res://scenes/main.tscn").instantiate()
	main.save_enabled = false
	root.add_child(main)
	main.set_physics_process(false)
	main.touch_enabled = true
	main.session.start(42,1,1,1)
	main._show_round()
	inspect_layout(main,Rect2(0,0,550,400))
	await preload("res://tests/qa_capture.gd").capture(self,"layout-narrow")
	finger(main,7,main.touch._stick+Vector2(32,0),true)
	finger(main,8,main.touch._bomb,true)
	root.size = Vector2i(1100,800)
	check(main.touch.direction == Vector2i.ZERO and not main.touch.bomb_held,"same-aspect physical resize cancels captured touch before draw")
	root.size = Vector2i(1600,800)
	var safe := Rect2(36,8,748,376)
	var physical := screen_space() * safe
	main.safe_area_provider = func():return physical
	main._resize()
	inspect_layout(main,safe)
	await preload("res://tests/qa_capture.gd").capture(self,"layout-left-inset")
	# Supply OS-space fixtures, then resize the real Window. Observations are
	# transformed back to physical display space, not compared with layout math.
	main.safe_area_provider = func():return physical_safe
	root.position = Vector2i(50,50)
	var fixtures := [
		["native-insets",550,400,12,10,18,20,1.0],
		["small-landscape",1136,640,0,0,0,0,1.0],
		["notch-left",1688,780,88,0,0,42,1.0],
		["notch-right",1688,780,0,0,88,42,1.0],
		["four-insets",1600,800,72,16,32,32,1.0],
		["compact-insets",640,360,16,8,16,20,1.0],
		["content-scale",1600,800,72,16,32,32,1.25],
	]
	for fixture in fixtures:
		var native_size := Vector2i(fixture[1],fixture[2])
		physical_safe = Rect2(screen_space().origin+Vector2(fixture[3],fixture[4]),Vector2(native_size)-Vector2(fixture[3]+fixture[5],fixture[4]+fixture[6]))
		var resized: bool = root.size != native_size or root.content_scale_factor != fixture[7]
		root.content_scale_factor = fixture[7]
		root.size = native_size
		# An inset-only change is consumed before the next draw. Real resize
		# checks below occur synchronously without a process/layout helper call.
		if not resized:main._process(0)
		var row := inspect_layout(main,physical_safe,screen_space())
		click(main,Vector2(64,371))
		check(main.paused,"scaled HUD pause accepts physical window input before draw")
		click(main,Vector2(300,207))
		check(not main.paused,"scaled overlay resume accepts physical window input before draw")
		row["fixture"] = fixture
		row["logical_viewport"] = rect_values(root.get_visible_rect())
		observations.append(row)
		check(main.session.state.tick_number == 0,"layout changes never tick gameplay")
		await preload("res://tests/qa_capture.gd").capture(self,"layout-"+fixture[0])
		inspect_layout(main,physical_safe,screen_space())
	# A transformed Control must invert the full transform for touch and drag.
	main.touch.scale = Vector2(1.2,0.8)
	main.touch.position = Vector2(17,11)
	finger(main,7,main.touch._stick+Vector2(32,0),true)
	check(main.touch.direction == Vector2i.RIGHT,"scaled/translated control receives touch through its inverse transform")
	var drag := InputEventScreenDrag.new()
	drag.index = 7
	drag.position = root.get_screen_transform() * main.touch.get_global_transform_with_canvas() * (main.touch._stick+Vector2(0,-32))
	root.push_input(drag,false)
	check(main.touch.direction == Vector2i.UP,"scaled/translated control receives drag through its inverse transform")
	finger(main,7,main.touch._stick,false)
	main.touch.scale = Vector2.ONE
	main.touch.position = Vector2.ZERO
	var trace := FileAccess.open(OS.get_environment("BOMB_IT_QA_DIR").path_join("layout-trace.json"),FileAccess.WRITE)
	check(trace != null,"layout evidence can be saved")
	if trace != null:trace.store_string(JSON.stringify({"synthetic_display_insets":true,"observations":observations},"  "))
	main.queue_free()
	await process_frame
	await create_timer(1).timeout
	if not failed:print("LAYOUT_RENDER_OK")
	quit(1 if failed else 0)
