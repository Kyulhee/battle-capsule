class_name MapDefinition
extends Resource

const MapSpecScript = preload("res://src/core/MapSpec.gd")

const DEFAULT_MATCH := {
	"bot_count": 11,
	"loot_count": 40,
	"spawn_radius": 45.0,
}

const DEFAULT_ZONE := {
	"wait_time": 30.0,
	"shrink_time": 20.0,
	"damage_per_second": 2.0,
	"initial_timer": 15.0,
	"stages": {},
}

const IMPLICIT_INITIAL_ZONE_RADIUS := 50.0
const IMPLICIT_NEXT_ZONE_RADIUS_MULT := 0.6
const MAX_REASONABLE_POI_RADIUS_RATIO := 0.25
const MAX_ITEM_DENSITY := 1.5
const VALID_ROUTE_ROLES := {
	"primary_choke": true,
	"flank": true,
	"loot_flow": true,
	"recovery_exit": true,
	"zone_rotation": true,
}
const VALID_COVER_CLASSES := {
	"hard": true,
	"screen": true,
	"soft": true,
}

@export var id: String = ""
@export var display_name: String = ""
@export var source_path: String = ""
@export var map_spec: Resource = null
@export var match_overrides: Dictionary = {}
@export var runtime_overrides: Dictionary = {}
@export var zone_overrides: Dictionary = {}
@export var scale_presets: Dictionary = {}
@export var scale_envelopes: Dictionary = {}


func load_from_json(json_text: String, source_path_value: String = "", game_config = null) -> bool:
	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		push_error("MapDefinition: JSON parse error at line %d: %s" % [
			json.get_error_line(),
			json.get_error_message()
		])
		return false
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		push_error("MapDefinition: root must be a Dictionary.")
		return false
	return load_from_data(data, source_path_value, game_config)


func load_from_data(data: Dictionary, source_path_value: String = "", _game_config = null) -> bool:
	var spec_data := _dictionary(data.get("map_spec", data))
	var spec := _map_spec_from_data(spec_data)
	if spec == null:
		return false

	source_path = source_path_value
	map_spec = spec
	display_name = String(data.get("display_name", spec.metadata.get("name", "Untitled Map")))
	id = String(data.get("id", spec.metadata.get("id", _slug(display_name))))
	match_overrides = _dictionary(data.get("match", {}))
	runtime_overrides = _dictionary(data.get("runtime", {}))
	zone_overrides = _dictionary(data.get("zone", {}))
	scale_presets = _dictionary(data.get("scale_presets", {}))
	scale_envelopes = _dictionary(data.get("scale_envelopes", {}))
	return true


func load_from_map_spec(spec: Resource, source_path_value: String = "") -> bool:
	source_path = source_path_value
	map_spec = spec
	match_overrides.clear()
	runtime_overrides.clear()
	zone_overrides.clear()
	scale_presets.clear()
	scale_envelopes.clear()
	if spec != null:
		display_name = String(spec.metadata.get("name", "Untitled Map"))
		id = String(spec.metadata.get("id", _slug(display_name)))
	return spec != null


func get_world_size() -> float:
	if map_spec == null or not map_spec.has_method("get_world_size"):
		return 0.0
	return float(map_spec.get_world_size())


func get_world_size_2d() -> Vector2:
	var world_size := get_world_size()
	return Vector2(world_size, world_size)


func get_world_half_extent() -> Vector2:
	return get_world_size_2d() * 0.5


func get_world_bounds() -> Rect2:
	var world_size := get_world_size_2d()
	return Rect2(-world_size * 0.5, world_size)


func is_world_position_inside(world_pos: Vector2, margin: float = 0.0) -> bool:
	var half_extent := get_world_half_extent()
	var safe_margin := maxf(0.0, margin)
	half_extent = Vector2(
		maxf(0.0, half_extent.x - safe_margin),
		maxf(0.0, half_extent.y - safe_margin)
	)
	return absf(world_pos.x) <= half_extent.x and absf(world_pos.y) <= half_extent.y


func clamp_world_position(world_pos: Vector2, margin: float = 0.0) -> Vector2:
	var half_extent := get_world_half_extent()
	var safe_margin := maxf(0.0, margin)
	half_extent = Vector2(
		maxf(0.0, half_extent.x - safe_margin),
		maxf(0.0, half_extent.y - safe_margin)
	)
	return Vector2(
		clampf(world_pos.x, -half_extent.x, half_extent.x),
		clampf(world_pos.y, -half_extent.y, half_extent.y)
	)


