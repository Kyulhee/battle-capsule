extends SceneTree


const TEST_PATH := "user://verify_settings_manager.cfg"
const LEGACY_PATH := "user://verify_settings_manager_legacy.cfg"
const FUTURE_PATH := "user://verify_settings_manager_future.cfg"
const MISSING_PATH := "user://verify_settings_manager_missing_probe.cfg"


func _init():
	_cleanup_probe(TEST_PATH)
	_cleanup_probe(LEGACY_PATH)
	_cleanup_probe(FUTURE_PATH)
	_cleanup_probe(MISSING_PATH)
	var settings_script = load("res://src/core/SettingsManager.gd")
	var manager = settings_script.new()

	manager.set_volume(2.0, false)
	if not is_equal_approx(manager.current_volume(), 1.0):
		_fail("SettingsManager did not clamp high volume.")
		return
	manager.set_volume(-0.25, false)
	if not is_equal_approx(manager.current_volume(), 0.0):
		_fail("SettingsManager did not clamp low volume.")
		return

	manager.set_volume(0.42, false)
	manager.set_fullscreen(true, false)
	if manager.save(TEST_PATH) != OK:
		_fail("SettingsManager could not save test settings.")
		return
	if not _has_schema(TEST_PATH, settings_script.SCHEMA_VERSION):
		_fail("SettingsManager did not write the current schema version.")
		return

	var loaded = settings_script.new()
	if not loaded.load_or_default(TEST_PATH):
		_fail("SettingsManager could not load saved test settings.")
		return
	if absf(loaded.current_volume() - 0.42) > 0.001:
		_fail("SettingsManager loaded incorrect volume: %.3f." % loaded.current_volume())
		return
	if not loaded.is_fullscreen():
		_fail("SettingsManager loaded incorrect fullscreen state.")
		return

	loaded.set_volume(0.65, false)
	loaded.set_fullscreen(false, false)
	if loaded.save(TEST_PATH) != OK:
		_fail("SettingsManager could not atomically replace test settings.")
		return
	if not FileAccess.file_exists(TEST_PATH + ".bak"):
		_fail("SettingsManager did not retain a settings backup.")
		return
	if FileAccess.file_exists(TEST_PATH + ".tmp"):
		_fail("SettingsManager left a temporary settings file behind.")
		return
	var replaced = settings_script.new()
	if not replaced.load_or_default(TEST_PATH):
		_fail("SettingsManager could not read the replaced primary settings.")
		return
	if absf(replaced.current_volume() - 0.65) > 0.001 or replaced.is_fullscreen():
		_fail("SettingsManager did not persist the replacement values.")
		return
	if not _write_text(TEST_PATH, "not a valid ConfigFile"):
		_fail("Could not prepare corrupt settings fixture.")
		return

	var recovered = settings_script.new()
	if not recovered.load_or_default(TEST_PATH):
		_fail("SettingsManager did not recover corrupt settings from backup.")
		return
	if absf(recovered.current_volume() - 0.42) > 0.001 or not recovered.is_fullscreen():
		_fail("SettingsManager recovered the wrong backup values.")
		return
	if not _has_schema(TEST_PATH, settings_script.SCHEMA_VERSION):
		_fail("SettingsManager did not restore a valid primary settings file.")
		return

	recovered.toggle_fullscreen(false)
	if recovered.is_fullscreen():
		_fail("SettingsManager toggle_fullscreen(false) did not update state.")
		return

	var legacy := ConfigFile.new()
	legacy.set_value(settings_script.AUDIO_SECTION, settings_script.MASTER_VOLUME_KEY, 0.27)
	legacy.set_value(settings_script.DISPLAY_SECTION, settings_script.FULLSCREEN_KEY, false)
	if legacy.save(LEGACY_PATH) != OK:
		_fail("Could not prepare legacy settings fixture.")
		return
	var migrated = settings_script.new()
	if not migrated.load_or_default(LEGACY_PATH):
		_fail("SettingsManager did not load legacy settings.")
		return
	if absf(migrated.current_volume() - 0.27) > 0.001 or migrated.is_fullscreen():
		_fail("SettingsManager changed legacy values during migration.")
		return
	if not _has_schema(LEGACY_PATH, settings_script.SCHEMA_VERSION):
		_fail("SettingsManager did not migrate legacy settings to the current schema.")
		return

	var future := ConfigFile.new()
	future.set_value(
		settings_script.META_SECTION,
		settings_script.SCHEMA_VERSION_KEY,
		settings_script.SCHEMA_VERSION + 1
	)
	future.set_value(settings_script.AUDIO_SECTION, settings_script.MASTER_VOLUME_KEY, 0.81)
	future.set_value(settings_script.DISPLAY_SECTION, settings_script.FULLSCREEN_KEY, true)
	if future.save(FUTURE_PATH) != OK:
		_fail("Could not prepare future-schema settings fixture.")
		return
	var older_backup := ConfigFile.new()
	older_backup.set_value(
		settings_script.META_SECTION,
		settings_script.SCHEMA_VERSION_KEY,
		settings_script.SCHEMA_VERSION
	)
	older_backup.set_value(settings_script.AUDIO_SECTION, settings_script.MASTER_VOLUME_KEY, 0.11)
	older_backup.set_value(settings_script.DISPLAY_SECTION, settings_script.FULLSCREEN_KEY, false)
	if older_backup.save(FUTURE_PATH + ".bak") != OK:
		_fail("Could not prepare older settings backup fixture.")
		return
	var future_guard = settings_script.new()
	if future_guard.load_or_default(FUTURE_PATH):
		_fail("SettingsManager loaded an unsupported future schema.")
		return
	if not _has_schema(FUTURE_PATH, settings_script.SCHEMA_VERSION + 1):
		_fail("SettingsManager replaced a future schema with its older backup.")
		return
	future_guard.set_volume(0.25, false)
	if future_guard.save(FUTURE_PATH) == OK:
		_fail("SettingsManager accepted a downgrade write over a future schema.")
		return
	if not _has_schema(FUTURE_PATH, settings_script.SCHEMA_VERSION + 1):
		_fail("SettingsManager overwrote a future schema during save.")
		return

	var missing = settings_script.new()
	if missing.load_or_default(MISSING_PATH):
		_fail("SettingsManager reported missing settings as loaded.")
		return
	if missing.current_volume() < 0.0 or missing.current_volume() > 1.0:
		_fail("SettingsManager missing-file fallback volume is out of range.")
		return

	print("SettingsManager smoke passed: volume=%.2f fullscreen=%s." % [
		loaded.current_volume(),
		str(loaded.is_fullscreen()),
	])
	_cleanup_probe(TEST_PATH)
	_cleanup_probe(LEGACY_PATH)
	_cleanup_probe(FUTURE_PATH)
	_cleanup_probe(MISSING_PATH)
	quit(0)


func _fail(message: String) -> void:
	_cleanup_probe(TEST_PATH)
	_cleanup_probe(LEGACY_PATH)
	_cleanup_probe(FUTURE_PATH)
	_cleanup_probe(MISSING_PATH)
	push_error(message)
	quit(1)


func _has_schema(path: String, expected_schema: int) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return false
	return int(cfg.get_value("meta", "schema_version", -1)) == expected_schema


func _write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true


func _cleanup_probe(path: String) -> void:
	for suffix in ["", ".bak", ".tmp", ".replace_old"]:
		var candidate: String = path + String(suffix)
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
