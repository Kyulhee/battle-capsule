extends SceneTree

const VersionedJsonStoreScript = preload("res://src/core/VersionedJsonStore.gd")
const TelemetryScript = preload("res://src/core/Telemetry.gd")
const MissionBadgeStoreScript = preload("res://src/systems/mission/MissionBadgeStore.gd")

var _test_paths: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var base_path := "C:/tmp/battle_capsule_persistence_verify_%d" % Time.get_ticks_usec()
	if not _verify_versioned_json_recovery(base_path + "_history.json"):
		_finish(false)
		return
	if not _verify_legacy_json_migration(base_path + "_legacy.json"):
		_finish(false)
		return
	if not _verify_rollback_compatibility(base_path + "_rollback.json"):
		_finish(false)
		return
	if not _verify_future_schema_protection(base_path + "_future.json"):
		_finish(false)
		return
	if not _verify_malformed_schema_recovery(base_path + "_malformed_schema.json"):
		_finish(false)
		return
	if not _verify_atomic_text_recovery(base_path + "_settings.cfg"):
		_finish(false)
		return
	if not _verify_badge_store(base_path + "_achievements.json"):
		_finish(false)
		return
	if not _verify_history_score_and_simulation_isolation(
		base_path + "_match_history.json",
		base_path + "_sim_result.json"
	):
		_finish(false)
		return
	if not _verify_malformed_history_normalization(base_path + "_malformed_history.json"):
		_finish(false)
		return
	if not _verify_history_limit(base_path + "_limited_history.json"):
		_finish(false)
		return
	if not _verify_main_commit_order():
		_finish(false)
		return

	print("Release persistence smoke passed.")
	_finish(true)


func _verify_versioned_json_recovery(path: String) -> bool:
	_track_path_family(path)
	if not VersionedJsonStoreScript.save_dictionary(path, {"value": "first"}, 1):
		return _fail("Initial versioned JSON save failed.")
	if not VersionedJsonStoreScript.save_dictionary(path, {"value": "second"}, 1):
		return _fail("Second versioned JSON save failed.")
	var current := _read_json(path)
	if int(current.get("schema_version", 0)) != 1:
		return _fail("Versioned JSON is missing schema_version=1.")
	if String(current.get("data", {}).get("value", "")) != "second":
		return _fail("Versioned JSON payload was not saved.")

	if not _write_text(path, "{broken"):
		return _fail("Could not create corrupt primary fixture.")
	var recovered := VersionedJsonStoreScript.load_dictionary(path, 1, {"value": "fallback"})
	if String(recovered.get("value", "")) != "first":
		return _fail("Corrupt primary did not fall back to the last-good backup.")
	var restored := _read_json(path)
	if String(restored.get("data", {}).get("value", "")) != "first":
		return _fail("Backup data was not restored to the primary path.")
	return true


func _verify_legacy_json_migration(path: String) -> bool:
	_track_path_family(path)
	if not _write_text(path, JSON.stringify({"0": [{"rank": 2, "score": 900}]})):
		return _fail("Could not create legacy JSON fixture.")
	var migrated := VersionedJsonStoreScript.load_dictionary(path, 1, {})
	if not migrated.has("0"):
		return _fail("Legacy dictionary payload was not preserved.")
	var envelope := _read_json(path)
	if int(envelope.get("schema_version", 0)) != 1:
		return _fail("Legacy dictionary was not migrated to schema_version=1.")
	if not (envelope.get("data", {}) is Dictionary):
		return _fail("Migrated envelope is missing its data dictionary.")
	return true


