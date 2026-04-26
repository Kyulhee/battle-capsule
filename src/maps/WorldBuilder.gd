extends Node3D
class_name WorldBuilder

@export var obstacle_scene: PackedScene = preload("res://src/environment/Obstacle.tscn")
@export var bush_scene: PackedScene = preload("res://src/environment/Bush.tscn")

func generate_world(spec: Resource):
	# 1. Clear existing generated content if any
	for child in get_children():
		child.queue_free()
		
	# 2. Build Floor and Boundaries
	_build_base(spec)
	
	# 3. Build Obstacles
	var obs_container = Node3D.new()
	obs_container.name = "GeneratedObstacles"
	add_child(obs_container)
	
	for o in spec.obstacles:
		var type_str = o.get("type", "rock_cluster")
		var pos = o.get("pos", [0, 0])
		var scale_vec = o.get("scale", [1, 1, 1])
		var rot_deg = o.get("rot", 0)
		
		if type_str == "bush_patch":
			var bush = bush_scene.instantiate()
			obs_container.add_child(bush)
			bush.global_position = Vector3(pos[0], 0, pos[1])
			bush.scale = Vector3(scale_vec[0], scale_vec[1], scale_vec[2])
		elif type_str == "rock_cluster":
			_build_rock_cluster(obs_container, pos, scale_vec)
		else:
			var obs = obstacle_scene.instantiate()
			obs_container.add_child(obs)
			obs.add_to_group("occluder")
			obs.global_position = Vector3(pos[0], 0, pos[1])
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
	var high: bool = base_height > 2.5
	var col_layer: int = (1 | 8) if high else 1

	var root = Node3D.new()
	root.name = "RockCluster_%d_%d" % [int(pos[0]), int(pos[1])]
	parent.add_child(root)
	root.position = Vector3(pos[0], 0, pos[1])

	# Center piece — tallest
	_add_rock_piece(root, Vector3(0, 0, 0), Vector3(1.3, base_height, 1.3), rng, col_layer)

	# Surrounding pieces
	var piece_count = rng.randi_range(4, 6)
	for i in range(piece_count):
		var angle = (float(i) / float(piece_count)) * TAU + rng.randf_range(-0.25, 0.25)
		var radius = rng.randf_range(0.7, 1.6)
		var px = cos(angle) * radius
		var pz = sin(angle) * radius
		var ph = base_height * rng.randf_range(0.28, 0.65)
		var ps = rng.randf_range(0.55, 1.05)
		_add_rock_piece(root, Vector3(px, 0, pz), Vector3(ps, ph, ps), rng, col_layer)

	# Ramp on high clusters so players can climb up
	if high:
		var ramp_angle = rng.randf_range(0, TAU)
		var ramp_cx = cos(ramp_angle)
		var ramp_cz = sin(ramp_angle)
		var ramp_y_rot = atan2(ramp_cx, ramp_cz)

		var ramp_body = StaticBody3D.new()
		root.add_child(ramp_body)
		ramp_body.position = Vector3(ramp_cx * 1.8, base_height * 0.35, ramp_cz * 1.8)
		ramp_body.rotation.y = ramp_y_rot
		ramp_body.rotation.x = deg_to_rad(26.0)
		ramp_body.collision_layer = 1

		var ramp_mesh = MeshInstance3D.new()
		var rmesh = BoxMesh.new()
		rmesh.size = Vector3(1.6, 0.18, 2.2)
		var rmat = StandardMaterial3D.new()
		rmat.albedo_color = Color(0.42, 0.39, 0.34)
		rmesh.surface_set_material(0, rmat)
		ramp_mesh.mesh = rmesh
		ramp_body.add_child(ramp_mesh)

		var ramp_col = CollisionShape3D.new()
		var rshape = BoxShape3D.new()
		rshape.size = Vector3(1.6, 0.18, 2.2)
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
