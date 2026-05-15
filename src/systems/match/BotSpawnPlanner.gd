class_name BotSpawnPlanner
extends RefCounted

const DEFAULT_ARCHETYPE := "AGGRESSIVE"
const DEFAULT_ARCHETYPE_WEIGHTS := [
	{"archetype": "AGGRESSIVE", "weight": 3},
	{"archetype": "DEFENSIVE", "weight": 3},
	{"archetype": "SNIPER", "weight": 2},
	{"archetype": "OPPORTUNIST", "weight": 3},
]

static func archetype_plan(bot_count: int, weights: Array = DEFAULT_ARCHETYPE_WEIGHTS) -> Array[String]:
	var plan: Array[String] = []
	if bot_count <= 0:
		return plan
	var base_pool = _build_weighted_pool(weights)
	if base_pool.is_empty():
		base_pool.append(DEFAULT_ARCHETYPE)
	while plan.size() < bot_count:
		var cycle = base_pool.duplicate()
		cycle.shuffle()
		for archetype in cycle:
			plan.append(str(archetype))
			if plan.size() >= bot_count:
				break
	return plan

static func force_archetype(plan: Array[String], archetype: String) -> Array[String]:
	var forced: Array[String] = []
	var archetype_name = _normalize_archetype_name(archetype)
	for _entry in plan:
		forced.append(archetype_name)
	return forced

static func _build_weighted_pool(weights: Array) -> Array[String]:
	var pool: Array[String] = []
	for spec in weights:
		var archetype = _normalize_archetype_name(str(spec.get("archetype", DEFAULT_ARCHETYPE)))
		var weight = max(0, int(spec.get("weight", 0)))
		for _i in range(weight):
			pool.append(archetype)
	return pool

static func _normalize_archetype_name(archetype: String) -> String:
	var normalized = archetype.strip_edges().to_upper()
	return normalized if normalized != "" else DEFAULT_ARCHETYPE
