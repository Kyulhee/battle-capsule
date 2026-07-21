extends Control


var map_size_3d := Vector2(120.0, 120.0)
var minimap_size := Vector2(240.0, 240.0)
var map_spec: Resource = null
var map_definition = null
var minimap_features: Array[Dictionary] = []
var _features: Array[Dictionary] = []


func configure(
		spec: Resource,
		features: Array[Dictionary],
		definition,
		world_size: Vector2,
		texture_size: Vector2
	) -> void:
	map_spec = spec
	map_definition = definition
	map_size_3d = world_size
	minimap_size = texture_size
	size = texture_size
	minimap_features = features.duplicate(true)
	_features = minimap_features.duplicate(true)
	if _features.is_empty():
		_features = _build_fallback_features()
	_features.sort_custom(Callable(self, "_sort_minimap_features"))
	queue_redraw()


func _draw() -> void:
	var half := map_size_3d / 2.0
	var boundary_points := PackedVector2Array([
		world_to_minimap(Vector2(-half.x, -half.y)),
		world_to_minimap(Vector2(half.x, -half.y)),
		world_to_minimap(Vector2(half.x, half.y)),
		world_to_minimap(Vector2(-half.x, half.y)),
	])
	draw_colored_polygon(boundary_points, Color(0.1, 0.1, 0.1, 0.8))
	draw_polyline(
		boundary_points + PackedVector2Array([boundary_points[0]]),
		Color(0.5, 0.5, 0.5),
		1.5
	)

	if map_spec == null:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(10.0, 20.0),
			"MAP DATA MISSING",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			12,
			Color.RED
		)
		return

	for feature in _features:
		_draw_minimap_feature(feature)


func world_to_minimap(world_position: Vector2) -> Vector2:
	var rotated := world_position.rotated(PI / 4.0)
	var scale_factor := minimap_size.x / (map_size_3d.x * 1.414)
	return minimap_size / 2.0 + rotated * scale_factor


func world_size_to_minimap(world_size: float) -> float:
	return world_size * (minimap_size.x / (map_size_3d.x * 1.414))


func _sort_minimap_features(a: Dictionary, b: Dictionary) -> bool:
	var layer_a := int(a.get("layer", 0))
	var layer_b := int(b.get("layer", 0))
	if layer_a == layer_b:
		var height_a := float(a.get("height", 0.0))
		var height_b := float(b.get("height", 0.0))
		if not is_equal_approx(height_a, height_b):
			return height_a < height_b
		return int(a.get("order", 0)) < int(b.get("order", 0))
	return layer_a < layer_b


func _draw_minimap_feature(feature: Dictionary) -> void:
	var position_value = feature.get("pos", [0.0, 0.0])
	var size_value = feature.get("size", [1.0, 1.0])
	var world_position := Vector2(float(position_value[0]), float(position_value[1]))
	var world_size := Vector2(float(size_value[0]), float(size_value[1]))
	var rotation_radians := deg_to_rad(float(feature.get("rot", 0.0)))
	var shape := String(feature.get("shape", "rect"))
	var colors := _feature_colors(String(feature.get("type", "")))

	if shape == "path":
		var path_points := PackedVector2Array()
		for point_data in feature.get("points", []):
			if typeof(point_data) == TYPE_ARRAY and point_data.size() >= 2:
				path_points.append(world_to_minimap(Vector2(
					float(point_data[0]),
					float(point_data[1])
				)))
		if path_points.size() >= 2:
			var path_width := maxf(
				1.0,
				world_size_to_minimap(float(feature.get("width", 1.0)))
			)
			if float(colors["width"]) > 0.0:
				draw_polyline(
					path_points,
					colors["border"],
					path_width + float(colors["width"]) * 2.0,
					true
				)
			draw_polyline(path_points, colors["fill"], path_width, true)
		return

	if shape == "ellipse":
		var ellipse_points := PackedVector2Array()
		for point_index in range(24):
			var angle := TAU * float(point_index) / 24.0
			var local_position := Vector2(
				cos(angle) * world_size.x * 0.5,
				sin(angle) * world_size.y * 0.5
			)
			ellipse_points.append(
				world_to_minimap(local_position.rotated(rotation_radians) + world_position)
			)
		draw_colored_polygon(ellipse_points, colors["fill"])
		return

	var half_size := world_size * 0.5
	var local_corners := [
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	]
	var points := PackedVector2Array()
	for corner in local_corners:
		points.append(world_to_minimap(corner.rotated(rotation_radians) + world_position))
	draw_colored_polygon(points, colors["fill"])
	draw_polyline(
		points + PackedVector2Array([points[0]]),
		colors["border"],
		float(colors["width"])
	)


