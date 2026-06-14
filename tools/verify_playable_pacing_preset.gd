extends SceneTree

const DEFAULT_PATH := "res://data/mapSpec_example.json"
const CANDIDATE_PATH := "res://data/mapSpec_night_forest_candidate.json"
const STRUCTURAL_PRESET := "target_99_probe"
const PLAYABLE_PRESET := "playable_pacing_v1"


func _init():
	var game_config_script = load("res://src/core/GameConfig.gd")
	var map_definition_script = load("res://src/core/MapDefinition.gd")
	var runtime_tuning_script = load("res://src/systems/match/MatchRuntimeTuning.gd")

	var game_config = game_config_script.new()
	game_config.load_or_default()

	var default_definition = _load_definition(map_definition_script, DEFAULT_PATH, game_config)
	if default_definition == null:
		return
	if default_definition.has_scale_preset(PLAYABLE_PRESET):
		_fail("%s must not be available on the default map." % PLAYABLE_PRESET)
		return

	var candidate = _load_definition(map_definition_script, CANDIDATE_PATH, game_config)
	if candidate == null:
		return
	if not candidate.has_scale_preset(STRUCTURAL_PRESET):
		_fail("Night candidate is missing structural preset %s." % STRUCTURAL_PRESET)
		return
	if not candidate.has_scale_preset(PLAYABLE_PRESET):
		_fail("Night candidate is missing playable pacing preset %s." % PLAYABLE_PRESET)
		return

	var issues: Array = candidate.validate(game_config, PLAYABLE_PRESET)
	if not issues.is_empty():
		_fail("%s validation failed: %s" % [PLAYABLE_PRESET, _join_issues(issues)])
		return

	var target_match: Dictionary = candidate.get_match_tuning(game_config, {}, STRUCTURAL_PRESET)
	var target_runtime: Dictionary = candidate.get_runtime_tuning(game_config, {}, STRUCTURAL_PRESET)
	var target_loot: Dictionary = runtime_tuning_script.loot(target_runtime)
	var target_zone: Dictionary = candidate.get_zone_tuning(game_config, {}, STRUCTURAL_PRESET)

	var playable_match: Dictionary = candidate.get_match_tuning(game_config, {}, PLAYABLE_PRESET)
	var playable_runtime: Dictionary = candidate.get_runtime_tuning(game_config, {}, PLAYABLE_PRESET)
	var playable_spawn: Dictionary = runtime_tuning_script.spawn(playable_runtime)
	var playable_loot: Dictionary = runtime_tuning_script.loot(playable_runtime)
	var playable_zone: Dictionary = candidate.get_zone_tuning(game_config, {}, PLAYABLE_PRESET)

	if not _verify_match(playable_match, target_match):
		return
	if not _verify_loot(playable_loot, target_loot):
		return
	if not _verify_zone(playable_zone, target_zone):
		return
	if not _verify_opening_zone(playable_match, playable_zone):
		return
	if int(playable_spawn.get("safe_spawn_attempts", 0)) < 180:
		_fail("%s should keep target-99 spawn reliability attempts." % PLAYABLE_PRESET)
		return

	print("%s smoke passed: bots=%d loot=%d initial=%.1f stage2=%.1f/%.1f." % [
		PLAYABLE_PRESET,
		int(playable_match.get("bot_count", 0)),
		int(playable_match.get("loot_count", 0)),
		float(playable_zone.get("initial_timer", 0.0)),
		float(playable_zone.get("stages", {}).get("2", {}).get("wait_time", 0.0)),
		float(playable_zone.get("stages", {}).get("2", {}).get("shrink_time", 0.0)),
	])
	quit(0)


func _verify_match(playable: Dictionary, target: Dictionary) -> bool:
	if int(playable.get("bot_count", 0)) != 99:
		return _fail_bool("%s should remain a 99-bot candidate." % PLAYABLE_PRESET)
	if int(playable.get("bot_count", 0)) != int(target.get("bot_count", -1)):
		return _fail_bool("%s should keep the structural preset bot count." % PLAYABLE_PRESET)
	if float(playable.get("spawn_radius", 0.0)) != float(target.get("spawn_radius", -1.0)):
		return _fail_bool("%s should keep the structural spawn radius." % PLAYABLE_PRESET)
	var playable_loot := int(playable.get("loot_count", 0))
	var target_loot := int(target.get("loot_count", 0))
	if playable_loot >= target_loot:
		return _fail_bool("%s should reduce initial loot versus %s." % [PLAYABLE_PRESET, STRUCTURAL_PRESET])
	if playable_loot < 190:
		return _fail_bool("%s loot_count is too low for a first playable 99-bot candidate." % PLAYABLE_PRESET)
	return true


