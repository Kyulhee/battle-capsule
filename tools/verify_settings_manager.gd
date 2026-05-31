extends SceneTree


const TEST_PATH := "user://verify_settings_manager.cfg"


func _init():
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

	loaded.toggle_fullscreen(false)
	if loaded.is_fullscreen():
		_fail("SettingsManager toggle_fullscreen(false) did not update state.")
		return

	var missing = settings_script.new()
	if missing.load_or_default("user://settings_manager_missing_probe.cfg"):
		_fail("SettingsManager reported missing settings as loaded.")
		return
	if missing.current_volume() < 0.0 or missing.current_volume() > 1.0:
		_fail("SettingsManager missing-file fallback volume is out of range.")
		return

	print("SettingsManager smoke passed: volume=%.2f fullscreen=%s." % [
		loaded.current_volume(),
		str(loaded.is_fullscreen()),
	])
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
