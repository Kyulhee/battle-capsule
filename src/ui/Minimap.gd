extends Control

func _init():
	print("[MINIMAP] Script initialized.")

@export var map_size_3d: Vector2 = Vector2(120, 120)
@export var minimap_size: Vector2 = Vector2(240, 240)

var player: Node3D
var current_zone_center = Vector2.ZERO
var current_zone_radius = 50.0
var next_zone_center = Vector2.ZERO
var next_zone_radius = 25.0

# Supply Info
var supply_pos = Vector2.ZERO
var supply_state = "none" # none, pending, active
var supply_pulse = 0.0

var map_spec: Resource = null
var minimap_features: Array[Dictionary] = []

func set_map_spec(spec: Resource, features: Array[Dictionary] = []):
	map_spec = spec
	map_size_3d = Vector2(spec.get_world_size(), spec.get_world_size())
	minimap_features = features.duplicate(true)
	queue_redraw()

func _ready():
	print("[MINIMAP] Ready. Attempting to pull MapSpec from Main...")
	var main = get_tree().get_root().get_node_or_null("Main")
	if main and main.get("map_spec"):
		print("[MINIMAP] MapSpec pulled successfully from Main.")
		set_map_spec(main.map_spec)

func _process(delta):
	if not player:
		var players = get_tree().get_nodes_in_group("players")
		if players.size() > 0: player = players[0]
	
	var main = get_tree().get_root().get_node_or_null("Main")
	if main:
		current_zone_center = main.zone.current_center
		current_zone_radius = main.zone.current_radius
		next_zone_center = main.zone.next_center
		next_zone_radius = main.zone.next_radius
		
		# Supply sync
		if main.get("supply_telegraphed"):
			supply_pos = Vector2(main.supply_pos.x, main.supply_pos.z)
			if main.get("supply_spawned"):
				supply_state = "active"
			else:
				supply_state = "pending"
		else:
			supply_state = "none"
			
	supply_pulse += delta * 5.0
	queue_redraw()

func _draw():
	var center = minimap_size / 2.0
	
	# 1. Draw Diamond Background
	var half = map_size_3d / 2.0
	var boundary_pts = PackedVector2Array([
		world_to_minimap(Vector2(-half.x, -half.y)),
		world_to_minimap(Vector2(half.x, -half.y)),
		world_to_minimap(Vector2(half.x, half.y)),
		world_to_minimap(Vector2(-half.x, half.y))
	])
	draw_colored_polygon(boundary_pts, Color(0.1, 0.1, 0.1, 0.8))
	draw_polyline(boundary_pts + PackedVector2Array([boundary_pts[0]]), Color(0.5, 0.5, 0.5), 1.5)
	
	if not map_spec:
		draw_string(ThemeDB.fallback_font, Vector2(10, 20), "MAP DATA MISSING", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.RED)
		return
	
	# 2. Draw POI Areas
	for poi in map_spec.pois:
		var pos = Vector2(poi.pos[0], poi.pos[1])
		var mini_pos = world_to_minimap(pos)
		var mini_rad = world_size_to_minimap(poi.radius)
		var role_color = Color(0.5, 0.5, 0.5, 0.05)
		match poi.get("role", ""):
			"loot_hub": role_color = Color(1.0, 0.8, 0.2, 0.08)
			"transit_choke": role_color = Color(1.0, 0.2, 0.2, 0.08)
			"concealment_field": role_color = Color(0.2, 1.0, 0.2, 0.08)
			"recovery_pocket": role_color = Color(0.2, 0.2, 1.0, 0.08)
		draw_circle(mini_pos, mini_rad, role_color)

	# 3. Draw final generated footprints from bottom to top.
	var features = minimap_features.duplicate(true)
	if features.is_empty():
		features = _build_fallback_features()
	features.sort_custom(Callable(self, "_sort_minimap_features"))
	for feature in features:
		_draw_minimap_feature(feature)

	# 4. Draw Supply Zones (Telegraphing/Active)
	if supply_state != "none":
		var mini_s_pos = world_to_minimap(supply_pos)
		var s_color = Color(1.0, 0.8, 0.1)
		if supply_state == "pending":
			var pulse_val = (sin(supply_pulse) + 1.0) / 2.0
			s_color.a = 0.3 + pulse_val * 0.4
			draw_arc(mini_s_pos, 15.0, 0, TAU, 32, s_color, 2.0)
			# Dashed effect simulation
			for i in range(8):
				draw_arc(mini_s_pos, 12.0, i * PI/4, i * PI/4 + PI/8, 8, s_color, 1.5)
		else:
			draw_circle(mini_s_pos, 5.0, s_color)
			draw_arc(mini_s_pos, 10.0, 0, TAU, 32, s_color, 2.0)

	# 5. Draw Zones
	# Next Zone (Dashed/Translucent)
	var nxt_pos = world_to_minimap(next_zone_center)
	var nxt_rad = world_size_to_minimap(next_zone_radius)
	var dashed_color = Color(1, 1, 1, 0.4)
	for i in range(24):
		draw_arc(nxt_pos, nxt_rad, i * TAU/24, i * TAU/24 + TAU/48, 4, dashed_color, 1.5)
	
	# Current Zone (Solid)
	var cur_pos = world_to_minimap(current_zone_center)
	var cur_rad = world_size_to_minimap(current_zone_radius)
	draw_arc(cur_pos, cur_rad, 0, TAU, 64, Color(0.2, 0.6, 1.0, 0.8), 3.0)
	
	# 6. Draw Player & View Frustum
	if player:
		var p_pos_2d = Vector2(player.global_position.x, player.global_position.z)
		var p_mini = world_to_minimap(p_pos_2d)
		var forward_3d = -player.global_transform.basis.z
		var angle = Vector2(forward_3d.x, forward_3d.z).angle()
		var mini_angle = angle + PI/4
		
		var fov_pts = PackedVector2Array([p_mini])
		var cone_dist = 40.0
		var fov_half = PI/6
		for i in range(5):
			var a = mini_angle - fov_half + (fov_half * 2 * i / 4.0)
			fov_pts.append(p_mini + Vector2(cos(a), sin(a)) * cone_dist)
		draw_colored_polygon(fov_pts, Color(1.0, 1.0, 1.0, 0.15))
		
		var arrow_pts = PackedVector2Array([
			p_mini + Vector2(cos(mini_angle), sin(mini_angle)) * 9,
			p_mini + Vector2(cos(mini_angle + 2.4), sin(mini_angle + 2.4)) * 6,
			p_mini + Vector2(cos(mini_angle - 2.4), sin(mini_angle - 2.4)) * 6
		])
		draw_colored_polygon(arrow_pts, Color.GREEN)
		draw_circle(p_mini, 3.5, Color.GREEN)

