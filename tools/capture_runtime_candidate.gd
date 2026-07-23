extends SceneTree


const DEFAULT_OUTPUT_PATH := "C:/tmp/runtime_candidate.png"
const ITEM_CATALOG = preload("res://src/core/ItemResourceCatalog.gd")


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	root.size = Vector2i(1920, 1080)
	var options := _capture_options()
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
	var capture_position: Vector2 = options["player_position"]
	if capture_position.is_finite() and is_instance_valid(main.player_ref):
		main.player_ref.global_position = Vector3(capture_position.x, 0.5, capture_position.y)
		main.player_ref.velocity = Vector3.ZERO
	if bool(options["equip_armor"]) \
			and is_instance_valid(main.player_ref) \
			and main.player_ref.has_method("receive_armor_equipment"):
		main.player_ref.receive_armor_equipment(ITEM_CATALOG.BALLISTIC_VEST)
	await create_timer(float(options["settle_seconds"])).timeout
	await process_frame
	await process_frame

	var image := root.get_texture().get_image()
	if image == null:
		push_error("Could not read the runtime candidate viewport.")
		quit(1)
		return

	var output_path := String(options["output_path"])
	var err := image.save_png(output_path)
	if err != OK:
		push_error("Could not save runtime candidate capture: %s." % output_path)
		quit(1)
		return
	print("Runtime candidate capture saved: %s" % output_path)
	quit(0)


func _capture_options() -> Dictionary:
	var options := {
		"output_path": DEFAULT_OUTPUT_PATH,
		"player_position": Vector2.INF,
		"settle_seconds": 4.0,
		"equip_armor": false,
	}
	for arg in OS.get_cmdline_user_args():
		var value := String(arg)
		if value.begins_with("capture_output="):
			options["output_path"] = value.trim_prefix("capture_output=")
		elif value.begins_with("capture_player_position="):
			var components := value.trim_prefix("capture_player_position=").split(",")
			if components.size() == 2:
				options["player_position"] = Vector2(
					float(components[0]),
					float(components[1])
				)
		elif value.begins_with("capture_settle_seconds="):
			options["settle_seconds"] = maxf(
				0.0,
				float(value.trim_prefix("capture_settle_seconds="))
			)
		elif value.begins_with("capture_equip_armor="):
			options["equip_armor"] = value.trim_prefix("capture_equip_armor=") == "true"
	return options
