extends SceneTree

# 실제 chase/start/finish/수집 분기를 사용하되 이동·지각·재탐색만 결정적으로 격리한다.
# 이 fixture는 NavMesh 통과나 자연 교전/생존 개선의 근거가 아니다.
class ChaseBot:
	extends "res://src/entities/bot/Bot.gd"
	var fixture_speed := 3.5
	var blocked := false
	var interrupt := false
	var alternative: Node3D
	func _ready():
		pass
	func _update_objective_scan(_delta: float, _pos: Vector3) -> void:
		pass
	func _maybe_interrupt_objective_for_enemy() -> bool:
		if interrupt:
			change_state(State.RECOVER)
			return true
		return false
	func _find_best_pickup(_radius: float, _prefer: bool = false) -> Node3D:
		return alternative if is_instance_valid(alternative) else target_actor
	func _nav_move_toward(pos: Vector3, delta: float, _rotate: bool = true):
		if not blocked:
			global_position = global_position.move_toward(pos, fixture_speed * delta)

class Ammo:
	extends Node3D
	var collected := false
	var item := ItemData.new()
	func _init():
		item.type = ItemData.Type.AMMO
		item.ammo_weapon_type = "ar"
		item.amount = 10
	func collect(bot):
		collected = true
		bot.receive_ammo("ar", 10)

var failures: Array[String] = []

func _init():
	_run.call_deferred()

func _run():
	for enabled in [false, true]:
		var pair := _pair(enabled)
		var bot = pair[0]
		var ammo = pair[1]
		var elapsed := _walk(bot, 120)
		_check(ammo.collected == enabled, "30m approach control/candidate collection mismatch")
		_check(elapsed > 7.5 if enabled else elapsed < 5.3, "30m chase timing mismatch")
		print("LOOT_CHASE candidate=%s elapsed=%.1f collected=%s distance=%.1f" % [enabled, elapsed, ammo.collected, bot.position.distance_to(ammo.position)])
		_free_pair(pair)
	for jitter in [false, true]:
		var pair := _pair(true)
		var bot = pair[0]
		bot.blocked = true
		var elapsed := 0.0
		for i in range(60):
			if jitter:
				bot.position.x = 0.2 if i % 2 else -0.2
			_tick(bot)
			elapsed += 0.1
			if bot.current_state != bot.State.CHASE:
				break
		_check(not pair[1].collected and elapsed < 5.3, "Blocked/jitter chase did not stop")
		_free_pair(pair)
	var slow := _pair(true)
	slow[0].fixture_speed = 0.2
	var slow_elapsed := _walk(slow[0], 200)
	_check(slow_elapsed > 14.9 and slow_elapsed < 15.3 and not slow[1].collected, "Progressing chase exceeded absolute cap")
	_free_pair(slow)
	var arrival := _pair(true, 2.0)
	arrival[0].state_timer = 16.0
	_tick(arrival[0])
	_check(arrival[1].collected, "In-range collection lost to timeout")
	_free_pair(arrival)
	var retarget := _pair(true)
	var alt := Ammo.new()
	root.add_child(alt)
	alt.position = Vector3(10, 0, 0)
	retarget[0].alternative = alt
	retarget[0].blocked = true
	retarget[0].state_timer = 5.1
	retarget[0].handle_chase_state(0.1)
	_check(retarget[0].target_actor == alt and retarget[0].state_timer == 0.0, "Retarget timer not reset")
	_check(is_equal_approx(retarget[0]._loot_best_distance, 10.0) and retarget[0]._loot_last_progress_time == 0.0, "Retarget inherited old progress")
	retarget[0].blocked = false
	_walk(retarget[0], 50)
	_check(alt.collected, "Retarget could not collect")
	alt.free()
	_free_pair(retarget)
	var expired := _pair(true)
	expired[1].free()
	_tick(expired[0])
	_check(expired[0].current_state == expired[0].State.IDLE, "Expired target did not exit safely")
	expired[0].free()
	var interrupt_pair := _pair(true)
	interrupt_pair[0].interrupt = true
	interrupt_pair[0].state_timer = 16.0
	_tick(interrupt_pair[0])
	_check(interrupt_pair[0].current_state == interrupt_pair[0].State.RECOVER, "Enemy interrupt lost priority over timeout")
	_free_pair(interrupt_pair)
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("Loot chase progress fixture passed: default, travel, stall, jitter, cap, arrival, retarget, expiry, interrupt.")
	quit(0)

func _pair(enabled: bool, distance := 30.0) -> Array:
	var bot := ChaseBot.new()
	bot.stats = StatsData.new()
	bot.stats.weapon_type = "ar"
	bot.stats.current_ammo = 0
	bot.stats.max_ammo = 30
	bot.current_health = bot.stats.max_health
	var ray := RayCast3D.new()
	ray.name = "RayCast3D"
	bot.add_child(ray)
	root.add_child(bot)
	bot.set_process(false)
	bot.set_physics_process(false)
	_check(not bot._loot_progress_timeout_enabled, "Candidate unexpectedly enabled by default")
	bot._loot_progress_timeout_enabled = enabled
	var ammo := Ammo.new()
	root.add_child(ammo)
	ammo.position = Vector3(distance, 0, 0)
	bot._start_loot_objective(ammo, "recover_seek_loot", true)
	bot.change_state(bot.State.CHASE)
	return [bot, ammo]

func _tick(bot):
	bot.state_timer += 0.1
	bot.handle_chase_state(0.1)

func _walk(bot, steps: int) -> float:
	var elapsed := 0.0
	for _i in range(steps):
		_tick(bot)
		elapsed += 0.1
		if bot.current_state != bot.State.CHASE:
			break
	return elapsed

func _free_pair(pair):
	for node in pair:
		node.free()

func _check(value: bool, message: String):
	if not value:
		failures.append(message)
