extends SceneTree


const PROBE_PATH := "res://data/mapSpec_poi_black_ridge_probe.json"
const PRESET := "poi_probe"

const REQUIRED_POI_ROLES := {
	"loot_hub": 1,
	"transit_choke": 2,
	"recovery_pocket": 1,
	"concealment_field": 2,
}

const REQUIRED_ROUTE_ROLES := {
	"primary_choke": 1,
	"flank": 2,
	"loot_flow": 1,
	"recovery_exit": 1,
}


func _init():
	var game_config_script = load("res://src/core/GameConfig.gd")
	var map_definition_script = load("res://src/core/MapDefinition.gd")

	var game_config = game_config_script.new()
	game_config.load_or_default()

	var definition = _load_definition(map_definition_script, game_config, PROBE_PATH)
	if definition == null:
		return
	if not definition.has_scale_preset(PRESET):
		_fail("Black Ridge probe is missing scale preset '%s'." % PRESET)
		return

	var issues: Array = definition.validate(game_config, PRESET)
	if not issues.is_empty():
		_fail("Black Ridge probe validation failed: %s" % _join_issues(issues))
		return

	var pois: Array[Dictionary] = definition.get_poi_descriptors()
	var routes: Array[Dictionary] = definition.get_route_descriptors()
	var obstacles: Array[Dictionary] = definition.get_obstacle_descriptors()
	if not _verify_poi_roles(pois):
		return
	if not _verify_routes(routes, pois):
		return
	if not _verify_obstacles(obstacles):
		return
	if not _verify_position_classification(definition):
		return
	if not _verify_probe_scale(definition, game_config):
		return

	print("Black Ridge POI probe smoke passed: pois=%d routes=%d obstacles=%d roles=%s route_roles=%s." % [
		pois.size(),
		routes.size(),
		obstacles.size(),
		str(_role_counts(pois)),
		str(_role_counts(routes)),
	])
	quit(0)


func _verify_poi_roles(pois: Array[Dictionary]) -> bool:
	var counts := _role_counts(pois)
	for role in REQUIRED_POI_ROLES.keys():
		var actual := int(counts.get(role, 0))
		var required := int(REQUIRED_POI_ROLES[role])
		if actual < required:
			_fail("Black Ridge probe needs at least %d POIs with role '%s'; got %d." % [required, role, actual])
			return false
	return true


func _verify_routes(routes: Array[Dictionary], pois: Array[Dictionary]) -> bool:
	var route_ids := {}
	for route in routes:
		var route_id := String(route.get("id", "")).strip_edges()
		if route_id.is_empty():
			_fail("Route has empty id.")
			return false
		route_ids[route_id] = true

	var counts := _role_counts(routes)
	for role in REQUIRED_ROUTE_ROLES.keys():
		var actual := int(counts.get(role, 0))
		var required := int(REQUIRED_ROUTE_ROLES[role])
		if actual < required:
			_fail("Black Ridge probe needs at least %d routes with role '%s'; got %d." % [required, role, actual])
			return false

	var poi_roles_by_name := {}
	for poi in pois:
		poi_roles_by_name[String(poi.get("name", ""))] = String(poi.get("role", ""))

	var direct_route_found := false
	for route in routes:
		var route_id := String(route.get("id", ""))
		var role := String(route.get("role", ""))
		var points: Array = route.get("points_2d", [])
		var width := float(route.get("width", 0.0))
		if points.size() < 2:
			_fail("Route %s did not expose at least 2 points_2d." % route_id)
			return false
		if width < 6.0:
			_fail("Route %s width is too narrow for POI probing: %.1f." % [route_id, width])
			return false

		if route_id == "ridge_direct_ascent":
			direct_route_found = true
			if role != "primary_choke":
				_fail("ridge_direct_ascent must be primary_choke, got %s." % role)
				return false
			if points.size() < 5:
				_fail("ridge_direct_ascent must be a multi-point route.")
				return false
			if width < 8.0 or width > 9.5:
				_fail("ridge_direct_ascent should stay readable but constrained; got width %.1f." % width)
				return false
			var alternate_id := String(route.get("alternate_route_id", "")).strip_edges()
			if alternate_id.is_empty() or not route_ids.has(alternate_id):
				_fail("ridge_direct_ascent needs a valid alternate_route_id.")
				return false

		var connects: Array = route.get("connects", [])
		if typeof(connects) != TYPE_ARRAY or connects.is_empty():
			_fail("Route %s needs connected POI names." % route_id)
			return false
		for poi_name in connects:
			if not poi_roles_by_name.has(String(poi_name)):
				_fail("Route %s connects unknown POI '%s'." % [route_id, String(poi_name)])
				return false

	if not direct_route_found:
		_fail("Black Ridge probe is missing ridge_direct_ascent.")
		return false
	return true


