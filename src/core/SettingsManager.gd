class_name SettingsManager
extends RefCounted


const VersionedJsonStoreScript = preload("res://src/core/VersionedJsonStore.gd")

const DEFAULT_PATH := "user://settings.cfg"
const META_SECTION := "meta"
const SCHEMA_VERSION_KEY := "schema_version"
const SCHEMA_VERSION := 1
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
	if _has_unsupported_schema(settings_path) \
			or _has_unsupported_schema(settings_path + VersionedJsonStoreScript.BACKUP_SUFFIX):
		push_warning(
			"SettingsManager: preserving settings written by a newer schema at %s." % settings_path
		)
		return false
	var loaded: Dictionary = VersionedJsonStoreScript.load_text_with_backup(
		settings_path,
		Callable(self, "_is_valid_settings_text")
	)
	if not bool(loaded.get("ok", false)):
		return false

	var cfg := ConfigFile.new()
	if cfg.parse(String(loaded.get("text", ""))) != OK:
		return false
	_volume_linear = _sanitize_volume(float(cfg.get_value(AUDIO_SECTION, MASTER_VOLUME_KEY, _volume_linear)))
	_fullscreen = bool(cfg.get_value(DISPLAY_SECTION, FULLSCREEN_KEY, _fullscreen))
	var loaded_schema := int(cfg.get_value(META_SECTION, SCHEMA_VERSION_KEY, 0))
	if loaded_schema < SCHEMA_VERSION and save(settings_path) != OK:
		push_warning("SettingsManager: loaded legacy settings but could not migrate %s." % settings_path)
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
	if _has_unsupported_schema(target_path) \
			or _has_unsupported_schema(target_path + VersionedJsonStoreScript.BACKUP_SUFFIX):
		push_warning(
			"SettingsManager: refusing to overwrite settings written by a newer schema at %s." % target_path
		)
		return ERR_FILE_UNRECOGNIZED
	var cfg := ConfigFile.new()
	cfg.set_value(META_SECTION, SCHEMA_VERSION_KEY, SCHEMA_VERSION)
	cfg.set_value(AUDIO_SECTION, MASTER_VOLUME_KEY, _volume_linear)
	cfg.set_value(DISPLAY_SECTION, FULLSCREEN_KEY, _fullscreen)
	var rotate_backup := _is_valid_settings_file(target_path)
	return OK if VersionedJsonStoreScript.atomic_write_text(
		target_path,
		cfg.encode_to_text(),
		rotate_backup
	) else ERR_CANT_CREATE


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


func _is_valid_settings_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	var read_error := file.get_error()
	file.close()
	return read_error == OK and _is_valid_settings_text(text)


func _is_valid_settings_text(text: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.parse(text) != OK:
		return false
	if not cfg.has_section_key(AUDIO_SECTION, MASTER_VOLUME_KEY):
		return false
	if not cfg.has_section_key(DISPLAY_SECTION, FULLSCREEN_KEY):
		return false

	var raw_volume = cfg.get_value(AUDIO_SECTION, MASTER_VOLUME_KEY)
	if typeof(raw_volume) != TYPE_FLOAT and typeof(raw_volume) != TYPE_INT:
		return false
	var raw_fullscreen = cfg.get_value(DISPLAY_SECTION, FULLSCREEN_KEY)
	if typeof(raw_fullscreen) != TYPE_BOOL:
		return false

	var raw_schema = cfg.get_value(META_SECTION, SCHEMA_VERSION_KEY, 0)
	if typeof(raw_schema) != TYPE_INT:
		return false
	var schema_version := int(raw_schema)
	return schema_version >= 0 and schema_version <= SCHEMA_VERSION


func _has_unsupported_schema(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return false
	if not cfg.has_section_key(META_SECTION, SCHEMA_VERSION_KEY):
		return false
	var raw_schema = cfg.get_value(META_SECTION, SCHEMA_VERSION_KEY)
	return typeof(raw_schema) == TYPE_INT and int(raw_schema) > SCHEMA_VERSION