func world_to_bounds_uv(world_pos: Vector2) -> Vector2:
	var world_size := get_world_size_2d()
	var half_extent := world_size * 0.5
	return Vector2(
		(world_pos.x + half_extent.x) / maxf(1.0, world_size.x),
		(world_pos.y + half_extent.y) / maxf(1.0, world_size.y)
	)


func bounds_uv_to_world(uv: Vector2) -> Vector2:
	var world_size := get_world_size_2d()
	var half_extent := world_size * 0.5
	return Vector2(
		uv.x * world_size.x - half_extent.x,
		uv.y * world_size.y - half_extent.y
	)


func world_distance_to_bounds_ratio(world_distance: float) -> float:
	var world_size := get_world_size_2d()
	var reference_size := maxf(1.0, minf(world_size.x, world_size.y))
	return world_distance / reference_size


func get_poi_descriptors() -> Array[Dictionary]:
	var descriptors: Array[Dictionary] = []
	if map_spec == null:
		return descriptors
	for i in range(map_spec.pois.size()):
		var poi := _dictionary(map_spec.pois[i])
		poi["index"] = i
		poi["pos_2d"] = _vector2_from_array(poi.get("pos", []), Vector2.ZERO)
		poi["radius"] = maxf(0.0, float(poi.get("radius", 0.0)))
		descriptors.append(poi)
	return descriptors


func get_obstacle_descriptors() -> Array[Dictionary]:
	var descriptors: Array[Dictionary] = []
	if map_spec == null:
		return descriptors
	for i in range(map_spec.obstacles.size()):
		var obstacle := _dictionary(map_spec.obstacles[i])
		var scale := _vector3_from_array(obstacle.get("scale", []), Vector3.ONE)
		var jitter := _vector2_from_array(obstacle.get("jitter", [0.0, 0.0]), Vector2.ZERO)
		var extent := _obstacle_axis_extent(obstacle, scale)
		obstacle["index"] = i
		obstacle["pos_2d"] = _vector2_from_array(obstacle.get("pos", []), Vector2.ZERO)
		obstacle["scale_3d"] = scale
		obstacle["jitter_2d"] = jitter
		obstacle["axis_extent_2d"] = extent
		obstacle["bounds_extent_2d"] = extent + Vector2(absf(jitter.x), absf(jitter.y))
		descriptors.append(obstacle)
	return descriptors


func get_surface_zone_descriptors() -> Array[Dictionary]:
	var descriptors: Array[Dictionary] = []
	if map_spec == null:
		return descriptors
	for i in range(map_spec.surface_zones.size()):
		var zone := _dictionary(map_spec.surface_zones[i])
		zone["index"] = i
		zone["pos_2d"] = _vector2_from_array(zone.get("pos", []), Vector2.ZERO)
		zone["size_2d"] = _vector2_from_array(zone.get("size", []), Vector2.ZERO)
		var points_2d: Array[Vector2] = []
		for point_data in _array(zone.get("points", [])):
			points_2d.append(_vector2_from_array(point_data, Vector2.INF))
		zone["points_2d"] = points_2d
		descriptors.append(zone)
	return descriptors


func get_surface_id_at(world_pos: Vector2, fallback: String = "dirt") -> String:
	var zones := get_surface_zone_descriptors()
	for i in range(zones.size() - 1, -1, -1):
		var zone: Dictionary = zones[i]
		if _surface_zone_contains(zone, world_pos):
			return String(zone.get("surface", fallback))
	return fallback


func get_route_descriptors() -> Array[Dictionary]:
	var descriptors: Array[Dictionary] = []
	if map_spec == null:
		return descriptors
	for i in range(map_spec.routes.size()):
		var route := _dictionary(map_spec.routes[i])
		var points_2d: Array[Vector2] = []
		for point_data in _array(route.get("points", [])):
			points_2d.append(_vector2_from_array(point_data, Vector2.INF))
		route["index"] = i
		route["points_2d"] = points_2d
		route["width"] = maxf(0.0, float(route.get("width", 0.0)))
		descriptors.append(route)
	return descriptors


