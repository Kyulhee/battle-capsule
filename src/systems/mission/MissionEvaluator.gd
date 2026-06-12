extends RefCounted
class_name MissionEvaluator

const MissionDataScript = preload("res://src/core/MissionData.gd")
const MissionTuningScript = preload("res://src/systems/mission/MissionTuning.gd")


static func evaluate(mission, context: Dictionary) -> bool:
	var won = bool(context.get("won", false))
	var kills = int(context.get("kills", 0))
	match mission.condition_type:
		MissionDataScript.ConditionType.FIRST_KILL:
			return kills >= int(mission.target_value)
		MissionDataScript.ConditionType.WIN_HIGH_HP:
			var player_hp := float(context.get("player_hp", 0.0))
			var player_max_hp := maxf(1.0, float(context.get("player_max_hp", 100.0)))
			return won and player_hp / player_max_hp >= float(mission.target_value)
		MissionDataScript.ConditionType.WIN_WITH_HEALS:
			return won and int(context.get("medkits_used", 0)) >= int(mission.target_value)
		MissionDataScript.ConditionType.SURVIVE_NO_KILLS:
			return kills == 0 and float(context.get("duration", 0.0)) >= mission.target_value
		MissionDataScript.ConditionType.WIN_PISTOL_ONLY:
			return won and not bool(context.get("used_non_pistol", false))
		MissionDataScript.ConditionType.KILL_LAST_WITH_MELEE:
			return won and str(context.get("last_kill_weapon", "")) == "knife"
		MissionDataScript.ConditionType.KILLS_WITH_WEAPON:
			var weapon_kills: Dictionary = context.get("kills_by_weapon", {})
			return int(weapon_kills.get(mission.weapon_filter, 0)) >= int(mission.target_value)
		MissionDataScript.ConditionType.KILL_IN_BUSH:
			return int(context.get("kills_in_bush", 0)) >= int(mission.target_value)
		MissionDataScript.ConditionType.WIN_AFTER_ZONE_OUTSIDE:
			return won and float(context.get("player_max_outside_sec", 0.0)) >= mission.target_value
		MissionDataScript.ConditionType.KILL_NEAR_SUPPLY:
			return int(context.get("kills_near_supply", 0)) >= int(mission.target_value)
		MissionDataScript.ConditionType.KILL_UNDETECTED:
			return int(context.get("kills_undetected", 0)) >= int(mission.target_value)
		MissionDataScript.ConditionType.KILL_WHILE_DETECTED:
			return int(context.get("kills_while_detected", 0)) >= int(mission.target_value)
		MissionDataScript.ConditionType.WIN_ON_DIFFICULTY:
			return won and int(context.get("difficulty", 0)) == int(mission.target_value)
		MissionDataScript.ConditionType.KILL_WITH_ALL_WEAPONS:
			if not bool(context.get("has_telemetry", false)):
				return false
			var all_weapon_kills: Dictionary = context.get("kills_by_weapon", {})
			for weapon_type in MissionTuningScript.ALL_WEAPON_KILL_TYPES:
				if int(all_weapon_kills.get(weapon_type, 0)) < MissionTuningScript.ALL_WEAPON_KILL_TARGET:
					return false
			return true
		MissionDataScript.ConditionType.WIN_ONE_SLOT:
			return won and int(context.get("max_gun_slots_used", 0)) <= int(mission.target_value)
	return false


static func early_fail_status(mission, context: Dictionary) -> bool:
	match mission.condition_type:
		MissionDataScript.ConditionType.WIN_PISTOL_ONLY:
			return bool(context.get("used_non_pistol", false))
		MissionDataScript.ConditionType.SURVIVE_NO_KILLS:
			return bool(context.get("has_telemetry", false)) and int(context.get("kills", 0)) >= 1
		MissionDataScript.ConditionType.WIN_ONE_SLOT:
			return int(context.get("max_gun_slots_used", 0)) > int(mission.target_value)
	return false
