extends SceneTree


const MAP_SPEC_PATH := "res://data/mapSpec_example.json"
const SOURCE_PRESET := "xlarge_60"
const TARGET_ENVELOPE := "target_99"


func _init():
	var game_config_script = load("res://src/core/GameConfig.gd")
	var map_definition_script = load("res://src/core/MapDefinition.gd")
	var runtime_tuning_script = load("res://src/systems/match/MatchRuntimeTuning.gd")

	var game_config = game_config_script.new()
	game_config.load_or_default()

	var json_text := _read_text(MAP_SPEC_PATH)
	if json_text.is_empty():
		return

	var definition = map_definition_script.new()
	if not definition.load_from_json(json_text, MAP_SPEC_PATH, game_config):
		_fail("MapDefinition could not load %s." % MAP_SPEC_PATH)
		return
	var issues: Array = definition.validate(game_config, SOURCE_PRESET)
	if not issues.is_empty():
		_fail("MapDefinition validation failed: %s" % _join_issues(issues))
		return
	if definition.has_scale_preset(TARGET_ENVELOPE):
		_fail("%s must remain a scale envelope, not a runtime scale preset." % TARGET_ENVELOPE)
		return
	if not definition.has_scale_envelope(TARGET_ENVELOPE):
		_fail("Missing scale envelope: %s." % TARGET_ENVELOPE)
		return

	var source := _source_metrics(definition, game_config, runtime_tuning_script, SOURCE_PRESET)
	var envelope: Dictionary = definition.get_scale_envelope(TARGET_ENVELOPE)
	if not _verify_envelope(envelope, source):
		return

	print("Scale envelope smoke passed: %s saturation=%.2f margin=%.1fm; %s min world=%.0fm spawn=%.0fm preferred world=%.0fm spawn=%.0fm." % [
		SOURCE_PRESET,
		float(source["annulus_saturation"]),
		float(source["boundary_margin"]),
		TARGET_ENVELOPE,
		float(envelope["world_size_min"]),
		float(envelope["spawn_radius_min"]),
		float(envelope["world_size_preferred"]),
		float(envelope["spawn_radius_preferred"]),
	])
	quit(0)


func _source_metrics(definition, game_config, runtime_tuning_script, preset_name: String) -> Dictionary:
	var match_tuning: Dictionary = definition.get_match_tuning(game_config, {}, preset_name)
	var runtime_tuning: Dictionary = definition.get_runtime_tuning(game_config, {}, preset_name)
	var spawn_tuning: Dictionary = runtime_tuning_script.spawn(runtime_tuning)
	var bot_count := int(match_tuning.get("bot_count", 0))
	var total_entities := bot_count + 1
	var world_size := float(definition.get_world_size())
	var spawn_radius := float(match_tuning.get("spawn_radius", 0.0))
	var inner_radius := float(spawn_tuning.get("inner_radius", 0.0))
	var clearance := float(spawn_tuning.get("entity_clearance", 0.0))
	return {
		"bot_count": bot_count,
		"total_entities": total_entities,
		"world_size": world_size,
		"spawn_radius": spawn_radius,
		"inner_radius": inner_radius,
		"entity_clearance": clearance,
		"boundary_margin": world_size * 0.5 - spawn_radius - clearance,
		"annulus_saturation": _annulus_saturation(total_entities, clearance, spawn_radius, inner_radius),
	}


func _verify_envelope(envelope: Dictionary, source: Dictionary) -> bool:
	var bot_count := int(envelope.get("bot_count", 0))
	var total_entities := int(envelope.get("total_entities", 0))
	var world_size_min := float(envelope.get("world_size_min", 0.0))
	var world_size_preferred := float(envelope.get("world_size_preferred", 0.0))
	var spawn_radius_min := float(envelope.get("spawn_radius_min", 0.0))
	var spawn_radius_preferred := float(envelope.get("spawn_radius_preferred", 0.0))
	var inner_radius := float(envelope.get("inner_radius", 0.0))
	var clearance := float(envelope.get("entity_clearance", 0.0))
	var boundary_margin_min := float(envelope.get("boundary_margin_min", 0.0))
	var max_saturation := float(envelope.get("max_annulus_saturation", 0.0))
	var preferred_saturation := float(envelope.get("preferred_annulus_saturation", 0.0))
	if bot_count != 99 or total_entities != 100:
		_fail("%s must target 99 bots / 100 total entities." % TARGET_ENVELOPE)
		return false
	if world_size_min <= float(source["world_size"]):
		_fail("%s world_size_min must be larger than current map." % TARGET_ENVELOPE)
		return false
	if spawn_radius_min <= float(source["spawn_radius"]):
		_fail("%s spawn_radius_min must be larger than current spawn radius." % TARGET_ENVELOPE)
		return false
	if world_size_min * 0.5 - spawn_radius_min - clearance < boundary_margin_min:
		_fail("%s min boundary margin is too small." % TARGET_ENVELOPE)
		return false
	var min_saturation := _annulus_saturation(total_entities, clearance, spawn_radius_min, inner_radius)
	if min_saturation > max_saturation:
		_fail("%s min envelope saturation %.3f exceeds %.3f." % [TARGET_ENVELOPE, min_saturation, max_saturation])
		return false
	var preferred_margin := world_size_preferred * 0.5 - spawn_radius_preferred - clearance
	if preferred_margin < boundary_margin_min:
		_fail("%s preferred boundary margin is too small." % TARGET_ENVELOPE)
		return false
	var preferred_value := _annulus_saturation(total_entities, clearance, spawn_radius_preferred, inner_radius)
	if preferred_value > preferred_saturation:
		_fail("%s preferred saturation %.3f exceeds %.3f." % [TARGET_ENVELOPE, preferred_value, preferred_saturation])
		return false
	if min_saturation > float(source["annulus_saturation"]) + 0.005:
		_fail("%s min saturation must not exceed the current 60-bot envelope." % TARGET_ENVELOPE)
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
