extends RefCounted
class_name VersionedJsonStore

const SCHEMA_VERSION_KEY := "schema_version"
const DATA_KEY := "data"
const BACKUP_SUFFIX := ".bak"
const TEMP_SUFFIX := ".tmp"


static func save_dictionary(path: String, data: Dictionary, schema_version: int) -> bool:
	if path.is_empty() or schema_version <= 0:
		push_error("VersionedJsonStore: invalid path or schema version.")
		return false

	var envelope := {
		SCHEMA_VERSION_KEY: schema_version,
		DATA_KEY: data.duplicate(true),
	}
	# Mirror payload keys at the root so the last unversioned public build can
	# still read and append history/badges during a rollback. Current readers
	# merge any rollback writes back into DATA_KEY.
	for compatibility_key in data:
		if compatibility_key == SCHEMA_VERSION_KEY or compatibility_key == DATA_KEY:
			continue
		envelope[compatibility_key] = _duplicate_variant(data[compatibility_key])
	var current := _read_dictionary_document(path, schema_version, true)
	if String(current.get("status", "")) == "unsupported_schema":
		push_warning(
			"VersionedJsonStore: refusing to overwrite unsupported schema at %s." % path
		)
		return false
	var rotate_backup := bool(current.get("valid", false))
	if not atomic_write_text(path, JSON.stringify(envelope, "\t"), rotate_backup):
		push_error("VersionedJsonStore: failed to replace %s." % path)
		return false
	return true


static func atomic_write_text(path: String, text: String, rotate_backup: bool = true) -> bool:
	if path.is_empty():
		return false
	var temp_path := path + TEMP_SUFFIX
	_remove_file(temp_path)
	if not _write_text(temp_path, text):
		_remove_file(temp_path)
		return false

	if rotate_backup and FileAccess.file_exists(path):
		if not _copy_with_replace(path, path + BACKUP_SUFFIX):
			_remove_file(temp_path)
			return false

	if not _replace_from_temp(temp_path, path):
		_remove_file(temp_path)
		return false
	return true


static func load_text_with_backup(path: String, validator: Callable = Callable()) -> Dictionary:
	var primary := _read_text_file(path)
	if bool(primary.get("ok", false)) and _is_text_valid(String(primary.get("text", "")), validator):
		primary["source"] = "primary"
		return primary

	var backup := _read_text_file(path + BACKUP_SUFFIX)
	if bool(backup.get("ok", false)) and _is_text_valid(String(backup.get("text", "")), validator):
		var recovered_text := String(backup.get("text", ""))
		var restored := atomic_write_text(path, recovered_text, false)
		if not restored:
			push_warning("VersionedJsonStore: backup loaded but primary restore failed for %s." % path)
		return {
			"ok": true,
			"text": recovered_text,
			"source": "backup",
			"restored": restored,
		}

	return {
		"ok": false,
		"text": "",
		"source": "none",
		"status": String(primary.get("status", "missing")),
	}


