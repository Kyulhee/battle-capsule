class_name FullMapOverlay
extends Control


const BACKDROP_COLOR := Color(0.0, 0.0, 0.0, 0.68)
const PANEL_COLOR := Color(0.035, 0.04, 0.045, 0.96)
const MAP_BG_COLOR := Color(0.075, 0.08, 0.075, 1.0)
const MAP_BORDER_COLOR := Color(0.56, 0.58, 0.58, 0.9)
const CURRENT_ZONE_COLOR := Color(0.22, 0.60, 1.0, 0.90)
const CURRENT_ZONE_FILL := Color(0.16, 0.42, 0.92, 0.10)
const NEXT_ZONE_COLOR := Color(1.0, 1.0, 1.0, 0.52)
const PLAYER_COLOR := Color(0.2, 1.0, 0.24, 1.0)
const SUPPLY_COLOR := Color(1.0, 0.82, 0.12, 1.0)


var main_ref: Node = null
var map_definition = null
var map_spec: Resource = null
var map_features: Array[Dictionary] = []
var scale_preset: String = ""
var map_size_3d: Vector2 = Vector2(120.0, 120.0)

var has_player: bool = false
var player_pos: Vector2 = Vector2.ZERO
var player_forward: Vector2 = Vector2(0.0, -1.0)
var current_zone_center: Vector2 = Vector2.ZERO
var current_zone_radius: float = 50.0
var next_zone_center: Vector2 = Vector2.ZERO
var next_zone_radius: float = 25.0
var supply_pos: Vector2 = Vector2.ZERO
var supply_state: String = "none"
var supply_pulse: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_process(false)


func configure(main_node: Node, definition, spec: Resource, features: Array[Dictionary], preset_name: String = "") -> void:
	main_ref = main_node
	set_map_data(definition, spec, features, preset_name)


func set_map_data(definition, spec: Resource, features: Array[Dictionary], preset_name: String = "") -> void:
	map_definition = definition
	map_spec = spec
	scale_preset = preset_name
	map_features = features.duplicate(true)
	if map_definition != null and map_definition.has_method("get_world_size_2d"):
		map_size_3d = map_definition.get_world_size_2d()
	elif map_spec != null and map_spec.has_method("get_world_size"):
		var world_size := float(map_spec.get_world_size())
		map_size_3d = Vector2(world_size, world_size)
	queue_redraw()


func set_runtime_state(
	p_pos: Vector2,
	p_forward: Vector2,
	cur_center: Vector2,
	cur_radius: float,
	nxt_center: Vector2,
	nxt_radius: float,
	s_pos: Vector2,
	s_state: String
) -> void:
	has_player = true
	player_pos = p_pos
	player_forward = p_forward.normalized() if p_forward.length() > 0.001 else Vector2(0.0, -1.0)
	current_zone_center = cur_center
	current_zone_radius = maxf(0.0, cur_radius)
	next_zone_center = nxt_center
	next_zone_radius = maxf(0.0, nxt_radius)
	supply_pos = s_pos
	supply_state = s_state
	queue_redraw()


func show_map() -> void:
	visible = true
	set_process(true)
	_sync_runtime_from_main()
	queue_redraw()


func hide_map() -> void:
	visible = false
	set_process(false)


func is_open() -> bool:
	return visible


func _process(delta: float) -> void:
	if not visible:
		return
	_sync_runtime_from_main()
	supply_pulse += delta * 5.0
	queue_redraw()


func _sync_runtime_from_main() -> void:
	if main_ref == null:
		if not is_inside_tree():
			return
		var tree := get_tree()
		if tree == null:
			return
		main_ref = tree.get_root().get_node_or_null("Main")
	if main_ref == null:
		return

	var zone = main_ref.get("zone")
	if zone != null:
		current_zone_center = zone.current_center
		current_zone_radius = zone.current_radius
		next_zone_center = zone.next_center
		next_zone_radius = zone.next_radius

	var player = main_ref.get("player_ref")
	has_player = player is Node3D and is_instance_valid(player)
	if has_player:
		var player_node := player as Node3D
		player_pos = Vector2(player_node.global_position.x, player_node.global_position.z)
		var forward_3d := -player_node.global_transform.basis.z
		var forward_2d := Vector2(forward_3d.x, forward_3d.z)
		player_forward = forward_2d.normalized() if forward_2d.length() > 0.001 else Vector2(0.0, -1.0)

	if bool(main_ref.get("supply_telegraphed")):
		var supply_3d: Vector3 = main_ref.get("supply_pos")
		supply_pos = Vector2(supply_3d.x, supply_3d.z)
		supply_state = "active" if bool(main_ref.get("supply_spawned")) else "pending"
	else:
		supply_state = "none"