func world_to_minimap(world_pos: Vector2) -> Vector2:
	var rotated = world_pos.rotated(PI/4)
	var scale_factor = minimap_size.x / (map_size_3d.x * 1.414)
	return (minimap_size / 2.0) + rotated * scale_factor

func world_size_to_minimap(size: float) -> float:
	return size * (minimap_size.x / (map_size_3d.x * 1.414))

func _sort_minimap_features(a: Dictionary, b: Dictionary) -> bool:
	var layer_a = int(a.get("layer", 0))
	var layer_b = int(b.get("layer", 0))
	if layer_a == layer_b:
		var height_a = float(a.get("height", 0.0))
		var height_b = float(b.get("height", 0.0))
		if not is_equal_approx(height_a, height_b):
			return height_a < height_b
		return int(a.get("order", 0)) < int(b.get("order", 0))
	return layer_a < layer_b

func _draw_minimap_feature(feature: Dictionary):
	var pos = feature.get("pos", [0.0, 0.0])
	var size = feature.get("size", [1.0, 1.0])
	var wpos = Vector2(float(pos[0]), float(pos[1]))
	var world_size = Vector2(float(size[0]), float(size[1]))
	var rot_rad = deg_to_rad(float(feature.get("rot", 0.0)))
	var shape = String(feature.get("shape", "rect"))
	var obs_type = String(feature.get("type", ""))
	var colors = _feature_colors(obs_type)

	if shape == "ellipse":
		var pts = PackedVector2Array()
		var steps = 24
		for i in range(steps):
			var a = TAU * float(i) / float(steps)
			var local = Vector2(cos(a) * world_size.x * 0.5, sin(a) * world_size.y * 0.5)
			pts.append(world_to_minimap(local.rotated(rot_rad) + wpos))
		draw_colored_polygon(pts, colors["fill"])
		return

	var hx = world_size.x * 0.5
	var hz = world_size.y * 0.5
	var corners_local = [
		Vector2(-hx, -hz),
		Vector2( hx, -hz),
		Vector2( hx,  hz),
		Vector2(-hx,  hz),
	]
	var pts = PackedVector2Array()
	for c in corners_local:
		pts.append(world_to_minimap(c.rotated(rot_rad) + wpos))
	draw_colored_polygon(pts, colors["fill"])
	draw_polyline(pts + PackedVector2Array([pts[0]]), colors["border"], float(colors["width"]))

func _feature_colors(obs_type: String) -> Dictionary:
	match obs_type:
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
		"canyon_wall", "rock_cluster":
			return {
				"fill": Color(0.42, 0.42, 0.46, 0.96),
				"border": Color(0.24, 0.24, 0.28, 1.0),
				"width": 1.2,
			}
		"log_pile":
			return {
				"fill": Color(0.44, 0.30, 0.14, 0.92),
				"border": Color(0.26, 0.17, 0.07, 1.0),
				"width": 1.0,
			}
	return {
		"fill": Color(0.35, 0.35, 0.40, 0.92),
		"border": Color(0.22, 0.22, 0.26, 1.0),
		"width": 1.0,
	}

func _build_fallback_features() -> Array[Dictionary]:
	var features: Array[Dictionary] = []
	if not map_spec:
		return features
	for obs in map_spec.obstacles:
		var obs_type = String(obs.get("type", ""))
		var scale = obs.get("scale", [1.0, 1.0, 1.0])
		var size = Vector2(float(scale[0]) * 2.0, float(scale[2]) * 2.0)
		var shape = "rect"
		var height = float(scale[1]) * 2.0
		var layer = _fallback_feature_layer(obs_type, height)
		if obs_type == "bush_patch":
			size = Vector2(float(scale[0]) * 3.0, float(scale[2]) * 3.0)
			shape = "ellipse"
		size = _fallback_cover_size(obs_type, size, height)
		features.append({
			"type": obs_type,
			"pos": obs.get("pos", [0.0, 0.0]),
			"size": [size.x, size.y],
			"rot": obs.get("rot", 0.0),
			"height": height,
			"layer": layer,
			"shape": shape,
			"order": features.size(),
		})
	return features

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

func _fallback_cover_size(obs_type: String, base_size: Vector2, height: float) -> Vector2:
	match obs_type:
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