func _verify_rollback_compatibility(path: String) -> bool:
	_track_path_family(path)
	var first_record := {"rank": 2, "score": 900}
	if not VersionedJsonStoreScript.save_dictionary(
		path,
		{"0": [first_record]},
		1
	):
		return _fail("Could not create rollback-compatible envelope.")
	var rollback_document := _read_json(path)
	if not (rollback_document.get("0", []) is Array) \
			or rollback_document.get("0", []).size() != 1:
		return _fail("Versioned JSON did not mirror legacy root keys.")
	rollback_document["0"].append({"rank": 3, "score": 700})
	if not _write_text(path, JSON.stringify(rollback_document)):
		return _fail("Could not simulate an unversioned rollback write.")
	var merged := VersionedJsonStoreScript.load_dictionary(path, 1, {})
	if not (merged.get("0", []) is Array) or merged.get("0", []).size() != 2:
		return _fail("Rollback root write was not merged into versioned data.")
	if not VersionedJsonStoreScript.save_dictionary(path, merged, 1):
		return _fail("Merged rollback data could not be persisted.")
	var persisted := _read_json(path)
	if persisted.get("data", {}).get("0", []).size() != 2 \
			or persisted.get("0", []).size() != 2:
		return _fail("Rollback merge was not preserved in data and legacy root views.")
	return true


func _verify_future_schema_protection(path: String) -> bool:
	_track_path_family(path)
	if not _write_text(path, JSON.stringify({
		"schema_version": 2,
		"data": {"value": "future"},
	})):
		return _fail("Could not create future-schema primary fixture.")
	if not _write_text(path + ".bak", JSON.stringify({
		"schema_version": 1,
		"data": {"value": "older-backup"},
	})):
		return _fail("Could not create older backup fixture.")

	var loaded := VersionedJsonStoreScript.load_dictionary(
		path,
		1,
		{"value": "safe-default"}
	)
	if String(loaded.get("value", "")) != "safe-default":
		return _fail("Future-schema primary incorrectly loaded an older backup.")
	if int(_read_json(path).get("schema_version", 0)) != 2:
		return _fail("Future-schema primary was overwritten during load.")
	if VersionedJsonStoreScript.save_dictionary(path, {"value": "downgrade"}, 1):
		return _fail("Future-schema primary accepted a downgrade write.")
	if int(_read_json(path).get("schema_version", 0)) != 2:
		return _fail("Future-schema primary was overwritten during save.")
	return true


func _verify_malformed_schema_recovery(path: String) -> bool:
	_track_path_family(path)
	if not _write_text(path, JSON.stringify({
		"schema_version": "1",
		"data": {"value": "malformed"},
	})):
		return _fail("Could not create malformed schema fixture.")
	if not _write_text(path + ".bak", JSON.stringify({
		"schema_version": 1,
		"data": {"value": "valid-backup"},
		"value": "valid-backup",
	})):
		return _fail("Could not create malformed-schema backup fixture.")
	var recovered := VersionedJsonStoreScript.load_dictionary(path, 1, {})
	if String(recovered.get("value", "")) != "valid-backup":
		return _fail("Malformed schema type did not recover from a valid backup.")
	if int(_read_json(path).get("schema_version", 0)) != 1:
		return _fail("Malformed schema recovery did not restore a valid primary.")
	return true


func _verify_atomic_text_recovery(path: String) -> bool:
	_track_path_family(path)
	var first := "[meta]\nschema_version=1\n"
	var second := "[meta]\nschema_version=2\n"
	if not VersionedJsonStoreScript.atomic_write_text(path, first):
		return _fail("Initial atomic text save failed.")
	if not VersionedJsonStoreScript.atomic_write_text(path, second):
		return _fail("Second atomic text save failed.")
	if _read_text(path) != second:
		return _fail("Second atomic text save did not replace the primary content.")
	if not _write_text(path, "[broken\n"):
		return _fail("Could not create corrupt text fixture.")
	var loaded := VersionedJsonStoreScript.load_text_with_backup(
		path,
		func(text: String): return text.contains("[meta]") and text.contains("schema_version=")
	)
	if not bool(loaded.get("ok", false)):
		return _fail("Atomic text backup could not be loaded.")
	if String(loaded.get("source", "")) != "backup":
		return _fail("Corrupt atomic text primary did not select its backup.")
	if String(loaded.get("text", "")) != first:
		return _fail("Atomic text recovery did not return the last-good content.")
	if not bool(loaded.get("restored", false)):
		return _fail("Atomic text backup was not restored to the primary path.")
	return true


