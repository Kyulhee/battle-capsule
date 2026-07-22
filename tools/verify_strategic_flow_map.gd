extends SceneTree


const CANDIDATE_PATH := "res://data/mapSpec_night_forest_expanded_candidate.json"
const PRESET := "target_99_probe"

const REQUIRED_POI_ROLES := {
	"loot_hub": 3,
	"transit_choke": 4,
	"recovery_pocket": 2,
	"concealment_field": 2,
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

	var game_config = game_config_script.new()
	game_config.load_or_default()

	var json_text := _read_text(CANDIDATE_PATH)
	if json_text.is_empty():
		return

	var definition = map_definition_script.new()
	if not definition.load_from_json(json_text, CANDIDATE_PATH, game_config):
		_fail("MapDefinition could not load %s." % CANDIDATE_PATH)
		return
	var issues: Array = definition.validate(game_config, PRESET)
	if not issues.is_empty():
		_fail("Strategic flow map validation failed: %s" % _join_issues(issues))
		return

	var pois: Array[Dictionary] = definition.get_poi_descriptors()
	var routes: Array[Dictionary] = definition.get_route_descriptors()
	if not _verify_poi_roles(pois):
		return
	if not _verify_routes(routes, pois):
		return
	if not _verify_position_classification(definition):
		return

	print("Strategic flow map smoke passed: pois=%d routes=%d roles=%s route_roles=%s." % [
		pois.size(),
		routes.size(),
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
			_fail("Candidate needs at least %d POIs with role '%s'; got %d." % [required, role, actual])
			return false
	return true


func _verify_routes(routes: Array[Dictionary], pois: Array[Dictionary]) -> bool:
	if routes.size() < 6:
		_fail("Candidate needs at least 6 strategic routes; got %d." % routes.size())
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
			_fail("Candidate needs at least %d routes with role '%s'; got %d." % [required, role, actual])
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
		if String(route.get("id", "")) == "central_meadow_cross" and float(route.get("width", 0.0)) > 16.0:
			_fail("Central meadow route should not be wide enough to absorb side-gate pressure.")
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
	var west_choke: Dictionary = definition.describe_strategic_position(Vector2(-104.0, -16.0))
	if String(west_choke.get("poi_role", "")) != "transit_choke":
		_fail("West ridge choke should classify as transit_choke POI, got %s." % west_choke.get("poi_role", ""))
		return false
	if String(west_choke.get("route_role", "")) != "primary_choke":
		_fail("West ridge choke should classify as primary_choke route, got %s." % west_choke.get("route_role", ""))
		return false

	var west_gate: Dictionary = definition.describe_strategic_position(Vector2(-54.0, 28.0))
	if String(west_gate.get("poi_name", "")) != "West Ridge Watch Post":
		_fail("West pressure gate should classify as West Ridge Watch Post, got %s." % west_gate.get("poi_name", ""))
		return false
	if String(west_gate.get("route_role", "")) != "primary_choke":
		_fail("West pressure gate should classify as primary_choke route, got %s." % west_gate.get("route_role", ""))
		return false

	var east_gate: Dictionary = definition.describe_strategic_position(Vector2(66.0, -10.0))
	if String(east_gate.get("poi_name", "")) != "East Pine Gate":
		_fail("East pressure gate should classify as East Pine Gate, got %s." % east_gate.get("poi_name", ""))
		return false
	if String(east_gate.get("route_role", "")) != "primary_choke":
		_fail("East pressure gate should classify as primary_choke route, got %s." % east_gate.get("route_role", ""))
		return false

	var central: Dictionary = definition.describe_strategic_position(Vector2.ZERO)
	if String(central.get("poi_role", "")) != "loot_hub":
		_fail("Central meadow should classify as loot_hub POI, got %s." % central.get("poi_role", ""))
		return false
	if String(central.get("route_role", "")) != "loot_flow":
		_fail("Central meadow should classify as loot_flow route, got %s." % central.get("route_role", ""))
		return false

	var south_ford: Dictionary = definition.describe_strategic_position(Vector2(20.0, -98.0))
	if String(south_ford.get("poi_name", "")) != "South Creek Bend":
		_fail("Logging Ford should classify as South Creek Bend, got %s." % south_ford.get("poi_name", ""))
		return false
	if String(south_ford.get("route_id", "")) != "south_creek_ford_choke" \
			or String(south_ford.get("route_role", "")) != "primary_choke":
		_fail("Logging Ford objective should classify as its primary choke.")
		return false
	return true


func _role_counts(descriptors: Array[Dictionary]) -> Dictionary:
	var counts := {}
	for descriptor in descriptors:
		var role := String(descriptor.get("role", ""))
		counts[role] = int(counts.get(role, 0)) + 1
	return counts


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
