extends SceneTree

const DEFAULT_PATH := "res://data/mapSpec_example.json"
const CANDIDATE_PATH := "res://data/mapSpec_night_forest_candidate.json"
const STRUCTURAL_PRESET := "target_99_probe"
const PLAYABLE_BASELINE_PRESET := "playable_pacing_v1"
const PLAYABLE_LATE_ZONE_PRESET := "playable_pacing_v2"
const PLAYABLE_FIRST_UPGRADE_PRESET := "playable_pacing_v3"
const PLAYABLE_MAP_WAVE_PRESET := "playable_pacing_v4"
const PLAYABLE_DURATION_PRESET := "playable_pacing_v5"
const PLAYABLE_EDGE_RETURN_PRESET := "playable_pacing_v6"
const PLAYABLE_PRESETS := [PLAYABLE_BASELINE_PRESET, PLAYABLE_LATE_ZONE_PRESET, PLAYABLE_FIRST_UPGRADE_PRESET, PLAYABLE_MAP_WAVE_PRESET, PLAYABLE_DURATION_PRESET, PLAYABLE_EDGE_RETURN_PRESET]


func _init():
	var game_config_script = load("res://src/core/GameConfig.gd")
	var map_definition_script = load("res://src/core/MapDefinition.gd")
	var runtime_tuning_script = load("res://src/systems/match/MatchRuntimeTuning.gd")

	var game_config = game_config_script.new()
	game_config.load_or_default()

	var default_definition = _load_definition(map_definition_script, DEFAULT_PATH, game_config)
	if default_definition == null:
		return
	for preset_name in PLAYABLE_PRESETS:
		if default_definition.has_scale_preset(preset_name):
			_fail("%s must not be available on the default map." % preset_name)
			return

	var candidate = _load_definition(map_definition_script, CANDIDATE_PATH, game_config)
	if candidate == null:
		return
	if not candidate.has_scale_preset(STRUCTURAL_PRESET):
		_fail("Night candidate is missing structural preset %s." % STRUCTURAL_PRESET)
		return
	for preset_name in PLAYABLE_PRESETS:
		if not candidate.has_scale_preset(preset_name):
			_fail("Night candidate is missing playable pacing preset %s." % preset_name)
			return

	var target_match: Dictionary = candidate.get_match_tuning(game_config, {}, STRUCTURAL_PRESET)
	var target_runtime: Dictionary = candidate.get_runtime_tuning(game_config, {}, STRUCTURAL_PRESET)
	var target_loot: Dictionary = runtime_tuning_script.loot(target_runtime)
	var target_zone: Dictionary = candidate.get_zone_tuning(game_config, {}, STRUCTURAL_PRESET)
	var baseline_zone: Dictionary = candidate.get_zone_tuning(game_config, {}, PLAYABLE_BASELINE_PRESET)
	var late_zone_match: Dictionary = candidate.get_match_tuning(game_config, {}, PLAYABLE_LATE_ZONE_PRESET)
	var late_zone_runtime: Dictionary = candidate.get_runtime_tuning(game_config, {}, PLAYABLE_LATE_ZONE_PRESET)
	var late_zone_spawn: Dictionary = runtime_tuning_script.spawn(late_zone_runtime)
	var late_zone_loot: Dictionary = runtime_tuning_script.loot(late_zone_runtime)
	var late_zone_zone: Dictionary = candidate.get_zone_tuning(game_config, {}, PLAYABLE_LATE_ZONE_PRESET)
	var map_wave_match: Dictionary = candidate.get_match_tuning(game_config, {}, PLAYABLE_MAP_WAVE_PRESET)
	var map_wave_runtime: Dictionary = candidate.get_runtime_tuning(game_config, {}, PLAYABLE_MAP_WAVE_PRESET)
	var map_wave_spawn: Dictionary = runtime_tuning_script.spawn(map_wave_runtime)
	var map_wave_loot: Dictionary = runtime_tuning_script.loot(map_wave_runtime)
	var map_wave_combat: Dictionary = runtime_tuning_script.combat(map_wave_runtime)
	var map_wave_zone: Dictionary = candidate.get_zone_tuning(game_config, {}, PLAYABLE_MAP_WAVE_PRESET)
	var duration_match: Dictionary = candidate.get_match_tuning(game_config, {}, PLAYABLE_DURATION_PRESET)
	var duration_runtime: Dictionary = candidate.get_runtime_tuning(game_config, {}, PLAYABLE_DURATION_PRESET)
	var duration_spawn: Dictionary = runtime_tuning_script.spawn(duration_runtime)
	var duration_loot: Dictionary = runtime_tuning_script.loot(duration_runtime)
	var duration_combat: Dictionary = runtime_tuning_script.combat(duration_runtime)
	var duration_bot: Dictionary = runtime_tuning_script.bot(duration_runtime)
	var duration_zone: Dictionary = candidate.get_zone_tuning(game_config, {}, PLAYABLE_DURATION_PRESET)

	for preset_name in PLAYABLE_PRESETS:
		var issues: Array = candidate.validate(game_config, preset_name)
		if not issues.is_empty():
			_fail("%s validation failed: %s" % [preset_name, _join_issues(issues)])
			return

		var playable_match: Dictionary = candidate.get_match_tuning(game_config, {}, preset_name)
		var playable_runtime: Dictionary = candidate.get_runtime_tuning(game_config, {}, preset_name)
		var playable_spawn: Dictionary = runtime_tuning_script.spawn(playable_runtime)
		var playable_loot: Dictionary = runtime_tuning_script.loot(playable_runtime)
		var playable_combat: Dictionary = runtime_tuning_script.combat(playable_runtime)
		var playable_bot: Dictionary = runtime_tuning_script.bot(playable_runtime)
		var playable_zone: Dictionary = candidate.get_zone_tuning(game_config, {}, preset_name)

		if not _verify_match(preset_name, playable_match, target_match):
			return
		if not _verify_loot(preset_name, playable_loot, target_loot):
			return
		if not _verify_zone(preset_name, playable_zone, target_zone):
			return
		if not _verify_opening_zone(preset_name, playable_match, playable_zone):
			return
		if not _verify_spawn(preset_name, playable_spawn, playable_match):
			return
		if preset_name == PLAYABLE_LATE_ZONE_PRESET and not _verify_late_zone_candidate(preset_name, playable_zone, baseline_zone):
			return
		if preset_name == PLAYABLE_FIRST_UPGRADE_PRESET and not _verify_first_upgrade_candidate(
			preset_name,
			playable_match,
			playable_spawn,
			playable_loot,
			playable_zone,
			late_zone_match,
			late_zone_spawn,
			late_zone_loot,
			late_zone_zone,
			["concealment_field", "loot_hub"],
			["transit_choke", "recovery_pocket"],
			[]
		):
			return
		if preset_name in [PLAYABLE_MAP_WAVE_PRESET, PLAYABLE_DURATION_PRESET, PLAYABLE_EDGE_RETURN_PRESET] and not _verify_first_upgrade_candidate(
			preset_name,
			playable_match,
			playable_spawn,
			playable_loot,
			playable_zone,
			late_zone_match,
			late_zone_spawn,
			late_zone_loot,
			late_zone_zone,
			["concealment_field", "loot_hub"],
			["transit_choke", "recovery_pocket"],
			[],
			true,
			-10.0 if preset_name in [PLAYABLE_DURATION_PRESET, PLAYABLE_EDGE_RETURN_PRESET] else 0.0
		):
			return
		if preset_name == PLAYABLE_DURATION_PRESET and not _verify_duration_candidate(
			preset_name,
			playable_match,
			playable_spawn,
			playable_loot,
			playable_combat,
			playable_zone,
			map_wave_match,
			map_wave_spawn,
			map_wave_loot,
			map_wave_combat,
			map_wave_zone
		):
			return
		if preset_name == PLAYABLE_EDGE_RETURN_PRESET and not _verify_edge_return_candidate(
			preset_name,
			playable_match,
			playable_spawn,
			playable_loot,
			playable_combat,
			playable_bot,
			playable_zone,
			duration_match,
			duration_spawn,
			duration_loot,
			duration_combat,
			duration_bot,
			duration_zone
		):
			return

		print("%s smoke passed: bots=%d loot=%d initial=%.1f stage2=%.1f/%.1f bot_vs_bot=%.2f edge_release=%.2f." % [
			preset_name,
			int(playable_match.get("bot_count", 0)),
			int(playable_match.get("loot_count", 0)),
			float(playable_zone.get("initial_timer", 0.0)),
			float(playable_zone.get("stages", {}).get("2", {}).get("wait_time", 0.0)),
			float(playable_zone.get("stages", {}).get("2", {}).get("shrink_time", 0.0)),
			float(playable_combat.get("bot_vs_bot_damage_mult", 1.0)),
			float(playable_bot.get("stage1_inside_zone_escape_release_ratio", 0.75)),
		])
	quit(0)


