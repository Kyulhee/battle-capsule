class_name HellTuning
extends RefCounted

const DEFAULTS := {
	"timers": {
		"blackout_initial_min": 12.0,
		"blackout_initial_max": 20.0,
		"blackout_repeat_min": 15.0,
		"blackout_repeat_max": 28.0,
		"bomb_initial_timer": 20.0,
		"bomb_repeat_min": 18.0,
		"bomb_repeat_max": 28.0,
		"bomb_start_after": 10.0,
	},
	"blackout": {
		"hold_min": 2.0,
		"hold_max": 4.0,
		"fade_in_alpha": 0.88,
		"fade_in_seconds": 0.3,
		"fade_out_alpha": 0.0,
		"fade_out_seconds": 0.5,
	},
	"bombardment": {
		"center_radius_mult": 0.85,
		"center_height": 0.05,
		"event_text": "BOMBARDMENT INCOMING",
		"event_text_color": [1.0, 0.35, 0.0, 1.0],
	},
	"barrage": {
		"outer_radius": 14.0,
		"pellet_radius": 2.5,
		"pellet_damage": 22.0,
		"pellet_count": 10,
		"base_delay": 0.7,
		"pellet_gap": 0.06,
		"outer_color": [1.0, 0.1, 0.1, 0.3],
		"pellet_color": [1.0, 0.45, 0.0, 0.75],
		"flash_color": [0.9, 0.3, 0.0, 0.5],
		"flash_duration": 0.3,
	},
	"standard": {
		"zone_radius": 15.0,
		"bomb_radius": 3.0,
		"bomb_damage": 18.0,
		"warn_delay": 1.5,
		"pellet_count": 10,
		"pellet_gap": 0.18,
		"marker_color": [1.0, 0.1, 0.1, 0.55],
		"flash_color": [0.9, 0.3, 0.0, 0.4],
		"flash_duration": 0.25,
		"completion_delay": 0.05,
	},
	"disc": {
		"height": 0.12,
		"emission_green_mult": 0.4,
		"emission_blue": 0.0,
		"emission_energy": 1.2,
	},
}

static func from_game_config(game_config) -> Dictionary:
	var tuning = DEFAULTS.duplicate(true)
	if game_config != null and game_config.has_method("hell_tuning"):
		tuning = _merge_dict(tuning, _migrate_flat_timers(game_config.hell_tuning()))
	return _sanitize(tuning)

static func timers(tuning: Dictionary) -> Dictionary:
	return _section(tuning, "timers")

static func blackout(tuning: Dictionary) -> Dictionary:
	return _section(tuning, "blackout")

static func bombardment(tuning: Dictionary) -> Dictionary:
	return _section(tuning, "bombardment")

static func barrage(tuning: Dictionary) -> Dictionary:
	return _section(tuning, "barrage")

static func standard(tuning: Dictionary) -> Dictionary:
	return _section(tuning, "standard")

static func disc(tuning: Dictionary) -> Dictionary:
	return _section(tuning, "disc")

static func _sanitize(tuning: Dictionary) -> Dictionary:
	return {
		"timers": _sanitize_timers(_merge_dict(DEFAULTS["timers"].duplicate(true), _section(tuning, "timers"))),
		"blackout": _sanitize_blackout(_merge_dict(DEFAULTS["blackout"].duplicate(true), _section(tuning, "blackout"))),
		"bombardment": _sanitize_bombardment(_merge_dict(DEFAULTS["bombardment"].duplicate(true), _section(tuning, "bombardment"))),
		"barrage": _sanitize_barrage(_merge_dict(DEFAULTS["barrage"].duplicate(true), _section(tuning, "barrage"))),
		"standard": _sanitize_standard(_merge_dict(DEFAULTS["standard"].duplicate(true), _section(tuning, "standard"))),
		"disc": _sanitize_disc(_merge_dict(DEFAULTS["disc"].duplicate(true), _section(tuning, "disc"))),
	}

static func _sanitize_timers(timers_tuning: Dictionary) -> Dictionary:
	var blackout_initial_min = maxf(0.0, float(timers_tuning.get("blackout_initial_min", 12.0)))
	var blackout_initial_max = maxf(blackout_initial_min, float(timers_tuning.get("blackout_initial_max", 20.0)))
	var blackout_repeat_min = maxf(0.0, float(timers_tuning.get("blackout_repeat_min", 15.0)))
	var blackout_repeat_max = maxf(blackout_repeat_min, float(timers_tuning.get("blackout_repeat_max", 28.0)))
	var bomb_repeat_min = maxf(0.0, float(timers_tuning.get("bomb_repeat_min", 18.0)))
	var bomb_repeat_max = maxf(bomb_repeat_min, float(timers_tuning.get("bomb_repeat_max", 28.0)))
	return {
		"blackout_initial_min": blackout_initial_min,
		"blackout_initial_max": blackout_initial_max,
		"blackout_repeat_min": blackout_repeat_min,
		"blackout_repeat_max": blackout_repeat_max,
		"bomb_initial_timer": maxf(0.0, float(timers_tuning.get("bomb_initial_timer", 20.0))),
		"bomb_repeat_min": bomb_repeat_min,
		"bomb_repeat_max": bomb_repeat_max,
		"bomb_start_after": maxf(0.0, float(timers_tuning.get("bomb_start_after", 10.0))),
	}