func _verify_loot(playable: Dictionary, target: Dictionary) -> bool:
	if float(playable.get("hotspot_density_mult", 0.0)) >= float(target.get("hotspot_density_mult", 0.0)):
		return _fail_bool("%s should reduce hotspot density versus %s." % [PLAYABLE_PRESET, STRUCTURAL_PRESET])
	if float(playable.get("hotspot_density_mult", 0.0)) < 1.0:
		return _fail_bool("%s hotspot density should not starve opening loot access." % PLAYABLE_PRESET)
	if float(playable.get("rare_bias_mult", 0.0)) >= float(target.get("rare_bias_mult", 0.0)):
		return _fail_bool("%s should reduce rare bias versus %s." % [PLAYABLE_PRESET, STRUCTURAL_PRESET])
	if float(playable.get("rare_bias_mult", 0.0)) < 1.05:
		return _fail_bool("%s rare bias should keep non-pistol upgrade seeds available." % PLAYABLE_PRESET)
	if float(playable.get("stage_wave_base_prob", 0.0)) >= float(target.get("stage_wave_base_prob", 0.0)):
		return _fail_bool("%s should reduce stage wave base probability." % PLAYABLE_PRESET)
	if float(playable.get("stage_wave_base_prob", 0.0)) < 0.04:
		return _fail_bool("%s stage wave base probability is too low for playable pacing v1." % PLAYABLE_PRESET)
	if float(playable.get("stage_wave_prob_per_stage", 0.0)) >= float(target.get("stage_wave_prob_per_stage", 0.0)):
		return _fail_bool("%s should reduce stage wave scaling." % PLAYABLE_PRESET)
	if float(playable.get("stage_wave_prob_per_stage", 0.0)) < 0.05:
		return _fail_bool("%s stage wave scaling is too low for playable pacing v1." % PLAYABLE_PRESET)
	if int(playable.get("stage_wave_count_mult", 0)) >= int(target.get("stage_wave_count_mult", 0)):
		return _fail_bool("%s should reduce stage wave count multiplier." % PLAYABLE_PRESET)
	if int(playable.get("stage_wave_count_mult", 0)) < 5:
		return _fail_bool("%s stage wave count multiplier is too low for playable pacing v1." % PLAYABLE_PRESET)
	return true


func _verify_zone(playable: Dictionary, target: Dictionary) -> bool:
	if float(playable.get("initial_timer", 0.0)) <= float(target.get("initial_timer", 0.0)):
		return _fail_bool("%s should extend initial safe time." % PLAYABLE_PRESET)
	if float(playable.get("wait_time", 0.0)) <= float(target.get("wait_time", 0.0)):
		return _fail_bool("%s should extend base wait time." % PLAYABLE_PRESET)
	if float(playable.get("shrink_time", 0.0)) <= float(target.get("shrink_time", 0.0)):
		return _fail_bool("%s should extend base shrink time." % PLAYABLE_PRESET)

	var playable_stages: Dictionary = playable.get("stages", {})
	var target_stages: Dictionary = target.get("stages", {})
	for stage_key in ["2", "3", "4", "5"]:
		var playable_stage: Dictionary = playable_stages.get(stage_key, {})
		var target_stage: Dictionary = target_stages.get(stage_key, {})
		if playable_stage.is_empty() or target_stage.is_empty():
			return _fail_bool("%s and %s should both define stage %s." % [PLAYABLE_PRESET, STRUCTURAL_PRESET, stage_key])
		if float(playable_stage.get("wait_time", 0.0)) <= float(target_stage.get("wait_time", 0.0)):
			return _fail_bool("%s should extend stage %s wait time." % [PLAYABLE_PRESET, stage_key])
		if float(playable_stage.get("shrink_time", 0.0)) <= float(target_stage.get("shrink_time", 0.0)):
			return _fail_bool("%s should extend stage %s shrink time." % [PLAYABLE_PRESET, stage_key])
	if float(playable_stages.get("2", {}).get("damage_per_second", 0.0)) > float(target_stages.get("2", {}).get("damage_per_second", 0.0)):
		return _fail_bool("%s should not raise early zone damage." % PLAYABLE_PRESET)
	return true


func _verify_opening_zone(playable_match: Dictionary, playable_zone: Dictionary) -> bool:
	var spawn_radius := float(playable_match.get("spawn_radius", 0.0))
	var initial_radius := float(playable_zone.get("initial_radius", 50.0))
	var zone_escape_threshold := 0.95
	if initial_radius * zone_escape_threshold < spawn_radius:
		return _fail_bool("%s initial_radius %.1f leaves spawn_radius %.1f in opening ZONE_ESCAPE." % [
			PLAYABLE_PRESET,
			initial_radius,
			spawn_radius,
		])
	return true


func _load_definition(map_definition_script, path: String, game_config):
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


func _fail_bool(message: String) -> bool:
	_fail(message)
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
