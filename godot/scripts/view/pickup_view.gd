class_name PickupView
extends OriginalTimeline

var kind := ""
var born := 0
var removed := -1
var variant := 1

func animate(clock_tick: int) -> bool:
	var frame_index := (clock_tick - born) % 80
	if removed >= 0:
		frame_index = 80 + clock_tick - removed
		if frame_index >= 100:
			return false
	show_frame(frame_index, 0, variant)
	return true
