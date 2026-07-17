extends SceneTree


const OVERVIEW_OUTPUT_PATH := "C:/tmp/world_route_cues_overview.png"
const PLAYER_VIEW_OUTPUT_PATH := "C:/tmp/world_route_cues_player_view.png"
const MAP_PATH := "res://data/mapSpec_night_forest_candidate.json"


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	root.size = Vector2i(1280, 720)

	var scene_root := Node3D.new()
	root.add_child(scene_root)
	_add_environment(scene_root)

	var definition = _load_map_definition()
	if definition == null:
		quit(1)
		return

	var world_builder = load("res://src/maps/WorldBuilder.gd").new()
	scene_root.add_child(world_builder)
	world_builder.generate_world(definition.map_spec, null)
	if world_builder.get_route_cue_descriptors().is_empty():
		push_error("World route cue capture found no route cues.")
		quit(1)
		return

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	camera.near = 0.1
	camera.far = 300.0
	scene_root.add_child(camera)

	var overview_captured: bool = await _capture_view(
		camera,
		Vector3.ZERO,
		180.0,
		OVERVIEW_OUTPUT_PATH,
		Vector2i(960, 960),
		true
	)
	if not overview_captured:
		quit(1)
		return
	var player_view_captured: bool = await _capture_view(
		camera,
		Vector3(48.0, 0.0, 22.0),
		12.0,
		PLAYER_VIEW_OUTPUT_PATH,
		Vector2i(1280, 720),
		false
	)
	if not player_view_captured:
		quit(1)
		return
	quit(0)


func _load_map_definition():
	var game_config = load("res://src/core/GameConfig.gd").new()
	game_config.load_or_default()
	var definition = load("res://src/core/MapDefinition.gd").new()
	var file := FileAccess.open(MAP_PATH, FileAccess.READ)
	if file == null or not definition.load_from_json(file.get_as_text(), MAP_PATH, game_config):
		push_error("Could not load the Night map for world route cue capture.")
		return null
	return definition


func _add_environment(scene_root: Node3D) -> void:
	var world_env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.12, 0.14, 0.18)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.1
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	world_env.environment = environment
	scene_root.add_child(world_env)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-58.0, -35.0, 0.0)
	moon.light_color = Color.WHITE
	moon.light_energy = 0.2
	moon.shadow_enabled = true
	scene_root.add_child(moon)

	var readability = load("res://src/environment/NightWorldReadability.gd").new()
	readability.attach(world_env, moon)
	readability.configure_for_metadata({"theme": "night_artificial_forest"})


func _capture_view(
	camera: Camera3D,
	target: Vector3,
	camera_size: float,
	output_path: String,
	viewport_size: Vector2i,
	top_down: bool
) -> bool:
	root.size = viewport_size
	camera.size = camera_size
	if top_down:
		camera.look_at_from_position(target + Vector3(0.0, 120.0, 0.0), target, Vector3.FORWARD)
	else:
		camera.look_at_from_position(
			target + Vector3(10.0, 14.142, 10.0),
			target,
			Vector3.UP
		)
	await process_frame
	await process_frame
	await process_frame
	await process_frame

	var image := root.get_texture().get_image()
	if image == null or image.save_png(output_path) != OK:
		push_error("Could not save world route cue capture: %s" % output_path)
		return false
	print("World route cue capture saved: %s" % output_path)
	return true
