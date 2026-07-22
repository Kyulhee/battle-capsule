extends SceneTree


const CANDIDATE_PATH := "res://data/mapSpec_night_forest_expanded_candidate.json"
const CANDIDATE_ID := "night_forest_m1_candidate"
const SOURCE_PRESET := "night_br_m1_60"
const LEGACY_PRESET := "xlarge_60"
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
	var legacy_source := _source_metrics(definition, game_config, runtime_tuning_script, LEGACY_PRESET)
	if source != legacy_source:
		_fail("Legacy xlarge_60 preset must remain an exact compatibility alias for night_br_m1_60.")
		return
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
	if int(summary.get("surface_zone_count", 0)) < 10:
		_fail("Candidate needs regional ground bands and physical paths.")
		return false
	if not _has_poi(definition, "Cabin Row"):
		_fail("Expanded candidate must expose Cabin Row as a player-facing POI.")
		return false
	var cabin_row := _poi_by_name(definition, "Cabin Row")
	var strategic_anchors: Array = cabin_row.get("strategic_anchors", [])
	if strategic_anchors.size() != 7:
		_fail("Cabin Row needs seven AI strategic anchors.")
		return false
	var anchor_roles := _anchor_role_counts(strategic_anchors)
	if int(anchor_roles.get("objective", 0)) != 1 \
			or int(anchor_roles.get("entry", 0)) != 3 \
			or int(anchor_roles.get("outer", 0)) != 3:
		_fail("Cabin Row strategic anchors must expose objective=1, entry=3, outer=3.")
		return false
	if not _has_poi(definition, "West Ridge Watch Post"):
		_fail("Expanded candidate must expose West Ridge Watch Post.")
		return false
	var watch_post := _poi_by_name(definition, "West Ridge Watch Post")
	var watch_identity: Dictionary = watch_post.get("identity", {})
	if String(watch_identity.get("theme", "")) != "ridge_watch_post":
		_fail("West Ridge Watch Post needs a distinct region identity.")
		return false
	var watch_anchors: Array = watch_post.get("strategic_anchors", [])
	var watch_anchor_roles := _anchor_role_counts(watch_anchors)
	if watch_anchors.size() != 5 \
			or int(watch_anchor_roles.get("objective", 0)) != 1 \
			or int(watch_anchor_roles.get("entry", 0)) != 2 \
			or int(watch_anchor_roles.get("outer", 0)) != 2:
		_fail("West Ridge strategic anchors must expose objective=1, entry=2, outer=2.")
		return false
	if definition.get_surface_id_at(Vector2(-90.0, 60.0)) != "grass":
		_fail("West forest band must resolve to grass.")
		return false
	if definition.get_surface_id_at(Vector2(0.0, 98.0)) != "dirt":
		_fail("Cabin Row yard must override the forest edge as dirt.")
		return false
	if definition.get_surface_id_at(Vector2(-56.0, 31.0)) != "dirt" \
			or definition.get_surface_id_at(Vector2(-89.0, -3.0)) != "dirt":
		_fail("West Ridge needs a dirt clearing and exposed service track.")
		return false
	if absf(definition.get_surface_movement_multiplier_at(Vector2(-90.0, 60.0)) - 0.84) > 0.001:
		_fail("Forest terrain must apply the slower off-road movement contract.")
		return false
	if absf(definition.get_surface_movement_multiplier_at(Vector2(0.0, 40.0)) - 1.0) > 0.001:
		_fail("Main service road must preserve full travel speed.")
		return false
	if absf(definition.get_surface_movement_multiplier_at(Vector2(30.0, 70.0)) - 0.92) > 0.001:
		_fail("Unmarked terrain must use the candidate's intermediate movement speed.")
		return false
	var road_waypoints: Array[Vector2] = definition.get_road_travel_waypoints(
		Vector2(-40.0, -70.0),
		Vector2(0.0, 100.0)
	)
	if road_waypoints.size() < 3:
		_fail("Long strategic rotations must preserve curved road waypoints, not only entry and exit.")
		return false
	for road_waypoint in road_waypoints:
		if absf(definition.get_surface_movement_multiplier_at(road_waypoint) - 1.0) > 0.001:
			_fail("Strategic road waypoints must remain on full-speed path surfaces.")
			return false
	if _count_prop_obstacles(definition, "landmark.cabin") != 3:
		_fail("Cabin Row needs three cabin landmarks.")
		return false
	if _count_prop_obstacles(definition, "landmark.wall") != 6:
		_fail("Cabin Row needs six wall segments around three open entries.")
		return false
	if _count_prop_obstacles(definition, "forest.tree") < 6:
		_fail("Cabin Row needs a physical tree boundary.")
		return false
	for prop_id in [
		"landmark.watchtower",
		"landmark.camp.tarp",
		"forest.fallen.tree",
		"forest.log.pile",
	]:
		if _count_prop_obstacles(definition, prop_id) != 1:
			_fail("West Ridge needs one '%s' landmark prop." % prop_id)
			return false
	if _count_prop_obstacles(definition, "forest.rock.large") != 2:
		_fail("West Ridge needs two large ridge rocks.")
		return false
	if _count_named_compound_cover(definition, "west_ridge_watch_post", "hard") != 5:
		_fail("West Ridge needs five hard-cover anchors.")
		return false
	if _count_named_compound_cover(definition, "west_ridge_watch_post", "screen") != 4:
		_fail("West Ridge needs three forest screens and one tarp screen.")
		return false
	var tarp := _obstacle_by_prop(definition, "landmark.camp.tarp")
	if String(tarp.get("cover_class", "")) != "screen":
		_fail("West Ridge tarp must block vision without blocking ballistics.")
		return false
	if _count_compound_cover(definition, "hard") != 9:
		_fail("Cabin Row needs nine explicit hard-cover masses.")
		return false
	if _count_compound_cover(definition, "screen") != 6:
		_fail("Cabin Row needs six explicit outer vision screens.")
		return false
	for entry_id in ["south", "west", "east"]:
		if _count_compound_entry(definition, "perimeter", entry_id) != 2:
			_fail("Cabin Row entry '%s' needs two perimeter shoulders." % entry_id)
			return false
		if _count_compound_entry(definition, "approach_cover", entry_id) < 1:
			_fail("Cabin Row entry '%s' needs approach cover." % entry_id)
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
	if int(summary.get("scale_preset_count", 0)) != 5:
		_fail("Candidate must expose the M1 preset, compatibility alias, baseline, probe, and nav regression presets.")
		return false
	return true


