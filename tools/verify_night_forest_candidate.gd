extends SceneTree


const DEFAULT_PATH := "res://data/mapSpec_example.json"
const CANDIDATE_PATH := "res://data/mapSpec_night_forest_candidate.json"
const PROBE_PRESET := "target_99_probe"
const TARGET_ENVELOPE := "target_99"

const REQUIRED_POI_ROLES := {
	"loot_hub": 3,
	"transit_choke": 4,
	"recovery_pocket": 2,
	"concealment_field": 4,
}

const REQUIRED_ROUTE_ROLES := {
	"primary_choke": 2,
	"flank": 2,
	"loot_flow": 1,
	"recovery_exit": 1,
}


func _init():
	var game_config_script = load("res://src/core/GameConfig.gd")
	var map_definition_script = load("res://src/core/MapDefinition.gd")
	var runtime_tuning_script = load("res://src/systems/match/MatchRuntimeTuning.gd")

	var game_config = game_config_script.new()
	game_config.load_or_default()

	var default_definition = _load_definition(map_definition_script, game_config, DEFAULT_PATH)
	if default_definition == null:
		return
	if default_definition.has_scale_preset(PROBE_PRESET):
		_fail("%s must not be available on the default map." % PROBE_PRESET)
		return

	var candidate = _load_definition(map_definition_script, game_config, CANDIDATE_PATH)
	if candidate == null:
		return
	if not candidate.has_scale_preset(PROBE_PRESET):
		_fail("Night candidate map is missing %s." % PROBE_PRESET)
		return
	if candidate.has_scale_preset(TARGET_ENVELOPE):
		_fail("%s must remain an envelope, not a runtime preset." % TARGET_ENVELOPE)
		return
	if not candidate.has_scale_envelope(TARGET_ENVELOPE):
		_fail("Night candidate map is missing %s envelope." % TARGET_ENVELOPE)
		return

	var issues: Array = candidate.validate(game_config, PROBE_PRESET)
	if not issues.is_empty():
		_fail("Night forest candidate validation failed: %s" % _join_issues(issues))
		return

	var pois: Array[Dictionary] = candidate.get_poi_descriptors()
	var routes: Array[Dictionary] = candidate.get_route_descriptors()
	if not _verify_poi_roles(pois):
		return
	if not _verify_routes(routes, pois):
		return
	if not _verify_position_classification(candidate):
		return

	var summary: Dictionary = candidate.summary(game_config, PROBE_PRESET)
	var match_tuning: Dictionary = candidate.get_match_tuning(game_config, {}, PROBE_PRESET)
	var runtime_tuning: Dictionary = candidate.get_runtime_tuning(game_config, {}, PROBE_PRESET)
	var spawn_tuning: Dictionary = runtime_tuning_script.spawn(runtime_tuning)
	var loot_tuning: Dictionary = runtime_tuning_script.loot(runtime_tuning)
	var envelope: Dictionary = candidate.get_scale_envelope(TARGET_ENVELOPE)
	if not _verify_probe(summary, match_tuning, spawn_tuning, loot_tuning, envelope):
		return

	print("Night forest candidate smoke passed: pois=%d routes=%d bots=%d loot=%d roles=%s route_roles=%s." % [
		pois.size(),
		routes.size(),
		int(match_tuning.get("bot_count", 0)),
		int(match_tuning.get("loot_count", 0)),
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
			_fail("Night candidate needs at least %d POIs with role '%s'; got %d." % [required, role, actual])
			return false
	return true


func _verify_routes(routes: Array[Dictionary], pois: Array[Dictionary]) -> bool:
	if routes.size() < 6:
		_fail("Night candidate needs at least 6 strategic routes; got %d." % routes.size())
		return false

	var route_ids := {}
	for route in routes:
		var route_id := String(route.get("id", "")).strip_edges()
		if route_id.is_empty():
			_fail("Strategic route has empty id.")
			return false
		route_ids[route_id] = true

	var counts := _role_counts(routes)
	for role in REQUIRED_ROUTE_ROLES.keys():
		var actual := int(counts.get(role, 0))
		var required := int(REQUIRED_ROUTE_ROLES[role])
		if actual < required:
			_fail("Night candidate needs at least %d routes with role '%s'; got %d." % [required, role, actual])
			return false

	var poi_roles_by_name := {}
	for poi in pois:
		poi_roles_by_name[String(poi.get("name", ""))] = String(poi.get("role", ""))

	var touched_poi_roles := {}
	for route in routes:
		var points: Array = route.get("points_2d", [])
		if points.size() < 2:
			_fail("Route %s did not expose at least 2 points_2d." % route.get("id", ""))
			return false
		if float(route.get("width", 0.0)) < 8.0:
			_fail("Route %s width is too narrow for strategic flow: %.1f." % [route.get("id", ""), float(route.get("width", 0.0))])
			return false
		var role := String(route.get("role", ""))
		if role == "primary_choke":
			if points.size() < 5:
				_fail("Primary choke %s should expose a multi-point gate path; got %d points." % [route.get("id", ""), points.size()])
				return false
			var alternate_id := String(route.get("alternate_route_id", "")).strip_edges()
			if alternate_id.is_empty() or not route_ids.has(alternate_id):
				_fail("Primary choke %s needs a valid alternate_route_id." % route.get("id", ""))
				return false
			if float(route.get("width", 0.0)) > 13.5:
				_fail("Primary choke %s should stay narrow enough to preserve crossing pressure." % route.get("id", ""))
				return false

		var connects: Array = route.get("connects", [])
		if typeof(connects) != TYPE_ARRAY or connects.is_empty():
			_fail("Route %s needs connected POI names." % route.get("id", ""))
			return false
		for poi_name in connects:
			var poi_role := String(poi_roles_by_name.get(String(poi_name), ""))
			if poi_role.is_empty():
				_fail("Route %s connects unknown POI '%s'." % [route.get("id", ""), String(poi_name)])
				return false
			touched_poi_roles[poi_role] = true

	for required_role in REQUIRED_POI_ROLES.keys():
		if not touched_poi_roles.has(required_role):
			_fail("Strategic routes do not touch POI role '%s'." % String(required_role))
			return false
	return true


func _verify_position_classification(definition) -> bool:
	var sluice: Dictionary = definition.describe_strategic_position(Vector2(4.0, -4.0))
	if String(sluice.get("poi_name", "")) != "Sluice Crossing":
		_fail("Sluice point should classify as Sluice Crossing, got %s." % sluice.get("poi_name", ""))
		return false
	if String(sluice.get("route_role", "")) != "primary_choke":
		_fail("Sluice point should classify as primary_choke route, got %s." % sluice.get("route_role", ""))
		return false

	var black_ridge: Dictionary = definition.describe_strategic_position(Vector2(-20.0, 20.0))
	if String(black_ridge.get("poi_name", "")) != "Black Ridge":
		_fail("Black Ridge point should classify as Black Ridge, got %s." % black_ridge.get("poi_name", ""))
		return false
	if String(black_ridge.get("route_role", "")) != "primary_choke":
		_fail("Black Ridge point should classify as primary_choke route, got %s." % black_ridge.get("route_role", ""))
		return false

	var wire: Dictionary = definition.describe_strategic_position(Vector2(48.0, 22.0))
	if String(wire.get("poi_name", "")) != "Wire Maze":
		_fail("Wire point should classify as Wire Maze, got %s." % wire.get("poi_name", ""))
		return false
	if String(wire.get("route_role", "")) != "primary_choke":
		_fail("Wire point should classify as primary_choke route, got %s." % wire.get("route_role", ""))
		return false

	var clinic: Dictionary = definition.describe_strategic_position(Vector2(58.0, -42.0))
	if String(clinic.get("poi_name", "")) != "False Clinic":
		_fail("Clinic point should classify as False Clinic, got %s." % clinic.get("poi_name", ""))
		return false
	if String(clinic.get("poi_role", "")) != "recovery_pocket":
		_fail("Clinic point should classify as recovery_pocket, got %s." % clinic.get("poi_role", ""))
		return false
	return true


func _verify_probe(summary: Dictionary, match_tuning: Dictionary, spawn_tuning: Dictionary, loot_tuning: Dictionary, envelope: Dictionary) -> bool:
	var bot_count := int(match_tuning.get("bot_count", 0))
	var total_entities := bot_count + 1
	var world_size := float(summary.get("world_size", 0.0))
	var spawn_radius := float(match_tuning.get("spawn_radius", 0.0))
	var inner_radius := float(spawn_tuning.get("inner_radius", 0.0))
	var clearance := float(spawn_tuning.get("entity_clearance", 0.0))
	var boundary_margin := world_size * 0.5 - spawn_radius - clearance
	var saturation := _annulus_saturation(total_entities, clearance, spawn_radius, inner_radius)
	if bot_count != int(envelope.get("bot_count", 0)):
		_fail("%s must target the %s bot count." % [PROBE_PRESET, TARGET_ENVELOPE])
		return false
	if int(match_tuning.get("loot_count", 0)) < 220:
		_fail("%s loot_count is below probe floor." % PROBE_PRESET)
		return false
	if float(loot_tuning.get("rare_bias_mult", 1.0)) < 1.2:
		_fail("%s rare_bias_mult is below economy-tempo probe floor." % PROBE_PRESET)
		return false
	if float(loot_tuning.get("hotspot_density_mult", 1.0)) < 1.10:
		_fail("%s hotspot_density_mult is below economy-tempo probe floor." % PROBE_PRESET)
		return false
	if world_size < float(envelope.get("world_size_preferred", 0.0)):
		_fail("%s world size is below preferred envelope." % PROBE_PRESET)
		return false
	if spawn_radius < float(envelope.get("spawn_radius_preferred", 0.0)):
		_fail("%s spawn radius is below preferred envelope." % PROBE_PRESET)
		return false
	if int(spawn_tuning.get("safe_spawn_attempts", 0)) < 160:
		_fail("%s safe_spawn_attempts must be at least 160." % PROBE_PRESET)
		return false
	if boundary_margin < float(envelope.get("boundary_margin_min", 0.0)):
		_fail("%s boundary margin %.1f is below envelope floor." % [PROBE_PRESET, boundary_margin])
		return false
	if saturation > float(envelope.get("preferred_annulus_saturation", 0.0)):
		_fail("%s saturation %.3f exceeds preferred envelope." % [PROBE_PRESET, saturation])
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


func _annulus_saturation(total_entities: int, clearance: float, spawn_radius: float, inner_radius: float) -> float:
	var annulus := maxf(1.0, spawn_radius * spawn_radius - inner_radius * inner_radius)
	return float(total_entities) * clearance * clearance / annulus


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


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