static func _sanitize_blackout(blackout_tuning: Dictionary) -> Dictionary:
	var hold_min = maxf(0.0, float(blackout_tuning.get("hold_min", 2.0)))
	return {
		"hold_min": hold_min,
		"hold_max": maxf(hold_min, float(blackout_tuning.get("hold_max", 4.0))),
		"fade_in_alpha": clampf(float(blackout_tuning.get("fade_in_alpha", 0.88)), 0.0, 1.0),
		"fade_in_seconds": maxf(0.0, float(blackout_tuning.get("fade_in_seconds", 0.3))),
		"fade_out_alpha": clampf(float(blackout_tuning.get("fade_out_alpha", 0.0)), 0.0, 1.0),
		"fade_out_seconds": maxf(0.0, float(blackout_tuning.get("fade_out_seconds", 0.5))),
	}

static func _sanitize_bombardment(bomb_tuning: Dictionary) -> Dictionary:
	return {
		"center_radius_mult": maxf(0.0, float(bomb_tuning.get("center_radius_mult", 0.85))),
		"center_height": float(bomb_tuning.get("center_height", 0.05)),
		"event_text": str(bomb_tuning.get("event_text", "BOMBARDMENT INCOMING")),
		"event_text_color": _color(bomb_tuning.get("event_text_color", DEFAULTS["bombardment"]["event_text_color"]), Color(1.0, 0.35, 0.0)),
	}

static func _sanitize_barrage(barrage_tuning: Dictionary) -> Dictionary:
	return {
		"outer_radius": maxf(0.0, float(barrage_tuning.get("outer_radius", 14.0))),
		"pellet_radius": maxf(0.0, float(barrage_tuning.get("pellet_radius", 2.5))),
		"pellet_damage": maxf(0.0, float(barrage_tuning.get("pellet_damage", 22.0))),
		"pellet_count": max(1, int(barrage_tuning.get("pellet_count", 10))),
		"base_delay": maxf(0.0, float(barrage_tuning.get("base_delay", 0.7))),
		"pellet_gap": maxf(0.0, float(barrage_tuning.get("pellet_gap", 0.06))),
		"outer_color": _color(barrage_tuning.get("outer_color", DEFAULTS["barrage"]["outer_color"]), Color(1.0, 0.1, 0.1, 0.3)),
		"pellet_color": _color(barrage_tuning.get("pellet_color", DEFAULTS["barrage"]["pellet_color"]), Color(1.0, 0.45, 0.0, 0.75)),
		"flash_color": _color(barrage_tuning.get("flash_color", DEFAULTS["barrage"]["flash_color"]), Color(0.9, 0.3, 0.0, 0.5)),
		"flash_duration": maxf(0.0, float(barrage_tuning.get("flash_duration", 0.3))),
	}

static func _sanitize_standard(standard_tuning: Dictionary) -> Dictionary:
	return {
		"zone_radius": maxf(0.0, float(standard_tuning.get("zone_radius", 15.0))),
		"bomb_radius": maxf(0.0, float(standard_tuning.get("bomb_radius", 3.0))),
		"bomb_damage": maxf(0.0, float(standard_tuning.get("bomb_damage", 18.0))),
		"warn_delay": maxf(0.0, float(standard_tuning.get("warn_delay", 1.5))),
		"pellet_count": max(1, int(standard_tuning.get("pellet_count", 10))),
		"pellet_gap": maxf(0.0, float(standard_tuning.get("pellet_gap", 0.18))),
		"marker_color": _color(standard_tuning.get("marker_color", DEFAULTS["standard"]["marker_color"]), Color(1.0, 0.1, 0.1, 0.55)),
		"flash_color": _color(standard_tuning.get("flash_color", DEFAULTS["standard"]["flash_color"]), Color(0.9, 0.3, 0.0, 0.4)),
		"flash_duration": maxf(0.0, float(standard_tuning.get("flash_duration", 0.25))),
		"completion_delay": maxf(0.0, float(standard_tuning.get("completion_delay", 0.05))),
	}

static func _sanitize_disc(disc_tuning: Dictionary) -> Dictionary:
	return {
		"height": maxf(0.01, float(disc_tuning.get("height", 0.12))),
		"emission_green_mult": maxf(0.0, float(disc_tuning.get("emission_green_mult", 0.4))),
		"emission_blue": maxf(0.0, float(disc_tuning.get("emission_blue", 0.0))),
		"emission_energy": maxf(0.0, float(disc_tuning.get("emission_energy", 1.2))),
	}

static func _migrate_flat_timers(source: Dictionary) -> Dictionary:
	var migrated = source.duplicate(true)
	var timers_section = _section(migrated, "timers")
	for key in DEFAULTS["timers"].keys():
		if migrated.has(key):
			timers_section[key] = migrated[key]
			migrated.erase(key)
	if not timers_section.is_empty():
		migrated["timers"] = timers_section
	return migrated

static func _color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if typeof(value) == TYPE_ARRAY:
		var arr: Array = value
		if arr.size() >= 3:
			var alpha = float(arr[3]) if arr.size() > 3 else fallback.a
			return Color(float(arr[0]), float(arr[1]), float(arr[2]), alpha)
	return fallback

static func _section(tuning: Dictionary, key: String) -> Dictionary:
	var section = tuning.get(key, {})
	if typeof(section) != TYPE_DICTIONARY:
		return {}
	return section.duplicate(true)

static func _merge_dict(target: Dictionary, source: Dictionary) -> Dictionary:
	if typeof(source) != TYPE_DICTIONARY:
		return target
	for key in source.keys():
		var incoming = source[key]
		var current = target.get(key)
		if typeof(current) == TYPE_DICTIONARY and typeof(incoming) == TYPE_DICTIONARY:
			target[key] = _merge_dict(current.duplicate(true), incoming)
		else:
			target[key] = incoming
	return target