func _draw() -> void:
	if not visible:
		return
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP_COLOR, true)

	var map_rect := _map_rect()
	var panel_rect := map_rect.grow(24.0)
	panel_rect.position.y -= 44.0
	panel_rect.size.y += 64.0
	draw_rect(panel_rect, PANEL_COLOR, true)

	var title := _map_title()
	var title_y := maxf(20.0, panel_rect.position.y + 28.0)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(panel_rect.position.x, title_y),
		title,
		HORIZONTAL_ALIGNMENT_CENTER,
		panel_rect.size.x,
		24,
		Color(0.88, 0.92, 0.90, 1.0)
	)
	if not scale_preset.is_empty():
		draw_string(
			ThemeDB.fallback_font,
			Vector2(panel_rect.position.x, title_y + 22.0),
			scale_preset,
			HORIZONTAL_ALIGNMENT_CENTER,
			panel_rect.size.x,
			11,
			Color(0.56, 0.62, 0.64, 0.85)
		)

	draw_rect(map_rect, MAP_BG_COLOR, true)
	_draw_grid(map_rect)
	draw_rect(map_rect, MAP_BORDER_COLOR, false, 2.0)

	if map_spec == null:
		draw_string(ThemeDB.fallback_font, map_rect.position + Vector2(18.0, 30.0), "MAP DATA MISSING", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.RED)
		return

	_draw_pois(map_rect)
	_draw_features(map_rect)
	_draw_supply(map_rect)
	_draw_zones(map_rect)
	_draw_player(map_rect)


func _map_rect() -> Rect2:
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280.0, 720.0)
	var max_side := maxf(180.0, minf(viewport_size.x - 48.0, viewport_size.y - 96.0))
	var side := clampf(max_side, 180.0, 900.0)
	return Rect2(
		Vector2((viewport_size.x - side) * 0.5, (viewport_size.y - side) * 0.5 + 20.0),
		Vector2(side, side)
	)


func world_to_full_map(world_pos: Vector2, map_rect: Rect2) -> Vector2:
	var normalized := _world_to_bounds_uv(world_pos)
	return map_rect.position + Vector2(normalized.x * map_rect.size.x, normalized.y * map_rect.size.y)


func world_size_to_full_map(world_size: float, map_rect: Rect2) -> float:
	if map_definition != null and map_definition.has_method("world_distance_to_bounds_ratio"):
		return map_definition.world_distance_to_bounds_ratio(world_size) * map_rect.size.x
	return world_size * (map_rect.size.x / maxf(1.0, map_size_3d.x))


func _map_title() -> String:
	if map_definition != null:
		var display_name := String(map_definition.get("display_name"))
		if not display_name.strip_edges().is_empty():
			return display_name
	if map_spec != null:
		var metadata = map_spec.get("metadata")
		if typeof(metadata) == TYPE_DICTIONARY:
			var name := String(metadata.get("name", ""))
			if not name.strip_edges().is_empty():
				return name
	return "FULL MAP"


