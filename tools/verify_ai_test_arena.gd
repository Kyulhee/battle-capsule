extends SceneTree


const MAP_PATH := "res://data/mapSpec_ai_test_arena.json"
const PRESET_EXPECTATIONS := {
	"baseline": {"bots": 1, "loot": 0, "fixed": 2, "initial_loot": false},
	"duel_1": {"bots": 1, "loot": 0, "fixed": 2, "initial_loot": false},
	"rock_nav_1": {"bots": 1, "loot": 0, "fixed": 2, "initial_loot": false},
	"wall_traffic_4": {"bots": 4, "loot": 0, "fixed": 5, "initial_loot": false},
	"open_traffic_4": {"bots": 4, "loot": 0, "fixed": 5, "initial_loot": false},
	"squad_4": {"bots": 4, "loot": 6, "fixed": 5, "initial_loot": true},
	"systems_8": {"bots": 8, "loot": 12, "fixed": 9, "initial_loot": true},
	"random_8": {"bots": 8, "loot": 12, "fixed": 0, "initial_loot": true},
}


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_config = load("res://src/core/GameConfig.gd").new()
	game_config.load_or_default()
	var definition = load("res://src/core/MapDefinition.gd").new()
	var file := FileAccess.open(MAP_PATH, FileAccess.READ)
	if file == null or not definition.load_from_json(file.get_as_text(), MAP_PATH, game_config):
		_fail("AI test arena could not load.")
		return

	if definition.id != "ai_test_arena" or not is_equal_approx(definition.get_world_size(), 96.0):
		_fail("AI test arena identity or world size is invalid.")
		return
	if definition.map_spec.pois.size() != 5 or definition.map_spec.obstacles.size() != 16:
		_fail("AI test arena should keep five diagnostic zones and sixteen obstacles.")
		return

	for preset_name in PRESET_EXPECTATIONS:
		if not _verify_preset(definition, game_config, preset_name, PRESET_EXPECTATIONS[preset_name]):
			return
	if not _verify_traffic_wall(definition):
		return
	if not _verify_fixed_spawn_sanitizer():
		return
	if not _verify_fixed_spawn_validation(game_config):
		return
	if not _verify_runtime_duel_spawn(definition, game_config):
		return

	print("AI test arena smoke passed: world=96m presets=8 duel/nav/traffic.")
	quit(0)


func _verify_preset(definition, game_config, preset_name: String, expected: Dictionary) -> bool:
	if not definition.has_scale_preset(preset_name):
		return _fail_bool("AI test arena preset is missing: %s." % preset_name)
	var issues: Array = definition.validate(game_config, preset_name)
	if not issues.is_empty():
		return _fail_bool("%s validation failed: %s" % [preset_name, _join_issues(issues)])
	var summary: Dictionary = definition.summary(game_config, preset_name)
	if int(summary.get("bot_count", -1)) != int(expected["bots"]):
		return _fail_bool("%s bot count mismatch." % preset_name)
	if int(summary.get("loot_count", -1)) != int(expected["loot"]):
		return _fail_bool("%s loot count mismatch." % preset_name)
	if int(summary.get("fixed_spawn_count", -1)) != int(expected["fixed"]):
		return _fail_bool("%s fixed spawn count mismatch." % preset_name)
	var runtime_tuning: Dictionary = definition.get_runtime_tuning(game_config, {}, preset_name)
	var loot_tuning = load("res://src/systems/match/MatchRuntimeTuning.gd").loot(runtime_tuning)
	if bool(loot_tuning.get("initial_spawn_enabled", true)) != bool(expected["initial_loot"]):
		return _fail_bool("%s initial loot isolation mismatch." % preset_name)
	return true


func _verify_traffic_wall(definition) -> bool:
	for obstacle in definition.get_obstacle_descriptors():
		if String(obstacle.get("type", "")) != "canyon_wall":
			continue
		var position: Vector2 = obstacle.get("pos_2d", Vector2.INF)
		if position.distance_to(Vector2(22.0, 32.0)) > 0.01:
			continue
		var scale: Vector3 = obstacle.get("scale_3d", Vector3.ZERO)
		if not scale.is_equal_approx(Vector3(2.0, 3.2, 1.2)):
			return _fail_bool("Traffic wall scale changed: %s." % scale)
		if not is_equal_approx(float(obstacle.get("rot", 0.0)), 0.0):
			return _fail_bool("Traffic wall rotation changed.")
		return true
	return _fail_bool("Traffic wall is missing.")