func _verify_obstacles(obstacles: Array[Dictionary]) -> bool:
	var high_ridge_count := 0
	var ridge_rock_count := 0
	for obstacle in obstacles:
		var obs_type := String(obstacle.get("type", ""))
		var scale: Vector3 = obstacle.get("scale_3d", Vector3.ONE)
		if obs_type == "canyon_wall" and scale.y >= 3.0:
			high_ridge_count += 1
		if obs_type == "rock_cluster" and scale.x >= 2.0:
			ridge_rock_count += 1
	if high_ridge_count < 3:
		_fail("Black Ridge probe needs at least three ridge wall segments.")
		return false
	if high_ridge_count > 5:
		_fail("Black Ridge probe has too many high wall segments for a contestable power position.")
		return false
	if ridge_rock_count < 2:
		_fail("Black Ridge probe needs at least two rock cover clusters.")
		return false
	if ridge_rock_count > 4:
		_fail("Black Ridge probe has too many large rock clusters for first-pass fortress risk.")
		return false
	return true


func _verify_position_classification(definition) -> bool:
	var crown: Dictionary = definition.describe_strategic_position(Vector2(0.0, 6.0))
	if String(crown.get("poi_name", "")) != "Black Ridge":
		_fail("Ridge crown should classify as Black Ridge, got %s." % crown.get("poi_name", ""))
		return false
	if String(crown.get("route_id", "")) != "ridge_direct_ascent":
		_fail("Ridge crown should classify on ridge_direct_ascent, got %s." % crown.get("route_id", ""))
		return false
	if String(crown.get("route_role", "")) != "primary_choke":
		_fail("Ridge crown should classify as primary_choke, got %s." % crown.get("route_role", ""))
		return false

	var north: Dictionary = definition.describe_strategic_position(Vector2(-10.0, 26.0))
	if String(north.get("poi_name", "")) != "North Pine Cover":
		_fail("North approach should classify as North Pine Cover, got %s." % north.get("poi_name", ""))
		return false
	if String(north.get("route_role", "")) != "flank":
		_fail("North approach should classify as flank, got %s." % north.get("route_role", ""))
		return false

	var south: Dictionary = definition.describe_strategic_position(Vector2(22.0, -12.0))
	if String(south.get("poi_name", "")) != "South Gully Brush":
		_fail("South approach should classify as South Gully Brush, got %s." % south.get("poi_name", ""))
		return false
	if String(south.get("route_role", "")) != "flank":
		_fail("South approach should classify as flank, got %s." % south.get("route_role", ""))
		return false

	var hollow: Dictionary = definition.describe_strategic_position(Vector2(8.0, -26.0))
	if String(hollow.get("poi_name", "")) != "Field Aid Hollow":
		_fail("Hollow point should classify as Field Aid Hollow, got %s." % hollow.get("poi_name", ""))
		return false
	if String(hollow.get("poi_role", "")) != "recovery_pocket":
		_fail("Hollow point should classify as recovery_pocket, got %s." % hollow.get("poi_role", ""))
		return false

	var reentry: Dictionary = definition.describe_strategic_position(Vector2(10.0, -14.0))
	if String(reentry.get("route_role", "")) != "recovery_exit":
		_fail("Hollow reentry segment should classify as recovery_exit, got %s." % reentry.get("route_role", ""))
		return false
	return true


func _verify_probe_scale(definition, game_config) -> bool:
	var summary: Dictionary = definition.summary(game_config, PRESET)
	var match_tuning: Dictionary = definition.get_match_tuning(game_config, {}, PRESET)
	var runtime_tuning: Dictionary = definition.get_runtime_tuning(game_config, {}, PRESET)
	var spawn := _dictionary(runtime_tuning.get("spawn", {}))
	var world_size := float(summary.get("world_size", 0.0))
	var spawn_radius := float(match_tuning.get("spawn_radius", 0.0))
	var clearance := float(spawn.get("entity_clearance", 3.5))
	if world_size > 82.0:
		_fail("POI probe world should stay compact; got %.1fm." % world_size)
		return false
	if int(match_tuning.get("bot_count", 0)) > 12:
		_fail("POI probe should keep bot_count <= 12.")
		return false
	if spawn_radius + clearance > world_size * 0.5:
		_fail("POI probe spawn radius exceeds boundary margin.")
		return false
	return true


func _role_counts(descriptors: Array[Dictionary]) -> Dictionary:
	var counts := {}
	for descriptor in descriptors:
		var role := String(descriptor.get("role", ""))
		counts[role] = int(counts.get(role, 0)) + 1
	return counts


func _load_definition(map_definition_script, game_config, path: String):
	var json_text := _read_text(path)
	if json_text.is_empty():
		return null
	var definition = map_definition_script.new()
	if not definition.load_from_json(json_text, path, game_config):
		_fail("Could not load MapDefinition from %s." % path)
		return null
	return definition


func _read_text(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("Could not open %s." % path)
		return ""
	return file.get_as_text()


func _join_issues(issues: Array) -> String:
	var parts: Array[String] = []
	for issue in issues:
		parts.append(String(issue))
	return "; ".join(parts)


func _dictionary(value) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
