extends RefCounted


const DEFAULT_PRESET := "poi_probe"


func verify(config: Dictionary) -> Dictionary:
	var label := String(config.get("label", "POI probe"))
	var path := String(config.get("path", ""))
	var preset := String(config.get("preset", DEFAULT_PRESET))

	var game_config_script = load("res://src/core/GameConfig.gd")
	var map_definition_script = load("res://src/core/MapDefinition.gd")
	var game_config = game_config_script.new()
	game_config.load_or_default()

	var definition = _load_definition(map_definition_script, game_config, path)
	if definition == null:
		return _result(false, "Could not load %s." % path)
	if not definition.has_scale_preset(preset):
		return _result(false, "%s is missing scale preset '%s'." % [label, preset])

	var issues: Array = definition.validate(game_config, preset)
	if not issues.is_empty():
		return _result(false, "%s validation failed: %s" % [label, _join_issues(issues)])

	var pois: Array[Dictionary] = definition.get_poi_descriptors()
	var routes: Array[Dictionary] = definition.get_route_descriptors()
	var obstacles: Array[Dictionary] = definition.get_obstacle_descriptors()

	var role_check := _verify_role_counts(label, "POI", pois, _dictionary(config.get("required_poi_roles", {})))
	if not bool(role_check.get("ok", false)):
		return role_check

	role_check = _verify_role_counts(label, "route", routes, _dictionary(config.get("required_route_roles", {})))
	if not bool(role_check.get("ok", false)):
		return role_check

	var poi_check := _verify_poi_contracts(label, pois, _array(config.get("poi_contracts", [])))
	if not bool(poi_check.get("ok", false)):
		return poi_check

	var route_check := _verify_route_contracts(label, routes, pois, _array(config.get("route_contracts", [])))
	if not bool(route_check.get("ok", false)):
		return route_check

	var obstacle_check := _verify_obstacle_rules(label, obstacles, _array(config.get("obstacle_rules", [])))
	if not bool(obstacle_check.get("ok", false)):
		return obstacle_check

	var classification_check := _verify_classifications(label, definition, _array(config.get("classifications", [])))
	if not bool(classification_check.get("ok", false)):
		return classification_check

	var scale_check := _verify_probe_scale(label, definition, game_config, preset, _dictionary(config.get("scale", {})))
	if not bool(scale_check.get("ok", false)):
		return scale_check

	return {
		"ok": true,
		"message": "%s smoke passed: pois=%d routes=%d obstacles=%d roles=%s route_roles=%s." % [
			label,
			pois.size(),
			routes.size(),
			obstacles.size(),
			str(_role_counts(pois)),
			str(_role_counts(routes)),
		]
	}


func _verify_role_counts(label: String, descriptor_name: String, descriptors: Array[Dictionary], required: Dictionary) -> Dictionary:
	var counts := _role_counts(descriptors)
	for role in required.keys():
		var actual := int(counts.get(role, 0))
		var minimum := int(required[role])
		if actual < minimum:
			return _result(false, "%s needs at least %d %ss with role '%s'; got %d." % [label, minimum, descriptor_name, role, actual])
	return _result(true, "")


func _verify_poi_contracts(label: String, pois: Array[Dictionary], contracts: Array) -> Dictionary:
	var pois_by_name := {}
	for poi in pois:
		pois_by_name[String(poi.get("name", ""))] = poi

	for contract in contracts:
		var spec := _dictionary(contract)
		var poi_name := String(spec.get("name", ""))
		if not pois_by_name.has(poi_name):
			return _result(false, "%s is missing POI '%s'." % [label, poi_name])
		var poi: Dictionary = pois_by_name[poi_name]
		if spec.has("role") and String(poi.get("role", "")) != String(spec["role"]):
			return _result(false, "%s POI '%s' must have role '%s', got '%s'." % [label, poi_name, spec["role"], poi.get("role", "")])
		if spec.has("item_density_min") and float(poi.get("item_density", 0.0)) < float(spec["item_density_min"]):
			return _result(false, "%s POI '%s' item_density is too low." % [label, poi_name])
		if spec.has("item_density_max") and float(poi.get("item_density", 0.0)) > float(spec["item_density_max"]):
			return _result(false, "%s POI '%s' item_density is too high." % [label, poi_name])
		if spec.has("rare_bias_min") and float(poi.get("rare_bias", 0.0)) < float(spec["rare_bias_min"]):
			return _result(false, "%s POI '%s' rare_bias is too low." % [label, poi_name])
		if spec.has("rare_bias_max") and float(poi.get("rare_bias", 0.0)) > float(spec["rare_bias_max"]):
			return _result(false, "%s POI '%s' rare_bias is too high." % [label, poi_name])
	return _result(true, "")


