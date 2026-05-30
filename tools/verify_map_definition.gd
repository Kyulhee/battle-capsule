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
			"medium": {"bot_count": 24},
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


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