func _draw_grid(map_rect: Rect2) -> void:
	var grid_color := Color(1.0, 1.0, 1.0, 0.055)
	var major_color := Color(1.0, 1.0, 1.0, 0.095)
	for i in range(1, 4):
		var t := float(i) / 4.0
		var x := lerpf(map_rect.position.x, map_rect.position.x + map_rect.size.x, t)
		var y := lerpf(map_rect.position.y, map_rect.position.y + map_rect.size.y, t)
		draw_line(Vector2(x, map_rect.position.y), Vector2(x, map_rect.position.y + map_rect.size.y), grid_color, 1.0)
		draw_line(Vector2(map_rect.position.x, y), Vector2(map_rect.position.x + map_rect.size.x, y), grid_color, 1.0)
	var center := world_to_full_map(Vector2.ZERO, map_rect)
	draw_line(Vector2(center.x, map_rect.position.y), Vector2(center.x, map_rect.position.y + map_rect.size.y), major_color, 1.0)
	draw_line(Vector2(map_rect.position.x, center.y), Vector2(map_rect.position.x + map_rect.size.x, center.y), major_color, 1.0)


func _draw_pois(map_rect: Rect2) -> void:
	for poi in _poi_source():
		var poi_pos := _descriptor_pos_2d(poi)
		var screen_pos := world_to_full_map(poi_pos, map_rect)
		var radius := world_size_to_full_map(float(poi.get("radius", 8.0)), map_rect)
		var colors := _poi_colors(String(poi.get("role", "")))
		draw_circle(screen_pos, radius, colors["fill"])
		draw_arc(screen_pos, radius, 0.0, TAU, 48, colors["border"], 1.2)
		var label := String(poi.get("name", ""))
		if not label.is_empty():
			var label_width := minf(180.0, map_rect.size.x * 0.34)
			var label_pos := screen_pos + Vector2(6.0, -4.0)
			if label_pos.x + label_width > map_rect.position.x + map_rect.size.x - 6.0:
				label_pos.x = screen_pos.x - label_width - 6.0
			label_pos.x = clampf(label_pos.x, map_rect.position.x + 6.0, map_rect.position.x + map_rect.size.x - label_width - 6.0)
			label_pos.y = clampf(label_pos.y, map_rect.position.y + 14.0, map_rect.position.y + map_rect.size.y - 6.0)
			draw_string(
				ThemeDB.fallback_font,
				label_pos,
				label,
				HORIZONTAL_ALIGNMENT_LEFT,
				label_width,
				11,
				Color(0.78, 0.82, 0.78, 0.85)
			)


func _draw_features(map_rect: Rect2) -> void:
	var features := map_features.duplicate(true)
	if features.is_empty():
		features = _build_fallback_features()
	features.sort_custom(Callable(self, "_sort_features"))
	for feature in features:
		_draw_feature(feature, map_rect)


func _draw_feature(feature: Dictionary, map_rect: Rect2) -> void:
	var pos = feature.get("pos", [0.0, 0.0])
	var size_data = feature.get("size", [1.0, 1.0])
	var world_pos := Vector2(float(pos[0]), float(pos[1]))
	var world_size := Vector2(float(size_data[0]), float(size_data[1]))
	var rot_rad := deg_to_rad(float(feature.get("rot", 0.0)))
	var shape := String(feature.get("shape", "rect"))
	var obs_type := String(feature.get("type", ""))
	var colors := _feature_colors(obs_type)

	if shape == "ellipse":
		var ellipse_pts := PackedVector2Array()
		for i in range(28):
			var a := TAU * float(i) / 28.0
			var local := Vector2(cos(a) * world_size.x * 0.5, sin(a) * world_size.y * 0.5)
			ellipse_pts.append(world_to_full_map(local.rotated(rot_rad) + world_pos, map_rect))
		draw_colored_polygon(ellipse_pts, colors["fill"])
		if float(colors["width"]) > 0.0:
			draw_polyline(ellipse_pts + PackedVector2Array([ellipse_pts[0]]), colors["border"], float(colors["width"]))
		return

	var half := world_size * 0.5
	var corners := [
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	]
	var pts := PackedVector2Array()
	for corner in corners:
		pts.append(world_to_full_map(corner.rotated(rot_rad) + world_pos, map_rect))
	draw_colored_polygon(pts, colors["fill"])
	if float(colors["width"]) > 0.0:
		draw_polyline(pts + PackedVector2Array([pts[0]]), colors["border"], float(colors["width"]))