func _verify_match(preset_name: String, playable: Dictionary, target: Dictionary) -> bool:
	if int(playable.get("bot_count", 0)) != 99:
		return _fail_bool("%s should remain a 99-bot candidate." % preset_name)
	if int(playable.get("bot_count", 0)) != int(target.get("bot_count", -1)):
		return _fail_bool("%s should keep the structural preset bot count." % preset_name)
	if float(playable.get("spawn_radius", 0.0)) != float(target.get("spawn_radius", -1.0)):
		return _fail_bool("%s should keep the structural spawn radius." % preset_name)
	var playable_loot := int(playable.get("loot_count", 0))
	var target_loot := int(target.get("loot_count", 0))
	if playable_loot >= target_loot:
		return _fail_bool("%s should reduce initial loot versus %s." % [preset_name, STRUCTURAL_PRESET])
	if playable_loot < 190:
		return _fail_bool("%s loot_count is too low for a first playable 99-bot candidate." % preset_name)
	return true


func _verify_loot(preset_name: String, playable: Dictionary, target: Dictionary) -> bool:
	if float(playable.get("hotspot_density_mult", 0.0)) >= float(target.get("hotspot_density_mult", 0.0)):
		return _fail_bool("%s should reduce hotspot density versus %s." % [preset_name, STRUCTURAL_PRESET])
	if float(playable.get("hotspot_density_mult", 0.0)) < 1.0:
		return _fail_bool("%s hotspot density should not starve opening loot access." % preset_name)
	if float(playable.get("rare_bias_mult", 0.0)) >= float(target.get("rare_bias_mult", 0.0)):
		return _fail_bool("%s should reduce rare bias versus %s." % [preset_name, STRUCTURAL_PRESET])
	if float(playable.get("rare_bias_mult", 0.0)) < 1.05:
		return _fail_bool("%s rare bias should keep non-pistol upgrade seeds available." % preset_name)
	if float(playable.get("stage_wave_base_prob", 0.0)) >= float(target.get("stage_wave_base_prob", 0.0)):
		return _fail_bool("%s should reduce stage wave base probability." % preset_name)
	if float(playable.get("stage_wave_base_prob", 0.0)) < 0.04:
		return _fail_bool("%s stage wave base probability is too low for playable pacing." % preset_name)
	if float(playable.get("stage_wave_prob_per_stage", 0.0)) >= float(target.get("stage_wave_prob_per_stage", 0.0)):
		return _fail_bool("%s should reduce stage wave scaling." % preset_name)
	if float(playable.get("stage_wave_prob_per_stage", 0.0)) < 0.05:
		return _fail_bool("%s stage wave scaling is too low for playable pacing." % preset_name)
	if int(playable.get("stage_wave_count_mult", 0)) >= int(target.get("stage_wave_count_mult", 0)):
		return _fail_bool("%s should reduce stage wave count multiplier." % preset_name)
	if int(playable.get("stage_wave_count_mult", 0)) < 5:
		return _fail_bool("%s stage wave count multiplier is too low for playable pacing." % preset_name)
	return true


