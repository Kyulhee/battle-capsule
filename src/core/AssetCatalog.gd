class_name AssetCatalog
extends RefCounted

const DEFAULT_PATH := "res://data/asset_catalog.json"

var data: Dictionary = {}
var missing_paths: Array[Dictionary] = []

func load_or_default(path: String = DEFAULT_PATH) -> void:
	data = _default_data()

	if not FileAccess.file_exists(path):
		push_warning("AssetCatalog: %s not found. Using built-in defaults." % path)
		_refresh_missing_paths()
		return

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("AssetCatalog: failed to open %s. Using built-in defaults." % path)
		_refresh_missing_paths()
		return

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error != OK:
		push_warning("AssetCatalog: JSON parse error at line %d: %s. Using built-in defaults." % [
			json.get_error_line(),
			json.get_error_message()
		])
		_refresh_missing_paths()
		return

	var parsed = json.get_data()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("AssetCatalog: root must be a Dictionary. Using built-in defaults.")
		_refresh_missing_paths()
		return

	data = _merge_dict(data, parsed)
	_refresh_missing_paths()

static func _merge_dict(target: Dictionary, source: Dictionary) -> Dictionary:
	for key in source.keys():
		var incoming = source[key]
		var current = target.get(key)
		if typeof(current) == TYPE_DICTIONARY and typeof(incoming) == TYPE_DICTIONARY:
			target[key] = _merge_dict(current.duplicate(true), incoming)
		else:
			target[key] = incoming
	return target

func get_entry(section_name: String, asset_id: String) -> Dictionary:
	var section = data.get(section_name, {})
	if typeof(section) != TYPE_DICTIONARY:
		return {}
	var entry = section.get(asset_id, {})
	if typeof(entry) == TYPE_DICTIONARY:
		return entry.duplicate(true)
	return {}

func get_path(section_name: String, asset_id: String, fallback: String = "") -> String:
	var entry = get_entry(section_name, asset_id)
	var path = String(entry.get("path", ""))
	return path if path != "" else fallback

func get_audio_path(sound_id: String) -> String:
	return get_path("audio", sound_id, "")

func get_audio_fallback(sound_id: String) -> String:
	var entry = get_entry("audio", sound_id)
	return String(entry.get("fallback", sound_id))

func get_color(section_name: String, asset_id: String, fallback: Color = Color.WHITE) -> Color:
	return get_tint(section_name, asset_id, "color", fallback)

func get_tint(section_name: String, asset_id: String, tint_key: String, fallback: Color = Color.WHITE) -> Color:
	var entry = get_entry(section_name, asset_id)
	var raw = entry.get(tint_key, [])
	if typeof(raw) == TYPE_ARRAY and raw.size() >= 3:
		var alpha = float(raw[3]) if raw.size() >= 4 else fallback.a
		return Color(float(raw[0]), float(raw[1]), float(raw[2]), alpha)
	return fallback

func get_cosmetic_tint(asset_id: String, tint_key: String, fallback: Color = Color.WHITE) -> Color:
	return get_tint("cosmetics", asset_id, tint_key, fallback)

func has_asset(section_name: String, asset_id: String) -> bool:
	var section = data.get(section_name, {})
	return typeof(section) == TYPE_DICTIONARY and section.has(asset_id)

func get_missing_paths() -> Array[Dictionary]:
	return missing_paths.duplicate(true)

func missing_count() -> int:
	return missing_paths.size()

func count_section(section_name: String) -> int:
	var section = data.get(section_name, {})
	return section.size() if typeof(section) == TYPE_DICTIONARY else 0

func summary() -> Dictionary:
	return {
		"audio": count_section("audio"),
		"icons": count_section("icons"),
		"materials": count_section("materials"),
		"props": count_section("props"),
		"cosmetics": count_section("cosmetics"),
		"missing": missing_count()
	}

func _refresh_missing_paths() -> void:
	missing_paths.clear()
	for section_name in ["audio", "icons", "materials", "props", "cosmetics"]:
		var section = data.get(section_name, {})
		if typeof(section) != TYPE_DICTIONARY:
			continue
		for asset_id in section.keys():
			var entry = section[asset_id]
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var path = String(entry.get("path", ""))
			if path == "":
				continue
			if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
				missing_paths.append({
					"section": section_name,
					"id": String(asset_id),
					"path": path,
				})
	if not missing_paths.is_empty():
		push_warning("AssetCatalog: %d configured asset paths are missing; fallbacks remain active." % missing_paths.size())

func _default_data() -> Dictionary:
	return {
		"audio": {
			"shoot": { "path": "", "fallback": "shoot" },
			"shoot.pistol": { "path": "", "fallback": "shoot" },
			"shoot.ar": { "path": "", "fallback": "shoot" },
			"shoot.shotgun": { "path": "", "fallback": "shoot" },
			"shoot.railgun": { "path": "", "fallback": "shoot" },
			"hit": { "path": "", "fallback": "hit" },
			"impact_wall": { "path": "", "fallback": "impact_wall" },
			"hurt": { "path": "", "fallback": "hurt" },
			"dry_fire": { "path": "", "fallback": "dry_fire" },
			"death": { "path": "", "fallback": "death" },
			"pickup": { "path": "", "fallback": "pickup" },
			"heal": { "path": "", "fallback": "heal" },
			"footstep": { "path": "", "fallback": "footstep" },
			"footstep.grass": { "path": "", "fallback": "footstep" },
			"footstep.dirt": { "path": "", "fallback": "footstep" },
			"footstep.stone": { "path": "", "fallback": "footstep" },
			"melee": { "path": "", "fallback": "melee" },
			"melee.swing.2": { "path": "", "fallback": "melee" },
			"melee.swing.3": { "path": "", "fallback": "melee" },
			"melee.hit": { "path": "", "fallback": "hit" },
			"reload": { "path": "", "fallback": "reload" },
			"zone_warning": { "path": "", "fallback": "zone_warning" }
		},
		"icons": {},
		"materials": {},
		"props": {},
		"cosmetics": {
			"player.default": {
				"body_tint": [0.10, 0.72, 0.18, 1.0],
				"accent_tint": [0.35, 1.0, 0.35, 1.0]
			},
			"bot.aggressive": {
				"body_tint": [0.85, 0.20, 0.18, 1.0],
				"accent_tint": [1.0, 0.45, 0.30, 1.0]
			},
			"bot.defensive": {
				"body_tint": [0.22, 0.36, 0.86, 1.0],
				"accent_tint": [0.50, 0.72, 1.0, 1.0]
			},
			"bot.sniper": {
				"body_tint": [0.38, 0.22, 0.72, 1.0],
				"accent_tint": [0.78, 0.58, 1.0, 1.0]
			},
			"bot.opportunist": {
				"body_tint": [0.95, 0.68, 0.18, 1.0],
				"accent_tint": [1.0, 0.85, 0.30, 1.0]
			}
		}
	}
