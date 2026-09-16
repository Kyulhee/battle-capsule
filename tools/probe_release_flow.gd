extends SceneTree
## External harness: no game preloads. The runner selects PCK or workspace code.

var _args: Dictionary = {}
var _checks: Array[String] = []
var _failed := false
var _records: Array = []
var _restart_count := 1
var _cycles: Array[Dictionary] = []
var _menu_label := ""


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var index := arg.find("=")
		if index > 0:
			_args[arg.left(index)] = arg.substr(index + 1)
	call_deferred("_run")


func _check(ok: bool, label: String) -> bool:
	if not ok:
		_failed = true
		push_error("RELEASE_FLOW: " + label)
	else:
		_checks.append(label)
	return ok


func _run() -> void:
	var raw_count := String(_args.get("restart_count", "1"))
	if not _check(raw_count in ["1", "5"], "bounded_restart_count"):
		quit(1)
		return
	_restart_count = int(raw_count)
	var expected := String(_args.get("expected_user_dir", "")).replace("\\", "/").to_lower()
	var actual := OS.get_user_data_dir().replace("\\", "/").to_lower()
	if not _check(not expected.is_empty() and actual == expected, "user_dir_isolated"):
		quit(1)
		return
	var phase := String(_args.get("phase", ""))
	if phase == "isolation":
		_check(not root.has_node("Telemetry") and not root.has_node("Sfx"), "no_autoloads_in_preflight")
		_check(not ResourceLoader.exists("res://src/Main.tscn"), "empty_host_in_preflight")
		_finish()
		return
	if not _check(phase in ["write_restart", "relaunch"], "known_phase"):
		_finish()
		return
	var tel = root.get_node_or_null("Telemetry")
	if not _check(tel != null and root.has_node("Sfx"), "runtime_autoloads_present"):
		_finish()
		return
	_check(tel.history_path == "user://match_history.json" and tel.sim_result_path == "user://sim_result_latest.json", "default_persistence_paths")
	var label = load("res://src/ui/BuildVersionLabel.gd").new()
	label._ready()
	_menu_label = label.text
	_check(_menu_label == String(_args.get("expected_menu", "v2.1.0-demo-dev | E-067")), "runtime_menu_label")
	label.free()
	if not _check(change_scene_to_file("res://src/Main.tscn") == OK, "runtime_scene_loaded"):
		_finish()
		return
	await scene_changed
	var main = current_scene
	_check(not main.is_simulation and not main.game_over, "normal_menu")
	if phase == "relaunch":
		_verify_saved(main, tel)
		main._on_records_pressed()
		_check(main.get_node("CanvasLayer/Control/RecordsPanel").visible, "relaunch_records_panel")
		await _shutdown()
		return
	if not _check(tel.load_history().is_empty() and not FileAccess.file_exists("user://achievements.json"), "fresh_profile_empty"):
		await _shutdown()
		return
	main._on_settings_volume_changed(0.37)
	main._on_settings_closed(0.37)
	main._on_difficulty_btn(1)
	main.get_node("CanvasLayer/Control/MainMenuPanel/VBoxContainer/StartBtn").pressed.emit()
	_check(is_instance_valid(main._artifact_panel), "start_button_artifact_selection")
	var artifact: Dictionary = load("res://src/core/ArtifactCatalog.gd").starting_artifacts(1)[0]
	main._on_artifact_selected(artifact)
	_check(main.alive_count == 61 and not main.is_simulation, "normal_61_participant_start")
	var previous_ids: Array[int] = []
	for cycle in range(_restart_count + 1):
		main = current_scene
		# Freeze gameplay, not the SceneTree harness/timers. No balance measurements.
		main.process_mode = Node.PROCESS_MODE_DISABLED
		var old_nodes_freed := true
		for old_id in previous_ids:
			old_nodes_freed = old_nodes_freed and not is_instance_id_valid(old_id)
		_check(old_nodes_freed, "previous_scene_nodes_freed_%d" % cycle)
		_check(not main.game_over and main.alive_count == 61 and main.match_timer == 0.0 and not main.is_simulation, "restart_match_reset_%d" % cycle)
		_check(int(main.difficulty) == 1 and main.player_ref.active_artifact.id == artifact.id, "restart_difficulty_artifact_%d" % cycle)
		_check(not tel.has_meta("_restart_difficulty") and not tel.has_meta("_restart_artifact"), "restart_metadata_consumed_%d" % cycle)
		_check(tel.match_in_progress and tel.metrics.session.kills == 0 and main.mission_tracker._medkits_used == 0 and not main.mission_tracker.pressure_active, "restart_telemetry_mission_reset_%d" % cycle)
		_check(tel.get_history_for_difficulty(1) == _records, "restart_did_not_duplicate_record_%d" % cycle)
		_check(is_equal_approx(main.settings_manager.current_volume(), 0.37), "restart_settings_retained_%d" % cycle)
		var sample := {
			"cycle": cycle, "scene_id": main.get_instance_id(),
			"actors": get_nodes_in_group("actors").size(),
			"bots": get_nodes_in_group("bots").size(),
			"players": get_nodes_in_group("players").size(),
			"previous_node_count": previous_ids.size(), "previous_nodes_freed": old_nodes_freed,
		}
		_check(sample.actors == 61 and sample.bots == 60 and sample.players == 1, "exact_participant_groups_%d" % cycle)
		previous_ids.clear()
		_collect_node_ids(main, previous_ids)
		await create_timer(0.35).timeout # Bot._ready deferred initialization completes.
		_select_clean_win(main)
		# A dirty mission counter must not survive the next scene reload.
		main.mission_tracker._medkits_used = 2
		var won := cycle % 2 == 0
		if won:
			for bot in get_nodes_in_group("bots"):
				bot.die()
			_check(main.game_over and main.alive_count == 1, "death_signals_trigger_victory_%d" % cycle)
		else:
			main.player_ref.die()
		_check_result(main, tel, won, 1 if won else 61, cycle + 1)
		_records = tel.get_history_for_difficulty(1).duplicate(true)
		sample["record_count"] = _records.size()
		sample["won"] = won
		_cycles.append(sample)
		# Drain deferred telemetry writes before starting a new match.
		await process_frame
		if _failed or cycle == _restart_count:
			break
		var restart := _button(main.get_node("CanvasLayer/Control/ResultPanel"), "RESTART")
		if not _check(restart != null, "result_restart_button_%d" % cycle):
			break
		restart.pressed.emit()
		await scene_changed
	_verify_saved(main, tel)
	await _shutdown()


