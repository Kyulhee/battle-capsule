extends SceneTree

const AUDIT = preload("res://tools/LootSearchAudit.gd")
class SearchBot:
	extends "res://src/entities/bot/Bot.gd"
	var senses := 0
	var weapon_checks := 0
	func _ready(): pass
	func can_sense_item(pos: Vector3) -> bool:
		senses += 1
		return pos.x != 2.0
	func can_receive_weapon(_stats: StatsData) -> bool:
		weapon_checks += 1
		return false

class SearchPickup:
	extends Node3D
	var item: ItemData

var failures: Array[String] = []
var samples: Array = []

func _init():
	_run.call_deferred()

func _run():
	create_timer(5.0).timeout.connect(func(): quit(1))
	var bot := SearchBot.new()
	bot.stats = StatsData.new()
	bot.stats.weapon_type = "ar"
	bot.stats.current_ammo = 0
	bot.stats.max_ammo = 30
	bot.current_health = bot.stats.max_health
	bot.equipped_armor_tier = 1
	var ray := RayCast3D.new()
	ray.name = "RayCast3D"
	bot.add_child(ray)
	root.add_child(bot)
	bot.set_process(false)
	bot.set_physics_process(false)
	var pickups: Array = []
	for x in [30, 2, 3, 4, 5, 6, 7, 8, 9, -7]:
		var p := SearchPickup.new()
		if x != 9:
			p.item = ItemData.new()
			p.item.type = ItemData.Type.AMMO
			p.item.ammo_weapon_type = "shotgun" if x == 3 else "ar"
			if x in [4, 5]:
				p.item.type = ItemData.Type.WEAPON
				if x == 5: p.item.weapon_stats = StatsData.new()
			elif x == 6:
				p.item.type = ItemData.Type.ARMOR
				p.item.equipment_id = "armor"
				p.item.equipment_tier = 1
			elif x == 8: p.item.type = ItemData.Type.HEAL
		root.add_child(p)
		p.position.x = x
		p.add_to_group("pickups")
		pickups.append(p)
	_check(not bot._loot_search_trace_sink.is_valid(), "Trace unexpectedly enabled")
	seed(88)
	var off = bot._find_best_pickup(20.0, true)
	var off_random := randi()
	var senses: int = bot.senses
	var checks: int = bot.weapon_checks
	var audit = AUDIT.new()
	bot._loot_search_trace_sink = func(sample):
		samples.append(sample.duplicate(true))
		audit.record(sample, 10.0)
	bot._pickup_search_timer = -1.0
	bot.senses = 0
	bot.weapon_checks = 0
	seed(88)
	var on = bot._find_best_pickup(20.0, true)
	_check(on == off and on == pickups[6], "Trace changed selection/tie ordering")
	_check(randi() == off_random and bot.senses == senses and bot.weapon_checks == checks,
		"Trace changed RNG or predicate calls")
	_check(senses == 9 and checks == 1, "Filter short circuit count differs")
	_check(samples[-1]["counts"] == {"pool": 10, "invalid": 0, "out_of_radius": 1,
		"not_sensed": 1, "ammo_mismatch": 1, "weapon_rejected": 2, "armor_not_upgrade": 1, "accepted": 4},
		"First-rejection accounting differs")
	bot._find_best_pickup(20.0, true)
	_check(samples[-1]["mode"] == "cached_hit" and bot.senses == senses, "Cache hit rescanned")
	bot.current_state = bot.State.RECOVER
	bot.recovery_substate = "patrol"
	bot._find_best_pickup(20.0, true)
	_check(audit.report["by_scope"].has("RECOVER/patrol"), "Recovery scope lost")
	for p in pickups: p.remove_from_group("pickups")
	bot._pickup_search_timer = -1.0
	_check(bot._find_best_pickup(20.0, true) == null, "Empty pool selected an item")
	bot._find_best_pickup(20.0, true)
	_check(samples[-1]["mode"] == "cached_none", "Negative cache was not recorded")
	for p in pickups: p.add_to_group("pickups")
	# Query radius change must still invalidate a matching timer-backed cache.
	_check(bot._find_best_pickup(21.0, true) == off and samples[-1]["mode"] == "scan", "Query change reused cache")
	off.free()
	var sink: Callable = bot._loot_search_trace_sink
	bot._loot_search_trace_sink = Callable()
	var expired_off = bot._find_best_pickup(21.0, true)
	bot._loot_search_trace_sink = sink
	_check(bot._find_best_pickup(21.0, true) == expired_off, "Trace changed expired-cache behavior")
	bot._pickup_search_timer = -1.0
	_check(bot._find_best_pickup(21.0, true) == pickups[-1], "Expired timer did not rescan")
	var captured := samples.size()
	for mode in ["armed", "reserve", "combat", "disabled"]:
		bot.current_state = bot.State.IDLE
		bot.stats.current_ammo = 1 if mode == "armed" else 0
		bot.reserve_ammo = 1 if mode == "reserve" else 0
		if mode == "combat": bot.current_state = bot.State.ATTACK
		if mode == "disabled": bot._loot_search_trace_sink = Callable()
		bot._pickup_search_timer = -1.0
		bot._find_best_pickup(21.0, true)
	_check(samples.size() == captured, "Out-of-scope/disabled searches emitted events")
	_check(audit.report["valid"], "Runtime sample accounting invalid")
	_test_retention(samples[0])
	for p in pickups:
		if is_instance_valid(p): p.free()
	bot.free()
	if not failures.is_empty():
		for failure in failures: push_error(failure)
		quit(1)
		return
	print("Loot search runtime passed: same choice/RNG/predicate calls, cache/expiry/scope, exact filters, bounded retention.")
	quit(0)

func _test_retention(base: Dictionary):
	var audit = AUDIT.new()
	for scope in AUDIT.SCOPES:
		for outcome in AUDIT.OUTCOMES:
			var sample := base.duplicate(true)
			sample["state"] = "IDLE" if scope == "IDLE" else "RECOVER"
			sample["recovery_substate"] = "" if scope == "IDLE" else scope.split("/")[1]
			for key in sample["counts"]: sample["counts"][key] = 0
			sample["mode"] = outcome if outcome.begins_with("cached_") else "scan"
			sample["selected_id"] = 42 if outcome in ["selected", "cached_hit"] else null
			var key: String = {"selected": "accepted", "invalid_pool": "invalid", "out_of_radius": "out_of_radius",
				"not_sensed": "not_sensed", "item_rules": "ammo_mismatch"}.get(outcome, "")
			if key != "":
				sample["counts"][key] = 1
				sample["counts"]["pool"] = 1
			var before := sample.duplicate(true)
			for i in range(3): audit.record(sample, 20.0 + i)
			_check(sample == before, "Audit mutated caller sample")
	_check(audit.report["valid"] and audit.report["calls"] == 96 and audit.report["events"].size() == 64
		and audit.report["omitted"] == 32, "Bounded exact retention mismatch")
	var invalid = AUDIT.new()
	var bad := base.duplicate(true)
	bad["counts"]["pool"] += 1
	invalid.record(bad, 2.0)
	_check(not invalid.report["valid"] and invalid.report["calls"] == 0, "Bad count sum accepted")

func _check(condition: bool, message: String):
	if not condition: failures.append(message)
