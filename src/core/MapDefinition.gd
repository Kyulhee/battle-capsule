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

@export var id: String = ""
@export var display_name: String = ""
@export var source_path: String = ""
@export var map_spec: Resource = null
@export var match_overrides: Dictionary = {}
@export var runtime_overrides: Dictionary = {}
@export var zone_overrides: Dictionary = {}
@export var scale_presets: Dictionary = {}


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
	return true


func load_from_map_spec(spec: Resource, source_path_value: String = "") -> bool:
	source_path = source_path_value
	map_spec = spec
	match_overrides.clear()
	runtime_overrides.clear()
	zone_overrides.clear()
	scale_presets.clear()
	if spec != null:
		display_name = String(spec.metadata.get("name", "Untitled Map"))
		id = String(spec.metadata.get("id", _slug(display_name)))
	return spec != null


func get_world_size() -> float:
	if map_spec == null or not map_spec.has_method("get_world_size"):
		return 0.0
	return float(map_spec.get_world_size())


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
		var extent := _obstacle_axis_extent(obstacle, scale)
		var jitter := _vector2_from_array(obstacle.get("jitter", [0.0, 0.0]), Vector2.ZERO)
		extent += Vector2(absf(jitter.x), absf(jitter.y))
		if absf(pos.x) + extent.x > half_size or absf(pos.y) + extent.y > half_size:
			issues.append("Obstacle %d extends outside world bounds." % i)

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
	if inner_radius < 0.0:
		issues.append("runtime.spawn.inner_radius must be non-negative.")
	elif spawn_radius < inner_radius:
		issues.append("spawn_radius %.1f is smaller than runtime.spawn.inner_radius %.1f." % [spawn_radius, inner_radius])
	if spawn_radius + maxf(0.0, entity_clearance) > half_size:
		issues.append("spawn_radius %.1f plus entity_clearance %.1f exceeds world half-size %.1f." % [spawn_radius, entity_clearance, half_size])

	var loot_count := int(match_tuning.get("loot_count", 0))
	if loot_count > 0 and _loot_hotspot_count() <= 0:
		issues.append("loot_count is positive but map has no loot-capable POIs.")
	elif loot_count > 0 and _loot_density_total() <= 0.0:
		issues.append("loot_count is positive but total loot density is zero.")

	_validate_zone_sanity(issues, game_config, preset_name, half_size)

	return issues


func summary(game_config = null, preset_name: String = "") -> Dictionary:
	var match_tuning := get_match_tuning(game_config, {}, preset_name)
	var zone_tuning := get_zone_tuning(game_config, {}, preset_name)
	return {
		"id": id,
		"display_name": display_name,
		"scale_preset": preset_name,
		"source_path": source_path,
		"world_size": get_world_size(),
		"poi_count": map_spec.pois.size() if map_spec != null else 0,
		"obstacle_count": map_spec.obstacles.size() if map_spec != null else 0,
		"route_count": map_spec.routes.size() if map_spec != null else 0,
		"bot_count": int(match_tuning.get("bot_count", 0)),
		"loot_count": int(match_tuning.get("loot_count", 0)),
		"spawn_radius": float(match_tuning.get("spawn_radius", 0.0)),
		"loot_hotspot_count": _loot_hotspot_count() if map_spec != null else 0,
		"zone_wait_time": float(zone_tuning.get("wait_time", 0.0)),
		"zone_shrink_time": float(zone_tuning.get("shrink_time", 0.0)),
		"zone_initial_radius": float(zone_tuning.get("initial_radius", IMPLICIT_INITIAL_ZONE_RADIUS)),
		"zone_stage_count": _dictionary(zone_tuning.get("stages", {})).size(),
		"scale_preset_count": scale_presets.size(),
	}


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
	for route in _array(data.get("routes", [])):
		if typeof(route) == TYPE_DICTIONARY:
			spec.routes.append(route.duplicate(true))
	return spec


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
