class_name MatchTuning
extends RefCounted

static func from_game_config(game_config, current: Dictionary) -> Dictionary:
	if not game_config:
		return {}
	return {
		"bot_count": max(0, int(game_config.match_value("bot_count", current.get("bot_count", 11)))),
		"loot_count": max(0, int(game_config.match_value("loot_count", current.get("loot_count", 40)))),
		"spawn_radius": maxf(1.0, float(game_config.match_value("spawn_radius", current.get("spawn_radius", 45.0)))),
		"zone_wait_time": maxf(1.0, float(game_config.zone_value("wait_time", current.get("zone_wait_time", 30.0)))),
		"zone_shrink_time": maxf(1.0, float(game_config.zone_value("shrink_time", current.get("zone_shrink_time", 20.0)))),
		"zone_damage": maxf(0.0, float(game_config.zone_value("damage_per_second", current.get("zone_damage", 2.0)))),
		"zone_initial_timer": maxf(0.1, float(game_config.zone_value("initial_timer", current.get("zone_initial_timer", 15.0)))),
		"zone_stage_configs": game_config.zone_stage_configs(),
	}

static func from_cmdline_arg(arg: String) -> Dictionary:
	var lower = arg.to_lower()
	if not lower.contains("="):
		return {}

	var key = lower.get_slice("=", 0)
	var value = lower.get_slice("=", 1)
	match key:
		"difficulty":
			var difficulty = _difficulty_index(value)
			if difficulty >= 0:
				return {"difficulty": difficulty}
		"bot_count":
			return {"tuning": {"bot_count": max(0, int(value))}}
		"loot_count":
			return {"tuning": {"loot_count": max(0, int(value))}}
		"spawn_radius":
			return {"tuning": {"spawn_radius": maxf(1.0, float(value))}}
		"zone_wait_time", "zone_wait":
			return {"tuning": {"zone_wait_time": maxf(1.0, float(value))}}
		"zone_shrink_time", "zone_shrink":
			return {"tuning": {"zone_shrink_time": maxf(1.0, float(value))}}
		"zone_damage", "zone_dps":
			return {"tuning": {"zone_damage": maxf(0.0, float(value))}}
		"zone_initial_timer", "zone_initial":
			return {"tuning": {"zone_initial_timer": maxf(0.1, float(value))}}
	return {}

static func _difficulty_index(value: String) -> int:
	match value:
		"easy", "0":
			return 0
		"normal", "1":
			return 1
		"hard", "2":
			return 2
		"hell", "3":
			return 3
	return -1
