extends SceneTree


const OUTPUT_PATH := "C:/tmp/player_night_readability.png"


func _init():
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)

	var scene_root := Node3D.new()
	root.add_child(scene_root)

	_add_environment(scene_root)
	_add_camera(scene_root)
	_add_readability_preview(scene_root)

	await process_frame
	await process_frame
	await process_frame
	await process_frame

	var image := root.get_texture().get_image()
	if image == null:
		push_error("Could not capture player night readability preview.")
		quit(1)
		return
	var err := image.save_png(OUTPUT_PATH)
	if err != OK:
		var fallback := ProjectSettings.globalize_path("user://player_night_readability.png")
		err = image.save_png(fallback)
		if err == OK:
			print("Player night readability preview saved: %s" % fallback)
			quit(0)
			return
		push_error("Could not save player night readability preview.")
		quit(1)
		return

	print("Player night readability preview saved: %s" % OUTPUT_PATH)
	quit(0)


func _add_environment(scene_root: Node3D) -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.012, 0.018)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.055, 0.065, 0.085)
	env.ambient_light_energy = 0.22
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	world_env.environment = env
	scene_root.add_child(world_env)

	var moon := DirectionalLight3D.new()
	moon.name = "LowMoonLight"
	moon.rotation_degrees = Vector3(-58.0, -35.0, 0.0)
	moon.light_color = Color(0.52, 0.62, 0.78)
	moon.light_energy = 0.08
	moon.shadow_enabled = true
	scene_root.add_child(moon)

	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(24.0, 16.0)
	ground.mesh = ground_mesh
	ground.material_override = _material(Color(0.025, 0.030, 0.026), 0.0, false)
	scene_root.add_child(ground)

	_add_low_wall(scene_root, Vector3(-4.2, 0.35, -2.4), Vector3(2.6, 0.7, 0.75), Color(0.11, 0.12, 0.12))
	_add_low_wall(scene_root, Vector3(5.0, 0.35, -1.1), Vector3(2.2, 0.7, 0.75), Color(0.10, 0.11, 0.12))
	_add_bush_preview(scene_root, Vector3(-3.2, 0.16, 2.8))
	_add_bush_preview(scene_root, Vector3(2.9, 0.16, 3.0))
	_add_pickup_preview(scene_root, Vector3(0.0, 0.16, -4.8), Color(0.95, 0.82, 0.25), "Ammo")
	_add_pickup_preview(scene_root, Vector3(3.2, 0.16, -5.8), Color(0.34, 0.70, 1.0), "Armor")


func _add_camera(scene_root: Node3D) -> void:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.6
	camera.look_at_from_position(Vector3(0.0, 9.2, 10.2), Vector3(0.0, 0.6, -0.8), Vector3.UP)
	camera.current = true
	scene_root.add_child(camera)


func _add_readability_preview(scene_root: Node3D) -> void:
	var readability_script = load("res://src/entities/player/PlayerNightReadability.gd")
	var host := Node3D.new()
	host.name = "PlayerNightPreview"
	host.position = Vector3(0.0, 0.0, 2.0)
	host.rotation.y = PI
	scene_root.add_child(host)

	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.42
	body_mesh.height = 1.75
	body.mesh = body_mesh
	body.position = Vector3(0.0, 0.95, 0.0)
	body.material_override = _material(Color(0.18, 0.85, 0.30), 0.08, false)
	host.add_child(body)

	var spot := SpotLight3D.new()
	spot.name = "VisionSpot"
	host.add_child(spot)

	var proximity := OmniLight3D.new()
	proximity.name = "ProximityLight"
	host.add_child(proximity)

	var readability = readability_script.new()
	readability.attach(host, spot, proximity)
	readability.configure_for_metadata({
		"id": "night_artificial_forest_candidate",
		"theme": "night_artificial_forest",
		"layout": "diagonal_sluice_black_ridge_wire_broadcast_false_clinic_probe_integrated",
	})

	_add_beam_guide(host)


func _add_beam_guide(host: Node3D) -> void:
	var guide := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.22
	mesh.bottom_radius = 2.6
	mesh.height = 7.2
	mesh.radial_segments = 32
	guide.mesh = mesh
	guide.position = Vector3(0.0, 0.035, -3.8)
	guide.rotation_degrees.x = 90.0
	guide.material_override = _material(Color(1.0, 0.86, 0.48, 0.14), 0.18, true)
	host.add_child(guide)


func _add_low_wall(scene_root: Node3D, pos: Vector3, scale: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = scale
	node.mesh = mesh
	node.position = pos
	node.material_override = _material(color, 0.0, false)
	scene_root.add_child(node)


func _add_bush_preview(scene_root: Node3D, pos: Vector3) -> void:
	for i in range(5):
		var node := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.62
		mesh.height = 0.48
		mesh.radial_segments = 12
		mesh.rings = 6
		node.mesh = mesh
		node.position = pos + Vector3((i - 2) * 0.42, 0.0, sin(float(i)) * 0.34)
		node.scale = Vector3(1.1, 0.42, 0.82)
		node.material_override = _material(Color(0.11, 0.22, 0.09, 0.86), 0.0, true)
		scene_root.add_child(node)


func _add_pickup_preview(scene_root: Node3D, pos: Vector3, color: Color, label_text: String) -> void:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.38
	mesh.bottom_radius = 0.38
	mesh.height = 0.16
	mesh.radial_segments = 24
	node.mesh = mesh
	node.position = pos
	node.material_override = _material(color, 0.55, false)
	scene_root.add_child(node)

	var light := OmniLight3D.new()
	light.position = pos + Vector3(0.0, 0.45, 0.0)
	light.light_color = color
	light.light_energy = 0.35
	light.omni_range = 1.8
	scene_root.add_child(light)

	var label := Label3D.new()
	label.text = label_text
	label.position = pos + Vector3(0.0, 0.72, 0.0)
	label.font_size = 24
	label.modulate = Color(0.86, 0.90, 0.82)
	label.outline_size = 6
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	scene_root.add_child(label)


func _material(color: Color, emission_mult: float, transparent: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.75
	material.emission_enabled = emission_mult > 0.0
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = emission_mult
	if transparent or color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.alpha_scissor_threshold = 0.02
	return material