func _draw_supply(map_rect: Rect2) -> void:
	if supply_state == "none":
		return
	var pos := world_to_full_map(supply_pos, map_rect)
	if supply_state == "pending":
		var pulse := (sin(supply_pulse) + 1.0) * 0.5
		var ring_color := SUPPLY_COLOR
		ring_color.a = 0.35 + pulse * 0.45
		_draw_dashed_circle(pos, 18.0 + pulse * 4.0, ring_color, 18, 2.0)
		draw_circle(pos, 4.0, Color(SUPPLY_COLOR.r, SUPPLY_COLOR.g, SUPPLY_COLOR.b, 0.8))
	else:
		draw_circle(pos, 6.0, SUPPLY_COLOR)
		draw_arc(pos, 14.0, 0.0, TAU, 48, SUPPLY_COLOR, 2.0)


func _draw_zones(map_rect: Rect2) -> void:
	var next_pos := world_to_full_map(next_zone_center, map_rect)
	var next_radius := world_size_to_full_map(next_zone_radius, map_rect)
	_draw_dashed_circle(next_pos, next_radius, NEXT_ZONE_COLOR, 32, 2.0)

	var cur_pos := world_to_full_map(current_zone_center, map_rect)
	var cur_radius := world_size_to_full_map(current_zone_radius, map_rect)
	draw_circle(cur_pos, cur_radius, CURRENT_ZONE_FILL)
	draw_arc(cur_pos, cur_radius, 0.0, TAU, 96, CURRENT_ZONE_COLOR, 3.0)


func _draw_player(map_rect: Rect2) -> void:
	if not has_player:
		return
	var pos := world_to_full_map(player_pos, map_rect)
	var angle := player_forward.angle()
	var cone_radius := 46.0
	var fov_half := PI / 7.0
	var cone := PackedVector2Array([pos])
	for i in range(5):
		var a := angle - fov_half + (fov_half * 2.0 * float(i) / 4.0)
		cone.append(pos + Vector2(cos(a), sin(a)) * cone_radius)
	draw_colored_polygon(cone, Color(PLAYER_COLOR.r, PLAYER_COLOR.g, PLAYER_COLOR.b, 0.13))

	var arrow := PackedVector2Array([
		pos + Vector2(cos(angle), sin(angle)) * 12.0,
		pos + Vector2(cos(angle + 2.35), sin(angle + 2.35)) * 8.0,
		pos + Vector2(cos(angle - 2.35), sin(angle - 2.35)) * 8.0,
	])
	draw_colored_polygon(arrow, PLAYER_COLOR)
	draw_circle(pos, 3.5, Color(0.02, 0.14, 0.02, 1.0))


func _draw_dashed_circle(center: Vector2, radius: float, color: Color, segments: int, width: float) -> void:
	if radius <= 0.0:
		return
	for i in range(segments):
		if i % 2 != 0:
			continue
		var start := TAU * float(i) / float(segments)
		var end := TAU * float(i + 0.65) / float(segments)
		draw_arc(center, radius, start, end, 8, color, width)


func _poi_colors(role: String) -> Dictionary:
	match role:
		"loot_hub":
			return {"fill": Color(0.92, 0.70, 0.18, 0.15), "border": Color(0.92, 0.70, 0.18, 0.42)}
		"transit_choke":
			return {"fill": Color(0.85, 0.24, 0.22, 0.13), "border": Color(0.85, 0.24, 0.22, 0.38)}
		"concealment_field":
			return {"fill": Color(0.22, 0.72, 0.28, 0.14), "border": Color(0.22, 0.72, 0.28, 0.36)}
		"recovery_pocket":
			return {"fill": Color(0.25, 0.42, 0.95, 0.13), "border": Color(0.25, 0.42, 0.95, 0.36)}
	return {"fill": Color(0.7, 0.7, 0.7, 0.10), "border": Color(0.7, 0.7, 0.7, 0.30)}


