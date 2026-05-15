class_name GameConfig
extends RefCounted

const DEFAULT_PATH := "res://data/game_config.json"

var data: Dictionary = {}

func load_or_default(path: String = DEFAULT_PATH) -> void:
	data = _default_data()

	if not FileAccess.file_exists(path):
		push_warning("GameConfig: %s not found. Using built-in defaults." % path)
		return

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("GameConfig: failed to open %s. Using built-in defaults." % path)
		return

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error != OK:
		push_warning("GameConfig: JSON parse error at line %d: %s. Using built-in defaults." % [
			json.get_error_line(),
			json.get_error_message()
		])
		return

	var parsed = json.get_data()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("GameConfig: root must be a Dictionary. Using built-in defaults.")
		return

	data = _merge_dict(data, parsed)

static func _merge_dict(target: Dictionary, source: Dictionary) -> Dictionary:
	for key in source.keys():
		var incoming = source[key]
		var current = target.get(key)
		if typeof(current) == TYPE_DICTIONARY and typeof(incoming) == TYPE_DICTIONARY:
			target[key] = _merge_dict(current.duplicate(true), incoming)
		else:
			target[key] = incoming
	return target

func match_value(key: String, fallback: Variant) -> Variant:
	return _section_value("match", key, fallback)

func zone_value(key: String, fallback: Variant) -> Variant:
	return _section_value("zone", key, fallback)

func zone_stage_configs() -> Dictionary:
	var section = data.get("zone", {})
	if typeof(section) != TYPE_DICTIONARY:
		return {}
	var stages = section.get("stages", {})
	if typeof(stages) != TYPE_DICTIONARY:
		return {}
	return stages.duplicate(true)

func hell_value(key: String, fallback: Variant) -> Variant:
	return _section_value("hell", key, fallback)

func runtime_tuning() -> Dictionary:
	var section = data.get("runtime", {})
	if typeof(section) != TYPE_DICTIONARY:
		return {}
	return section.duplicate(true)

func get_difficulty_params(difficulty: int) -> Dictionary:
	var section: Dictionary = data.get("difficulty", {})
	var params = section.get(str(difficulty), section.get(difficulty, {}))
	if typeof(params) != TYPE_DICTIONARY:
		return {}
	return params.duplicate(true)

func _section_value(section_name: String, key: String, fallback: Variant) -> Variant:
	var section = data.get(section_name, {})
	if typeof(section) != TYPE_DICTIONARY:
		return fallback
	return section.get(key, fallback)

func _default_data() -> Dictionary:
	return {
		"match": {
			"bot_count": 11,
			"loot_count": 40,
			"spawn_radius": 45.0
		},
		"zone": {
			"wait_time": 30.0,
			"shrink_time": 20.0,
			"damage_per_second": 2.0,
			"initial_timer": 15.0,
			"stages": {
				"2": { "wait_time": 20.0, "shrink_time": 15.0, "damage_per_second": 5.0 },
				"3": { "wait_time": 15.0, "shrink_time": 12.0, "damage_per_second": 10.0 },
				"4": { "wait_time": 10.0, "shrink_time": 10.0, "damage_per_second": 15.0 }
			}
		},
		"difficulty": {
			"0": { "vision_mult": 0.75, "reaction_delay": 1.2, "aim_spread": 1.8, "loot_break_mult": 0.0, "awareness_level": 0 },
			"1": { "vision_mult": 1.0, "reaction_delay": 0.2, "aim_spread": 1.0, "loot_break_mult": 1.0, "awareness_level": 1, "combat_loot_floor": 0.20, "idle_scan_interval_max": 1.8 },
			"2": { "vision_mult": 1.25, "reaction_delay": 0.0, "aim_spread": 0.65, "loot_break_mult": 1.5, "awareness_level": 2, "combat_loot_floor": 0.35, "combat_loot_radius": 22.0, "idle_scan_interval_max": 1.2 },
			"3": { "vision_mult": 1.5, "reaction_delay": 0.0, "aim_spread": 0.5, "loot_break_mult": 2.0, "awareness_level": 2, "combat_loot_floor": 0.40, "combat_loot_radius": 25.0, "idle_scan_interval_max": 0.9 }
		},
		"hell": {
			"blackout_initial_min": 12.0,
			"blackout_initial_max": 20.0,
			"blackout_repeat_min": 15.0,
			"blackout_repeat_max": 28.0,
			"bomb_initial_timer": 20.0,
			"bomb_repeat_min": 18.0,
			"bomb_repeat_max": 28.0
		},
		"runtime": {
			"spawn": {
				"safe_spawn_attempts": 50,
				"inner_radius": 5.0,
				"spawn_height": 1.0,
				"fallback_range": 10.0,
				"entity_clearance": 3.5,
				"obstacle_clearance_margin": 2.0
			},
			"navigation": {
				"agent_height": 1.8,
				"agent_radius": 0.5,
				"agent_max_climb": 0.3,
				"agent_max_slope": 45.0,
				"cell_size": 0.3,
				"cell_height": 0.25
			},
			"loot": {
				"stage_wave_base_prob": 0.1,
				"stage_wave_prob_per_stage": 0.1,
				"stage_wave_count_mult": 10
			},
			"supply_fallback": {
				"range": 25.0,
				"height": 1.0,
				"timer": 8.0
			}
		}
	}
