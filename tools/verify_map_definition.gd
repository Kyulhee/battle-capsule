extends SceneTree


const MAP_SPEC_PATH := "res://data/mapSpec_example.json"


func _init():
	var game_config_script = load("res://src/core/GameConfig.gd")
	var map_definition_script = load("res://src/core/MapDefinition.gd")

	var game_config = game_config_script.new()
	game_config.load_or_default()

	var json_text := _read_text(MAP_SPEC_PATH)
	if json_text.is_empty():
		return

	var legacy_definition = map_definition_script.new()
	if not legacy_definition.load_from_json(json_text, MAP_SPEC_PATH, game_config):
		_fail("MapDefinition could not wrap legacy MapSpec JSON.")
		return
	if not _validate_definition(legacy_definition, game_config, "legacy"):
		return

	var summary: Dictionary = legacy_definition.summary(game_config)
	if String(summary.get("id", "")) != "mountain_forest_alpha":
		_fail("Legacy MapDefinition id mismatch: %s" % summary.get("id", ""))
		return
	if int(summary.get("bot_count", 0)) != 11:
		_fail("Legacy MapDefinition did not inherit bot_count from GameConfig.")
		return
	if int(summary.get("loot_count", 0)) != 40:
		_fail("Legacy MapDefinition did not inherit loot_count from GameConfig.")
		return
	if float(summary.get("spawn_radius", 0.0)) != 45.0:
		_fail("Legacy MapDefinition did not inherit spawn_radius from GameConfig.")
		return
	if int(summary.get("scale_preset_count", 0)) != 3:
		_fail("Legacy MapDefinition did not load scale presets.")
		return
	var medium_summary: Dictionary = legacy_definition.summary(game_config, "medium_24")
	if int(medium_summary.get("bot_count", 0)) != 24:
		_fail("Legacy MapDefinition did not apply medium_24 bot_count preset.")
		return
	if int(medium_summary.get("loot_count", 0)) != 72:
		_fail("Legacy MapDefinition did not apply medium_24 loot_count preset.")
		return
	if float(medium_summary.get("spawn_radius", 0.0)) != 52.0:
		_fail("Legacy MapDefinition did not apply medium_24 spawn_radius preset.")
		return
	var medium_runtime: Dictionary = legacy_definition.get_runtime_tuning(game_config, {}, "medium_24")
	var medium_loot: Dictionary = medium_runtime.get("loot", {})
	if absf(float(medium_loot.get("hotspot_density_mult", 0.0)) - 1.08) > 0.001:
		_fail("Legacy MapDefinition did not apply medium_24 hotspot_density_mult preset.")
		return
	var large_summary: Dictionary = legacy_definition.summary(game_config, "large_40")
	if int(large_summary.get("bot_count", 0)) != 40:
		_fail("Legacy MapDefinition did not apply large_40 bot_count preset.")
		return
	if int(large_summary.get("loot_count", 0)) != 104:
		_fail("Legacy MapDefinition did not apply large_40 loot_count preset.")
		return
	if float(large_summary.get("spawn_radius", 0.0)) != 56.0:
		_fail("Legacy MapDefinition did not apply large_40 spawn_radius preset.")
		return
	var large_runtime: Dictionary = legacy_definition.get_runtime_tuning(game_config, {}, "large_40")
	var large_loot: Dictionary = large_runtime.get("loot", {})
	if absf(float(large_loot.get("hotspot_density_mult", 0.0)) - 1.12) > 0.001:
		_fail("Legacy MapDefinition did not apply large_40 hotspot_density_mult preset.")
		return
	var large_zone: Dictionary = legacy_definition.get_zone_tuning(game_config, {}, "large_40")
	if float(large_zone.get("initial_timer", 0.0)) != 20.0:
		_fail("Legacy MapDefinition did not apply large_40 zone initial_timer preset.")
		return
	if float(large_zone.get("wait_time", 0.0)) != 34.0:
		_fail("Legacy MapDefinition did not apply large_40 zone wait_time preset.")
		return
	if float(large_zone.get("shrink_time", 0.0)) != 24.0:
		_fail("Legacy MapDefinition did not apply large_40 zone shrink_time preset.")
		return

	var parsed := _parse_json(json_text)
	if parsed.is_empty():
		return
	var wrapper_definition = map_definition_script.new()
	if not wrapper_definition.load_from_data({
		"id": "mountain_forest_alpha_scale_test",
		"display_name": "Mountain Forest Alpha Scale Test",
		"map_spec": parsed,
		"match": {
			"bot_count": 24,
			"loot_count": 72,
			"spawn_radius": 52.0,
		},
		"scale_presets": {
			"baseline": {"bot_count": 11},
			"medium": {"bot_count": 18},
		},
	}, "test://wrapper", game_config):
		_fail("MapDefinition could not load wrapper format.")
		return
	if not _validate_definition(wrapper_definition, game_config, "wrapper"):
		return

	var wrapper_summary: Dictionary = wrapper_definition.summary(game_config)
	if int(wrapper_summary.get("bot_count", 0)) != 24:
		_fail("Wrapper MapDefinition did not apply match bot_count override.")
		return
	if int(wrapper_summary.get("loot_count", 0)) != 72:
		_fail("Wrapper MapDefinition did not apply match loot_count override.")
		return
	if float(wrapper_summary.get("spawn_radius", 0.0)) != 52.0:
		_fail("Wrapper MapDefinition did not apply match spawn_radius override.")
		return
	if int(wrapper_summary.get("scale_preset_count", 0)) != 2:
		_fail("Wrapper MapDefinition did not preserve scale presets.")
		return
	var wrapper_medium_summary: Dictionary = wrapper_definition.summary(game_config, "medium")
	if int(wrapper_medium_summary.get("bot_count", 0)) != 18:
		_fail("Wrapper MapDefinition did not apply flat medium preset.")
		return
	if int(wrapper_medium_summary.get("loot_hotspot_count", 0)) <= 0:
		_fail("Wrapper MapDefinition did not report loot hotspot coverage.")
		return
	if float(wrapper_medium_summary.get("zone_initial_radius", 0.0)) <= 0.0:
		_fail("Wrapper MapDefinition did not report zone initial radius.")
		return

	if not _verify_validation_issues(map_definition_script, game_config, parsed):
		return

	print("MapDefinition smoke passed: %s pois=%d obstacles=%d wrapper_bots=%d." % [
		String(summary.get("id", "")),
		int(summary.get("poi_count", 0)),
		int(summary.get("obstacle_count", 0)),
		int(wrapper_summary.get("bot_count", 0)),
	])
	quit(0)


