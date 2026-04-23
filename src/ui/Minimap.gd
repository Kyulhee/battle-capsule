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

func set_map_spec(spec: Resource):
	map_spec = spec
	map_size_3d = Vector2(spec.get_world_size(), spec.get_world_size())
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
		current_zone_center = main.current_zone_center
		current_zone_radius = main.current_zone_radius
		next_zone_center = main.next_zone_center
		next_zone_radius = main.next_zone_radius
		
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

	# 3. Draw Shaped Obstacles
	for obs in map_spec.obstacles:
		var pos = Vector2(obs.pos[0], obs.pos[1])
		var scale = Vector2(obs.scale[0], obs.scale[2])
		var rot_rad = deg_to_rad(obs.get("rot", 0))
		var corners = [Vector2(-scale.x/2, -scale.y/2), Vector2(scale.x/2, -scale.y/2), Vector2(scale.x/2, scale.y/2), Vector2(-scale.x/2, scale.y/2)]
		var mini_corners = PackedVector2Array()
		for c in corners:
			var world_corner = c.rotated(rot_rad) + pos
			mini_corners.append(world_to_minimap(world_corner))
		var color = Color(0.35, 0.35, 0.4)
		draw_colored_polygon(mini_corners, color)

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
