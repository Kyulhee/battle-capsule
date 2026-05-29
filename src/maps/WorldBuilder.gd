extends Node3D
class_name WorldBuilder

@export var obstacle_scene: PackedScene = preload("res://src/environment/Obstacle.tscn")
@export var bush_scene: PackedScene = preload("res://src/environment/Bush.tscn")

const BUSH_PROP_ID := "forest.bush"

var minimap_features: Array[Dictionary] = []

func generate_world(spec: Resource, asset_catalog = null):
	# 1. Clear existing generated content if any
	for child in get_children():
		child.queue_free()
	minimap_features.clear()
		
	# 2. Build Floor and Boundaries
	_build_base(spec)
	
	# 3. Build Obstacles
	var obs_container = Node3D.new()
	obs_container.name = "GeneratedObstacles"
	add_child(obs_container)
	
	for o in spec.obstacles:
		var type_str = o.get("type", "rock_cluster")
		var pos = o.get("pos", [0, 0]).duplicate()
		var scale_vec = o.get("scale", [1, 1, 1])
		var rot_deg = o.get("rot", 0)

		# Deterministic jitter: seed from base position so result is stable per-map
		var jitter = o.get("jitter", [0, 0])
		if jitter[0] > 0 or jitter[1] > 0:
			var rng = RandomNumberGenerator.new()
			rng.seed = int(abs(pos[0]) * 3137 + abs(pos[1]) * 7919)
			pos[0] += rng.randf_range(-jitter[0], jitter[0])
			pos[1] += rng.randf_range(-jitter[1], jitter[1])
			rot_deg += rng.randf_range(-o.get("rot_jitter", 0.0), o.get("rot_jitter", 0.0))

		if type_str == "bush_patch":
			_build_bush_patch(obs_container, pos, scale_vec, rot_deg, asset_catalog)
			_record_minimap_feature(
				type_str,
				Vector2(pos[0], pos[1]),
				Vector2(scale_vec[0] * 3.0, scale_vec[2] * 3.0),
				rot_deg,
				scale_vec[1] * 2.0,
				0,
				"ellipse"
			)
		elif type_str == "rock_cluster":
			_build_rock_cluster(obs_container, pos, scale_vec)
		else:
			var obs = obstacle_scene.instantiate()
			obs_container.add_child(obs)
			obs.add_to_group("occluder")
			obs.add_to_group("obstacles")
			obs.position = Vector3(pos[0], 0, pos[1])
			obs.rotation_degrees.y = rot_deg
			obs.scale = Vector3(scale_vec[0], scale_vec[1], scale_vec[2])

			# Height-based collision: low obstacles don't block bullets
			var height = scale_vec[1]
			if height > 2.5:
				obs.collision_layer = 1 | 8
			else:
				obs.collision_layer = 1

			match type_str:
				"canyon_wall":
					obs.type = 0 # ROCK
				"tree_cluster":
					obs.type = 1 # TREE
				"log_pile":
					obs.type = 2 # LOG
			_record_minimap_feature(
				type_str,
				Vector2(pos[0], pos[1]),
				Vector2(scale_vec[0] * 2.0, scale_vec[2] * 2.0),
				rot_deg,
				scale_vec[1] * 2.0,
				2 if scale_vec[1] > 2.5 else 1,
				"rect"
			)

func get_minimap_features() -> Array[Dictionary]:
	return minimap_features.duplicate(true)

func _build_bush_patch(parent: Node3D, pos: Array, scale_vec: Array, rot_deg: float, asset_catalog) -> void:
	var bush = bush_scene.instantiate()
	parent.add_child(bush)
	bush.position = Vector3(pos[0], 0, pos[1])
	bush.rotation_degrees.y = rot_deg
	bush.scale = Vector3(scale_vec[0], scale_vec[1], scale_vec[2])
	_apply_catalog_visual(bush, BUSH_PROP_ID, asset_catalog)

func _apply_catalog_visual(root: Node, prop_id: String, asset_catalog) -> bool:
	var visual := _instantiate_prop_visual(asset_catalog, prop_id)
	if visual == null:
		return false

	visual.name = "CatalogPropVisual"
	visual.position = Vector3.ZERO
	visual.rotation = Vector3.ZERO
	visual.scale = Vector3.ONE
	visual.set_meta("prop_id", prop_id)
	_disable_collision_nodes(visual)
	root.add_child(visual)
	_set_default_bush_mesh_visible(root, false)
	return true