func _feature_colors(obstacle_type: String) -> Dictionary:
	match obstacle_type:
		"ground.forest_grass":
			return {
				"fill": Color(0.19, 0.32, 0.16, 0.88),
				"border": Color(0.13, 0.22, 0.11, 0.0),
				"width": 0.0,
			}
		"ground.forest_dirt":
			return {
				"fill": Color(0.19, 0.16, 0.12, 0.90),
				"border": Color(0.12, 0.10, 0.08, 0.0),
				"width": 0.0,
			}
		"ground.path_dirt":
			return {
				"fill": Color(0.43, 0.34, 0.22, 0.94),
				"border": Color(0.17, 0.13, 0.09, 0.84),
				"width": 0.8,
			}
		"bush_patch":
			return {
				"fill": Color(0.22, 0.58, 0.20, 0.42),
				"border": Color(0.16, 0.36, 0.12, 0.0),
				"width": 0.0,
			}
		"tree_cluster":
			return {
				"fill": Color(0.24, 0.20, 0.14, 0.92),
				"border": Color(0.12, 0.09, 0.06, 1.0),
				"width": 1.0,
			}
		"canyon_wall", "rock_cluster", "ridge_rock":
			return {
				"fill": Color(0.42, 0.42, 0.46, 0.96),
				"border": Color(0.24, 0.24, 0.28, 1.0),
				"width": 1.2,
			}
		"log_pile", "fallen_tree":
			return {
				"fill": Color(0.44, 0.30, 0.14, 0.92),
				"border": Color(0.26, 0.17, 0.07, 1.0),
				"width": 1.0,
			}
		"cabin", "watchtower":
			return {
				"fill": Color(0.48, 0.30, 0.16, 0.98),
				"border": Color(0.18, 0.11, 0.06, 1.0),
				"width": 1.4,
			}
		"ruined_wall", "camp_crate", "barrel_cluster":
			return {
				"fill": Color(0.48, 0.38, 0.24, 0.96),
				"border": Color(0.20, 0.15, 0.09, 1.0),
				"width": 1.0,
			}
		"camp_tarp":
			return {
				"fill": Color(0.24, 0.31, 0.16, 0.88),
				"border": Color(0.12, 0.16, 0.08, 0.95),
				"width": 1.0,
			}
	return {
		"fill": Color(0.35, 0.35, 0.40, 0.92),
		"border": Color(0.22, 0.22, 0.26, 1.0),
		"width": 1.0,
	}


func _build_fallback_features() -> Array[Dictionary]:
	var features: Array[Dictionary] = []
	if map_spec == null and map_definition == null:
		return features
	for obstacle in _obstacle_source():
		var obstacle_type := String(obstacle.get("type", ""))
		var scale := _descriptor_scale_3d(obstacle)
		var feature_size := Vector2(scale.x * 2.0, scale.z * 2.0)
		var shape := "rect"
		var height := scale.y * 2.0
		if obstacle_type == "bush_patch":
			feature_size = Vector2(scale.x * 3.0, scale.z * 3.0)
			shape = "ellipse"
		feature_size = _fallback_cover_size(obstacle_type, feature_size, height)
		features.append({
			"type": obstacle_type,
			"pos": obstacle.get("pos", [0.0, 0.0]),
			"size": [feature_size.x, feature_size.y],
			"rot": obstacle.get("rot", 0.0),
			"height": height,
			"layer": _fallback_feature_layer(obstacle_type, height),
			"shape": shape,
			"order": features.size(),
		})
	return features


func _obstacle_source() -> Array[Dictionary]:
	if map_definition != null and map_definition.has_method("get_obstacle_descriptors"):
		return map_definition.get_obstacle_descriptors()
	var obstacles: Array[Dictionary] = []
	if map_spec == null:
		return obstacles
	for obstacle in map_spec.obstacles:
		if typeof(obstacle) == TYPE_DICTIONARY:
			obstacles.append(obstacle.duplicate(true))
	return obstacles


func _descriptor_scale_3d(descriptor: Dictionary) -> Vector3:
	var scale_value = descriptor.get("scale_3d", null)
	if typeof(scale_value) == TYPE_VECTOR3:
		return scale_value
	var scale_array = descriptor.get("scale", [1.0, 1.0, 1.0])
	if typeof(scale_array) == TYPE_ARRAY and scale_array.size() >= 3:
		return Vector3(
			float(scale_array[0]),
			float(scale_array[1]),
			float(scale_array[2])
		)
	return Vector3.ONE


func _fallback_feature_layer(obstacle_type: String, height: float) -> int:
	match obstacle_type:
		"bush_patch":
			return 0
		"log_pile", "fallen_tree":
			return 1
		"rock_cluster", "ridge_rock":
			return 3 if height > 2.5 else 2
		"tree_cluster", "watchtower":
			return 3
		"camp_tarp":
			return 1
		"canyon_wall":
			return 4
	return 1


func _fallback_cover_size(
		obstacle_type: String,
		base_size: Vector2,
		height: float
	) -> Vector2:
	match obstacle_type:
		"bush_patch", "log_pile", "fallen_tree", "ridge_rock", "watchtower", "camp_tarp":
			return base_size
		"rock_cluster":
			var rock_margin := clampf(height * 0.55, 0.4, 2.6)
			return base_size + Vector2(rock_margin, rock_margin)
		"tree_cluster":
			var tree_margin := clampf(height * 0.28, 1.0, 3.4)
			return base_size + Vector2(tree_margin, tree_margin)
		"canyon_wall":
			var wall_margin := clampf(height * 0.38, 1.2, 4.8)
			return base_size + Vector2(wall_margin, wall_margin)
	return base_size
