extends SceneTree


const DEFAULT_MAP_PATH := "res://data/mapSpec_night_forest_expanded_candidate.json"
const DEFAULT_PRESET := "night_br_m1_60"


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var options := _capture_options()
	var map_path := String(options["map_path"])
	var preset := String(options["preset"])
	var output_tag := String(options["output_tag"])
	var output_path := "C:/tmp/full_map_%s.png" % output_tag
	var minimap_output_path := "C:/tmp/minimap_%s.png" % output_tag

	var game_config = load("res://src/core/GameConfig.gd").new()
	game_config.load_or_default()
	var definition = load("res://src/core/MapDefinition.gd").new()
	var file := FileAccess.open(map_path, FileAccess.READ)
	if file == null or not definition.load_from_json(file.get_as_text(), map_path, game_config):
		push_error("Could not load %s for map capture." % map_path)
		quit(1)
		return
	if not definition.has_scale_preset(preset):
		push_error("Map capture preset does not exist: %s." % preset)
		quit(1)
		return

	var world_builder = load("res://src/maps/WorldBuilder.gd").new()
	world_builder.generate_world(definition.map_spec, null)
	var features: Array[Dictionary] = world_builder.get_minimap_features()
	world_builder.free()

	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(canvas)

	var overlay = load("res://src/ui/FullMapOverlay.gd").new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(overlay)
	overlay.set_map_data(definition, definition.map_spec, features, preset)
	var half_size: float = definition.get_world_size() * 0.5
	overlay.set_runtime_state(
		Vector2(-half_size * 0.14, half_size * 0.10),
		Vector2(0.7, -0.7),
		Vector2.ZERO,
		half_size * 0.84,
		Vector2(half_size * 0.14, -half_size * 0.10),
		half_size * 0.48,
		Vector2(half_size * 0.27, half_size * 0.38),
		"pending"
	)
	overlay.show_map()

	await process_frame
	await process_frame
	await process_frame
	await process_frame

	var image := root.get_texture().get_image()
	if image == null:
		push_error("Could not capture the full-map orientation.")
		quit(1)
		return
	var err := image.save_png(output_path)
	if err != OK:
		push_error("Could not save the full-map orientation capture.")
		quit(1)
		return
	print("Full-map orientation capture saved: %s" % output_path)

	overlay.hide_map()
	overlay.queue_free()
	await process_frame

	var minimap_viewport := SubViewport.new()
	minimap_viewport.size = Vector2i(280, 280)
	minimap_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(minimap_viewport)
	var minimap = load("res://src/ui/Minimap.gd").new()
	minimap.position = Vector2.ZERO
	minimap.size = Vector2(280.0, 280.0)
	minimap.minimap_size = Vector2(280.0, 280.0)
	minimap_viewport.add_child(minimap)
	minimap.set_map_spec(definition.map_spec, features, definition)

	await process_frame
	await process_frame
	await process_frame

	var minimap_image := minimap_viewport.get_texture().get_image()
	if minimap_image == null or minimap_image.save_png(minimap_output_path) != OK:
		push_error("Could not save the minimap orientation capture.")
		quit(1)
		return
	print("Minimap orientation capture saved: %s" % minimap_output_path)
	quit(0)


func _capture_options() -> Dictionary:
	var options := {
		"map_path": DEFAULT_MAP_PATH,
		"preset": DEFAULT_PRESET,
		"output_tag": "orientation",
	}
	for arg in OS.get_cmdline_user_args():
		var value := String(arg)
		if value.begins_with("map_spec_path="):
			options["map_path"] = value.trim_prefix("map_spec_path=")
		elif value.begins_with("scale_preset="):
			options["preset"] = value.trim_prefix("scale_preset=")
		elif value.begins_with("output_tag="):
			var tag := value.trim_prefix("output_tag=").replace("/", "_").replace("\\", "_")
			if not tag.is_empty():
				options["output_tag"] = tag
	return options
