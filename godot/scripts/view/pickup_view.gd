class_name PickupView
extends OriginalTimeline

var kind := ""
var born := 0
var removed := -1
var variant := 1

func animate(clock_tick: int) -> bool:
	# Frame 80 immediately jumps to frame 1; it is not a displayed idle frame.
	var frame_index := (clock_tick - born) % 79
	if removed >= 0:
		frame_index = 80 + clock_tick - removed
		if frame_index >= 100:
			return false
	show_frame(frame_index, 0, variant)
	if removed >= 0 and variant <= 6:
		var icon := layers[1]
		var source_offset: Array = art.manifest.pickup_removal[str(variant)].offset
		icon.texture = art.pickup_fade(variant,frame_index-80)
		icon.position += icon.transform.basis_xform(Vector2(source_offset[0],source_offset[1])-art.offset(293))
		# The recovered SVG already applies the source alpha to each fill.
		icon.modulate.a = 1.0
	return true
