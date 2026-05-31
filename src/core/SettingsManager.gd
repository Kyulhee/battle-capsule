class_name SettingsManager
extends RefCounted


const DEFAULT_PATH := "user://settings.cfg"
const AUDIO_SECTION := "audio"
const DISPLAY_SECTION := "display"
const MASTER_VOLUME_KEY := "master_volume"
const FULLSCREEN_KEY := "fullscreen"


var settings_path: String = DEFAULT_PATH
var _volume_linear: float = 1.0
var _fullscreen: bool = false


func load_or_default(path: String = DEFAULT_PATH) -> bool:
	settings_path = path
	sync_from_runtime()
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) != OK:
		return false
	_volume_linear = _sanitize_volume(float(cfg.get_value(AUDIO_SECTION, MASTER_VOLUME_KEY, _volume_linear)))
	_fullscreen = bool(cfg.get_value(DISPLAY_SECTION, FULLSCREEN_KEY, _fullscreen))
	return true


func sync_from_runtime() -> void:
	_volume_linear = _sanitize_volume(db_to_linear(AudioServer.get_bus_volume_db(0)))
	_fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


func apply_current() -> void:
	apply_volume()
	apply_fullscreen()


func apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(_volume_linear))


func apply_fullscreen() -> void:
	if _fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func save(path: String = "") -> int:
	var target_path := settings_path if path.strip_edges().is_empty() else path
	var cfg := ConfigFile.new()
	cfg.set_value(AUDIO_SECTION, MASTER_VOLUME_KEY, _volume_linear)
	cfg.set_value(DISPLAY_SECTION, FULLSCREEN_KEY, _fullscreen)
	return cfg.save(target_path)


func current_volume() -> float:
	return _volume_linear


func is_fullscreen() -> bool:
	return _fullscreen


func set_volume(value: float, apply_now: bool = true) -> void:
	_volume_linear = _sanitize_volume(value)
	if apply_now:
		apply_volume()


func set_fullscreen(enabled: bool, apply_now: bool = true) -> void:
	_fullscreen = enabled
	if apply_now:
		apply_fullscreen()


func toggle_fullscreen(apply_now: bool = true) -> bool:
	set_fullscreen(not _fullscreen, apply_now)
	return _fullscreen


static func _sanitize_volume(value: float) -> float:
	return clampf(value, 0.0, 1.0)