func _instantiate_prop_visual(asset_catalog, prop_id: String) -> Node3D:
	if asset_catalog == null or not asset_catalog.has_method("get_path"):
		return null
	var path := String(asset_catalog.get_path("props", prop_id, ""))
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		push_warning("WorldBuilder: prop path missing for %s: %s" % [prop_id, path])
		return null

	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is PackedScene:
			var instance = resource.instantiate()
			if instance is Node3D:
				return instance
			if instance:
				instance.queue_free()
			push_warning("WorldBuilder: prop %s root is not Node3D." % prop_id)
			return null

	if path.get_extension().to_lower() == "glb":
		return _instantiate_gltf_scene(path, prop_id)

	push_warning("WorldBuilder: prop path is not loadable for %s: %s" % [prop_id, path])
	return null

func _instantiate_gltf_scene(path: String, prop_id: String) -> Node3D:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(path, state)
	if error != OK:
		push_warning("WorldBuilder: GLB import failed for %s at %s (error %d)." % [prop_id, path, error])
		return null
	var scene = document.generate_scene(state)
	if scene is Node3D:
		return scene
	if scene:
		scene.queue_free()
	push_warning("WorldBuilder: GLB root is not Node3D for %s: %s" % [prop_id, path])
	return null

func _disable_collision_nodes(node: Node) -> void:
	if node is CollisionObject3D:
		var collision_object := node as CollisionObject3D
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
	for child in node.get_children():
		_disable_collision_nodes(child)

func _set_default_bush_mesh_visible(root: Node, visible: bool) -> void:
	var fallback_mesh := root.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if fallback_mesh:
		fallback_mesh.visible = visible

func _record_minimap_feature(
	type_str: String,
	pos: Vector2,
	size: Vector2,
	rot_deg: float,
	height: float,
	layer: int,
	shape: String
):
	var resolved_layer = max(layer, _minimap_layer_for(type_str, height))
	var cover_size = _minimap_cover_size(type_str, size, height)
	minimap_features.append({
		"type": type_str,
		"pos": [pos.x, pos.y],
		"size": [cover_size.x, cover_size.y],
		"base_size": [size.x, size.y],
		"rot": rot_deg,
		"height": height,
		"layer": resolved_layer,
		"shape": shape,
		"order": minimap_features.size(),
	})

func _minimap_layer_for(type_str: String, height: float) -> int:
	match type_str:
		"bush_patch":
			return 0
		"log_pile":
			return 1
		"rock_cluster":
			return 3 if height > 2.5 else 2
		"tree_cluster":
			return 3
		"canyon_wall":
			return 4
	return 1

func _minimap_cover_size(type_str: String, base_size: Vector2, height: float) -> Vector2:
	match type_str:
		"bush_patch", "log_pile":
			return base_size
		"rock_cluster":
			var rock_margin = clampf(height * 0.55, 0.4, 2.6)
			return base_size + Vector2(rock_margin, rock_margin)
		"tree_cluster":
			var tree_margin = clampf(height * 0.28, 1.0, 3.4)
			return base_size + Vector2(tree_margin, tree_margin)
		"canyon_wall":
			var wall_margin = clampf(height * 0.38, 1.2, 4.8)
			return base_size + Vector2(wall_margin, wall_margin)
	return base_size

func _build_base(spec: Resource):
	var size = spec.get_world_size()
	
	# Create Floor
	var floor_body = StaticBody3D.new()
	floor_body.name = "Floor"
	add_child(floor_body)
	
	var mesh_instance = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(size, 1, size)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.12, 0.08) # Dirt
	mesh.material = mat
	mesh_instance.mesh = mesh
	floor_body.add_child(mesh_instance)
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(size, 1, size)
	col.shape = shape
	floor_body.add_child(col)
	floor_body.position.y = -0.5
	
	# Create Boundaries
	var bounds_node = Node3D.new()
	bounds_node.name = "Boundaries"
	add_child(bounds_node)
	
	_add_wall(bounds_node, Vector3(0, 5, -size/2), Vector3(size, 10, 1)) # North
	_add_wall(bounds_node, Vector3(0, 5, size/2), Vector3(size, 10, 1))  # South
	_add_wall(bounds_node, Vector3(size/2, 5, 0), Vector3(1, 10, size))  # East
	_add_wall(bounds_node, Vector3(-size/2, 5, 0), Vector3(1, 10, size)) # West