func _verify_fixed_spawn_sanitizer() -> bool:
	var runtime_tuning = load("res://src/systems/match/MatchRuntimeTuning.gd")
	var spawn: Dictionary = runtime_tuning.spawn({
		"spawn": {
			"fixed_positions": [[1, 2], ["bad", 3], [4], [5.5, -6.5]],
		}
	})
	var fixed: Array = spawn.get("fixed_positions", [])
	if fixed.size() != 2:
		return _fail_bool("Fixed spawn sanitizer should keep only numeric 2D positions.")
	if Vector2(float(fixed[1][0]), float(fixed[1][1])).distance_to(Vector2(5.5, -6.5)) > 0.001:
		return _fail_bool("Fixed spawn sanitizer changed valid coordinates.")
	return true


func _verify_fixed_spawn_validation(game_config) -> bool:
	var invalid_definition = load("res://src/core/MapDefinition.gd").new()
	if not invalid_definition.load_from_data({
		"id": "invalid_ai_test_spawn",
		"display_name": "Invalid AI Test Spawn",
		"metadata": {
			"id": "invalid_ai_test_spawn",
			"name": "Invalid AI Test Spawn",
			"world_size": 40,
		},
		"match": {
			"bot_count": 1,
			"loot_count": 0,
			"spawn_radius": 12.0,
		},
		"runtime": {
			"spawn": {
				"entity_clearance": 3.5,
				"fixed_positions": [[0.0, 0.0]],
			},
		},
		"pois": [
			{"name": "Probe", "pos": [0, 0], "radius": 4, "item_density": 0.0, "rare_bias": 0.0},
		],
		"obstacles": [],
	}, "test://invalid_ai_test_spawn", game_config):
		return _fail_bool("Invalid fixed spawn validation fixture could not load.")
	var issues: Array = invalid_definition.validate(game_config)
	var expected := "runtime.spawn.fixed_positions needs at least 2 entries"
	for issue in issues:
		if String(issue).contains(expected):
			return true
	return _fail_bool("Fixed spawn validation did not reject an incomplete player/bot anchor list.")


func _verify_runtime_duel_spawn(definition, game_config) -> bool:
	var main = load("res://src/Main.gd").new()
	main.map_spec = definition.map_spec
	main.map_definition = definition
	main.spawn_radius = 24.0
	main.match_runtime_tuning = definition.get_runtime_tuning(game_config, {}, "duel_1")
	main._reset_spawn_runtime()
	var player_position: Vector3 = main._get_safe_spawn_pos()
	var bot_position: Vector3 = main._get_safe_spawn_pos()
	var failure := ""
	if _flat_position(player_position).distance_to(Vector2(0.0, -2.0)) > 0.001:
		failure = "Runtime duel player did not use fixed spawn slot 0."
	elif _flat_position(bot_position).distance_to(Vector2(0.0, 2.5)) > 0.001:
		failure = "Runtime duel bot did not use fixed spawn slot 1."
	else:
		var spawn_summary: Dictionary = main._spawn_distribution_summary()
		if int(spawn_summary.get("fixed_count", 0)) != 2:
			failure = "Runtime duel did not report two fixed spawns."
		elif int(spawn_summary.get("fallback_count", -1)) != 0:
			failure = "Runtime duel unexpectedly used random fallback."
	if failure == "":
		main.is_simulation = true
		main._reset_spawn_runtime()
		var simulation_bot_position: Vector3 = main._get_safe_spawn_pos()
		if _flat_position(simulation_bot_position).distance_to(Vector2(0.0, 2.5)) > 0.001:
			failure = "Simulation should skip fixed player slot 0 and spawn its first bot at slot 1."

	main.free()
	if failure != "":
		return _fail_bool(failure)
	return true


func _flat_position(position: Vector3) -> Vector2:
	return Vector2(position.x, position.z)


func _join_issues(issues: Array) -> String:
	var parts: Array[String] = []
	for issue in issues:
		parts.append(String(issue))
	return "; ".join(parts)


func _fail_bool(message: String) -> bool:
	push_error(message)
	quit(1)
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
