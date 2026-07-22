extends SceneTree

func _init():
	if not _verify_clean_win_ratio():
		quit(1)
		return
	if not _verify_health_capacity_lock_paths():
		quit(1)
		return
	if not _verify_hell_starting_health_contract():
		quit(1)
		return

	print("Mission health rules smoke passed.")
	quit(0)


func _verify_clean_win_ratio() -> bool:
	var catalog_script = load("res://src/systems/mission/MissionCatalog.gd")
	var evaluator_script = load("res://src/systems/mission/MissionEvaluator.gd")
	var hud_formatter_script = load("res://src/systems/mission/MissionHudFormatter.gd")
	var description_formatter_script = load("res://src/systems/mission/MissionDescriptionFormatter.gd")
	var tuning_script = load("res://src/systems/mission/MissionTuning.gd")

	var mission = _find_mission(catalog_script.bonus_missions(), "clean_win")
	if mission == null:
		return _fail("clean_win mission was not found.")
	if absf(float(mission.target_value) - tuning_script.CLEAN_WIN_HP_RATIO) > 0.001:
		return _fail("clean_win target_value should be the max-HP ratio tuning value.")
	if evaluator_script.evaluate(mission, {"won": true, "player_hp": 49.0, "player_max_hp": 100.0}):
		return _fail("clean_win passed below 50% HP.")
	if not evaluator_script.evaluate(mission, {"won": true, "player_hp": 50.0, "player_max_hp": 100.0}):
		return _fail("clean_win did not pass at 50% HP.")
	if not evaluator_script.evaluate(mission, {"won": true, "player_hp": 1.0, "player_max_hp": 1.0}):
		return _fail("clean_win did not pass at 1/1 HP.")
	if evaluator_script.evaluate(mission, {"won": false, "player_hp": 100.0, "player_max_hp": 100.0}):
		return _fail("clean_win passed without winning.")

	var hud_text: String = hud_formatter_script.bonus_hud_text(mission, {"current_hp": 1.0, "current_max_hp": 1.0, "kills": 0})
	if hud_text.find("1 / 1") < 0 or hud_text.find(tuning_script.clean_win_ratio_label()) < 0:
		return _fail("clean_win HUD should display current/max HP and the ratio requirement.")
	var description: String = description_formatter_script.bonus_description(mission)
	if description.find(tuning_script.clean_win_ratio_label()) < 0:
		return _fail("clean_win description should display the ratio requirement.")
	return true


func _verify_health_capacity_lock_paths() -> bool:
	var catalog_script = load("res://src/core/ArtifactCatalog.gd")
	var artifact := _find_artifact(catalog_script.starting_artifacts(1), "zone_battery")
	if artifact.is_empty():
		return _fail("zone_battery artifact was not found.")
	var mods: Dictionary = artifact.get("mods", {})
	if float(mods.get("heal_mult", 1.0)) != 0.0:
		return _fail("zone_battery should mark healing as unavailable.")

	var player_source := _read_text("res://src/entities/player/Player.gd")
	if player_source.find("func apply_health_capacity_lock") < 0:
		return _fail("Player is missing apply_health_capacity_lock().")
	if player_source.find("PLAYER_HEALTH_POLICY.capacity_locked_state") < 0:
		return _fail("Health capacity lock should use the tested health policy.")
	if player_source.find("_heal_regen = 0.0") < 0:
		return _fail("Health capacity lock should cancel pending heal regen.")
	if player_source.find("float(mods.get(\"heal_mult\", 1.0)) == 0.0") < 0:
		return _fail("Player artifact apply should detect heal_mult=0.")
	if player_source.find("apply_health_capacity_lock(1.0)") < 0:
		return _fail("Player artifact apply should lock max HP to 1 for no-heal artifacts.")
	return true


func _verify_hell_starting_health_contract() -> bool:
	var health_policy = load("res://src/entities/player/PlayerHealthPolicy.gd")
	var hell_start: Dictionary = health_policy.starting_state(100.0, 1.0)
	if not is_equal_approx(float(hell_start.get("current_health", 0.0)), 1.0):
		return _fail("Hell must start the player at 1 current HP.")
	if not is_equal_approx(float(hell_start.get("max_health", 0.0)), 100.0):
		return _fail("Hell start must preserve max HP so healing can raise current HP.")
	var locked: Dictionary = health_policy.capacity_locked_state(100.0, 1.0)
	if not is_equal_approx(float(locked.get("current_health", 0.0)), 1.0) \
			or not is_equal_approx(float(locked.get("max_health", 0.0)), 1.0):
		return _fail("No-heal artifacts must still lock current and max HP to 1.")

	var player_source := _read_text("res://src/entities/player/Player.gd")
	var main_source := _read_text("res://src/Main.gd")
	if player_source.find("PLAYER_HEALTH_POLICY.starting_state") < 0:
		return _fail("Player starting HP must use the tested health policy.")
	if main_source.find("p.apply_starting_health(1.0)") < 0:
		return _fail("Hell spawn must use the recoverable 1 HP start path.")
	if main_source.find("p.apply_health_capacity_lock(1.0)") >= 0:
		return _fail("Hell spawn must not lock max HP to 1.")
	return true


func _find_mission(missions: Array, id: String):
	for mission in missions:
		if String(mission.id) == id:
			return mission
	return null


func _find_artifact(artifacts: Array, id: String) -> Dictionary:
	for artifact in artifacts:
		if String(artifact.get("id", "")) == id:
			return artifact
	return {}


func _read_text(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _fail(message: String) -> bool:
	push_error(message)
	return false