func _verify_spawn(preset_name: String, playable_spawn: Dictionary, playable_match: Dictionary) -> bool:
	if int(playable_spawn.get("safe_spawn_attempts", 0)) < 220:
		return _fail_bool("%s should raise safe spawn attempts for 5m opening spacing." % preset_name)
	var clearance := float(playable_spawn.get("entity_clearance", 0.0))
	if clearance < 5.0:
		return _fail_bool("%s should keep 5m opening entity clearance." % preset_name)
	var spawn_radius := float(playable_match.get("spawn_radius", 0.0))
	var inner_radius := float(playable_spawn.get("inner_radius", 0.0))
	var total_entities := int(playable_match.get("bot_count", 0)) + 1
	var annulus := maxf(1.0, spawn_radius * spawn_radius - inner_radius * inner_radius)
	var saturation := float(total_entities) * clearance * clearance / annulus
	if saturation > 0.55:
		return _fail_bool("%s 5m opening spacing is too saturated: %.2f." % [preset_name, saturation])
	return true


func _verify_zone(preset_name: String, playable: Dictionary, target: Dictionary) -> bool:
	if float(playable.get("initial_timer", 0.0)) <= float(target.get("initial_timer", 0.0)):
		return _fail_bool("%s should extend initial safe time." % preset_name)
	if float(playable.get("wait_time", 0.0)) <= float(target.get("wait_time", 0.0)):
		return _fail_bool("%s should extend base wait time." % preset_name)
	if float(playable.get("shrink_time", 0.0)) <= float(target.get("shrink_time", 0.0)):
		return _fail_bool("%s should extend base shrink time." % preset_name)

	var playable_stages: Dictionary = playable.get("stages", {})
	var target_stages: Dictionary = target.get("stages", {})
	for stage_key in ["2", "3", "4", "5"]:
		var playable_stage: Dictionary = playable_stages.get(stage_key, {})
		var target_stage: Dictionary = target_stages.get(stage_key, {})
		if playable_stage.is_empty() or target_stage.is_empty():
			return _fail_bool("%s and %s should both define stage %s." % [preset_name, STRUCTURAL_PRESET, stage_key])
		if float(playable_stage.get("wait_time", 0.0)) <= float(target_stage.get("wait_time", 0.0)):
			return _fail_bool("%s should extend stage %s wait time." % [preset_name, stage_key])
		if float(playable_stage.get("shrink_time", 0.0)) <= float(target_stage.get("shrink_time", 0.0)):
			return _fail_bool("%s should extend stage %s shrink time." % [preset_name, stage_key])
	if float(playable_stages.get("2", {}).get("damage_per_second", 0.0)) > float(target_stages.get("2", {}).get("damage_per_second", 0.0)):
		return _fail_bool("%s should not raise early zone damage." % preset_name)
	return true


