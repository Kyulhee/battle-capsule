extends SceneTree


const CANDIDATE_PATH := "res://data/mapSpec_night_forest_expanded_candidate.json"
const SOURCE_PRESET := "xlarge_60"


func _init():
	var match_tuning_script = load("res://src/systems/match/MatchTuning.gd")
	var game_config_script = load("res://src/core/GameConfig.gd")
	var map_definition_script = load("res://src/core/MapDefinition.gd")

	var path_arg: Dictionary = match_tuning_script.from_cmdline_arg("map_spec_path=%s" % CANDIDATE_PATH)
	if String(path_arg.get("map_spec_path", "")) != CANDIDATE_PATH:
		_fail("map_spec_path CLI arg did not preserve the candidate path.")
		return
	var alias_arg: Dictionary = match_tuning_script.from_cmdline_arg("map_definition_path=%s" % CANDIDATE_PATH)
	if String(alias_arg.get("map_spec_path", "")) != CANDIDATE_PATH:
		_fail("map_definition_path CLI alias did not map to map_spec_path.")
		return
	var preset_arg: Dictionary = match_tuning_script.from_cmdline_arg("map_scale_preset=%s" % SOURCE_PRESET)
	if String(preset_arg.get("scale_preset", "")) != SOURCE_PRESET:
		_fail("map_scale_preset CLI arg did not parse correctly.")
		return

	var game_config = game_config_script.new()
	game_config.load_or_default()
	var json_text := _read_text(String(path_arg["map_spec_path"]))
	if json_text.is_empty():
		return
	var definition = map_definition_script.new()
	if not definition.load_from_json(json_text, String(path_arg["map_spec_path"]), game_config):
		_fail("Candidate MapDefinition could not load from parsed CLI path.")
		return
	var issues: Array = definition.validate(game_config, String(preset_arg["scale_preset"]))
	if not issues.is_empty():
		_fail("Candidate MapDefinition validation failed from parsed CLI path: %s" % _join_issues(issues))
		return
	var summary: Dictionary = definition.summary(game_config, String(preset_arg["scale_preset"]))
	if String(summary.get("source_path", "")) != CANDIDATE_PATH:
		_fail("Candidate summary source_path mismatch: %s" % summary.get("source_path", ""))
		return
	if int(summary.get("bot_count", 0)) != 60:
		_fail("Candidate CLI smoke did not apply xlarge_60 bot_count.")
		return
	if float(summary.get("world_size", 0.0)) != 260.0:
		_fail("Candidate CLI smoke did not load the 260m map.")
		return

	print("Map runtime path smoke passed: %s %s bots=%d world=%.0fm." % [
		CANDIDATE_PATH,
		SOURCE_PRESET,
		int(summary.get("bot_count", 0)),
		float(summary.get("world_size", 0.0)),
	])
	quit(0)


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
