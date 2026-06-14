extends SceneTree

const CANDIDATE_PATH := "res://data/mapSpec_night_forest_candidate.json"
const PLAYABLE_PRESET := "playable_pacing_v1"


func _init():
	var game_config_script = load("res://src/core/GameConfig.gd")
	var map_definition_script = load("res://src/core/MapDefinition.gd")
	var match_bootstrap_script = load("res://src/systems/match/MatchBootstrap.gd")
	var zone_controller_script = load("res://src/systems/zone/ZoneController.gd")

	var game_config = game_config_script.new()
	game_config.load_or_default()

	var definition = map_definition_script.new()
	var json_text := _read_text(CANDIDATE_PATH)
	if json_text.is_empty():
		return
	if not definition.load_from_json(json_text, CANDIDATE_PATH, game_config):
		_fail("Could not load candidate map definition.")
		return

	var zone_tuning: Dictionary = definition.get_zone_tuning(game_config, {}, PLAYABLE_PRESET)
	var zone = match_bootstrap_script.create_zone(
		zone_controller_script,
		float(zone_tuning.get("wait_time", 0.0)),
		float(zone_tuning.get("shrink_time", 0.0)),
		float(zone_tuning.get("damage_per_second", 0.0)),
		float(zone_tuning.get("initial_timer", 0.0)),
		zone_tuning.get("stages", {}),
		Callable(),
		Callable(),
		float(zone_tuning.get("initial_radius", 50.0)),
		float(zone_tuning.get("next_radius", -1.0))
	)

	var expected_initial := 86.0
	if absf(float(zone.current_radius) - expected_initial) > 0.01:
		_fail("Zone initial radius was not applied: got %.2f expected %.2f." % [float(zone.current_radius), expected_initial])
		return

	var expected_next := expected_initial * 0.6
	if absf(float(zone.next_radius) - expected_next) > 0.01:
		_fail("Zone next radius should derive from tuned initial radius: got %.2f expected %.2f." % [float(zone.next_radius), expected_next])
		return

	var match_tuning: Dictionary = definition.get_match_tuning(game_config, {}, PLAYABLE_PRESET)
	var spawn_radius := float(match_tuning.get("spawn_radius", 0.0))
	if float(zone.current_radius) * 0.95 < spawn_radius:
		_fail("Opening zone radius leaves spawn radius in immediate ZONE_ESCAPE.")
		return

	print("zone initial radius tuning smoke passed: current=%.1f next=%.1f spawn=%.1f." % [
		float(zone.current_radius),
		float(zone.next_radius),
		spawn_radius,
	])
	quit(0)


func _read_text(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("Could not open %s." % path)
		return ""
	return file.get_as_text()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
