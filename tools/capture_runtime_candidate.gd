extends SceneTree


const DEFAULT_OUTPUT_PATH := "C:/tmp/runtime_candidate.png"


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	root.size = Vector2i(1920, 1080)
	var main_scene: PackedScene = load("res://src/Main.tscn")
	if main_scene == null:
		push_error("Could not load Main.tscn for runtime capture.")
		quit(1)
		return

	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	if not main.has_method("start_game"):
		push_error("Main scene does not expose start_game for runtime capture.")
		quit(1)
		return
	main.start_game()
	await create_timer(4.0).timeout
	await process_frame
	await process_frame

	var image := root.get_texture().get_image()
	if image == null:
		push_error("Could not read the runtime candidate viewport.")
		quit(1)
		return

	var output_path := DEFAULT_OUTPUT_PATH
	for arg in OS.get_cmdline_user_args():
		var value := String(arg)
		if value.begins_with("capture_output="):
			output_path = value.trim_prefix("capture_output=")
	var err := image.save_png(output_path)
	if err != OK:
		push_error("Could not save runtime candidate capture: %s." % output_path)
		quit(1)
		return
	print("Runtime candidate capture saved: %s" % output_path)
	quit(0)