func _verify_late_zone_candidate(preset_name: String, playable: Dictionary, baseline: Dictionary) -> bool:
	for key in ["initial_timer", "wait_time", "shrink_time"]:
		if absf(float(playable.get(key, 0.0)) - float(baseline.get(key, -1.0))) > 0.001:
			return _fail_bool("%s should keep baseline %s to preserve stage 2 timing." % [preset_name, key])

	var playable_stages: Dictionary = playable.get("stages", {})
	var baseline_stages: Dictionary = baseline.get("stages", {})
	for stage_key in ["2", "3", "4", "5"]:
		var playable_stage: Dictionary = playable_stages.get(stage_key, {})
		var baseline_stage: Dictionary = baseline_stages.get(stage_key, {})
		if playable_stage.is_empty() or baseline_stage.is_empty():
			return _fail_bool("%s and %s should both define stage %s." % [preset_name, PLAYABLE_BASELINE_PRESET, stage_key])
		if float(playable_stage.get("wait_time", 0.0)) <= float(baseline_stage.get("wait_time", 0.0)):
			return _fail_bool("%s should extend stage %s wait time versus %s." % [preset_name, stage_key, PLAYABLE_BASELINE_PRESET])
		if float(playable_stage.get("shrink_time", 0.0)) <= float(baseline_stage.get("shrink_time", 0.0)):
			return _fail_bool("%s should extend stage %s shrink time versus %s." % [preset_name, stage_key, PLAYABLE_BASELINE_PRESET])
		if float(playable_stage.get("damage_per_second", 0.0)) > float(baseline_stage.get("damage_per_second", 0.0)):
			return _fail_bool("%s should not raise stage %s damage versus %s." % [preset_name, stage_key, PLAYABLE_BASELINE_PRESET])
	return true