func describe_strategic_position(world_pos: Vector2) -> Dictionary:
	var context := {
		"poi_role": "open",
		"poi_name": "none",
		"poi_inside": false,
		"nearest_poi_role": "none",
		"nearest_poi_name": "none",
		"nearest_poi_distance": -1.0,
		"nearest_poi_radius": 0.0,
		"nearest_poi_edge_distance": -1.0,
		"route_role": "off_route",
		"route_id": "off_route",
		"route_on": false,
		"nearest_route_role": "none",
		"nearest_route_id": "none",
		"nearest_route_distance": -1.0,
		"nearest_route_width": 0.0,
		"nearest_route_edge_distance": -1.0,
	}

	var nearest_poi_distance := INF
	for poi in get_poi_descriptors():
		var poi_pos: Vector2 = poi.get("pos_2d", Vector2.ZERO)
		var distance := world_pos.distance_to(poi_pos)
		if distance < nearest_poi_distance:
			nearest_poi_distance = distance
			var radius := float(poi.get("radius", 0.0))
			context["nearest_poi_role"] = String(poi.get("role", "none"))
			context["nearest_poi_name"] = String(poi.get("name", "none"))
			context["nearest_poi_distance"] = distance
			context["nearest_poi_radius"] = radius
			context["nearest_poi_edge_distance"] = maxf(0.0, distance - radius)
			if distance <= radius:
				context["poi_inside"] = true
				context["poi_role"] = String(poi.get("role", "open"))
				context["poi_name"] = String(poi.get("name", "none"))

	var nearest_route_distance := INF
	for route in get_route_descriptors():
		var points: Array = route.get("points_2d", [])
		var distance := _route_distance(world_pos, points)
		if distance < nearest_route_distance:
			nearest_route_distance = distance
			var width := float(route.get("width", 0.0))
			context["nearest_route_role"] = String(route.get("role", "none"))
			context["nearest_route_id"] = String(route.get("id", "none"))
			context["nearest_route_distance"] = distance
			context["nearest_route_width"] = width
			context["nearest_route_edge_distance"] = maxf(0.0, distance - width)
			if distance <= width:
				context["route_on"] = true
				context["route_role"] = String(route.get("role", "off_route"))
				context["route_id"] = String(route.get("id", "off_route"))

	return context


func get_match_tuning(game_config = null, fallback: Dictionary = {}, preset_name: String = "") -> Dictionary:
	var tuning := _merge_dict(DEFAULT_MATCH.duplicate(true), fallback.duplicate(true))
	if game_config != null and game_config.has_method("match_value"):
		for key in DEFAULT_MATCH.keys():
			tuning[key] = game_config.match_value(String(key), tuning.get(key, DEFAULT_MATCH[key]))
	tuning = _merge_dict(tuning, match_overrides)
	tuning = _merge_dict(tuning, _preset_section(preset_name, "match"))
	tuning["bot_count"] = max(0, int(tuning.get("bot_count", DEFAULT_MATCH["bot_count"])))
	tuning["loot_count"] = max(0, int(tuning.get("loot_count", DEFAULT_MATCH["loot_count"])))
	tuning["spawn_radius"] = maxf(1.0, float(tuning.get("spawn_radius", DEFAULT_MATCH["spawn_radius"])))
	return tuning


func get_runtime_tuning(game_config = null, fallback: Dictionary = {}, preset_name: String = "") -> Dictionary:
	var tuning := fallback.duplicate(true)
	if game_config != null and game_config.has_method("runtime_tuning"):
		tuning = _merge_dict(tuning, game_config.runtime_tuning())
	tuning = _merge_dict(tuning, runtime_overrides)
	return _merge_dict(tuning, _preset_section(preset_name, "runtime"))


func get_zone_tuning(game_config = null, fallback: Dictionary = {}, preset_name: String = "") -> Dictionary:
	var tuning := _merge_dict(DEFAULT_ZONE.duplicate(true), fallback.duplicate(true))
	if game_config != null and game_config.has_method("zone_value"):
		for key in ["wait_time", "shrink_time", "damage_per_second", "initial_timer"]:
			tuning[key] = game_config.zone_value(key, tuning.get(key, DEFAULT_ZONE[key]))
	if game_config != null and game_config.has_method("zone_stage_configs"):
		tuning["stages"] = game_config.zone_stage_configs()
	tuning = _merge_dict(tuning, zone_overrides)
	tuning = _merge_dict(tuning, _preset_section(preset_name, "zone"))
	tuning["wait_time"] = maxf(1.0, float(tuning.get("wait_time", DEFAULT_ZONE["wait_time"])))
	tuning["shrink_time"] = maxf(1.0, float(tuning.get("shrink_time", DEFAULT_ZONE["shrink_time"])))
	tuning["damage_per_second"] = maxf(0.0, float(tuning.get("damage_per_second", DEFAULT_ZONE["damage_per_second"])))
	tuning["initial_timer"] = maxf(0.1, float(tuning.get("initial_timer", DEFAULT_ZONE["initial_timer"])))
	if typeof(tuning.get("stages", {})) != TYPE_DICTIONARY:
		tuning["stages"] = {}
	return tuning


