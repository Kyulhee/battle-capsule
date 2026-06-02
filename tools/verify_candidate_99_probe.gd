extends SceneTree


const DEFAULT_PATH := "res://data/mapSpec_example.json"
const CANDIDATE_PATH := "res://data/mapSpec_large_candidate.json"
const PROBE_PRESET := "target_99_probe"
const TARGET_ENVELOPE := "target_99"


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
	if default_definition.has_scale_preset(TARGET_ENVELOPE):
		_fail("%s must remain an envelope, not a runtime preset." % TARGET_ENVELOPE)
		return

	var candidate = _load_definition(map_definition_script, game_config, CANDIDATE_PATH)
	if candidate == null:
		return
	if not candidate.has_scale_preset(PROBE_PRESET):
		_fail("Candidate map is missing %s." % PROBE_PRESET)
		return
	if candidate.has_scale_preset(TARGET_ENVELOPE):
		_fail("%s must remain an envelope, not a runtime preset." % TARGET_ENVELOPE)
		return
	if not candidate.has_scale_envelope(TARGET_ENVELOPE):
		_fail("Candidate map is missing %s envelope." % TARGET_ENVELOPE)
		return

	var issues: Array = candidate.validate(game_config, PROBE_PRESET)
	if not issues.is_empty():
		_fail("Candidate 99 probe validation failed: %s" % _join_issues(issues))
		return
	var summary: Dictionary = candidate.summary(game_config, PROBE_PRESET)
	var match_tuning: Dictionary = candidate.get_match_tuning(game_config, {}, PROBE_PRESET)
	var runtime_tuning: Dictionary = candidate.get_runtime_tuning(game_config, {}, PROBE_PRESET)
	var spawn_tuning: Dictionary = runtime_tuning_script.spawn(runtime_tuning)
	var loot_tuning: Dictionary = runtime_tuning_script.loot(runtime_tuning)
	var envelope: Dictionary = candidate.get_scale_envelope(TARGET_ENVELOPE)
	if not _verify_probe(summary, match_tuning, spawn_tuning, loot_tuning, envelope):
		return

	print("Candidate 99 probe smoke passed: bots=%d loot=%d world=%.0fm spawn=%.0fm saturation=%.2f." % [
		int(match_tuning.get("bot_count", 0)),
		int(match_tuning.get("loot_count", 0)),
		float(summary.get("world_size", 0.0)),
		float(match_tuning.get("spawn_radius", 0.0)),
		_annulus_saturation(
			int(envelope.get("total_entities", 0)),
			float(spawn_tuning.get("entity_clearance", 0.0)),
			float(match_tuning.get("spawn_radius", 0.0)),
			float(spawn_tuning.get("inner_radius", 0.0))
		),
	])
	quit(0)


func _load_definition(map_definition_script, game_config, path: String):
	var json_text := _read_text(path)
	if json_text.is_empty():
		return null
	var definition = map_definition_script.new()
	if not definition.load_from_json(json_text, path, game_config):
		_fail("Could not load MapDefinition from %s." % path)
		return null
	return definition


func _verify_probe(summary: Dictionary, match_tuning: Dictionary, spawn_tuning: Dictionary, loot_tuning: Dictionary, envelope: Dictionary) -> bool:
	var bot_count := int(match_tuning.get("bot_count", 0))
	var total_entities := bot_count + 1
	var envelope_entities := int(envelope.get("total_entities", 0))
	var world_size := float(summary.get("world_size", 0.0))
	var spawn_radius := float(match_tuning.get("spawn_radius", 0.0))
	var inner_radius := float(spawn_tuning.get("inner_radius", 0.0))
	var clearance := float(spawn_tuning.get("entity_clearance", 0.0))
	var boundary_margin := world_size * 0.5 - spawn_radius - clearance
	var saturation := _annulus_saturation(total_entities, clearance, spawn_radius, inner_radius)
	if bot_count != int(envelope.get("bot_count", 0)) or total_entities != envelope_entities:
		_fail("%s must target the %s bot/entity counts." % [PROBE_PRESET, TARGET_ENVELOPE])
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