func _verify_route_contracts(label: String, routes: Array[Dictionary], pois: Array[Dictionary], contracts: Array) -> Dictionary:
	var route_ids := {}
	var routes_by_id := {}
	for route in routes:
		var route_id := String(route.get("id", "")).strip_edges()
		if route_id.is_empty():
			return _result(false, "%s route has empty id." % label)
		route_ids[route_id] = true
		routes_by_id[route_id] = route

	var poi_names := {}
	for poi in pois:
		poi_names[String(poi.get("name", ""))] = true

	for route in routes:
		var route_id := String(route.get("id", ""))
		var connects: Array = route.get("connects", [])
		if typeof(connects) != TYPE_ARRAY or connects.is_empty():
			return _result(false, "%s route %s needs connected POI names." % [label, route_id])
		for poi_name in connects:
			if not poi_names.has(String(poi_name)):
				return _result(false, "%s route %s connects unknown POI '%s'." % [label, route_id, String(poi_name)])

	for contract in contracts:
		var spec := _dictionary(contract)
		var route_id := String(spec.get("id", ""))
		if not routes_by_id.has(route_id):
			return _result(false, "%s is missing route '%s'." % [label, route_id])
		var route: Dictionary = routes_by_id[route_id]
		var points: Array = route.get("points_2d", [])
		var width := float(route.get("width", 0.0))
		if spec.has("role") and String(route.get("role", "")) != String(spec["role"]):
			return _result(false, "%s route '%s' must have role '%s', got '%s'." % [label, route_id, spec["role"], route.get("role", "")])
		if points.size() < int(spec.get("min_points", 2)):
			return _result(false, "%s route '%s' needs more points." % [label, route_id])
		if width < float(spec.get("min_width", 0.0)):
			return _result(false, "%s route '%s' width is too narrow: %.1f." % [label, route_id, width])
		if spec.has("max_width") and width > float(spec["max_width"]):
			return _result(false, "%s route '%s' width is too wide: %.1f." % [label, route_id, width])
		if bool(spec.get("requires_alternate", false)):
			var alternate_id := String(route.get("alternate_route_id", "")).strip_edges()
			if alternate_id.is_empty() or not route_ids.has(alternate_id):
				return _result(false, "%s route '%s' needs a valid alternate_route_id." % [label, route_id])
		var required_connects: Array = _array(spec.get("connects", []))
		var connects: Array = route.get("connects", [])
		for poi_name in required_connects:
			if not connects.has(String(poi_name)):
				return _result(false, "%s route '%s' must connect '%s'." % [label, route_id, String(poi_name)])
	return _result(true, "")


func _verify_obstacle_rules(label: String, obstacles: Array[Dictionary], rules: Array) -> Dictionary:
	for rule in rules:
		var spec := _dictionary(rule)
		var count := 0
		var types: Array = _array(spec.get("types", []))
		for obstacle in obstacles:
			var obs_type := String(obstacle.get("type", ""))
			if not types.has(obs_type):
				continue
			var scale: Vector3 = obstacle.get("scale_3d", Vector3.ONE)
			if spec.has("min_y") and scale.y < float(spec["min_y"]):
				continue
			if spec.has("min_x") and scale.x < float(spec["min_x"]):
				continue
			count += 1
		var rule_label := String(spec.get("label", "obstacle rule"))
		if spec.has("min") and count < int(spec["min"]):
			return _result(false, "%s needs at least %d %s; got %d." % [label, int(spec["min"]), rule_label, count])
		if spec.has("max") and count > int(spec["max"]):
			return _result(false, "%s has too many %s; got %d." % [label, rule_label, count])
	return _result(true, "")


func _verify_classifications(label: String, definition, classifications: Array) -> Dictionary:
	for classification in classifications:
		var spec := _dictionary(classification)
		var pos = spec.get("pos", Vector2.ZERO)
		var described: Dictionary = definition.describe_strategic_position(pos)
		var point_label := String(spec.get("label", str(pos)))
		for key in ["poi_name", "poi_role", "route_id", "route_role"]:
			if not spec.has(key):
				continue
			if String(described.get(key, "")) != String(spec[key]):
				return _result(false, "%s %s should classify %s='%s', got '%s'." % [label, point_label, key, String(spec[key]), String(described.get(key, ""))])
	return _result(true, "")


func _verify_probe_scale(label: String, definition, game_config, preset: String, scale_config: Dictionary) -> Dictionary:
	var summary: Dictionary = definition.summary(game_config, preset)
	var match_tuning: Dictionary = definition.get_match_tuning(game_config, {}, preset)
	var runtime_tuning: Dictionary = definition.get_runtime_tuning(game_config, {}, preset)
	var spawn := _dictionary(runtime_tuning.get("spawn", {}))
	var world_size := float(summary.get("world_size", 0.0))
	var spawn_radius := float(match_tuning.get("spawn_radius", 0.0))
	var clearance := float(spawn.get("entity_clearance", 3.5))
	var max_world := float(scale_config.get("max_world", 82.0))
	var max_bots := int(scale_config.get("max_bots", 12))
	if world_size > max_world:
		return _result(false, "%s world should stay compact; got %.1fm." % [label, world_size])
	if int(match_tuning.get("bot_count", 0)) > max_bots:
		return _result(false, "%s should keep bot_count <= %d." % [label, max_bots])
	if spawn_radius + clearance > world_size * 0.5:
		return _result(false, "%s spawn radius exceeds boundary margin." % label)
	return _result(true, "")


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
		return null
	return definition


func _read_text(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
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


func _array(value) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return value
	return []


func _result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}
