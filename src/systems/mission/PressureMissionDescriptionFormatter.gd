extends RefCounted
class_name PressureMissionDescriptionFormatter

const MissionTuningScript = preload("res://src/systems/mission/MissionTuning.gd")


static func description(conditions: Array, condition: Dictionary) -> String:
	var parts: Array = []
	var compact = conditions.size() > 1
	for cond in conditions:
		parts.append(condition_text(cond, condition, compact))
	return " + ".join(parts)


static func condition_text(cond: Dictionary, condition: Dictionary, compact: bool = false) -> String:
	var target = int(cond.get("target", 1))
	var modifier = str(cond.get("modifier", ""))
	var type_id = int(cond.get("type", -1))
	if type_id == int(condition["KILL"]):
		match modifier:
			"undetected":
				return "미탐지 킬 %d" % target if compact else "미탐지 상태로 킬 %d" % target
			"heavily_detected":
				return "봇 %d마리+ 감지 상태에서 킬 %d" % [
					MissionTuningScript.HEAVILY_DETECTED_BOT_COUNT,
					target,
				]
			_:
				return "킬 %d" % target if compact else "킬 %d 달성" % target
	elif type_id == int(condition["NO_DAMAGE"]):
		return "피해 0" if compact else "피해 받지 않기"
	elif type_id == int(condition["NO_HEAL"]):
		return "힐 금지" if compact else "힐 사용 금지"
	elif type_id == int(condition["ZONE_OUTSIDE_SEC"]):
		return "자기장 밖 %d초" % target if compact else "자기장 밖 %d초 이상 체류" % target
	elif type_id == int(condition["KILL_MELEE"]):
		return "칼 킬 %d" % target if compact else "칼로 킬 %d" % target
	elif type_id == int(condition["SURVIVE_DETECTED_SEC"]):
		return "봇 %d마리+ 감지 상태에서 %d초 생존" % [
			MissionTuningScript.DETECTED_BOT_COUNT,
			target,
		]
	elif type_id == int(condition["KILL_WHILE_ZONE_OUTSIDE"]):
		return "자기장 밖에서 킬 %d" % target
	elif type_id == int(condition["KILL_LOW_HP"]):
		return "HP %s 이하에서 킬 %d" % [MissionTuningScript.low_hp_ratio_label(), target]
	return "조건 %d/%d" % [type_id, target]