func get_scale_preset(preset_name: String) -> Dictionary:
	return _dictionary(scale_presets.get(preset_name, {}))


func has_scale_preset(preset_name: String) -> bool:
	return preset_name.is_empty() or scale_presets.has(preset_name)


func get_scale_envelope(envelope_name: String) -> Dictionary:
	return _dictionary(scale_envelopes.get(envelope_name, {}))


func has_scale_envelope(envelope_name: String) -> bool:
	return scale_envelopes.has(envelope_name)


func validate(game_config = null, preset_name: String = "") -> Array[String]:
	var issues: Array[String] = []
	if id.strip_edges().is_empty():
		issues.append("MapDefinition id is empty.")
	if display_name.strip_edges().is_empty():
		issues.append("MapDefinition display_name is empty.")
	if not has_scale_preset(preset_name):
		issues.append("Scale preset '%s' does not exist." % preset_name)
	if map_spec == null:
		issues.append("MapDefinition has no map_spec.")
		return issues

	var world_size := get_world_size()
	if world_size <= 0.0:
		issues.append("Map world_size must be positive.")
		return issues
	var half_size := world_size * 0.5

	if map_spec.pois.is_empty():
		issues.append("Map has no POIs.")
	for i in range(map_spec.pois.size()):
		var poi: Dictionary = map_spec.pois[i]
		var pos := _vector2_from_array(poi.get("pos", []), Vector2.INF)
		var radius := float(poi.get("radius", 0.0))
		var item_density := float(poi.get("item_density", 0.0))
		var rare_bias := float(poi.get("rare_bias", 0.0))
		if not pos.is_finite():
			issues.append("POI %d has invalid pos." % i)
			continue
		if radius <= 0.0:
			issues.append("POI %d has non-positive radius." % i)
		elif radius > world_size * MAX_REASONABLE_POI_RADIUS_RATIO:
			issues.append("POI %d radius %.1f is too large for world_size %.1f." % [i, radius, world_size])
		if absf(pos.x) + radius > half_size or absf(pos.y) + radius > half_size:
			issues.append("POI %d extends outside world bounds." % i)
		if item_density < 0.0:
			issues.append("POI %d has negative item_density." % i)
		elif item_density > MAX_ITEM_DENSITY:
			issues.append("POI %d item_density %.2f exceeds %.2f." % [i, item_density, MAX_ITEM_DENSITY])
		if rare_bias < 0.0 or rare_bias > 1.0:
			issues.append("POI %d rare_bias %.2f must be within 0..1." % [i, rare_bias])

	for i in range(map_spec.obstacles.size()):
		var obstacle: Dictionary = map_spec.obstacles[i]
		var pos := _vector2_from_array(obstacle.get("pos", []), Vector2.INF)
		var scale := _vector3_from_array(obstacle.get("scale", []), Vector3.ZERO)
		if not pos.is_finite():
			issues.append("Obstacle %d has invalid pos." % i)
			continue
		if scale.x <= 0.0 or scale.y <= 0.0 or scale.z <= 0.0:
			issues.append("Obstacle %d has non-positive scale." % i)
			continue
		var cover_class := String(obstacle.get("cover_class", "")).strip_edges().to_lower()
		if not cover_class.is_empty() and not VALID_COVER_CLASSES.has(cover_class):
			issues.append("Obstacle %d cover_class '%s' is unknown." % [i, cover_class])
		var extent := _obstacle_axis_extent(obstacle, scale)
		var jitter := _vector2_from_array(obstacle.get("jitter", [0.0, 0.0]), Vector2.ZERO)
		extent += Vector2(absf(jitter.x), absf(jitter.y))
		if absf(pos.x) + extent.x > half_size or absf(pos.y) + extent.y > half_size:
			issues.append("Obstacle %d extends outside world bounds." % i)

	for i in range(map_spec.surface_zones.size()):
		var zone := _dictionary(map_spec.surface_zones[i])
		var shape := String(zone.get("shape", "rect"))
		var surface_id := String(zone.get("surface", "")).strip_edges()
		var material_id := String(zone.get("material_id", "")).strip_edges()
		if surface_id.is_empty():
			issues.append("Surface zone %d has empty surface id." % i)
		if material_id.is_empty():
			issues.append("Surface zone %d has empty material_id." % i)
		if shape == "path":
			var points := _array(zone.get("points", []))
			if points.size() < 2:
				issues.append("Surface zone %d path needs at least 2 points." % i)
			if float(zone.get("width", 0.0)) <= 0.0:
				issues.append("Surface zone %d path width must be positive." % i)
			for point_index in range(points.size()):
				var point := _vector2_from_array(points[point_index], Vector2.INF)
				if not point.is_finite():
					issues.append("Surface zone %d point %d is invalid." % [i, point_index])
				elif absf(point.x) > half_size or absf(point.y) > half_size:
					issues.append("Surface zone %d point %d extends outside world bounds." % [i, point_index])
		elif shape in ["rect", "ellipse"]:
			var pos := _vector2_from_array(zone.get("pos", []), Vector2.INF)
			var size := _vector2_from_array(zone.get("size", []), Vector2.ZERO)
			if not pos.is_finite():
				issues.append("Surface zone %d has invalid pos." % i)
			elif absf(pos.x) > half_size or absf(pos.y) > half_size:
				issues.append("Surface zone %d center extends outside world bounds." % i)
			if size.x <= 0.0 or size.y <= 0.0:
				issues.append("Surface zone %d has non-positive size." % i)
		else:
			issues.append("Surface zone %d shape '%s' is unknown." % [i, shape])

	for i in range(map_spec.routes.size()):
		var route := _dictionary(map_spec.routes[i])
		var route_id := String(route.get("id", route.get("name", ""))).strip_edges()
		var role := String(route.get("role", "")).strip_edges()
		if route_id.is_empty():
			issues.append("Route %d has empty id." % i)
		if role.is_empty():
			issues.append("Route %d has empty role." % i)
		elif not VALID_ROUTE_ROLES.has(role):
			issues.append("Route %d role '%s' is unknown." % [i, role])
		if route.has("width") and float(route.get("width", 0.0)) <= 0.0:
			issues.append("Route %d width must be positive." % i)
		var points := _array(route.get("points", []))
		if points.size() < 2:
			issues.append("Route %d needs at least 2 points." % i)
			continue
		for point_index in range(points.size()):
			var point := _vector2_from_array(points[point_index], Vector2.INF)
			if not point.is_finite():
				issues.append("Route %d point %d is invalid." % [i, point_index])
				continue
			if absf(point.x) > half_size or absf(point.y) > half_size:
				issues.append("Route %d point %d extends outside world bounds." % [i, point_index])

	var match_tuning := get_match_tuning(game_config, {}, preset_name)
	var runtime_tuning := get_runtime_tuning(game_config, {}, preset_name)
	var spawn_radius := float(match_tuning.get("spawn_radius", 0.0))
	if spawn_radius <= 0.0:
		issues.append("spawn_radius must be positive.")
	elif spawn_radius > half_size:
		issues.append("spawn_radius %.1f exceeds world half-size %.1f." % [spawn_radius, half_size])
	var spawn_section := _dictionary(runtime_tuning.get("spawn", {}))
	var inner_radius := float(spawn_section.get("inner_radius", 0.0))
	var entity_clearance := float(spawn_section.get("entity_clearance", 0.0))
	var obstacle_clearance := float(spawn_section.get("obstacle_clearance_margin", 0.0))
	if inner_radius < 0.0:
		issues.append("runtime.spawn.inner_radius must be non-negative.")
	elif spawn_radius < inner_radius:
		issues.append("spawn_radius %.1f is smaller than runtime.spawn.inner_radius %.1f." % [spawn_radius, inner_radius])
	if spawn_radius + maxf(0.0, entity_clearance) > half_size:
		issues.append("spawn_radius %.1f plus entity_clearance %.1f exceeds world half-size %.1f." % [spawn_radius, entity_clearance, half_size])
	_validate_fixed_spawn_positions(
		issues,
		_array(spawn_section.get("fixed_positions", [])),
		int(match_tuning.get("bot_count", 0)) + 1,
		half_size,
		maxf(0.0, entity_clearance),
		maxf(0.0, obstacle_clearance)
	)

	var loot_count := int(match_tuning.get("loot_count", 0))
	if loot_count > 0 and _loot_hotspot_count() <= 0:
		issues.append("loot_count is positive but map has no loot-capable POIs.")
	elif loot_count > 0 and _loot_density_total() <= 0.0:
		issues.append("loot_count is positive but total loot density is zero.")

	_validate_zone_sanity(issues, game_config, preset_name, half_size)
	_validate_scale_envelopes(issues)

	return issues


