extends SceneTree


const OUTPUT_PATH := "C:/tmp/full_map_orientation.png"
const MINIMAP_OUTPUT_PATH := "C:/tmp/minimap_orientation.png"
const MAP_PATH := "res://data/mapSpec_night_forest_candidate.json"


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	root.size = Vector2i(1280, 720)

	var game_config = load("res://src/core/GameConfig.gd").new()
	game_config.load_or_default()
	var definition = load("res://src/core/MapDefinition.gd").new()
	var file := FileAccess.open(MAP_PATH, FileAccess.READ)
	if file == null or not definition.load_from_json(file.get_as_text(), MAP_PATH, game_config):
		push_error("Could not load the Night map for orientation capture.")
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
	overlay.set_map_data(definition, definition.map_spec, features, "playable_pacing_v6")
	overlay.set_runtime_state(
		Vector2(-18.0, 12.0),
		Vector2(0.7, -0.7),
		Vector2.ZERO,
		76.0,
		Vector2(18.0, -12.0),
		43.0,
		Vector2(34.0, 50.0),
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
	var err := image.save_png(OUTPUT_PATH)
	if err != OK:
		push_error("Could not save the full-map orientation capture.")
		quit(1)
		return
	print("Full-map orientation capture saved: %s" % OUTPUT_PATH)

	overlay.hide_map()
	overlay.queue_free()
	await process_frame

	var minimap_viewport := SubViewport.new()
	minimap_viewport.size = Vector2i(240, 240)
	minimap_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(minimap_viewport)
	var minimap = load("res://src/ui/Minimap.gd").new()
	minimap.position = Vector2.ZERO
	minimap.size = Vector2(240.0, 240.0)
	minimap.minimap_size = Vector2(240.0, 240.0)
	minimap_viewport.add_child(minimap)
	minimap.set_map_spec(definition.map_spec, features, definition)

	await process_frame
	await process_frame
	await process_frame

	var minimap_image := minimap_viewport.get_texture().get_image()
	if minimap_image == null or minimap_image.save_png(MINIMAP_OUTPUT_PATH) != OK:
		push_error("Could not save the minimap orientation capture.")
		quit(1)
		return
	print("Minimap orientation capture saved: %s" % MINIMAP_OUTPUT_PATH)
	quit(0)
