extends SceneTree


const CANDIDATE_PATH := "res://data/mapSpec_night_forest_expanded_candidate.json"
const CANDIDATE_ID := "night_forest_expanded_whitebox"
const SOURCE_PRESET := "xlarge_60"
const TARGET_ENVELOPE := "target_99"


func _init():
	var game_config_script = load("res://src/core/GameConfig.gd")
	var map_definition_script = load("res://src/core/MapDefinition.gd")
	var runtime_tuning_script = load("res://src/systems/match/MatchRuntimeTuning.gd")

	var game_config = game_config_script.new()
	game_config.load_or_default()

	var json_text := _read_text(CANDIDATE_PATH)
	if json_text.is_empty():
		return

	var definition = map_definition_script.new()
	if not definition.load_from_json(json_text, CANDIDATE_PATH, game_config):
		_fail("MapDefinition could not load %s." % CANDIDATE_PATH)
		return
	var issues: Array = definition.validate(game_config, SOURCE_PRESET)
	if not issues.is_empty():
		_fail("Expanded Night candidate validation failed: %s" % _join_issues(issues))
		return
	if definition.id != CANDIDATE_ID:
		_fail("Expanded Night candidate id mismatch: %s." % definition.id)
		return
	if definition.has_scale_preset(TARGET_ENVELOPE):
		_fail("%s must remain a scale envelope, not a runtime scale preset." % TARGET_ENVELOPE)
		return
	if not definition.has_scale_envelope(TARGET_ENVELOPE):
		_fail("Missing scale envelope: %s." % TARGET_ENVELOPE)
		return

	var summary: Dictionary = definition.summary(game_config, SOURCE_PRESET)
	var source := _source_metrics(definition, game_config, runtime_tuning_script, SOURCE_PRESET)
	var envelope: Dictionary = definition.get_scale_envelope(TARGET_ENVELOPE)
	if not _verify_candidate(definition, summary, source, envelope):
		return

	print("Expanded Night candidate smoke passed: %s world=%.0fm spawn=%.0fm margin=%.1fm target_99 preferred saturation=%.2f." % [
		SOURCE_PRESET,
		float(source["world_size"]),
		float(source["spawn_radius"]),
		float(source["boundary_margin"]),
		float(source["target_saturation"]),
	])
	quit(0)


func _source_metrics(definition, game_config, runtime_tuning_script, preset_name: String) -> Dictionary:
	var match_tuning: Dictionary = definition.get_match_tuning(game_config, {}, preset_name)
	var runtime_tuning: Dictionary = definition.get_runtime_tuning(game_config, {}, preset_name)
	var spawn_tuning: Dictionary = runtime_tuning_script.spawn(runtime_tuning)
	var world_size := float(definition.get_world_size())
	var spawn_radius := float(match_tuning.get("spawn_radius", 0.0))
	var inner_radius := float(spawn_tuning.get("inner_radius", 0.0))
	var clearance := float(spawn_tuning.get("entity_clearance", 0.0))
	return {
		"bot_count": int(match_tuning.get("bot_count", 0)),
		"loot_count": int(match_tuning.get("loot_count", 0)),
		"world_size": world_size,
		"spawn_radius": spawn_radius,
		"inner_radius": inner_radius,
		"entity_clearance": clearance,
		"safe_spawn_attempts": int(spawn_tuning.get("safe_spawn_attempts", 0)),
		"boundary_margin": world_size * 0.5 - spawn_radius - clearance,
		"target_saturation": 0.0,
	}


func _verify_candidate(definition, summary: Dictionary, source: Dictionary, envelope: Dictionary) -> bool:
	var bot_count := int(source.get("bot_count", 0))
	var world_size := float(source.get("world_size", 0.0))
	var spawn_radius := float(source.get("spawn_radius", 0.0))
	var inner_radius := float(source.get("inner_radius", 0.0))
	var clearance := float(source.get("entity_clearance", 0.0))
	var boundary_margin := float(source.get("boundary_margin", 0.0))
	var world_size_preferred := float(envelope.get("world_size_preferred", 0.0))
	var spawn_radius_min := float(envelope.get("spawn_radius_min", 0.0))
	var spawn_radius_preferred := float(envelope.get("spawn_radius_preferred", 0.0))
	var boundary_margin_min := float(envelope.get("boundary_margin_min", 0.0))
	var target_entities := int(envelope.get("total_entities", 0))
	var target_saturation_limit := float(envelope.get("preferred_annulus_saturation", 0.0))
	var target_saturation := _annulus_saturation(target_entities, clearance, spawn_radius_preferred, inner_radius)
	source["target_saturation"] = target_saturation

	if bot_count != 60:
		_fail("%s must remain the 60-bot candidate smoke preset." % SOURCE_PRESET)
		return false
	if int(source.get("loot_count", 0)) < 180:
		_fail("%s loot_count is too low for expanded candidate density checks." % SOURCE_PRESET)
		return false
	if int(source.get("safe_spawn_attempts", 0)) < 120:
		_fail("%s safe_spawn_attempts must be at least 120." % SOURCE_PRESET)
		return false
	if world_size < world_size_preferred:
		_fail("Candidate world size %.1f is below %s preferred %.1f." % [world_size, TARGET_ENVELOPE, world_size_preferred])
		return false
	if spawn_radius < spawn_radius_min:
		_fail("Candidate spawn radius %.1f is below %s minimum %.1f." % [spawn_radius, TARGET_ENVELOPE, spawn_radius_min])
		return false
	if boundary_margin < boundary_margin_min:
		_fail("Candidate boundary margin %.1f is below %.1f." % [boundary_margin, boundary_margin_min])
		return false
	if target_saturation > target_saturation_limit:
		_fail("Candidate target saturation %.3f exceeds %.3f." % [target_saturation, target_saturation_limit])
		return false
	if int(summary.get("poi_count", 0)) < 10:
		_fail("Candidate needs at least 10 POIs.")
		return false
	if int(summary.get("obstacle_count", 0)) < 70:
		_fail("Candidate needs at least 70 obstacles.")
		return false
	if _count_obstacles_near(definition, "tree_cluster", Vector2.ZERO, 15.0) < 2:
		_fail("Central Meadow needs two close tree-cover shoulders.")
		return false
	if _count_obstacles_near(definition, "bush_patch", Vector2.ZERO, 12.0) < 2:
		_fail("Central Meadow needs two close concealment shoulders.")
		return false
	var south_center := Vector2(20.0, -98.0)
	if _count_obstacles_near(definition, "tree_cluster", south_center, 12.0) < 1:
		_fail("South Creek Bend needs close physical cover.")
		return false
	if _count_obstacles_near(definition, "bush_patch", south_center, 12.0) < 1:
		_fail("South Creek Bend needs close concealment.")
		return false
	if int(summary.get("route_count", 0)) < 6:
		_fail("Candidate needs at least 6 strategic route descriptors.")
		return false
	if int(summary.get("scale_preset_count", 0)) != 4:
		_fail("Candidate should only expose gameplay presets plus the nav_hotspot_1 regression preset.")
		return false
	return true


func _count_obstacles_near(definition, type_name: String, center: Vector2, radius: float) -> int:
	var count := 0
	for obstacle in definition.get_obstacle_descriptors():
		if String(obstacle.get("type", "")) != type_name:
			continue
		var position: Vector2 = obstacle.get("pos_2d", Vector2.INF)
		if position.distance_to(center) <= radius:
			count += 1
	return count


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
