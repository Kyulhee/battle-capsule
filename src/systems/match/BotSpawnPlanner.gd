class_name BotSpawnPlanner
extends RefCounted

const DEFAULT_ARCHETYPE_WEIGHTS := [
	{"archetype": 0, "weight": 3}, # AGGRESSIVE
	{"archetype": 1, "weight": 3}, # DEFENSIVE
	{"archetype": 2, "weight": 2}, # SNIPER
	{"archetype": 3, "weight": 3}, # OPPORTUNIST
]

static func archetype_plan(bot_count: int, weights: Array = DEFAULT_ARCHETYPE_WEIGHTS) -> Array[int]:
	var plan: Array[int] = []
	if bot_count <= 0:
		return plan
	var base_pool = _build_weighted_pool(weights)
	if base_pool.is_empty():
		base_pool.append(0)
	while plan.size() < bot_count:
		var cycle = base_pool.duplicate()
		cycle.shuffle()
		for archetype in cycle:
			plan.append(int(archetype))
			if plan.size() >= bot_count:
				break
	return plan

static func force_archetype(plan: Array[int], archetype: int) -> Array[int]:
	var forced: Array[int] = []
	for _entry in plan:
		forced.append(archetype)
	return forced

static func _build_weighted_pool(weights: Array) -> Array[int]:
	var pool: Array[int] = []
	for spec in weights:
		var archetype = int(spec.get("archetype", 0))
		var weight = max(0, int(spec.get("weight", 0)))
		for _i in range(weight):
			pool.append(archetype)
	return pool
