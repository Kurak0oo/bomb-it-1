class_name WeaponIndicator
extends OriginalTimeline
## Sprite 299: nested item, recovered multiplication signs, and dynamic count.

var labels: Array[Label] = []
# Source device TextField: textWidth 9 for either 1 or 2, 18 for 10/11/12/20
# at size 15. Font 295 has no SWF advance table; the exported TTF's synthesized
# proportional advances cannot be used for this counter (issue-03 evidence).
const DIGIT_ADVANCE := 9.0

func _init() -> void:
	symbol = 299

func _ready() -> void:
	super._ready()
	for white in [false, true]:
		add_child(art.sprite(297 if white else 294))
		var label := _digit_label(white)
		label.position = Vector2(23.7,-46.3) if white else Vector2(24.3,-45.9)
		# Symbol 299 uses a device TextField. Its observed baseline is five pixels
		# below Godot Label's top-aligned baseline with the recovered font (see
		# reference/issue-03.md and the independent weapon-count captures).
		label.position.y += 5
		add_child(label)
		labels.append(label)

func _digit_label(white: bool) -> Label:
	var label := Label.new()
	label.size = Vector2(20.2,21.15)
	label.add_theme_font_override("font", load("res://art/original/fonts/295_Arial Black.ttf"))
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color.WHITE if white else Color("666666"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func sync(actor: HeroState) -> void:
	visible = actor.alive and actor.special_count > 0
	if not visible:
		return
	show_frame(0, 0, SpecialRules.WEAPONS.find(actor.special_weapon) + 7)
	var digits := str(actor.special_count)
	for layer in labels.size():
		var label := labels[layer]
		label.text = digits.left(1)
		for index in range(1, digits.length()):
			if label.get_child_count() < index:
				var digit := _digit_label(layer == 1)
				digit.position.x = index * DIGIT_ADVANCE
				label.add_child(digit)
		for index in label.get_child_count():
			var digit: Label = label.get_child(index)
			digit.visible = index + 1 < digits.length()
			if digit.visible:
				digit.text = digits[index + 1]
