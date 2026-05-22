extends RefCounted
class_name PressureConditionEvaluator


static func filter_feasible(pool: Array, zone_stage: int, bot_alive: int, condition: Dictionary) -> Array:
	return pool.filter(func(d): return is_descriptor_feasible(d, zone_stage, bot_alive, condition))


static func is_descriptor_feasible(descriptor: Dictionary, zone_stage: int, bot_alive: int, condition: Dictionary) -> bool:
	for cond in descriptor.get("conditions", []):
		var target = int(cond.get("target", 1))
		var type_id = int(cond["type"])
		if type_id == int(condition["KILL"]) \
			or type_id == int(condition["KILL_MELEE"]) \
			or type_id == int(condition["KILL_WHILE_ZONE_OUTSIDE"]) \
			or type_id == int(condition["KILL_LOW_HP"]):
			if bot_alive < target:
				return false
		elif type_id == int(condition["SURVIVE_DETECTED_SEC"]):
			if bot_alive < 2:
				return false
		elif type_id == int(condition["ZONE_OUTSIDE_SEC"]):
			if zone_stage >= 3 and target >= 10:
				return false
	return true


static func evaluate_conditions(descriptor: Dictionary, counters: Dictionary, condition: Dictionary) -> bool:
	for cond in descriptor.get("conditions", []):
		if not eval_single_condition(cond, counters, condition):
			return false
	return true


static func eval_single_condition(cond: Dictionary, counters: Dictionary, condition: Dictionary) -> bool:
	var target = int(cond.get("target", 1))
	var modifier = str(cond.get("modifier", ""))
	var type_id = int(cond["type"])
	if type_id == int(condition["KILL"]):
		match modifier:
			"undetected":
				return int(counters.get("kills_undetected", 0)) >= target
			"heavily_detected":
				return int(counters.get("kills_heavily_detected", 0)) >= target
			_:
				return int(counters.get("kills_total", 0)) >= target
	elif type_id == int(condition["NO_DAMAGE"]):
		return float(counters.get("damage_taken", 0.0)) == 0.0
	elif type_id == int(condition["NO_HEAL"]):
		return not bool(counters.get("heals_violated", false))
	elif type_id == int(condition["ZONE_OUTSIDE_SEC"]):
		return float(counters.get("outside_zone_sec", 0.0)) >= float(target)
	elif type_id == int(condition["KILL_MELEE"]):
		return int(counters.get("kills_melee", 0)) >= target
	elif type_id == int(condition["SURVIVE_DETECTED_SEC"]):
		return float(counters.get("detected_sec", 0.0)) >= float(target)
	elif type_id == int(condition["KILL_WHILE_ZONE_OUTSIDE"]):
		return int(counters.get("kills_outside_zone", 0)) >= target
	elif type_id == int(condition["KILL_LOW_HP"]):
		return int(counters.get("kills_low_hp", 0)) >= target
	return false
