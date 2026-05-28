extends SceneTree

const OUTPUT_PATH := "C:/tmp/artifact_visual_gallery.png"
const VISUAL_CONTEXTS := [
	{
		"id": "red_trigger",
		"label": "Red Trigger",
		"context": {"weapon_type": "shotgun", "is_dead": false},
		"position": Vector3(-5.4, 0.0, -1.8),
	},
	{
		"id": "armor_sponge",
		"label": "Armor Sponge",
		"context": {"shield_ratio": 0.85, "is_dead": false},
		"position": Vector3(-1.8, 0.0, -1.8),
	},
	{
		"id": "silent_core",
		"label": "Silent Core",
		"context": {"move_speed": 5.0, "move_dir_x": 0.75, "move_dir_z": -0.35, "is_crouching": false, "is_dead": false},
		"position": Vector3(1.8, 0.0, -1.8),
	},
	{
		"id": "zone_battery",
		"label": "Zone Battery",
		"context": {"zone_battery_near": true, "zone_battery_charging": true, "is_dead": false},
		"position": Vector3(5.4, 0.0, -1.8),
	},
	{
		"id": "emergency_shell",
		"label": "Emergency Shell Ready",
		"context": {"is_dead": false},
		"position": Vector3(-3.6, 0.0, 2.0),
	},
	{
		"id": "emergency_shell",
		"label": "Emergency Shell Break",
		"context": {"is_dead": false, "event": "emergency_shell_triggered"},
		"position": Vector3(0.0, 0.0, 2.0),
	},
	{
		"id": "ghost_grass",
		"label": "Ghost Grass",
		"context": {"ghost_grass_active": true, "is_dead": false},
		"position": Vector3(3.6, 0.0, 2.0),
	},
]

var _visuals_script = null


func _init():
	_run.call_deferred()


func _run() -> void:
	_visuals_script = load("res://src/entities/player/PlayerArtifactVisuals.gd")
	var catalog_script = load("res://src/core/ArtifactCatalog.gd")
	var artifact_by_id := {}
	for artifact in catalog_script.starting_artifacts(1):
		artifact_by_id[String(artifact.get("id", ""))] = artifact

	root.size = Vector2i(1280, 720)
	var scene_root = Node3D.new()
	root.add_child(scene_root)

	var world_env = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.035, 0.04, 0.055)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.36, 0.42)
	env.ambient_light_energy = 1.0
	world_env.environment = env
	scene_root.add_child(world_env)

	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-58.0, -38.0, 0.0)
	light.light_energy = 2.1
	scene_root.add_child(light)

	var camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.4
	camera.look_at_from_position(Vector3(0.0, 6.8, 8.8), Vector3(0.0, 0.95, 0.0), Vector3.UP)
	camera.current = true
	scene_root.add_child(camera)

	for spec in VISUAL_CONTEXTS:
		_add_artifact_preview(scene_root, spec, artifact_by_id)

	await process_frame
	await process_frame
	await process_frame

	var image = root.get_texture().get_image()
	if image == null:
		push_error("Could not capture artifact visual gallery.")
		quit(1)
		return
	var err = image.save_png(OUTPUT_PATH)
	if err != OK:
		var fallback = ProjectSettings.globalize_path("user://artifact_visual_gallery.png")
		err = image.save_png(fallback)
		if err == OK:
			print("Artifact visual gallery saved: %s" % fallback)
			quit(0)
			return
		push_error("Could not save artifact visual gallery.")
		quit(1)
		return

	print("Artifact visual gallery saved: %s" % OUTPUT_PATH)
	quit(0)


func _add_artifact_preview(scene_root: Node3D, spec: Dictionary, artifact_by_id: Dictionary) -> void:
	var artifact_id = String(spec.get("id", ""))
	var artifact: Dictionary = artifact_by_id.get(artifact_id, {})
	var host = Node3D.new()
	host.name = "%sPreview" % artifact_id
	host.position = spec.get("position", Vector3.ZERO)
	scene_root.add_child(host)

	var body = MeshInstance3D.new()
	var body_mesh = CapsuleMesh.new()
	body_mesh.radius = 0.48
	body_mesh.height = 2.0
	body.mesh = body_mesh
	body.position = Vector3(0.0, 1.0, 0.0)
	body.material_override = _make_material(Color(0.22, 0.92, 0.42, 1.0), 0.14)
	host.add_child(body)

	var base_disc = MeshInstance3D.new()
	var base_mesh = CylinderMesh.new()
	base_mesh.top_radius = 0.82
	base_mesh.bottom_radius = 0.82
	base_mesh.height = 0.04
	base_mesh.radial_segments = 32
	base_disc.mesh = base_mesh
	base_disc.position = Vector3(0.0, 0.02, 0.0)
	base_disc.material_override = _make_material(Color(0.12, 0.14, 0.18, 0.92), 0.0)
	host.add_child(base_disc)

	var label = Label3D.new()
	label.text = String(spec.get("label", artifact_id))
	label.position = Vector3(0.0, 2.45, 0.0)
	label.font_size = 32
	label.modulate = artifact.get("color", Color.WHITE)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	host.add_child(label)

	var visuals = _visuals_script.new()
	visuals.attach(host)
	visuals.configure(artifact)
	var context: Dictionary = spec.get("context", {})
	if String(context.get("event", "")) != "":
		visuals.on_artifact_event(String(context.get("event", "")))
	for i in range(8):
		visuals.tick(0.05, context)


func _make_material(color: Color, emission_mult: float) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = emission_mult > 0.0
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = emission_mult
	if color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
