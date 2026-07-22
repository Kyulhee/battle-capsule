extends Control

const MINIMAP_STATIC_LAYER = preload("res://src/ui/MinimapStaticLayer.gd")
const MAP_ROTATION := PI / 4.0
const STATIC_CACHE_SIZE := Vector2i(768, 768)

func _init():
	print("[MINIMAP] Script initialized.")

@export var map_size_3d: Vector2 = Vector2(120, 120)
@export var minimap_size: Vector2 = Vector2(280, 280)
@export var local_view_size_m := 120.0

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
var map_definition = null
var minimap_features: Array[Dictionary] = []
var _static_viewport: SubViewport = null
var _static_texture: TextureRect = null
var _static_layer: Control = null
var _pois: Array[Dictionary] = []

func set_map_spec(spec: Resource, features: Array[Dictionary] = [], definition = null):
	map_spec = spec
	map_definition = definition
	if map_definition != null and map_definition.has_method("get_world_size_2d"):
		map_size_3d = map_definition.get_world_size_2d()
	elif spec != null and spec.has_method("get_world_size"):
		map_size_3d = Vector2(spec.get_world_size(), spec.get_world_size())
	minimap_features = features.duplicate(true)
	_pois = _poi_source()
	if is_inside_tree():
		_refresh_static_cache()
	queue_redraw()

func _ready():
	clip_contents = true
	_ensure_static_cache()
	print("[MINIMAP] Ready. Attempting to pull MapSpec from Main...")
	var main = get_tree().get_root().get_node_or_null("Main")
	if main and main.get("map_spec"):
		print("[MINIMAP] MapSpec pulled successfully from Main.")
		set_map_spec(main.map_spec, [], main.get("map_definition"))
	else:
		_refresh_static_cache()

func _ensure_static_cache() -> void:
	if is_instance_valid(_static_viewport):
		return
	_static_viewport = SubViewport.new()
	_static_viewport.name = "StaticMapViewport"
	_static_viewport.disable_3d = true
	_static_viewport.transparent_bg = true
	add_child(_static_viewport)

	_static_layer = MINIMAP_STATIC_LAYER.new()
	_static_layer.name = "StaticMapLayer"
	_static_viewport.add_child(_static_layer)

	_static_texture = TextureRect.new()
	_static_texture.name = "StaticMapTexture"
	_static_texture.show_behind_parent = true
	_static_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_static_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_static_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_static_texture.stretch_mode = TextureRect.STRETCH_SCALE
	_static_texture.texture = _static_viewport.get_texture()
	add_child(_static_texture)

func _refresh_static_cache() -> void:
	_ensure_static_cache()
	_static_viewport.size = STATIC_CACHE_SIZE
	_static_layer.configure(
		map_spec,
		minimap_features,
		map_definition,
		map_size_3d,
		Vector2(STATIC_CACHE_SIZE)
	)
	_static_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_update_static_texture_transform()

func _process(delta):
	if not player:
		var players = get_tree().get_nodes_in_group("players")
		if players.size() > 0: player = players[0]
	
	var main = get_tree().get_root().get_node_or_null("Main")
	if main:
		if main.zone:
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
	_update_static_texture_transform()
	queue_redraw()

func _draw():
	if not map_spec:
		return

	_draw_local_poi_labels()

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
		var mini_angle = angle + MAP_ROTATION
		
		var fov_pts = PackedVector2Array([p_mini])
		var cone_dist = minf(52.0, world_size_to_minimap(22.0))
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

	draw_rect(Rect2(Vector2.ZERO, minimap_size), Color(0.68, 0.70, 0.68, 0.82), false, 2.0)

func world_to_minimap(world_pos: Vector2) -> Vector2:
	var relative := world_pos - _focus_world_position()
	return minimap_size * 0.5 + relative.rotated(MAP_ROTATION) * _local_world_scale()

func world_size_to_minimap(size: float) -> float:
	return size * _local_world_scale()

func _update_static_texture_transform() -> void:
	if not is_instance_valid(_static_texture):
		return
	var texture_size := Vector2(STATIC_CACHE_SIZE)
	var full_world_scale := texture_size.x / maxf(1.0, map_size_3d.x * sqrt(2.0))
	var display_scale := _local_world_scale() / full_world_scale
	var focus_texture_position := (
		texture_size * 0.5
		+ _focus_world_position().rotated(MAP_ROTATION) * full_world_scale
	)
	_static_texture.size = texture_size * display_scale
	_static_texture.position = minimap_size * 0.5 - focus_texture_position * display_scale

func _local_world_scale() -> float:
	return minimap_size.x / maxf(1.0, local_view_size_m)

func _focus_world_position() -> Vector2:
	if is_instance_valid(player):
		return Vector2(player.global_position.x, player.global_position.z)
	return Vector2.ZERO

func _draw_local_poi_labels() -> void:
	var label_width := minf(130.0, minimap_size.x * 0.46)
	for poi in _pois:
		if String(poi.get("role", "")) not in ["loot_hub", "recovery_pocket"]:
			continue
		var label := _poi_label(poi)
		if label.is_empty():
			continue
		var mini_position := world_to_minimap(_descriptor_pos_2d(poi))
		var mini_radius := world_size_to_minimap(float(poi.get("radius", 8.0)))
		if (
			mini_position.x + mini_radius < 0.0
			or mini_position.y + mini_radius < 0.0
			or mini_position.x - mini_radius > minimap_size.x
			or mini_position.y - mini_radius > minimap_size.y
		):
			continue
		var label_position := mini_position + Vector2(-label_width * 0.5, -mini_radius - 3.0)
		label_position.x = clampf(label_position.x, 4.0, minimap_size.x - label_width - 4.0)
		label_position.y = clampf(label_position.y, 13.0, minimap_size.y - 4.0)
		draw_string(
			ThemeDB.fallback_font,
			label_position,
			label,
			HORIZONTAL_ALIGNMENT_CENTER,
			label_width,
			11,
			Color(0.84, 0.86, 0.80, 0.90)
		)


func _poi_label(poi: Dictionary) -> String:
	var identity = poi.get("identity", null)
	if typeof(identity) == TYPE_DICTIONARY:
		var map_label := String(identity.get("map_label", "")).strip_edges()
		if not map_label.is_empty():
			return map_label
	return String(poi.get("name", "")).strip_edges()

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

func _descriptor_pos_2d(descriptor: Dictionary) -> Vector2:
	var position_value = descriptor.get("pos_2d", null)
	if typeof(position_value) == TYPE_VECTOR2:
		return position_value
	var position_array = descriptor.get("pos", [0.0, 0.0])
	if typeof(position_array) == TYPE_ARRAY and position_array.size() >= 2:
		return Vector2(float(position_array[0]), float(position_array[1]))
	return Vector2.ZERO
