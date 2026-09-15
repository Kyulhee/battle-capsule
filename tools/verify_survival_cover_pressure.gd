extends SceneTree

class FixtureMain:
	extends Node
	var zone = {"current_center": Vector2.ZERO, "current_radius": 100.0}

class CoverBot:
	extends "res://src/entities/bot/Bot.gd"
	var enemy: Entity
	var accept_target := true
	var pressure_clear := true
	var searches := 0
	var moves := 0
	var exit_reason := ""
	func _ready(): pass
	func _observe_survival_break_episode_progress() -> void: pass
	func _track_survival_break_episode_event(_event: String, _context: Dictionary = {}) -> bool: return true
	func _can_reengage_after_pressure() -> bool: return pressure_clear
	func _find_nearest_target() -> Entity:
		searches += 1
		return enemy
	func acquire_enemy_target(value: Entity, _source: String) -> bool:
		return value != null and accept_target
	func _nav_move_toward(pos: Vector3, delta: float, _rotate: bool = true):
		moves += 1
		position = position.move_toward(pos, 4.0 * delta)
	func _try_reload(): pass
	func change_state(next: State, reason: String = ""):
		current_state = next
		exit_reason = reason

var failures: Array[String] = []

func _init(): _run.call_deferred()

func _check(ok: bool, message: String):
	if not ok: failures.append(message)

func _reset(bot):
	bot.position = Vector3.ZERO
	bot.current_state = bot.State.DISENGAGE
	bot._disengage_entry_reason = "survival_break"
	bot._disengage_cover = Vector3(10, 0, 0)
	bot.current_health = 10.0
	bot._flee_hp_ratio = 0.25
	bot.stats.current_ammo = 10
	bot.reserve_ammo = 0
	bot.state_timer = 4.6
	bot._retreating_to_reload = false
	bot.enemy = null
	bot.accept_target = true
	bot.pressure_clear = true
	bot.searches = 0
	bot.moves = 0
	bot.exit_reason = ""

func _run():
	var main := FixtureMain.new()
	main.name = "Main"
	root.add_child(main)
	var bot := CoverBot.new()
	bot.stats = StatsData.new()
	var ray := RayCast3D.new()
	ray.name = "RayCast3D"
	bot.add_child(ray)
	root.add_child(bot)
	bot.set_process(false)
	bot.set_physics_process(false)
	_reset(bot)
	bot.handle_disengage_state(0.1)
	_check(bot.current_state == bot.State.IDLE and bot.exit_reason == "pressure_no_target"
		and bot.moves == 0 and bot.searches == 1, "Legacy premature exit did not reproduce")
	print("LEGACY_REPRO: remaining cover=10m, timer=4.6, null target -> IDLE, movement calls=", bot.moves)
	if "legacy_only=true" not in OS.get_cmdline_user_args():
		_check(bot.get("_survival_cover_pressure_enabled") == false, "Candidate must default OFF")
		bot.set("_survival_cover_pressure_enabled", true)
		_reset(bot)
		bot.handle_disengage_state(0.1)
		_check(bot.current_state == bot.State.DISENGAGE and bot.moves == 1 and bot.searches == 1
			and bot.position.is_equal_approx(Vector3(0.4, 0, 0)), "Candidate did not continue existing cover with one search")
		for boundary in ["ordinary", "no_cover", "reached", "ammo", "timeout", "zone", "enemy", "rejected", "reload"]:
			_reset(bot)
			var expected := "pressure_no_target"
			match boundary:
				"ordinary": bot._disengage_entry_reason = "outnumbered"
				"no_cover": bot._disengage_cover = Vector3.ZERO
				"reached": bot._disengage_cover = Vector3(2, 0, 0)
				"ammo":
					bot.stats.current_ammo = 0
					expected = "ammo_empty"
				"timeout":
					bot.state_timer = 8.01
					expected = "timeout"
				"zone":
					main.zone.current_radius = -1.0
					expected = "zone_override"
				"enemy", "rejected":
					bot.enemy = Entity.new()
					bot.accept_target = boundary == "enemy"
					if bot.accept_target: expected = "pressure_reengage"
				"reload":
					bot._retreating_to_reload = true
					expected = "reload_no_target"
			bot.handle_disengage_state(0.1)
			var expected_state = bot.State.IDLE
			if boundary == "ammo": expected_state = bot.State.RECOVER
			if boundary == "zone": expected_state = bot.State.ZONE_ESCAPE
			if boundary == "enemy": expected_state = bot.State.CHASE
			_check(bot.exit_reason == expected and bot.current_state == expected_state
				and bot.moves == 0, "Boundary changed: " + boundary)
			main.zone.current_radius = 100.0
			if bot.enemy != null: bot.enemy.free()
		for timer in [2.0, 4.49, 4.5, 8.0]:
			_reset(bot)
			bot.state_timer = timer
			bot.handle_disengage_state(0.1)
			_check(bot.current_state == bot.State.DISENGAGE and bot.moves == 1, "Timer boundary failed: " + str(timer))
		_reset(bot)
		bot._disengage_cover = Vector3(2.25, 0, 0)
		bot.handle_disengage_state(0.1)
		bot.state_timer += 0.1
		bot.handle_disengage_state(0.1)
		_check(bot.current_state == bot.State.IDLE and bot.moves == 1
			and bot.exit_reason == "pressure_no_target", "Reached cover did not preserve normal exit")
		for enabled in [false, true]:
			_reset(bot)
			bot.set("_survival_cover_pressure_enabled", enabled)
			seed(8800)
			var expected_random := randi()
			seed(8800)
			bot.handle_disengage_state(0.1)
			_check(randi() == expected_random, "Null-target branch consumed RNG")
	bot.free()
	main.free()
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("Survival cover pressure handler verification passed.")
	quit(0 if failures.is_empty() else 1)