static func refresh_backup(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	return _copy_with_replace(path, path + BACKUP_SUFFIX)


static func load_dictionary(
	path: String,
	schema_version: int,
	fallback: Dictionary = {},
	migrate_legacy: bool = true
) -> Dictionary:
	var primary := _read_dictionary_document(path, schema_version, migrate_legacy)
	if bool(primary.get("valid", false)):
		var primary_data: Dictionary = primary.get("data", {})
		if bool(primary.get("legacy", false)):
			if not save_dictionary(path, primary_data, schema_version):
				push_warning("VersionedJsonStore: loaded legacy data but could not migrate %s." % path)
		return primary_data.duplicate(true)
	if String(primary.get("status", "")) == "unsupported_schema":
		push_warning(
			"VersionedJsonStore: preserving unsupported schema at %s; backup recovery is disabled." % path
		)
		return fallback.duplicate(true)

	var backup_path := path + BACKUP_SUFFIX
	var backup := _read_dictionary_document(backup_path, schema_version, migrate_legacy)
	if bool(backup.get("valid", false)):
		var recovered_data: Dictionary = backup.get("data", {})
		push_warning("VersionedJsonStore: recovering %s from its backup." % path)
		if not save_dictionary(path, recovered_data, schema_version):
			push_warning("VersionedJsonStore: backup loaded but primary restore failed for %s." % path)
		return recovered_data.duplicate(true)

	if String(primary.get("status", "missing")) != "missing":
		push_warning("VersionedJsonStore: no usable data found at %s; using defaults." % path)
	return fallback.duplicate(true)


static func _read_dictionary_document(
	path: String,
	schema_version: int,
	allow_legacy: bool
) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"valid": false, "status": "missing"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"valid": false, "status": "io_error"}
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {"valid": false, "status": "corrupt"}
	var parsed = parser.data
	if not (parsed is Dictionary):
		return {"valid": false, "status": "corrupt"}

	var document: Dictionary = parsed
	if document.has(SCHEMA_VERSION_KEY):
		var raw_schema = document.get(SCHEMA_VERSION_KEY)
		if typeof(raw_schema) != TYPE_INT and typeof(raw_schema) != TYPE_FLOAT:
			return {"valid": false, "status": "corrupt"}
		var document_schema := int(raw_schema)
		if float(raw_schema) != float(document_schema):
			return {"valid": false, "status": "corrupt"}
		if document_schema != schema_version:
			return {"valid": false, "status": "unsupported_schema"}
		var payload = document.get(DATA_KEY)
		if not (payload is Dictionary):
			return {"valid": false, "status": "corrupt"}
		var merged_payload: Dictionary = (payload as Dictionary).duplicate(true)
		for compatibility_key in document:
			if compatibility_key == SCHEMA_VERSION_KEY or compatibility_key == DATA_KEY:
				continue
			if not merged_payload.has(compatibility_key):
				merged_payload[compatibility_key] = _duplicate_variant(
					document[compatibility_key]
				)
				continue
			merged_payload[compatibility_key] = _merge_compatibility_value(
				merged_payload[compatibility_key],
				document[compatibility_key]
			)
		return {
			"valid": true,
			"status": "current",
			"legacy": false,
			"data": merged_payload,
		}

	if allow_legacy:
		return {
			"valid": true,
			"status": "legacy",
			"legacy": true,
			"data": document.duplicate(true),
		}
	return {"valid": false, "status": "unsupported_schema"}


static func _write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	var write_error := file.get_error()
	file.close()
	return write_error == OK


static func _read_text_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "status": "missing", "text": ""}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "status": "io_error", "text": ""}
	var text := file.get_as_text()
	var read_error := file.get_error()
	file.close()
	if read_error != OK:
		return {"ok": false, "status": "io_error", "text": ""}
	return {"ok": true, "status": "ok", "text": text}


static func _is_text_valid(text: String, validator: Callable) -> bool:
	if not validator.is_valid():
		return true
	return bool(validator.call(text))


static func _duplicate_variant(value):
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value


static func _merge_compatibility_value(current_value, compatibility_value):
	if current_value is Array and compatibility_value is Array:
		var merged: Array = (current_value as Array).duplicate(true)
		for item in compatibility_value:
			if not merged.has(item):
				merged.append(_duplicate_variant(item))
		return merged
	if current_value is Dictionary and compatibility_value is Dictionary:
		var merged: Dictionary = (current_value as Dictionary).duplicate(true)
		for key in compatibility_value:
			if not merged.has(key):
				merged[key] = _duplicate_variant(compatibility_value[key])
		return merged
	return current_value


static func _copy_with_replace(source_path: String, target_path: String) -> bool:
	var temp_target := target_path + TEMP_SUFFIX
	_remove_file(temp_target)
	var copy_error := DirAccess.copy_absolute(
		ProjectSettings.globalize_path(source_path),
		ProjectSettings.globalize_path(temp_target)
	)
	if copy_error != OK:
		_remove_file(temp_target)
		return false
	return _replace_from_temp(temp_target, target_path)


static func _replace_from_temp(temp_path: String, target_path: String) -> bool:
	var temp_absolute := ProjectSettings.globalize_path(temp_path)
	var target_absolute := ProjectSettings.globalize_path(target_path)
	var rename_error := DirAccess.rename_absolute(temp_absolute, target_absolute)
	if rename_error == OK:
		return true

	if not FileAccess.file_exists(target_path):
		return false

	var displaced_path := target_path + ".replace_old"
	var displaced_absolute := ProjectSettings.globalize_path(displaced_path)
	_remove_file(displaced_path)
	if DirAccess.rename_absolute(target_absolute, displaced_absolute) != OK:
		return false
	if DirAccess.rename_absolute(temp_absolute, target_absolute) == OK:
		_remove_file(displaced_path)
		return true

	DirAccess.rename_absolute(displaced_absolute, target_absolute)
	return false


static func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
