extends RefCounted
class_name MissionHudFormatter

const PressureEffectCatalogScript = preload("res://src/core/PressureEffectCatalog.gd")


static func pressure_hud_text(descriptor: Dictionary, deadline: float, counters: Dictionary, condition: Dictionary) -> String:
	if descriptor.is_empty():
		return ""
	var title = descriptor.get("title", "")
	var desc = descriptor.get("description", "")
	var sec = int(ceil(deadline))
	var progress = pressure_progress_text(descriptor, counters, condition)
	var line2 = desc if progress == "" else "%s  [%s]" % [desc, progress]
	var reward_txt = format_pressure_effects(descriptor.get("reward", []))
	var penalty_txt = format_pressure_effects(descriptor.get("penalty", []))
	return "⚡ %s  |  %ds\n%s\n✓ %s   ✗ %s" % [title, sec, line2, reward_txt, penalty_txt]


static func format_pressure_effects(effects: Array) -> String:
	return PressureEffectCatalogScript.format_effects(effects)


static func pressure_progress_text(descriptor: Dictionary, counters: Dictionary, condition: Dictionary) -> String:
	var conditions = descriptor.get("conditions", [])
	if conditions.is_empty():
		return ""
	var parts: Array = []
	for cond in conditions:
		var target = int(cond.get("target", 1))
		var mod = cond.get("modifier", "")
		var type_id = int(cond["type"])
		if type_id == int(condition["KILL"]):
			var cur = int(counters.get("kills_undetected", 0)) if mod == "undetected" \
				else (int(counters.get("kills_heavily_detected", 0)) if mod == "heavily_detected" else int(counters.get("kills_total", 0)))
			parts.append("킬 %d/%d" % [cur, target])
		elif type_id == int(condition["NO_DAMAGE"]):
			parts.append("무피해 ✓" if float(counters.get("damage_taken", 0.0)) == 0.0 else "피해 발생 ✗")
		elif type_id == int(condition["NO_HEAL"]):
			parts.append("힐 미사용 ✓" if not bool(counters.get("heals_violated", false)) else "힐 사용 ✗")
		elif type_id == int(condition["ZONE_OUTSIDE_SEC"]):
			parts.append("존 밖 %.0f/%ds" % [float(counters.get("outside_zone_sec", 0.0)), target])
		elif type_id == int(condition["KILL_MELEE"]):
			parts.append("칼 킬 %d/%d" % [int(counters.get("kills_melee", 0)), target])
		elif type_id == int(condition["SURVIVE_DETECTED_SEC"]):
			parts.append("감지 생존 %.0f/%ds" % [float(counters.get("detected_sec", 0.0)), target])
		elif type_id == int(condition["KILL_WHILE_ZONE_OUTSIDE"]):
			parts.append("존 밖 킬 %d/%d" % [int(counters.get("kills_outside_zone", 0)), target])
		elif type_id == int(condition["KILL_LOW_HP"]):
			parts.append("저HP 킬 %d/%d" % [int(counters.get("kills_low_hp", 0)), target])
	return "  ".join(parts)