func _verify_first_upgrade_candidate(
	preset_name: String,
	playable_match: Dictionary,
	playable_spawn: Dictionary,
	playable_loot: Dictionary,
	playable_zone: Dictionary,
	late_zone_match: Dictionary,
	late_zone_spawn: Dictionary,
	late_zone_loot: Dictionary,
	late_zone_zone: Dictionary,
	required_roles: Array,
	blocked_roles: Array,
	required_wave_roles: Array,
	requires_initial_non_pistol_tuning: bool = false,
	initial_timer_delta: float = 0.0
) -> bool:
	for key in ["bot_count", "loot_count", "spawn_radius"]:
		if absf(float(playable_match.get(key, 0.0)) - float(late_zone_match.get(key, -1.0))) > 0.001:
			return _fail_bool("%s should keep %s from %s." % [preset_name, key, PLAYABLE_LATE_ZONE_PRESET])
	for key in ["safe_spawn_attempts", "inner_radius", "entity_clearance"]:
		if absf(float(playable_spawn.get(key, 0.0)) - float(late_zone_spawn.get(key, -1.0))) > 0.001:
			return _fail_bool("%s should keep spawn.%s from %s." % [preset_name, key, PLAYABLE_LATE_ZONE_PRESET])
	for key in ["stage_wave_base_prob", "stage_wave_prob_per_stage", "stage_wave_count_mult", "hotspot_density_mult", "rare_bias_mult"]:
		if absf(float(playable_loot.get(key, 0.0)) - float(late_zone_loot.get(key, -1.0))) > 0.001:
			return _fail_bool("%s should keep loot.%s from %s." % [preset_name, key, PLAYABLE_LATE_ZONE_PRESET])
	for key in ["initial_radius", "initial_timer", "wait_time", "shrink_time", "damage_per_second"]:
		var expected := float(late_zone_zone.get(key, -1.0))
		if key == "initial_timer":
			expected += initial_timer_delta
		if absf(float(playable_zone.get(key, 0.0)) - expected) > 0.001:
			return _fail_bool("%s should keep zone.%s from %s." % [preset_name, key, PLAYABLE_LATE_ZONE_PRESET])
	var playable_stages: Dictionary = playable_zone.get("stages", {})
	var late_zone_stages: Dictionary = late_zone_zone.get("stages", {})
	for stage_key in ["2", "3", "4", "5"]:
		var playable_stage: Dictionary = playable_stages.get(stage_key, {})
		var late_zone_stage: Dictionary = late_zone_stages.get(stage_key, {})
		for key in ["wait_time", "shrink_time", "damage_per_second"]:
			if absf(float(playable_stage.get(key, 0.0)) - float(late_zone_stage.get(key, -1.0))) > 0.001:
				return _fail_bool("%s should keep zone stage %s %s from %s." % [preset_name, stage_key, key, PLAYABLE_LATE_ZONE_PRESET])

	var role_mult_variant = playable_loot.get("role_weapon_chance_mult", {})
	if typeof(role_mult_variant) != TYPE_DICTIONARY:
		return _fail_bool("%s role_weapon_chance_mult should be a dictionary." % preset_name)
	var role_mult: Dictionary = role_mult_variant
	for role in required_roles:
		if not role_mult.has(role):
			return _fail_bool("%s should tune weapon access for %s." % [preset_name, role])
		var value := float(role_mult[role])
		if value <= 0.0 or value >= 1.0:
			return _fail_bool("%s %s multiplier %.2f should reduce without disabling." % [preset_name, role, value])
	if role_mult.has("concealment_field") and role_mult.has("loot_hub") and float(role_mult["concealment_field"]) > float(role_mult["loot_hub"]):
		return _fail_bool("%s should reduce concealment initial weapons at least as much as loot hubs." % preset_name)
	for role in blocked_roles:
		if role_mult.has(role) and absf(float(role_mult[role]) - 1.0) > 0.001:
			return _fail_bool("%s should not tune %s in the first-upgrade context candidate." % [preset_name, role])
	var wave_role_mult_variant = playable_loot.get("role_wave_weapon_chance_mult", {})
	if typeof(wave_role_mult_variant) != TYPE_DICTIONARY:
		return _fail_bool("%s role_wave_weapon_chance_mult should be a dictionary." % preset_name)
	var wave_role_mult: Dictionary = wave_role_mult_variant
	for role in required_wave_roles:
		if not wave_role_mult.has(role):
			return _fail_bool("%s should tune wave weapon access for %s." % [preset_name, role])
		var wave_value := float(wave_role_mult[role])
		if wave_value <= 0.0 or wave_value >= 1.0:
			return _fail_bool("%s wave %s multiplier %.2f should reduce without disabling." % [preset_name, role, wave_value])
	if required_wave_roles.is_empty() and not wave_role_mult.is_empty():
		return _fail_bool("%s should not tune wave weapon access." % preset_name)
	var initial_non_pistol_mult := float(playable_loot.get("initial_non_pistol_weapon_weight_mult", 1.0))
	if requires_initial_non_pistol_tuning:
		if initial_non_pistol_mult < 0.0 or initial_non_pistol_mult >= 1.0:
			return _fail_bool("%s initial non-pistol multiplier %.2f should reduce opening upgrades." % [preset_name, initial_non_pistol_mult])
	else:
		if absf(initial_non_pistol_mult - 1.0) > 0.001:
			return _fail_bool("%s should not tune initial non-pistol weapon weights." % preset_name)
	return true