func _validate_definition(definition, game_config, label: String) -> bool:
	var issues: Array = definition.validate(game_config)
	if not issues.is_empty():
		_fail("%s MapDefinition validation failed: %s" % [label, _join_issues(issues)])
		return false
	var summary: Dictionary = definition.summary(game_config)
	if float(summary.get("world_size", 0.0)) <= 0.0:
		_fail("%s MapDefinition world size is invalid." % label)
		return false
	if int(summary.get("poi_count", 0)) <= 0:
		_fail("%s MapDefinition has no POIs." % label)
		return false
	if int(summary.get("obstacle_count", 0)) <= 0:
		_fail("%s MapDefinition has no obstacles." % label)
		return false
	if int(summary.get("zone_stage_count", 0)) <= 0:
		_fail("%s MapDefinition did not inherit zone stage configs." % label)
		return false
	return true


func _verify_validation_issues(map_definition_script, game_config, parsed: Dictionary) -> bool:
	var invalid_spec := parsed.duplicate(true)
	invalid_spec["pois"] = _duplicate_array(parsed.get("pois", []))
	invalid_spec["obstacles"] = _duplicate_array(parsed.get("obstacles", []))
	if invalid_spec["pois"].size() > 0:
		var invalid_poi: Dictionary = invalid_spec["pois"][0].duplicate(true)
		invalid_poi["item_density"] = -0.25
		invalid_poi["rare_bias"] = 1.25
		invalid_spec["pois"][0] = invalid_poi
	invalid_spec["obstacles"].append({
		"type": "canyon_wall",
		"pos": [54.0, 0.0],
		"scale": [8.0, 2.0, 2.0],
		"rot": 45.0,
	})

	var invalid_definition = map_definition_script.new()
	if not invalid_definition.load_from_data({
		"id": "invalid_validation_probe",
		"display_name": "Invalid Validation Probe",
		"map_spec": invalid_spec,
		"match": {
			"bot_count": 11,
			"loot_count": 40,
			"spawn_radius": 58.0,
		},
		"zone": {
			"initial_radius": 90.0,
			"next_radius": 95.0,
			"stages": {
				"2": {"wait_time": -1.0},
			},
		},
	}, "test://invalid", game_config):
		_fail("Invalid MapDefinition probe could not load.")
		return false

	var issues: Array = invalid_definition.validate(game_config)
	for expected in [
		"POI 0 has negative item_density.",
		"POI 0 rare_bias 1.25 must be within 0..1.",
		"Obstacle 35 extends outside world bounds.",
		"spawn_radius 58.0 plus entity_clearance 3.5 exceeds world half-size 60.0.",
		"zone.initial_radius 90.0 exceeds world half-size 60.0.",
		"zone.next_radius 95.0 must be smaller than initial_radius 90.0.",
		"zone.stages.2.wait_time must be positive.",
	]:
		if not _issues_contain(issues, expected):
			_fail("Expected validation issue not found: %s\nActual: %s" % [expected, _join_issues(issues)])
			return false
	return true


func _read_text(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("Could not open %s." % path)
		return ""
	return file.get_as_text()


func _parse_json(json_text: String) -> Dictionary:
	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		_fail("Could not parse %s: %s." % [MAP_SPEC_PATH, json.get_error_message()])
		return {}
	var parsed = json.get_data()
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("%s root is not a Dictionary." % MAP_SPEC_PATH)
		return {}
	return parsed


func _join_issues(issues: Array) -> String:
	var parts: Array[String] = []
	for issue in issues:
		parts.append(String(issue))
	return "; ".join(parts)


func _issues_contain(issues: Array, expected: String) -> bool:
	for issue in issues:
		if String(issue) == expected:
			return true
	return false


func _duplicate_array(value) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return value.duplicate(true)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