func summary(game_config = null, preset_name: String = "") -> Dictionary:
	var match_tuning := get_match_tuning(game_config, {}, preset_name)
	var runtime_tuning := get_runtime_tuning(game_config, {}, preset_name)
	var zone_tuning := get_zone_tuning(game_config, {}, preset_name)
	var spawn_section := _dictionary(runtime_tuning.get("spawn", {}))
	return {
		"id": id,
		"display_name": display_name,
		"scale_preset": preset_name,
		"source_path": source_path,
		"world_size": get_world_size(),
		"poi_count": map_spec.pois.size() if map_spec != null else 0,
		"obstacle_count": map_spec.obstacles.size() if map_spec != null else 0,
		"surface_zone_count": map_spec.surface_zones.size() if map_spec != null else 0,
		"route_count": map_spec.routes.size() if map_spec != null else 0,
		"bot_count": int(match_tuning.get("bot_count", 0)),
		"loot_count": int(match_tuning.get("loot_count", 0)),
		"spawn_radius": float(match_tuning.get("spawn_radius", 0.0)),
		"fixed_spawn_count": _array(spawn_section.get("fixed_positions", [])).size(),
		"loot_hotspot_count": _loot_hotspot_count() if map_spec != null else 0,
		"zone_wait_time": float(zone_tuning.get("wait_time", 0.0)),
		"zone_shrink_time": float(zone_tuning.get("shrink_time", 0.0)),
		"zone_initial_radius": float(zone_tuning.get("initial_radius", IMPLICIT_INITIAL_ZONE_RADIUS)),
		"zone_stage_count": _dictionary(zone_tuning.get("stages", {})).size(),
		"scale_preset_count": scale_presets.size(),
		"scale_envelope_count": scale_envelopes.size(),
	}