func _verify_badge_store(path: String) -> bool:
	_track_path_family(path)
	if not _write_text(path, JSON.stringify({
		"badges": ["legacy_win", "legacy_win"],
	})):
		return _fail("Could not create legacy achievements fixture.")
	var migrated := MissionBadgeStoreScript.load_achievements(path)
	if migrated.get("badges", []) != ["legacy_win"]:
		return _fail("Legacy achievements were not migrated and deduplicated.")
	if not MissionBadgeStoreScript.save_badge("clean_win", path):
		return _fail("Achievement badge save failed.")
	if not MissionBadgeStoreScript.save_badge("clean_win", path):
		return _fail("Duplicate achievement badge save failed.")
	if not MissionBadgeStoreScript.save_badge("latest_win", path):
		return _fail("Second achievement badge save failed.")
	if not _write_text(path, "{broken"):
		return _fail("Could not create corrupt achievements fixture.")
	var recovered := MissionBadgeStoreScript.load_achievements(path)
	if recovered.get("badges", []) != ["legacy_win", "clean_win"]:
		return _fail("Achievements did not recover the previous last-good backup.")

	var rollback_document := _read_json(path)
	rollback_document["badges"].append("rollback_win")
	if not _write_text(path, JSON.stringify(rollback_document)):
		return _fail("Could not simulate a legacy achievements rollback write.")
	var loaded := MissionBadgeStoreScript.load_achievements(path)
	var badges: Array = loaded.get("badges", [])
	if badges != ["legacy_win", "clean_win", "rollback_win"]:
		return _fail("Legacy rollback badge was not merged into versioned achievements.")
	var envelope := _read_json(path)
	if int(envelope.get("schema_version", 0)) != 1:
		return _fail("Achievements are missing schema_version=1.")
	return true


func _verify_history_score_and_simulation_isolation(
	history_path: String,
	sim_result_path: String
) -> bool:
	_track_path_family(history_path)
	_track_path_family(sim_result_path)
	var tel = TelemetryScript.new()
	tel.history_path = history_path
	tel.sim_result_path = sim_result_path
	root.add_child(tel)
	tel.current_difficulty = 2
	tel.start_match()
	tel.metrics.session.kills = 3
	tel.metrics.session.assists = 2
	tel.end_match(4, "Player", 2)
	if FileAccess.file_exists(history_path):
		tel.free()
		return _fail("A non-persisting/simulation match wrote user history.")

	var mission_bonus := 800
	var expected_score: int = tel.calculate_score(4, 3, 2, true, 2) + mission_bonus
	if tel.calculate_current_score(mission_bonus) != expected_score:
		tel.free()
		return _fail("Current score does not include the mission bonus exactly once.")
	var saved_score: int = tel.save_current_match_history(mission_bonus)
	if saved_score != expected_score:
		tel.free()
		return _fail("Saved history score differs from the result score.")
	var records: Array = tel.get_history_for_difficulty(2)
	if records.size() != 1:
		tel.free()
		return _fail("Expected exactly one committed user match record.")
	var record: Dictionary = records[0]
	if int(record.get("score", -1)) != expected_score:
		tel.free()
		return _fail("Committed match record has the wrong score.")
	if int(record.get("mission_bonus", -1)) != mission_bonus:
		tel.free()
		return _fail("Committed match record does not preserve its mission bonus.")
	var envelope := _read_json(history_path)
	if int(envelope.get("schema_version", 0)) != 1:
		tel.free()
		return _fail("Match history is missing schema_version=1.")
	tel.free()
	return true


func _verify_malformed_history_normalization(path: String) -> bool:
	_track_path_family(path)
	if not _write_text(path, JSON.stringify({
		"0": [
			{"rank": 2, "score": 900},
			{"rank": "bad", "score": 10},
			{
				"rank": 1,
				"score": 1000,
				"win": "yes",
				"kills": "many",
				"date": 42,
			},
		],
	})):
		return _fail("Could not create malformed history fixture.")
	var tel = TelemetryScript.new()
	tel.history_path = path
	root.add_child(tel)
	var records: Array = tel.get_history_for_difficulty(0)
	if records.size() != 2:
		tel.free()
		return _fail("Malformed required history fields were not rejected safely.")
	for record in records:
		for required_key in [
			"date", "rank", "kills", "assists", "duration",
			"win", "difficulty", "score", "mission_bonus",
		]:
			if not record.has(required_key):
				tel.free()
				return _fail("Normalized history is missing UI field %s." % required_key)
		if typeof(record.get("date")) != TYPE_STRING \
				or typeof(record.get("win")) != TYPE_BOOL:
			tel.free()
			return _fail("Normalized history retained unsafe UI field types.")
	tel.free()
	return true