func _verify_duration_candidate(
	preset_name: String,
	playable_match: Dictionary,
	playable_spawn: Dictionary,
	playable_loot: Dictionary,
	playable_combat: Dictionary,
	playable_zone: Dictionary,
	baseline_match: Dictionary,
	baseline_spawn: Dictionary,
	baseline_loot: Dictionary,
	baseline_combat: Dictionary,
	baseline_zone: Dictionary
) -> bool:
	if playable_match != baseline_match:
		return _fail_bool("%s should keep match tuning from %s." % [preset_name, PLAYABLE_MAP_WAVE_PRESET])
	if playable_spawn != baseline_spawn:
		return _fail_bool("%s should keep spawn tuning from %s." % [preset_name, PLAYABLE_MAP_WAVE_PRESET])
	if playable_loot != baseline_loot:
		return _fail_bool("%s should keep loot tuning from %s." % [preset_name, PLAYABLE_MAP_WAVE_PRESET])
	var expected_zone := baseline_zone.duplicate(true)
	expected_zone["initial_timer"] = float(baseline_zone.get("initial_timer", 0.0)) - 10.0
	if playable_zone != expected_zone:
		return _fail_bool("%s should only reduce %s initial_timer by 10s." % [preset_name, PLAYABLE_MAP_WAVE_PRESET])
	if absf(float(baseline_combat.get("bot_vs_bot_damage_mult", 0.0)) - 1.0) > 0.001:
		return _fail_bool("%s should keep default bot-vs-bot damage." % PLAYABLE_MAP_WAVE_PRESET)
	var damage_mult := float(playable_combat.get("bot_vs_bot_damage_mult", 1.0))
	if damage_mult < 0.45 or damage_mult > 0.65:
		return _fail_bool("%s bot-vs-bot damage %.2f should remain a bounded duration probe." % [preset_name, damage_mult])
	return true


func _verify_edge_return_candidate(
	preset_name: String,
	playable_match: Dictionary,
	playable_spawn: Dictionary,
	playable_loot: Dictionary,
	playable_combat: Dictionary,
	playable_bot: Dictionary,
	playable_zone: Dictionary,
	baseline_match: Dictionary,
	baseline_spawn: Dictionary,
	baseline_loot: Dictionary,
	baseline_combat: Dictionary,
	baseline_bot: Dictionary,
	baseline_zone: Dictionary
) -> bool:
	if playable_match != baseline_match or playable_spawn != baseline_spawn:
		return _fail_bool("%s should keep match and spawn tuning from %s." % [preset_name, PLAYABLE_DURATION_PRESET])
	if playable_loot != baseline_loot or playable_combat != baseline_combat or playable_zone != baseline_zone:
		return _fail_bool("%s should keep loot, combat, and zone tuning from %s." % [preset_name, PLAYABLE_DURATION_PRESET])
	var baseline_release := float(baseline_bot.get("stage1_inside_zone_escape_release_ratio", 0.0))
	if not is_equal_approx(baseline_release, 0.75):
		return _fail_bool("%s should preserve the existing 0.75 inside-zone release ratio." % PLAYABLE_DURATION_PRESET)
	var candidate_release := float(playable_bot.get("stage1_inside_zone_escape_release_ratio", 0.0))
	if candidate_release < 0.88 or candidate_release > 0.92:
		return _fail_bool("%s inside-zone release ratio %.2f should remain near the stage 1 entry band." % [preset_name, candidate_release])
	return true


func _verify_opening_zone(preset_name: String, playable_match: Dictionary, playable_zone: Dictionary) -> bool:
	var spawn_radius := float(playable_match.get("spawn_radius", 0.0))
	var initial_radius := float(playable_zone.get("initial_radius", 50.0))
	var zone_escape_threshold := 0.95
	if initial_radius * zone_escape_threshold < spawn_radius:
		return _fail_bool("%s initial_radius %.1f leaves spawn_radius %.1f in opening ZONE_ESCAPE." % [
			preset_name,
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
