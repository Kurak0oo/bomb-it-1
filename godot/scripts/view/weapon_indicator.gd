class_name WeaponIndicator
extends OriginalTimeline
## Sprite 299: nested item, recovered multiplication signs, and dynamic count.

var labels: Array[Label] = []

func _init() -> void:
	symbol = 299

func _ready() -> void:
	super._ready()
	for white in [false, true]:
		add_child(art.sprite(297 if white else 294))
		var label := Label.new()
		label.position = Vector2(23.7,-46.3) if white else Vector2(24.3,-45.9)
		# Symbol 299 uses a device TextField. Its observed baseline is five pixels
		# below Godot Label's top-aligned baseline with the recovered font (see
		# reference/issue-03.md and the independent weapon-count captures).
		label.position.y += 5
		label.size = Vector2(20.2,21.15)
		label.add_theme_font_override("font", load("res://art/original/fonts/295_Arial Black.ttf"))
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color.WHITE if white else Color("666666"))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		labels.append(label)

func sync(actor: HeroState) -> void:
	visible = actor.alive and actor.special_count > 0
	if not visible:
		return
	show_frame(0, 0, SpecialRules.WEAPONS.find(actor.special_weapon) + 7)
	for label in labels:
		label.text = str(actor.special_count)
