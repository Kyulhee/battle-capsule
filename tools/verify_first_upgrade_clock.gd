extends SceneTree

# Controlled ordering, not a claim about how many physics ticks a real frame runs.
# Use the real Bot chase, Pickup.collect, Entity.receive_weapon and Telemetry clock.
class ClockMain:
	extends Node
	var match_timer := 0.0
	var map_definition = null
	var map_spec_path := "res://tests/clock_fixture.json"
	var map_scale_preset := "test"
	func advance_process(delta: float): match_timer += delta
class ClockBot:
	extends "res://src/entities/bot/Bot.gd"
	var nav_calls := 0
	var advance_navigation := false
	func _ready(): pass
	func _update_objective_scan(_delta: float, _pos: Vector3) -> void: pass
	func _maybe_interrupt_objective_for_enemy() -> bool: return false
	func _try_reload(): pass
	func change_state(new_state: State, _reason: String = ""): current_state = new_state
	func _nav_move_toward(pos: Vector3, delta: float, _rotate: bool = true):
		nav_calls += 1
		if advance_navigation: position = position.move_toward(pos, 4.0 * delta)
class ClockPickup:
	extends "res://src/entities/pickup/Pickup.gd"
	func _ready(): pass
class RejectClockBot:
	extends ClockBot
	func receive_weapon(_weapon: StatsData) -> bool: return false

var failures: Array[String] = []

func _init(): _run.call_deferred()
func _check(ok: bool, message: String):
	if not ok: failures.append(message)

func _run():
	var main := ClockMain.new()
	main.name = "Main"
	root.add_child(main)
	var tel = root.get_node("Telemetry")
	var original_scale := Engine.time_scale
	for scale in [1.0, 5.0]:
		Engine.time_scale = scale
		for scenario in ["physics_before_process", "process_before_physics", "outside_collect_radius", "positive_clock", "burst_before_process"]:
			main.match_timer = 0.0
			tel.start_match()
			_check(tel.metrics.economy.first_upgrade_time == -1.0, "Unset time is not -1")
			var bot := ClockBot.new()
			bot.stats = StatsData.new()
			bot.stats.weapon_type = "pistol"
			bot.stats.weapon_tier = 1
			bot.stats.current_ammo = 20
			bot.current_health = bot.stats.max_health
			var ray := RayCast3D.new()
			ray.name = "RayCast3D"
			bot.add_child(ray)
			root.add_child(bot)
			bot.set_process(false)
			bot.set_physics_process(false)
			var pickup := ClockPickup.new()
			pickup.item = ItemData.new()
			pickup.item.type = ItemData.Type.WEAPON
			pickup.item.item_name = "shotgun"
			pickup.item.weapon_stats = StatsData.new()
			pickup.item.weapon_stats.weapon_type = "shotgun"
			pickup.item.weapon_stats.weapon_tier = 2
			pickup._spawn_source = "initial_loot"
			root.add_child(pickup)
			pickup.set_process(false)
			pickup.position = Vector3(2.5001 if scenario == "outside_collect_radius" else 2.5, 0, 0)
			if scenario == "burst_before_process":
				pickup.position.x = 4.16684 # E078 closest initial XZ pair; not attributed to its first collector.
				bot.advance_navigation = true
			bot.target_actor = pickup
			bot.is_targeting_loot = true
			bot.current_state = bot.State.CHASE
			var physics_delta: float = scale / 60.0
			if scenario == "process_before_physics": main.advance_process(physics_delta)
			if scenario == "positive_clock": main.advance_process(12.5)
			var expected_time := main.match_timer
			var success_events: Array = []
			_check(not pickup._collect_success_sink.is_valid(), "Default success observer is active")
			pickup._collect_success_sink = func(observed_pickup, observed_bot):
				success_events.append([observed_pickup == pickup, observed_bot == bot, observed_bot.stats.weapon_type])
			var steps := 8 if scenario == "burst_before_process" else 1
			for step in range(steps):
				bot.state_timer += physics_delta
				bot.handle_chase_state(physics_delta)
				if pickup.is_queued_for_deletion(): break
			var collected: bool = scenario != "outside_collect_radius" and not (scenario == "burst_before_process" and scale == 1.0)
			_check(pickup.is_queued_for_deletion() == collected and (bot.stats.weapon_type == "shotgun") == collected,
				"Actual collect/equip differs: " + scenario)
			_check(bot.nav_calls > 0 if scenario == "burst_before_process" else bot.nav_calls == int(not collected), "Collect radius/navigation boundary differs")
			_check(tel.metrics.economy.first_upgrade_time == (expected_time if collected else -1.0), "Economy time differs")
			_check(tel.metrics.pacing.first_non_pistol_upgrade_time == (expected_time if collected else -1.0), "Pacing/economy clock differs")
			_check(success_events == ([[true, true, "shotgun"]] if collected else []), "Success observer must run once after actual equip")
			if collected:
				_check(tel.metrics.economy.first_upgrade_source == "initial_loot", "Collection source missing")
				main.advance_process(3.0)
				tel.log_pickup("assault_rifle", "weapon", false)
				_check(tel.metrics.economy.first_upgrade_time == expected_time, "Later pickup overwrote zero first event")
			print("UPGRADE_CLOCK scale=%.0f scenario=%s handler_delta=%.6f nav_calls=%d displacement=%.6f collected=%s event=%.6f" % [
				scale, scenario, physics_delta, bot.nav_calls, bot.position.length(), collected, tel.metrics.economy.first_upgrade_time])
			pickup.free()
			bot.free()
	var rejected_bot := RejectClockBot.new()
	rejected_bot.stats = StatsData.new()
	rejected_bot.stats.weapon_type = "pistol"
	rejected_bot.stats.weapon_tier = 1
	var rejected_ray := RayCast3D.new()
	rejected_ray.name = "RayCast3D"
	rejected_bot.add_child(rejected_ray)
	root.add_child(rejected_bot)
	var rejected_pickup := ClockPickup.new()
	rejected_pickup.item = ItemData.new()
	rejected_pickup.item.type = ItemData.Type.WEAPON
	rejected_pickup.item.item_name = "shotgun"
	rejected_pickup.item.weapon_stats = StatsData.new()
	rejected_pickup.item.weapon_stats.weapon_type = "shotgun"
	rejected_pickup.item.weapon_stats.weapon_tier = 2
	root.add_child(rejected_pickup)
	var rejected_events: Array = []
	rejected_pickup._collect_success_sink = func(_pickup, _bot): rejected_events.append(true)
	_check(not rejected_pickup.collect(rejected_bot), "Rejected equipment reported success")
	_check(rejected_events.is_empty() and not rejected_pickup.is_queued_for_deletion(), "Rejected receive emitted success or deleted pickup")
	_check(rejected_bot.stats.weapon_type == "pistol", "Rejected equipment changed weapon")
	rejected_pickup.free()
	rejected_bot.free()
	Engine.time_scale = original_scale
	tel.match_in_progress = false
	main.free()
	if not failures.is_empty():
		for failure in failures: push_error(failure)
		quit(1)
		return
	print("First upgrade clock passed: real collection at 2.5m and accelerated stub approach from4.16684m can record canonical0 before process advances; -1 unset/zero retained; no double scaling. Controlled handler order, not full-match scheduling/reachability proof.")
	quit(0)