func _validate_fixed_spawn_positions(
	issues: Array[String],
	raw_positions: Array,
	required_count: int,
	half_size: float,
	entity_clearance: float,
	obstacle_clearance: float
) -> void:
	if raw_positions.is_empty():
		return
	if raw_positions.size() < required_count:
		issues.append("runtime.spawn.fixed_positions needs at least %d entries for player plus bots, got %d." % [
			required_count,
			raw_positions.size(),
		])

	var positions: Array[Vector2] = []
	for i in range(raw_positions.size()):
		var position := _vector2_from_array(raw_positions[i], Vector2.INF)
		if not position.is_finite():
			issues.append("runtime.spawn.fixed_positions.%d is invalid." % i)
			continue
		positions.append(position)
		if absf(position.x) + entity_clearance > half_size \
				or absf(position.y) + entity_clearance > half_size:
			issues.append("runtime.spawn.fixed_positions.%d exceeds world bounds with entity_clearance." % i)
		if _fixed_spawn_overlaps_obstacle(position, obstacle_clearance):
			issues.append("runtime.spawn.fixed_positions.%d overlaps a blocking obstacle." % i)

	for i in range(positions.size()):
		for j in range(i + 1, positions.size()):
			if positions[i].distance_to(positions[j]) < entity_clearance:
				issues.append("runtime.spawn.fixed_positions.%d and %d are closer than entity_clearance %.1f." % [
					i,
					j,
					entity_clearance,
				])


func _fixed_spawn_overlaps_obstacle(position: Vector2, margin: float) -> bool:
	if map_spec == null:
		return false
	for obstacle_data in map_spec.obstacles:
		var obstacle := _dictionary(obstacle_data)
		if String(obstacle.get("type", "")) == "bush_patch":
			continue
		var obstacle_pos := _vector2_from_array(obstacle.get("pos", []), Vector2.INF)
		var scale := _vector3_from_array(obstacle.get("scale", []), Vector3.ZERO)
		if not obstacle_pos.is_finite() or scale == Vector3.ZERO:
			continue
		var extent := _obstacle_axis_extent(obstacle, scale) + Vector2.ONE * margin
		var delta := position - obstacle_pos
		if absf(delta.x) < extent.x and absf(delta.y) < extent.y:
			return true
	return false


func _preset_section(preset_name: String, section_name: String) -> Dictionary:
	if preset_name.is_empty():
		return {}
	var preset := get_scale_preset(preset_name)
	var section := _dictionary(preset.get(section_name, {}))
	if not section.is_empty():
		return section
	if section_name == "match":
		var flat_match := {}
		for key in DEFAULT_MATCH.keys():
			if preset.has(key):
				flat_match[key] = preset[key]
		return flat_match
	return {}


