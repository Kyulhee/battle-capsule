class_name MatchRuntimeTuning
extends RefCounted

const DEFAULTS := {
	"spawn": {
		"safe_spawn_attempts": 50,
		"inner_radius": 5.0,
		"spawn_height": 1.0,
		"fallback_range": 10.0,
		"entity_clearance": 3.5,
		"obstacle_clearance_margin": 2.0,
	},
	"navigation": {
		"agent_height": 1.8,
		"agent_radius": 0.5,
		"agent_max_climb": 0.3,
		"agent_max_slope": 45.0,
		"cell_size": 0.3,
		"cell_height": 0.25,
	},
	"loot": {
		"stage_wave_base_prob": 0.1,
		"stage_wave_prob_per_stage": 0.1,
		"stage_wave_count_mult": 10,
		"hotspot_density_mult": 1.0,
		"rare_bias_mult": 1.0,
	},
	"supply_fallback": {
		"range": 25.0,
		"height": 1.0,
		"timer": 8.0,
	},
}

static func from_game_config(game_config) -> Dictionary:
	var tuning = DEFAULTS.duplicate(true)
	if game_config != null and game_config.has_method("runtime_tuning"):
		tuning = _merge_dict(tuning, game_config.runtime_tuning())
	return _sanitize(tuning)

static func spawn(tuning: Dictionary) -> Dictionary:
	return _sanitize_spawn(_merge_dict(DEFAULTS["spawn"].duplicate(true), _section(tuning, "spawn")))

static func navigation(tuning: Dictionary) -> Dictionary:
	return _sanitize_navigation(_merge_dict(DEFAULTS["navigation"].duplicate(true), _section(tuning, "navigation")))

static func stage_loot_wave(tuning: Dictionary, stage: int) -> Dictionary:
	var loot_tuning := loot(tuning)
	return {
		"probability": float(loot_tuning["stage_wave_base_prob"]) + (float(stage) * float(loot_tuning["stage_wave_prob_per_stage"])),
		"count_mult": int(loot_tuning["stage_wave_count_mult"]),
	}

static func loot(tuning: Dictionary) -> Dictionary:
	return _sanitize_loot(_merge_dict(DEFAULTS["loot"].duplicate(true), _section(tuning, "loot")))

static func supply_fallback(tuning: Dictionary) -> Dictionary:
	return _sanitize_supply_fallback(_merge_dict(DEFAULTS["supply_fallback"].duplicate(true), _section(tuning, "supply_fallback")))

static func _sanitize(tuning: Dictionary) -> Dictionary:
	return {
		"spawn": spawn(tuning),
		"navigation": navigation(tuning),
		"loot": loot(tuning),
		"supply_fallback": supply_fallback(tuning),
	}

static func _sanitize_spawn(spawn_tuning: Dictionary) -> Dictionary:
	return {
		"safe_spawn_attempts": max(1, int(spawn_tuning.get("safe_spawn_attempts", 50))),
		"inner_radius": maxf(0.0, float(spawn_tuning.get("inner_radius", 5.0))),
		"spawn_height": float(spawn_tuning.get("spawn_height", 1.0)),
		"fallback_range": maxf(0.0, float(spawn_tuning.get("fallback_range", 10.0))),
		"entity_clearance": maxf(0.0, float(spawn_tuning.get("entity_clearance", 3.5))),
		"obstacle_clearance_margin": maxf(0.0, float(spawn_tuning.get("obstacle_clearance_margin", 2.0))),
	}

static func _sanitize_navigation(nav_tuning: Dictionary) -> Dictionary:
	return {
		"agent_height": maxf(0.1, float(nav_tuning.get("agent_height", 1.8))),
		"agent_radius": maxf(0.1, float(nav_tuning.get("agent_radius", 0.5))),
		"agent_max_climb": maxf(0.0, float(nav_tuning.get("agent_max_climb", 0.3))),
		"agent_max_slope": clampf(float(nav_tuning.get("agent_max_slope", 45.0)), 0.0, 90.0),
		"cell_size": maxf(0.01, float(nav_tuning.get("cell_size", 0.3))),
		"cell_height": maxf(0.01, float(nav_tuning.get("cell_height", 0.25))),
	}

static func _sanitize_loot(loot_tuning: Dictionary) -> Dictionary:
	return {
		"stage_wave_base_prob": maxf(0.0, float(loot_tuning.get("stage_wave_base_prob", 0.1))),
		"stage_wave_prob_per_stage": maxf(0.0, float(loot_tuning.get("stage_wave_prob_per_stage", 0.1))),
		"stage_wave_count_mult": max(0, int(loot_tuning.get("stage_wave_count_mult", 10))),
		"hotspot_density_mult": maxf(0.0, float(loot_tuning.get("hotspot_density_mult", 1.0))),
		"rare_bias_mult": maxf(0.0, float(loot_tuning.get("rare_bias_mult", 1.0))),
	}

static func _sanitize_supply_fallback(supply_tuning: Dictionary) -> Dictionary:
	return {
		"range": maxf(0.0, float(supply_tuning.get("range", 25.0))),
		"height": float(supply_tuning.get("height", 1.0)),
		"timer": maxf(0.1, float(supply_tuning.get("timer", 8.0))),
	}

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