func _collect_node_ids(node: Node, ids: Array[int]) -> void:
	ids.append(node.get_instance_id())
	for child in node.get_children():
		_collect_node_ids(child, ids)


func _select_clean_win(main) -> void:
	for mission in load("res://src/systems/mission/MissionCatalog.gd").bonus_missions():
		if mission.id == "clean_win":
			main.mission_tracker.active_mission = mission
			return
	_check(false, "clean_win_mission_exists")


func _check_result(main, tel, won: bool, rank: int, expected_count: int) -> void:
	var nodes: Dictionary = main._result_panel_nodes
	_check(nodes.header.text == ("VICTORY!" if won else "ELIMINATED"), "result_header_%s" % won)
	_check(nodes.rank.text == "RANK  #%d" % rank, "result_rank_%d" % rank)
	var bonus: int = main.mission_tracker.active_mission.score_bonus if won else 0
	var expected: int = tel.calculate_current_score(bonus)
	_check(nodes.score.text == "SCORE  %d" % expected, "result_score_%s" % won)
	_check("MISSION CLEAR" in nodes.mission.text if won else "MISSION FAILED" in nodes.mission.text, "result_mission_%s" % won)
	var records: Array = tel.get_history_for_difficulty(1)
	if not _check(records.size() == expected_count, "record_count_%d" % expected_count):
		return
	var record: Dictionary = records[0 if won else -1]
	_check(int(record.get("score", -1)) == expected and int(record.get("mission_bonus", -1)) == bonus, "saved_score_bonus_%s" % won)


func _verify_saved(main, tel) -> void:
	var records: Array = tel.get_history_for_difficulty(1)
	var expected_count := _restart_count + 1
	_check(records.size() == expected_count, "persistent_record_count")
	var wins := 0
	var losses := 0
	for record in records:
		_check(record.difficulty == 1 and record.kills == 0 and record.assists == 0, "saved_record_session")
		if record.win:
			wins += 1
			_check(record.rank == 1 and record.mission_bonus == 500 and record.score == 2450, "saved_victory_score")
		else:
			losses += 1
			_check(record.rank == 61 and record.mission_bonus == 0 and record.score == 0, "saved_defeat_score")
	_check(wins == expected_count / 2 and losses == expected_count / 2, "alternating_results_exact")
	var badges: Dictionary = load("res://src/systems/mission/MissionBadgeStore.gd").load_achievements()
	_check(badges.get("badges", []) == ["clean_win"], "one_success_badge_only")
	_check(is_equal_approx(main.settings_manager.current_volume(), 0.37), "saved_volume")
	for path in ["user://match_history.json", "user://achievements.json"]:
		var envelope = JSON.parse_string(FileAccess.get_file_as_string(path))
		_check(envelope is Dictionary and envelope.get("schema_version", 0) == 1, "schema_1_" + path.get_file())
	_records = records.duplicate(true)


func _button(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for child in node.get_children():
		var found := _button(child, text)
		if found != null:
			return found
	return null


func _shutdown() -> void:
	if is_instance_valid(current_scene):
		current_scene.process_mode = Node.PROCESS_MODE_DISABLED
	await create_timer(1.2).timeout
	var sfx = root.get_node_or_null("Sfx")
	if sfx != null:
		sfx.stop_all_for_shutdown()
	await create_timer(1.0).timeout
	_finish()


func _finish() -> void:
	var file := FileAccess.open(String(_args.get("report_path", "")), FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"passed": not _failed, "checks": _checks,
		"user_dir": OS.get_user_data_dir(), "records": _records,
		"restart_count": _restart_count, "cycles": _cycles,
		"menu_label": _menu_label,
		"runtime_source": String(_args.get("runtime_source", "e067"))}, "\t"))
	file.close()
	quit(1 if _failed else 0)