static func _map_spec_from_data(data: Dictionary) -> Resource:
	if data.is_empty():
		push_error("MapDefinition: map spec data is empty.")
		return null
	var spec = MapSpecScript.new()
	spec.metadata = _dictionary(data.get("metadata", {}))
	for poi in _array(data.get("pois", [])):
		if typeof(poi) == TYPE_DICTIONARY:
			spec.pois.append(poi.duplicate(true))
	for obstacle in _array(data.get("obstacles", [])):
		if typeof(obstacle) == TYPE_DICTIONARY:
			spec.obstacles.append(obstacle.duplicate(true))
	for surface_zone in _array(data.get("surface_zones", [])):
		if typeof(surface_zone) == TYPE_DICTIONARY:
			spec.surface_zones.append(surface_zone.duplicate(true))
	for route in _array(data.get("routes", [])):
		if typeof(route) == TYPE_DICTIONARY:
			spec.routes.append(route.duplicate(true))
	return spec


static func _surface_zone_contains(zone: Dictionary, world_pos: Vector2) -> bool:
	var shape := String(zone.get("shape", "rect"))
	if shape == "path":
		var points: Array = zone.get("points_2d", [])
		return _route_distance(world_pos, points) <= float(zone.get("width", 0.0)) * 0.5

	var center: Vector2 = zone.get("pos_2d", Vector2.ZERO)
	var size: Vector2 = zone.get("size_2d", Vector2.ZERO)
	var local := (world_pos - center).rotated(-deg_to_rad(float(zone.get("rot", 0.0))))
	if shape == "ellipse":
		var radii := size * 0.5
		if radii.x <= 0.0 or radii.y <= 0.0:
			return false
		var normalized := Vector2(local.x / radii.x, local.y / radii.y)
		return normalized.length_squared() <= 1.0
	return absf(local.x) <= size.x * 0.5 and absf(local.y) <= size.y * 0.5


static func _merge_dict(target: Dictionary, source: Dictionary) -> Dictionary:
	if typeof(source) != TYPE_DICTIONARY:
		return target
	for key in source.keys():
		var incoming = source[key]
		var current = target.get(key)
		if typeof(current) == TYPE_DICTIONARY and typeof(incoming) == TYPE_DICTIONARY:
			target[key] = _merge_dict(current.duplicate(true), incoming)
		else:
			target[key] = incoming
	return target


static func _dictionary(value) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value.duplicate(true)
	return {}


static func _array(value) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return value.duplicate(true)
	return []


static func _vector2_from_array(value, fallback: Vector2) -> Vector2:
	if typeof(value) != TYPE_ARRAY or value.size() < 2:
		return fallback
	return Vector2(float(value[0]), float(value[1]))


static func _vector3_from_array(value, fallback: Vector3) -> Vector3:
	if typeof(value) != TYPE_ARRAY or value.size() < 3:
		return fallback
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


static func _obstacle_axis_extent(obstacle: Dictionary, scale: Vector3) -> Vector2:
	var obs_type := String(obstacle.get("type", ""))
	var half_extents := Vector2(scale.x, scale.z)
	match obs_type:
		"bush_patch":
			half_extents = Vector2(scale.x * 1.5, scale.z * 1.5)
		"rock_cluster":
			var rock_radius := maxf(scale.x, scale.z) * 1.6
			half_extents = Vector2(rock_radius, rock_radius)
	var rot := deg_to_rad(float(obstacle.get("rot", 0.0)))
	var c := absf(cos(rot))
	var s := absf(sin(rot))
	return Vector2(
		c * half_extents.x + s * half_extents.y,
		s * half_extents.x + c * half_extents.y
	)


static func _route_distance(point: Vector2, points: Array) -> float:
	if points.size() < 2:
		return INF
	var best := INF
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		if not a.is_finite() or not b.is_finite():
			continue
		best = minf(best, _distance_to_segment(point, a, b))
	return best


static func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var length_sq := ab.length_squared()
	if length_sq <= 0.0001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / length_sq, 0.0, 1.0)
	return point.distance_to(a + ab * t)


func _loot_hotspot_count() -> int:
	var count := 0
	for poi in map_spec.pois:
		if float(poi.get("item_density", 0.0)) > 0.0:
			count += 1
	return count


func _loot_density_total() -> float:
	var total := 0.0
	for poi in map_spec.pois:
		total += maxf(0.0, float(poi.get("item_density", 0.0)))
	return total


