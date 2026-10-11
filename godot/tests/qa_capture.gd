extends RefCounted
## Captures are run artifacts. Approved baselines are never written by tests.

static func capture(tree: SceneTree, name_text: String) -> void:
	await tree.process_frame
	await RenderingServer.frame_post_draw
	var directory := OS.get_environment("BOMB_IT_QA_DIR")
	if directory == "":
		directory = ProjectSettings.globalize_path("res://../.artifacts/captures")
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		push_error("Cannot create capture directory: " + directory)
		tree.quit(1)
		return
	var error := tree.root.get_texture().get_image().save_png(directory.path_join("qa-" + name_text + ".png"))
	if error != OK:
		push_error("Cannot save capture: " + name_text)
		tree.quit(1)
	var file := FileAccess.open(directory.path_join("runtime.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot save capture runtime metadata")
		tree.quit(1)
		return
	file.store_string(JSON.stringify({"engine": Engine.get_version_info().string,
		"os": OS.get_name(), "renderer": RenderingServer.get_video_adapter_name(),
		"display": DisplayServer.get_name()}, "  "))
