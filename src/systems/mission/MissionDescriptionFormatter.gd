extends RefCounted
class_name MissionDescriptionFormatter

const MissionDataScript = preload("res://src/core/MissionData.gd")
const MissionTuningScript = preload("res://src/systems/mission/MissionTuning.gd")

const WEAPON_LABELS = {
	"pistol": "피스톨",
	"ar": "돌격소총",
	"shotgun": "샷건",
	"railgun": "레일건",
	"knife": "칼",
}

const COMPACT_WEAPON_LABELS = {
	"pistol": "피스톨",
	"ar": "AR",
	"shotgun": "샷건",
	"railgun": "레일건",
	"knife": "칼",
}


static func bonus_description(mission) -> String:
	match mission.condition_type:
		MissionDataScript.ConditionType.FIRST_KILL:
			return "이번 매치에서 %d킬 이상 달성" % _target_int(mission)
		MissionDataScript.ConditionType.WIN_HIGH_HP:
			return "최대 HP의 %s 이상으로 1등" % MissionTuningScript.clean_win_ratio_label()
		MissionDataScript.ConditionType.WIN_WITH_HEALS:
			return "구급상자(◆) %d회 이상 사용 후 1등" % _target_int(mission)
		MissionDataScript.ConditionType.KILL_WITH_ALL_WEAPONS:
			return "%s으로 각각 %d킬 이상 달성" % [
				all_weapon_labels(true),
				MissionTuningScript.ALL_WEAPON_KILL_TARGET,
			]
		MissionDataScript.ConditionType.SURVIVE_NO_KILLS:
			return "킬 없이 %d초 이상 생존" % _target_int(mission)
		MissionDataScript.ConditionType.WIN_PISTOL_ONLY:
			return "권총만 사용해서 1등"
		MissionDataScript.ConditionType.KILL_LAST_WITH_MELEE:
			return "마지막 킬을 칼로 끝내고 1등"
		MissionDataScript.ConditionType.KILLS_WITH_WEAPON:
			return "%s으로 %d킬 이상" % [weapon_label(str(mission.weapon_filter)), _target_int(mission)]
		MissionDataScript.ConditionType.KILL_IN_BUSH:
			return "수풀 안/근처에서 %d킬 이상" % _target_int(mission)
		MissionDataScript.ConditionType.WIN_AFTER_ZONE_OUTSIDE:
			return "자기장 밖에서 %d초 이상 버티고 1등" % _target_int(mission)
		MissionDataScript.ConditionType.KILL_NEAR_SUPPLY:
			return "보급 캡슐 근처(%s)에서 %d킬 이상" % [
				MissionTuningScript.supply_kill_radius_label(),
				_target_int(mission),
			]
		MissionDataScript.ConditionType.KILL_UNDETECTED:
			return "봇이 인식하기 전(awareness < %s)에 %d킬 이상" % [
				MissionTuningScript.detection_threshold_label(),
				_target_int(mission),
			]
		MissionDataScript.ConditionType.KILL_WHILE_DETECTED:
			return "봇 %d명 이상 감지 상태에서 %d킬 이상" % [
				MissionTuningScript.DETECTED_BOT_COUNT,
				_target_int(mission),
			]
		MissionDataScript.ConditionType.WIN_ONE_SLOT:
			return "총기 슬롯 %d개 이하만 사용하고 1등" % _target_int(mission)
	return str(mission.description)


static func weapon_label(weapon_type: String, compact: bool = false) -> String:
	var labels = COMPACT_WEAPON_LABELS if compact else WEAPON_LABELS
	return str(labels.get(weapon_type, weapon_type))


static func all_weapon_labels(compact: bool = false, separator: String = "·") -> String:
	var labels: Array = []
	for weapon_type in MissionTuningScript.ALL_WEAPON_KILL_TYPES:
		labels.append(weapon_label(str(weapon_type), compact))
	return separator.join(labels)


static func _target_int(mission) -> int:
	return int(round(float(mission.target_value)))