func _build_rock_cluster(parent: Node3D, pos: Array, scale_vec: Array):
	var rng = RandomNumberGenerator.new()
	rng.seed = int(abs(pos[0]) * 1000 + abs(pos[1]) * 7777)

	var base_height: float = scale_vec[1]
	var footprint_mult = clampf((float(scale_vec[0]) + float(scale_vec[2])) / 6.0, 0.65, 1.35)
	var high: bool = base_height > 2.5
	var col_layer: int = (1 | 8) if high else 1

	var root = Node3D.new()
	root.name = "RockCluster_%d_%d" % [int(pos[0]), int(pos[1])]
	parent.add_child(root)
	root.position = Vector3(pos[0], 0, pos[1])
	root.add_to_group("obstacles")

	# Center piece — tallest
	_add_rock_piece(root, Vector3(0, 0, 0), Vector3(1.3 * footprint_mult, base_height, 1.3 * footprint_mult), rng, col_layer)

	# Surrounding pieces
	var piece_count = rng.randi_range(4, 6)
	for i in range(piece_count):
		var angle = (float(i) / float(piece_count)) * TAU + rng.randf_range(-0.25, 0.25)
		var radius = rng.randf_range(0.7, 1.6) * footprint_mult
		var px = cos(angle) * radius
		var pz = sin(angle) * radius
		var ph = base_height * rng.randf_range(0.28, 0.65)
		var ps = rng.randf_range(0.55, 1.05) * footprint_mult
		_add_rock_piece(root, Vector3(px, 0, pz), Vector3(ps, ph, ps), rng, col_layer)

	# Ramp on high clusters so players can climb up
	if high:
		var ramp_angle = rng.randf_range(0, TAU)
		var ramp_cx = cos(ramp_angle)
		var ramp_cz = sin(ramp_angle)
		var ramp_y_rot = atan2(ramp_cx, ramp_cz)

		var ramp_body = StaticBody3D.new()
		root.add_child(ramp_body)
		ramp_body.position = Vector3(ramp_cx * 1.8 * footprint_mult, base_height * 0.35, ramp_cz * 1.8 * footprint_mult)
		ramp_body.rotation.y = ramp_y_rot
		ramp_body.rotation.x = deg_to_rad(26.0)
		ramp_body.collision_layer = 1

		var ramp_mesh = MeshInstance3D.new()
		var rmesh = BoxMesh.new()
		rmesh.size = Vector3(1.6 * footprint_mult, 0.18, 2.2 * footprint_mult)
		var rmat = StandardMaterial3D.new()
		rmat.albedo_color = Color(0.42, 0.39, 0.34)
		rmesh.surface_set_material(0, rmat)
		ramp_mesh.mesh = rmesh
		ramp_body.add_child(ramp_mesh)

		var ramp_col = CollisionShape3D.new()
		var rshape = BoxShape3D.new()
		rshape.size = Vector3(1.6 * footprint_mult, 0.18, 2.2 * footprint_mult)
		ramp_col.shape = rshape
		ramp_body.add_child(ramp_col)

func _add_rock_piece(parent: Node3D, local_pos: Vector3, size: Vector3, rng: RandomNumberGenerator, col_layer: int):
	var body = StaticBody3D.new()
	parent.add_child(body)
	body.add_to_group("occluder")
	body.position = local_pos + Vector3(0, size.y * 0.5, 0)
	body.rotation.y = rng.randf_range(0.0, TAU)
	body.rotation.x = rng.randf_range(-0.15, 0.15)
	body.rotation.z = rng.randf_range(-0.12, 0.12)
	body.collision_layer = col_layer

	var mesh_inst = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	var mat = StandardMaterial3D.new()
	var g = rng.randf_range(0.33, 0.54)
	mat.albedo_color = Color(g, g * 0.96, g * 0.91)
	mesh.surface_set_material(0, mat)
	mesh_inst.mesh = mesh
	body.add_child(mesh_inst)

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	var root_pos = Vector2(parent.position.x, parent.position.z)
	var piece_pos = root_pos + Vector2(local_pos.x, local_pos.z)
	_record_minimap_feature(
		"rock_cluster",
		piece_pos,
		Vector2(size.x, size.z),
		rad_to_deg(body.rotation.y),
		size.y,
		2 if col_layer & 8 != 0 else 1,
		"rect"
	)

func _add_wall(parent: Node, pos: Vector3, size: Vector3):
	var wall = StaticBody3D.new()
	parent.add_child(wall)
	wall.add_to_group("occluder")
	wall.position = pos
	
	var mesh_instance = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.2, 0.2)
	mesh.material = mat
	mesh_instance.mesh = mesh
	wall.add_child(mesh_instance)
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	wall.add_child(col)
