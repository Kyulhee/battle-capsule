extends SceneTree


const PROBE_PATH := "res://data/mapSpec_poi_false_clinic_probe.json"
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
		_fail("False Clinic probe is missing scale preset '%s'." % PRESET)
		return

	var issues: Array = definition.validate(game_config, PRESET)
	if not issues.is_empty():
		_fail("False Clinic probe validation failed: %s" % _join_issues(issues))
		return

	var pois: Array[Dictionary] = definition.get_poi_descriptors()
	var routes: Array[Dictionary] = definition.get_route_descriptors()
	var obstacles: Array[Dictionary] = definition.get_obstacle_descriptors()
	if not _verify_poi_roles(pois):
		return
	if not _verify_recovery_pocket_limits(pois):
		return
	if not _verify_routes(routes, pois):
		return
	if not _verify_obstacles(obstacles):
		return
	if not _verify_position_classification(definition):
		return
	if not _verify_probe_scale(definition, game_config):
		return

	print("False Clinic POI probe smoke passed: pois=%d routes=%d obstacles=%d roles=%s route_roles=%s." % [
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
			_fail("False Clinic probe needs at least %d POIs with role '%s'; got %d." % [required, role, actual])
			return false
	return true


func _verify_recovery_pocket_limits(pois: Array[Dictionary]) -> bool:
	for poi in pois:
		if String(poi.get("name", "")) != "False Clinic":
			continue
		if String(poi.get("role", "")) != "recovery_pocket":
			_fail("False Clinic must be a recovery_pocket.")
			return false
		if float(poi.get("item_density", 1.0)) > 0.50:
			_fail("False Clinic item_density is too high for a recovery pocket.")
			return false
		if float(poi.get("rare_bias", 1.0)) > 0.12:
			_fail("False Clinic rare_bias is too high for a recovery pocket.")
			return false
		return true
	_fail("False Clinic POI is missing.")
	return false


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
			_fail("False Clinic probe needs at least %d routes with role '%s'; got %d." % [required, role, actual])
			return false

	var poi_roles_by_name := {}
	for poi in pois:
		poi_roles_by_name[String(poi.get("name", ""))] = String(poi.get("role", ""))

	var front_route_found := false
	var reentry_found := false
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

		if route_id == "clinic_front_lane":
			front_route_found = true
			if role != "primary_choke":
				_fail("clinic_front_lane must be primary_choke, got %s." % role)
				return false
			if points.size() < 5:
				_fail("clinic_front_lane must be a multi-point route.")
				return false
			if width < 8.0 or width > 9.5:
				_fail("clinic_front_lane should stay readable but constrained; got width %.1f." % width)
				return false
			var alternate_id := String(route.get("alternate_route_id", "")).strip_edges()
			if alternate_id.is_empty() or not route_ids.has(alternate_id):
				_fail("clinic_front_lane needs a valid alternate_route_id.")
				return false

		if route_id == "clinic_reentry":
			reentry_found = true
			if role != "recovery_exit":
				_fail("clinic_reentry must be recovery_exit, got %s." % role)
				return false
			var connects: Array = route.get("connects", [])
			if not connects.has("False Clinic") or not connects.has("Clinic Doorway"):
				_fail("clinic_reentry must connect False Clinic back to Clinic Doorway.")
				return false

		var connects_any: Array = route.get("connects", [])
		if typeof(connects_any) != TYPE_ARRAY or connects_any.is_empty():
			_fail("Route %s needs connected POI names." % route_id)
			return false
		for poi_name in connects_any:
			if not poi_roles_by_name.has(String(poi_name)):
				_fail("Route %s connects unknown POI '%s'." % [route_id, String(poi_name)])
				return false

	if not front_route_found:
		_fail("False Clinic probe is missing clinic_front_lane.")
		return false
	if not reentry_found:
		_fail("False Clinic probe is missing clinic_reentry.")
		return false
	return true


func _verify_obstacles(obstacles: Array[Dictionary]) -> bool:
	var facade_wall_count := 0
	var soft_cover_count := 0
	for obstacle in obstacles:
		var obs_type := String(obstacle.get("type", ""))
		var scale: Vector3 = obstacle.get("scale_3d", Vector3.ONE)
		if obs_type == "canyon_wall" and scale.y >= 3.0:
			facade_wall_count += 1
		if obs_type == "log_pile" or obs_type == "bush_patch":
			soft_cover_count += 1
	if facade_wall_count < 2:
		_fail("False Clinic probe needs at least two facade wall segments.")
		return false
	if facade_wall_count > 4:
		_fail("False Clinic probe has too many hard wall segments for first-pass re-entry risk.")
		return false
	if soft_cover_count < 5:
		_fail("False Clinic probe needs enough soft cover around the pocket and exits.")
		return false
	return true


func _verify_position_classification(definition) -> bool:
	var doorway: Dictionary = definition.describe_strategic_position(Vector2.ZERO)
	if String(doorway.get("poi_name", "")) != "Clinic Doorway":
		_fail("Center should classify as Clinic Doorway, got %s." % doorway.get("poi_name", ""))
		return false
	if String(doorway.get("route_id", "")) != "clinic_front_lane":
		_fail("Center should classify on clinic_front_lane, got %s." % doorway.get("route_id", ""))
		return false
	if String(doorway.get("route_role", "")) != "primary_choke":
		_fail("Center should classify as primary_choke, got %s." % doorway.get("route_role", ""))
		return false

	var north: Dictionary = definition.describe_strategic_position(Vector2(-10.0, 24.0))
	if String(north.get("poi_name", "")) != "North Privacy Hedge":
		_fail("North flank should classify as North Privacy Hedge, got %s." % north.get("poi_name", ""))
		return false
	if String(north.get("route_role", "")) != "flank":
		_fail("North flank should classify as flank, got %s." % north.get("route_role", ""))
		return false

	var south: Dictionary = definition.describe_strategic_position(Vector2(22.0, -12.0))
	if String(south.get("poi_name", "")) != "South Curtain Brush":
		_fail("South flank should classify as South Curtain Brush, got %s." % south.get("poi_name", ""))
		return false
	if String(south.get("route_role", "")) != "flank":
		_fail("South flank should classify as flank, got %s." % south.get("route_role", ""))
		return false

	var clinic: Dictionary = definition.describe_strategic_position(Vector2(8.0, -24.0))
	if String(clinic.get("poi_name", "")) != "False Clinic":
		_fail("Clinic point should classify as False Clinic, got %s." % clinic.get("poi_name", ""))
		return false
	if String(clinic.get("poi_role", "")) != "recovery_pocket":
		_fail("Clinic point should classify as recovery_pocket, got %s." % clinic.get("poi_role", ""))
		return false

	var reentry: Dictionary = definition.describe_strategic_position(Vector2(10.0, -12.0))
	if String(reentry.get("route_role", "")) != "recovery_exit":
		_fail("Clinic reentry segment should classify as recovery_exit, got %s." % reentry.get("route_role", ""))
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
	if world_size > 80.0:
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