func _verify_history_limit(path: String) -> bool:
	_track_path_family(path)
	var legacy_records: Array = []
	for index in range(55):
		legacy_records.append({
			"date": "2026-07-26",
			"rank": index + 1,
			"kills": 0,
			"assists": 0,
			"duration": 60,
			"win": false,
			"difficulty": 0,
			"score": 100 + index,
		})
	if not _write_text(path, JSON.stringify({"0": legacy_records})):
		return _fail("Could not create oversized legacy history fixture.")

	var tel = TelemetryScript.new()
	tel.history_path = path
	root.add_child(tel)
	var normalized: Array = tel.get_history_for_difficulty(0)
	if normalized.size() != TelemetryScript.HISTORY_LIMIT_PER_DIFFICULTY:
		tel.free()
		return _fail("Oversized legacy history was not capped at 50 records.")
	if int(normalized[0].get("score", -1)) != 154:
		tel.free()
		return _fail("History normalization did not preserve descending score order.")

	tel.current_difficulty = 0
	tel.start_match()
	tel.metrics.session.kills = 10
	tel.end_match(1, "Player", 1, false)
	var appended_score: int = tel.save_current_match_history(1000)
	var after_append: Array = tel.get_history_for_difficulty(0)
	if after_append.size() != TelemetryScript.HISTORY_LIMIT_PER_DIFFICULTY:
		tel.free()
		return _fail("Appending a history record exceeded the 50-record cap.")
	if int(after_append[0].get("score", -1)) != appended_score:
		tel.free()
		return _fail("History cap discarded the highest newly appended score.")

	if not tel.clear_history():
		tel.free()
		return _fail("Clear history could not finalize its primary and backup.")
	if not _write_text(path, "{broken"):
		tel.free()
		return _fail("Could not create post-clear corrupt history fixture.")
	if not tel.get_history_for_difficulty(0).is_empty():
		tel.free()
		return _fail("Corrupt history resurrected records from before CLEAR ALL.")
	tel.free()
	return true


func _verify_main_commit_order() -> bool:
	var source := _read_text("res://src/Main.gd")
	var end_index := source.find("get_node(\"/root/Telemetry\").end_match(")
	var mission_index := source.find("# Evaluate bonus mission")
	var history_index := source.find("tel.save_current_match_history(mission_bonus_score)")
	if end_index < 0 or mission_index < 0 or history_index < 0:
		return _fail("Main is missing the explicit telemetry finalize/mission/history sequence.")
	if not (end_index < mission_index and mission_index < history_index):
		return _fail("Main must evaluate the mission before committing user history.")
	var end_block := source.substr(end_index, mission_index - end_index)
	if end_block.find("false") < 0:
		return _fail("Main end_match must defer history persistence until mission scoring is known.")
	var history_context_start := maxi(mission_index, history_index - 180)
	var history_block := source.substr(history_context_start, history_index - history_context_start)
	if history_block.find("if not is_simulation") < 0:
		return _fail("Main must gate user history commits out of simulation.")
	return true


func _track_path_family(path: String) -> void:
	for suffix in ["", ".bak", ".tmp", ".replace_old", ".bak.tmp", ".bak.replace_old"]:
		_test_paths.append(path + suffix)


func _finish(success: bool) -> void:
	for path in _test_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	quit(0 if success else 1)


func _read_json(path: String) -> Dictionary:
	var parsed = JSON.parse_string(_read_text(path))
	return parsed if parsed is Dictionary else {}


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	var error := file.get_error()
	file.close()
	return error == OK


func _fail(message: String) -> bool:
	push_error(message)
	return false