func _validate_zone_sanity(issues: Array[String], game_config, preset_name: String, half_size: float) -> void:
	var zone_tuning := get_zone_tuning(game_config, {}, preset_name)
	var initial_radius := float(zone_tuning.get("initial_radius", IMPLICIT_INITIAL_ZONE_RADIUS))
	var next_radius := float(zone_tuning.get("next_radius", initial_radius * IMPLICIT_NEXT_ZONE_RADIUS_MULT))
	if initial_radius <= 0.0:
		issues.append("zone.initial_radius must be positive.")
	elif initial_radius > half_size:
		issues.append("zone.initial_radius %.1f exceeds world half-size %.1f." % [initial_radius, half_size])
	if next_radius <= 0.0:
		issues.append("zone.next_radius must be positive.")
	elif next_radius >= initial_radius:
		issues.append("zone.next_radius %.1f must be smaller than initial_radius %.1f." % [next_radius, initial_radius])
	for key in ["wait_time", "shrink_time", "initial_timer"]:
		if float(zone_tuning.get(key, 0.0)) <= 0.0:
			issues.append("zone.%s must be positive." % key)
	if float(zone_tuning.get("damage_per_second", 0.0)) < 0.0:
		issues.append("zone.damage_per_second must be non-negative.")
	var stages := _dictionary(zone_tuning.get("stages", {}))
	for stage_key in stages.keys():
		var stage := _dictionary(stages[stage_key])
		if stage.is_empty():
			issues.append("zone.stages.%s must be a Dictionary." % String(stage_key))
			continue
		for key in ["wait_time", "shrink_time"]:
			if stage.has(key) and float(stage.get(key, 0.0)) <= 0.0:
				issues.append("zone.stages.%s.%s must be positive." % [String(stage_key), key])
		if stage.has("damage_per_second") and float(stage.get("damage_per_second", 0.0)) < 0.0:
			issues.append("zone.stages.%s.damage_per_second must be non-negative." % String(stage_key))


func _validate_scale_envelopes(issues: Array[String]) -> void:
	for envelope_key in scale_envelopes.keys():
		var envelope_name := String(envelope_key)
		var envelope := _dictionary(scale_envelopes[envelope_key])
		if envelope.is_empty():
			issues.append("scale_envelopes.%s must be a Dictionary." % envelope_name)
			continue
		var bot_count := int(envelope.get("bot_count", -1))
		var total_entities := int(envelope.get("total_entities", bot_count + 1))
		if bot_count < 0:
			issues.append("scale_envelopes.%s.bot_count must be non-negative." % envelope_name)
		if total_entities <= 0:
			issues.append("scale_envelopes.%s.total_entities must be positive." % envelope_name)
		elif bot_count >= 0 and total_entities < bot_count + 1:
			issues.append("scale_envelopes.%s.total_entities must include player + bots." % envelope_name)
		for field in ["world_size_min", "spawn_radius_min", "inner_radius", "entity_clearance"]:
			if envelope.has(field) and float(envelope.get(field, 0.0)) <= 0.0:
				issues.append("scale_envelopes.%s.%s must be positive." % [envelope_name, field])
		if envelope.has("world_size_preferred") and float(envelope.get("world_size_preferred", 0.0)) < float(envelope.get("world_size_min", 0.0)):
			issues.append("scale_envelopes.%s.world_size_preferred must be >= world_size_min." % envelope_name)
		if envelope.has("spawn_radius_preferred") and float(envelope.get("spawn_radius_preferred", 0.0)) < float(envelope.get("spawn_radius_min", 0.0)):
			issues.append("scale_envelopes.%s.spawn_radius_preferred must be >= spawn_radius_min." % envelope_name)
		if envelope.has("boundary_margin_min") and float(envelope.get("boundary_margin_min", 0.0)) < 0.0:
			issues.append("scale_envelopes.%s.boundary_margin_min must be non-negative." % envelope_name)
		for field in ["max_annulus_saturation", "preferred_annulus_saturation"]:
			if envelope.has(field) and float(envelope.get(field, 0.0)) <= 0.0:
				issues.append("scale_envelopes.%s.%s must be positive." % [envelope_name, field])


static func _slug(value: String) -> String:
	var result := ""
	var lower := value.to_lower()
	for i in range(lower.length()):
		var code := lower.unicode_at(i)
		if (code >= 97 and code <= 122) or (code >= 48 and code <= 57):
			result += lower.substr(i, 1)
		elif not result.ends_with("_"):
			result += "_"
	result = result.strip_edges()
	while result.ends_with("_"):
		result = result.substr(0, result.length() - 1)
	return "map" if result.is_empty() else result