func _has_poi(definition, poi_name: String) -> bool:
	for poi in definition.get_poi_descriptors():
		if String(poi.get("name", "")) == poi_name:
			return true
	return false


func _count_prop_obstacles(definition, prop_id: String) -> int:
	var count := 0
	for obstacle in definition.get_obstacle_descriptors():
		if String(obstacle.get("prop_id", "")) == prop_id:
			count += 1
	return count


func _obstacle_by_prop(definition, prop_id: String) -> Dictionary:
	for obstacle in definition.get_obstacle_descriptors():
		if String(obstacle.get("prop_id", "")) == prop_id:
			return obstacle
	return {}


func _count_named_compound_cover(definition, compound_id: String, cover_class: String) -> int:
	var count := 0
	for obstacle in definition.get_obstacle_descriptors():
		if String(obstacle.get("compound_id", "")) == compound_id \
				and String(obstacle.get("cover_class", "")) == cover_class:
			count += 1
	return count


func _poi_by_name(definition, poi_name: String) -> Dictionary:
	for poi in definition.get_poi_descriptors():
		if String(poi.get("name", "")) == poi_name:
			return poi
	return {}


func _anchor_role_counts(anchors: Array) -> Dictionary:
	var counts := {}
	for anchor in anchors:
		if not anchor is Dictionary:
			continue
		var role := String(anchor.get("role", ""))
		counts[role] = int(counts.get(role, 0)) + 1
	return counts


func _count_compound_cover(definition, cover_class: String) -> int:
	var count := 0
	for obstacle in definition.get_obstacle_descriptors():
		if String(obstacle.get("compound_id", "")) == "cabin_row" \
				and String(obstacle.get("cover_class", "")) == cover_class:
			count += 1
	return count


func _count_compound_entry(definition, role: String, entry_id: String) -> int:
	var count := 0
	for obstacle in definition.get_obstacle_descriptors():
		if String(obstacle.get("compound_id", "")) == "cabin_row" \
				and String(obstacle.get("compound_role", "")) == role \
				and String(obstacle.get("entry_id", "")) == entry_id:
			count += 1
	return count


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
