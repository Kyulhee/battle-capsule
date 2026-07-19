extends Node3D
class_name WorldBuilder

@export var obstacle_scene: PackedScene = preload("res://src/environment/Obstacle.tscn")
@export var bush_scene: PackedScene = preload("res://src/environment/Bush.tscn")

const BUSH_PROP_ID := "forest.bush"

var minimap_features: Array[Dictionary] = []
var _surface_material_cache: Dictionary = {}

func generate_world(spec: Resource, asset_catalog = null):
	# 1. Clear existing generated content if any
	for child in get_children():
		child.queue_free()
	minimap_features.clear()
	_surface_material_cache.clear()
		
	# 2. Build Floor and Boundaries
	_build_base(spec, asset_catalog)
	_build_surface_zones(spec, asset_catalog)
	
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
			_build_standard_obstacle(
				obs_container,
				o,
				type_str,
				pos,
				scale_vec,
				rot_deg,
				asset_catalog
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


func _build_standard_obstacle(
	parent: Node3D,
	descriptor: Dictionary,
	type_str: String,
	pos: Array,
	scale_vec: Array,
	rot_deg: float,
	asset_catalog
) -> void:
	var obs = obstacle_scene.instantiate()
	parent.add_child(obs)
	obs.position = Vector3(pos[0], 0, pos[1])
	obs.rotation_degrees.y = rot_deg
	obs.scale = Vector3(scale_vec[0], scale_vec[1], scale_vec[2])

	var collision_enabled := bool(descriptor.get("collision", true))
	if collision_enabled:
		obs.add_to_group("occluder")
		obs.add_to_group("obstacles")
		obs.collision_layer = (1 | 8) if float(scale_vec[1]) > 2.5 else 1
	else:
		obs.remove_from_group("obstacles")
		obs.collision_layer = 0
		obs.collision_mask = 0

	match type_str:
		"canyon_wall":
			obs.type = 0 # ROCK
		"tree_cluster":
			obs.type = 1 # TREE
		"log_pile":
			obs.type = 2 # LOG

	var prop_id := String(descriptor.get("prop_id", "")).strip_edges()
	if not prop_id.is_empty():
		var visual_scale := _vector3_from_value(
			descriptor.get("visual_scale", [1.0, 1.0, 1.0]),
			Vector3.ONE
		)
		_apply_catalog_visual(obs, prop_id, asset_catalog, visual_scale)

	var map_size := Vector2(float(scale_vec[0]) * 2.0, float(scale_vec[2]) * 2.0)
	var raw_map_size = descriptor.get("map_size", [])
	if typeof(raw_map_size) == TYPE_ARRAY and raw_map_size.size() >= 2:
		map_size = Vector2(float(raw_map_size[0]), float(raw_map_size[1]))
	_record_minimap_feature(
		type_str,
		Vector2(pos[0], pos[1]),
		map_size,
		rot_deg,
		float(scale_vec[1]) * 2.0,
		2 if float(scale_vec[1]) > 2.5 else 1,
		String(descriptor.get("map_shape", "rect"))
	)


func _apply_catalog_visual(
	root: Node,
	prop_id: String,
	asset_catalog,
	world_visual_scale: Variant = null
) -> bool:
	var visual := _instantiate_prop_visual(asset_catalog, prop_id)
	if visual == null:
		return false

	visual.name = "CatalogPropVisual"
	visual.position = Vector3.ZERO
	visual.rotation = Vector3.ZERO
	visual.scale = Vector3.ONE
	if world_visual_scale is Vector3 and root is Node3D:
		var parent_scale := (root as Node3D).scale
		var desired := world_visual_scale as Vector3
		visual.scale = Vector3(
			desired.x / maxf(absf(parent_scale.x), 0.001),
			desired.y / maxf(absf(parent_scale.y), 0.001),
			desired.z / maxf(absf(parent_scale.z), 0.001)
		)
	visual.set_meta("prop_id", prop_id)
	_disable_collision_nodes(visual)
	root.add_child(visual)
	if root.has_method("set_catalog_visual_active"):
		root.set_catalog_visual_active(true)
	else:
		_set_default_bush_mesh_visible(root, false)
	return true


func _vector3_from_value(value: Variant, fallback: Vector3) -> Vector3:
	if value is Vector3:
		return value
	if typeof(value) == TYPE_ARRAY and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return fallback

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
				return _optimize_static_prop_scene(instance, prop_id)
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
		return _optimize_static_prop_scene(scene, prop_id)
	if scene:
		scene.queue_free()
	push_warning("WorldBuilder: GLB root is not Node3D for %s: %s" % [prop_id, path])
	return null


func _optimize_static_prop_scene(scene: Node3D, prop_id: String) -> Node3D:
	if prop_id.begins_with("forest.bush"):
		return scene
	var groups := {}
	_collect_static_mesh_surfaces(scene, Transform3D.IDENTITY, groups)
	if groups.is_empty():
		return scene

	var optimized := Node3D.new()
	optimized.name = scene.name
	for material_key in groups:
		var entries: Array = groups[material_key]
		if entries.is_empty():
			continue
		var surface_tool := SurfaceTool.new()
		surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for entry in entries:
			surface_tool.append_from(
				entry["mesh"],
				int(entry["surface"]),
				entry["transform"]
			)
		var material = entries[0].get("material")
		if material is Material:
			surface_tool.set_material(material)
		var merged_mesh := surface_tool.commit()
		if merged_mesh == null:
			continue
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = merged_mesh
		optimized.add_child(mesh_instance)

	if optimized.get_child_count() == 0:
		optimized.free()
		return scene
	scene.free()
	return optimized


func _collect_static_mesh_surfaces(
	node: Node,
	parent_transform: Transform3D,
	groups: Dictionary
) -> void:
	var current_transform := parent_transform
	if node is Node3D:
		current_transform = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh:
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				var array_mesh := mesh_instance.mesh as ArrayMesh
				if (
					array_mesh != null
					and array_mesh.surface_get_primitive_type(surface_index)
						!= Mesh.PRIMITIVE_TRIANGLES
				):
					continue
				var material: Material = mesh_instance.get_surface_override_material(surface_index)
				if material == null:
					material = mesh_instance.mesh.surface_get_material(surface_index)
				var material_key := (
					String.num_int64(material.get_instance_id())
					if material != null
					else "none"
				)
				if not groups.has(material_key):
					groups[material_key] = []
				groups[material_key].append({
					"mesh": mesh_instance.mesh,
					"surface": surface_index,
					"transform": current_transform,
					"material": material,
				})
	for child in node.get_children():
		_collect_static_mesh_surfaces(child, current_transform, groups)


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
	if type_str.begins_with("ground."):
		return -20
	match type_str:
		"bush_patch":
			return 0
		"log_pile":
			return 1
		"camp_crate", "barrel_cluster":
			return 2
		"rock_cluster":
			return 3 if height > 2.5 else 2
		"tree_cluster", "ruined_wall", "cabin":
			return 3
		"canyon_wall":
			return 4
	return 1

func _minimap_cover_size(type_str: String, base_size: Vector2, height: float) -> Vector2:
	match type_str:
		"bush_patch", "log_pile":
			return base_size
		"camp_crate", "barrel_cluster", "ruined_wall", "cabin":
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

func _build_surface_zones(spec: Resource, asset_catalog) -> void:
	if spec == null:
		return
	var container := Node3D.new()
	container.name = "GeneratedSurfaceZones"

	for zone_index in range(spec.surface_zones.size()):
		var zone: Dictionary = spec.surface_zones[zone_index]
		var shape := String(zone.get("shape", "rect"))
		var material_id := String(zone.get("material_id", "ground.forest_dirt"))
		var y_offset := 0.012 + float(zone_index) * 0.0005
		if shape == "path":
			_build_surface_path(container, zone, material_id, asset_catalog, y_offset)
		else:
			var pos_data = zone.get("pos", [0.0, 0.0])
			var size_data = zone.get("size", [1.0, 1.0])
			var world_pos := Vector2(float(pos_data[0]), float(pos_data[1]))
			var world_size := Vector2(float(size_data[0]), float(size_data[1]))
			var rot_deg := float(zone.get("rot", 0.0))
			if shape == "ellipse":
				_add_surface_ellipse(
					container,
					world_pos,
					world_size,
					rot_deg,
					material_id,
					asset_catalog,
					y_offset
				)
			else:
				_add_surface_rect(
					container,
					world_pos,
					world_size,
					rot_deg,
					material_id,
					asset_catalog,
					y_offset
				)
		_record_surface_feature(zone, material_id, zone_index)
	var optimized := _optimize_static_prop_scene(container, "surface.zones")
	optimized.name = "GeneratedSurfaceZones"
	add_child(optimized)


func _build_surface_path(
	parent: Node3D,
	zone: Dictionary,
	material_id: String,
	asset_catalog,
	y_offset: float
) -> void:
	var points_data: Array = zone.get("points", [])
	var width := maxf(0.1, float(zone.get("width", 1.0)))
	var points: Array[Vector2] = []
	for point_data in points_data:
		if typeof(point_data) == TYPE_ARRAY and point_data.size() >= 2:
			points.append(Vector2(float(point_data[0]), float(point_data[1])))
	for i in range(points.size() - 1):
		var start := points[i]
		var finish := points[i + 1]
		var delta := finish - start
		if delta.length() <= 0.001:
			continue
		_add_surface_rect(
			parent,
			(start + finish) * 0.5,
			Vector2(width, delta.length()),
			rad_to_deg(atan2(delta.x, delta.y)),
			material_id,
			asset_catalog,
			y_offset
		)
	for point in points:
		_add_surface_ellipse(
			parent,
			point,
			Vector2.ONE * width,
			0.0,
			material_id,
			asset_catalog,
			y_offset + 0.0001
		)


func _add_surface_rect(
	parent: Node3D,
	world_pos: Vector2,
	world_size: Vector2,
	rot_deg: float,
	material_id: String,
	asset_catalog,
	y_offset: float
) -> void:
	var instance := MeshInstance3D.new()
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_size := world_size * 0.5
	var corners := [
		Vector3(-half_size.x, 0.0, -half_size.y),
		Vector3(half_size.x, 0.0, -half_size.y),
		Vector3(half_size.x, 0.0, half_size.y),
		Vector3(-half_size.x, 0.0, half_size.y),
	]
	var indices := [0, 2, 1, 0, 3, 2]
	var uvs := [
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(0.0, 1.0),
	]
	for index in indices:
		surface_tool.set_uv(uvs[index])
		surface_tool.add_vertex(corners[index])
	surface_tool.generate_normals()
	var mesh := surface_tool.commit()
	mesh.surface_set_material(0, _surface_material(asset_catalog, material_id, world_size))
	instance.mesh = mesh
	instance.position = Vector3(world_pos.x, y_offset, world_pos.y)
	instance.rotation_degrees.y = rot_deg
	parent.add_child(instance)


func _add_surface_ellipse(
	parent: Node3D,
	world_pos: Vector2,
	world_size: Vector2,
	rot_deg: float,
	material_id: String,
	asset_catalog,
	y_offset: float
) -> void:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_size := world_size * 0.5
	const SEGMENTS := 32
	for i in range(SEGMENTS):
		var angle_a := TAU * float(i) / float(SEGMENTS)
		var angle_b := TAU * float(i + 1) / float(SEGMENTS)
		var point_a := Vector2(cos(angle_a) * half_size.x, sin(angle_a) * half_size.y)
		var point_b := Vector2(cos(angle_b) * half_size.x, sin(angle_b) * half_size.y)
		surface_tool.set_uv(Vector2(0.5, 0.5))
		surface_tool.add_vertex(Vector3.ZERO)
		surface_tool.set_uv(Vector2(
			0.5 + point_b.x / maxf(world_size.x, 0.001),
			0.5 + point_b.y / maxf(world_size.y, 0.001)
		))
		surface_tool.add_vertex(Vector3(point_b.x, 0.0, point_b.y))
		surface_tool.set_uv(Vector2(
			0.5 + point_a.x / maxf(world_size.x, 0.001),
			0.5 + point_a.y / maxf(world_size.y, 0.001)
		))
		surface_tool.add_vertex(Vector3(point_a.x, 0.0, point_a.y))
	surface_tool.generate_normals()
	var instance := MeshInstance3D.new()
	var mesh := surface_tool.commit()
	mesh.surface_set_material(0, _surface_material(asset_catalog, material_id, world_size))
	instance.mesh = mesh
	instance.position = Vector3(world_pos.x, y_offset, world_pos.y)
	instance.rotation_degrees.y = rot_deg
	parent.add_child(instance)


func _surface_material(asset_catalog, material_id: String, _world_size: Vector2) -> StandardMaterial3D:
	if _surface_material_cache.has(material_id):
		return _surface_material_cache[material_id] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tile_scale := 12.0
	if material_id == "ground.forest_dirt":
		tile_scale = 24.0
	elif material_id == "ground.path_dirt":
		tile_scale = 4.0
	material.uv1_scale = Vector3(tile_scale, tile_scale, 1.0)
	if asset_catalog != null and asset_catalog.has_method("get_color"):
		material.albedo_color = asset_catalog.get_color(
			"materials",
			material_id,
			Color.WHITE
		)
	var texture := _load_catalog_texture(asset_catalog, material_id)
	if texture:
		material.albedo_texture = texture
	_surface_material_cache[material_id] = material
	return material


func _load_catalog_texture(asset_catalog, material_id: String) -> Texture2D:
	if asset_catalog == null or not asset_catalog.has_method("get_path"):
		return null
	var path := String(asset_catalog.get_path("materials", material_id, ""))
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is Texture2D:
			return resource
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image != null and not image.is_empty():
			return ImageTexture.create_from_image(image)
	return null


func _record_surface_feature(zone: Dictionary, material_id: String, zone_index: int) -> void:
	var feature := {
		"type": material_id,
		"pos": zone.get("pos", [0.0, 0.0]),
		"size": zone.get("size", [1.0, 1.0]),
		"rot": zone.get("rot", 0.0),
		"height": 0.0,
		"layer": -20 + zone_index,
		"shape": zone.get("shape", "rect"),
		"order": minimap_features.size(),
		"width": zone.get("width", 0.0),
		"points": zone.get("points", []),
	}
	minimap_features.append(feature)


func _build_base(spec: Resource, asset_catalog):
	var size = spec.get_world_size()
	
	# Create Floor
	var floor_body = StaticBody3D.new()
	floor_body.name = "Floor"
	add_child(floor_body)
	
	var mesh_instance = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(size, 1, size)
	var mat = _surface_material(
		asset_catalog,
		"ground.forest_dirt",
		Vector2(size, size)
	)
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
