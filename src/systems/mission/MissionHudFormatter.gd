extends RefCounted
class_name MissionHudFormatter

const MissionDataScript = preload("res://src/core/MissionData.gd")
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


static func bonus_hud_text(mission, context: Dictionary) -> String:
	var kills = int(context.get("kills", 0))
	match mission.condition_type:
		MissionDataScript.ConditionType.FIRST_KILL:
			return "%s\n킬 횟수  %d / 1" % [mission.title, kills]
		MissionDataScript.ConditionType.WIN_HIGH_HP:
			return "%s\n현재 HP %.0f — 우승 시 HP %.0f 이상 필요" % [
				mission.title,
				float(context.get("current_hp", 0.0)),
				mission.target_value,
			]
		MissionDataScript.ConditionType.WIN_WITH_HEALS:
			return "%s\n구급상자(◆) 사용  %d / %d" % [
				mission.title,
				int(context.get("medkits_used", 0)),
				int(mission.target_value),
			]
		MissionDataScript.ConditionType.SURVIVE_NO_KILLS:
			if kills >= 1:
				return "%s\n✗ 킬 발생 — 실패 확정" % mission.title
			return "%s\n킬 없이 90초 생존 — 현재 킬 0회" % mission.title
		MissionDataScript.ConditionType.WIN_PISTOL_ONLY:
			if bool(context.get("used_non_pistol", false)):
				return "%s\n✗ 다른 무기 사용됨 — 실패 확정" % mission.title
			return "%s\n권총만 사용 중 ✓" % mission.title
		MissionDataScript.ConditionType.KILL_LAST_WITH_MELEE:
			var weapon_names = {"knife": "칼 ✓", "pistol": "피스톨", "ar": "돌격소총", "shotgun": "샷건", "railgun": "레일건"}
			var last_weapon = str(context.get("last_kill_weapon", ""))
			if last_weapon == "":
				return "%s\n칼로 마지막 킬 달성 — 아직 킬 없음" % mission.title
			return "%s\n칼로 마지막 킬 달성 — 현재 %s" % [mission.title, weapon_names.get(last_weapon, last_weapon)]
		MissionDataScript.ConditionType.KILLS_WITH_WEAPON:
			var weapon_kills: Dictionary = context.get("kills_by_weapon", {})
			var wkills = int(weapon_kills.get(mission.weapon_filter, 0))
			var weapon_names2 = {"pistol": "피스톨", "ar": "돌격소총", "shotgun": "샷건", "railgun": "레일건", "knife": "칼"}
			return "%s\n%s 킬  %d / %d" % [mission.title, weapon_names2.get(mission.weapon_filter, mission.weapon_filter), wkills, int(mission.target_value)]
		MissionDataScript.ConditionType.KILL_IN_BUSH:
			return "%s\n수풀 안/근처 킬  %d / %d" % [mission.title, int(context.get("kills_in_bush", 0)), int(mission.target_value)]
		MissionDataScript.ConditionType.WIN_AFTER_ZONE_OUTSIDE:
			return "%s\n자기장 밖 최장 체류  %.0f초 / %.0f초" % [mission.title, float(context.get("player_max_outside_sec", 0.0)), mission.target_value]
		MissionDataScript.ConditionType.KILL_NEAR_SUPPLY:
			return "%s\n보급 캡슐 근처(12m) 킬  %d / %d" % [mission.title, int(context.get("kills_near_supply", 0)), int(mission.target_value)]
		MissionDataScript.ConditionType.KILL_UNDETECTED:
			return "%s\n봇 미탐지 상태에서 킬  %d / %d" % [mission.title, int(context.get("kills_undetected", 0)), int(mission.target_value)]
		MissionDataScript.ConditionType.KILL_WHILE_DETECTED:
			return "%s\n봇 2명 이상 감지 상태에서 킬  %d / %d" % [mission.title, int(context.get("kills_while_detected", 0)), int(mission.target_value)]
		MissionDataScript.ConditionType.WIN_ON_DIFFICULTY:
			var diff_names = ["쉬움", "보통", "어려움", "지옥"]
			var diff_index = int(mission.target_value)
			return "%s\n%s 난이도로 1등 달성 필요" % [mission.title, diff_names[diff_index] if diff_index < diff_names.size() else "?"]
		MissionDataScript.ConditionType.KILL_WITH_ALL_WEAPONS:
			if not bool(context.get("has_telemetry", false)):
				return "%s\n모든 총으로 각각 1킬 이상 달성" % mission.title
			var all_weapon_kills: Dictionary = context.get("kills_by_weapon", {})
			var gun_labels = [["pistol", "피스톨"], ["ar", "돌격소총"], ["shotgun", "샷건"], ["railgun", "레일건"]]
			var done: Array = []
			var todo: Array = []
			for g in gun_labels:
				if all_weapon_kills.get(g[0], 0) >= 1: done.append(g[1])
				else: todo.append(g[1])
			var status = ""
			if done.size() > 0: status += "✓ " + "  ".join(done)
			if todo.size() > 0:
				if status != "": status += "   /   "
				status += "✗ " + "  ".join(todo)
			return "%s\n%s" % [mission.title, status]
		MissionDataScript.ConditionType.WIN_ONE_SLOT:
			var max_gun_slots_used = int(context.get("max_gun_slots_used", 0))
			if max_gun_slots_used > 1:
				return "%s\n✗ 총기 2종 이상 소지 — 실패 확정" % mission.title
			return "%s\n총기 슬롯 %d/1 사용 중 ✓" % [mission.title, max_gun_slots_used]
	return mission.title