func _feature_colors(obs_type: String) -> Dictionary:
	match obs_type:
		"bush_patch":
			return {
				"fill": Color(0.20, 0.50, 0.18, 0.34),
				"border": Color(0.12, 0.28, 0.09, 0.0),
				"width": 0.0,
			}
		"tree_cluster":
			return {
				"fill": Color(0.24, 0.19, 0.13, 0.84),
				"border": Color(0.10, 0.08, 0.05, 0.95),
				"width": 1.0,
			}
		"canyon_wall", "rock_cluster":
			return {
				"fill": Color(0.42, 0.43, 0.46, 0.92),
				"border": Color(0.23, 0.24, 0.27, 0.95),
				"width": 1.1,
			}
		"log_pile":
			return {
				"fill": Color(0.42, 0.28, 0.13, 0.82),
				"border": Color(0.23, 0.15, 0.07, 0.92),
				"width": 1.0,
			}
	return {
		"fill": Color(0.34, 0.35, 0.38, 0.84),
		"border": Color(0.20, 0.21, 0.24, 0.95),
		"width": 1.0,
	}


func _sort_features(a: Dictionary, b: Dictionary) -> bool:
	var layer_a := int(a.get("layer", 0))
	var layer_b := int(b.get("layer", 0))
	if layer_a == layer_b:
		var height_a := float(a.get("height", 0.0))
		var height_b := float(b.get("height", 0.0))
		if not is_equal_approx(height_a, height_b):
			return height_a < height_b
		return int(a.get("order", 0)) < int(b.get("order", 0))
	return layer_a < layer_b


func _build_fallback_features() -> Array[Dictionary]:
	var features: Array[Dictionary] = []
	if map_spec == null and map_definition == null:
		return features
	for obs in _obstacle_source():
		var obs_type := String(obs.get("type", ""))
		var scale := _descriptor_scale_3d(obs)
		var size := Vector2(scale.x * 2.0, scale.z * 2.0)
		var shape := "rect"
		var height := scale.y * 2.0
		if obs_type == "bush_patch":
			size = Vector2(scale.x * 3.0, scale.z * 3.0)
			shape = "ellipse"
		features.append({
			"type": obs_type,
			"pos": obs.get("pos", [0.0, 0.0]),
			"size": [size.x, size.y],
			"rot": obs.get("rot", 0.0),
			"height": height,
			"layer": _fallback_feature_layer(obs_type, height),
			"shape": shape,
			"order": features.size(),
		})
	return features


func _world_to_bounds_uv(world_pos: Vector2) -> Vector2:
	if map_definition != null and map_definition.has_method("world_to_bounds_uv"):
		return map_definition.world_to_bounds_uv(world_pos)
	var half := map_size_3d * 0.5
	return Vector2(
		(world_pos.x + half.x) / maxf(1.0, map_size_3d.x),
		(world_pos.y + half.y) / maxf(1.0, map_size_3d.y)
	)


func _poi_source() -> Array[Dictionary]:
	if map_definition != null and map_definition.has_method("get_poi_descriptors"):
		return map_definition.get_poi_descriptors()
	var pois: Array[Dictionary] = []
	if map_spec == null:
		return pois
	for poi in map_spec.pois:
		if typeof(poi) == TYPE_DICTIONARY:
			pois.append(poi.duplicate(true))
	return pois


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


func _descriptor_pos_2d(descriptor: Dictionary) -> Vector2:
	var pos_value = descriptor.get("pos_2d", null)
	if typeof(pos_value) == TYPE_VECTOR2:
		return pos_value
	var pos = descriptor.get("pos", [0.0, 0.0])
	if typeof(pos) == TYPE_ARRAY and pos.size() >= 2:
		return Vector2(float(pos[0]), float(pos[1]))
	return Vector2.ZERO


func _descriptor_scale_3d(descriptor: Dictionary) -> Vector3:
	var scale_value = descriptor.get("scale_3d", null)
	if typeof(scale_value) == TYPE_VECTOR3:
		return scale_value
	var scale = descriptor.get("scale", [1.0, 1.0, 1.0])
	if typeof(scale) == TYPE_ARRAY and scale.size() >= 3:
		return Vector3(float(scale[0]), float(scale[1]), float(scale[2]))
	return Vector3.ONE


func _fallback_feature_layer(obs_type: String, height: float) -> int:
	match obs_type:
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
