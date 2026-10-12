class_name OriginalHud
extends Node2D
## Root frame 9 / Symbols 537 and 536. Presentation only, sampled at 35 Hz.

const PANEL_Y := [47.4, 114.4, 181.45, 248.5]
const FONT = preload("res://art/original/fonts/295_Arial Black.ttf")
var art: OriginalArt
var panels: Array[Dictionary] = []
var previous: Array[Dictionary] = []
var blinks: Array[Dictionary] = []
var stage_label: Label
var timer_digits: Array[Label] = []
var portraits: Array[Texture2D] = []

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for number in range(1,5):portraits.append(load("res://art/original/hud/portrait-%d.png" % number))
	var background := Sprite2D.new()
	background.centered = false
	background.texture = load("res://art/original/hud/background.png")
	background.scale = Vector2.ONE / 2
	background.z_index = -150
	add_child(background)
	for id in 4:
		var panel := Node2D.new()
		panel.position = Vector2(43.95, PANEL_Y[id])
		add_child(panel)
		var portrait := Sprite2D.new()
		portrait.centered = false
		portrait.position = Vector2(-40,-40)
		portrait.scale = Vector2.ONE / 2
		panel.add_child(portrait)
		var bomb := art.sprite(371)
		bomb.scale = Vector2(0.333343505859375,0.3339385986328125)
		bomb.position = Vector2(26.3,-26.95) + art.offset(371) * bomb.scale
		panel.add_child(bomb)
		var status := {}
		for entry in [["shield",4,-15.5],["shoe",6,-4.55],["glove",2,6.4]]:
			var icon := OriginalTimeline.new()
			icon.art = art
			icon.symbol = 326
			icon.position = Vector2(26.4,entry[2])
			icon.scale = Vector2.ONE * 0.3149871826171875
			panel.add_child(icon)
			icon.show_frame(0,0,entry[1])
			status[entry[0]] = icon
		var lives := _label(panel, Rect2(-31,12.85,13.5,14.1), 10)
		var bombs := _label(panel, Rect2(11.75,-33.35,13.5,14.1), 10)
		var score := _label(panel, Rect2(-12.85,12.85,40.1,14.1), 10)
		score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var mask := Sprite2D.new()
		mask.centered = false
		mask.texture = load("res://art/original/hud/eliminated.png")
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/original/hud/manifest.json"))
		mask.position = Vector2(-24.75,15.45) + Vector2(manifest.mask_bounds[0],manifest.mask_bounds[1]) * 0.96038818359375
		mask.scale = Vector2.ONE * 0.96038818359375 / 2
		panel.add_child(mask)
		panels.append({"portrait":portrait,"life":lives,"totalBomb":bombs,"score":score,"bomb":bomb,"mask":mask,"shield":status.shield,"shoe":status.shoe,"glove":status.glove})
		previous.append({})
		blinks.append({})
	stage_label = _label(self, Rect2(54.6,305.2,16,14.05), 10)
	for x in [-36.35,-22.0,2.55,17.5]:
		timer_digits.append(_label(self, Rect2(48.55+x,336.55,13.9,14.05), 10))

func _label(parent: Node, rectangle: Rect2, font_size: int) -> Label:
	var label := Label.new()
	label.position = rectangle.position
	label.size = rectangle.size
	label.add_theme_font_override("font",FONT)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func sync(session: GameSession) -> void:
	for id in 4:
		var hero := session.state.heroes[id]
		var panel: Dictionary = panels[id]
		panel.portrait.texture = portraits[hero.character_id-1]
		panel.life.text = str(maxi(hero.lives,0))
		panel.totalBomb.text = str(hero.bombs_available)
		panel.score.text = str(hero.score)
		panel.mask.visible = hero.lives <= 0
		panel.bomb.texture = art.frame(371,session.state.tick_number % 40 + 1)
		panel.shield.visible = hero.armor
		panel.glove.visible = hero.glove
		panel.shoe.visible = hero.speed_level < SimRules.FRAMES_PER_TILE
		for entry in [["shield",4],["shoe",6],["glove",2]]:
			# Hidden icons have no script side effects. Sample the absolute source
			# phase when visible again instead of recomposing invisible layers.
			if panel[entry[0]].visible:
				panel[entry[0]].show_frame(session.state.tick_number % 80, session.state.tick_number, entry[1])
		var values := {"life":hero.lives,"totalBomb":hero.bomb_capacity,"bomb":hero.bomb_level,"shoe":hero.speed_level}
		if not previous[id].is_empty():
			for key in values:
				if (values[key] > previous[id][key] and key != "shoe") or (key == "shoe" and values[key] < previous[id][key]):
					blinks[id][key] = session.state.tick_number
		previous[id] = values
		for key in blinks[id].keys():
			var remaining: int = 35 - (session.state.tick_number - blinks[id][key])
			panel[key].visible = remaining <= 0 or remaining % 10 < 5
			if remaining <= 0:
				blinks[id].erase(key)
	stage_label.text = "%02d" % session.stage
	# Retain the accepted deterministic timer; source wall-clock policy is separate.
	var seconds := ceili(session.remaining_ticks / 35.0)
	var digits := "%02d%02d" % [seconds / 60, seconds % 60]
	for i in 4:
		timer_digits[i].text = digits[i]
