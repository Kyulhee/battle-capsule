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
		else:
			var obs = obstacle_scene.instantiate()
			obs_container.add_child(obs)
			obs.global_position = Vector3(pos[0], 0, pos[1])
			obs.rotation_degrees.y = rot_deg
			obs.scale = Vector3(scale_vec[0], scale_vec[1], scale_vec[2])
			
			# Height-based collision: low obstacles don't block bullets
			var height = scale_vec[1]
			if height > 2.5:
				# High: Blocks movement (1) + Bullets (4)
				obs.collision_layer = 1 | 8
			else:
				# Low: Only blocks movement (1)
				obs.collision_layer = 1
			
			match type_str:
				"canyon_wall", "rock_cluster":
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

func _add_wall(parent: Node, pos: Vector3, size: Vector3):
	var wall = StaticBody3D.new()
	parent.add_child(wall)
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
