extends SceneTree

var failures: Array[String] = []

func _init(): _run.call_deferred()

func _check(ok: bool, label: String):
	if not ok: failures.append(label)

func _run():
	# Main의 Player/Sfx 의존성은 autoload 준비 후 로드한다.
	var main = load("res://tools/MatchClockHarness.gd").new()
	main.name = "Main"
	var builder := Node.new()
	builder.name = "WorldBuilder"
	main.add_child(builder)
	root.add_child(main)
	main.set_process(false)
	main.set_physics_process(false)
	var tel = root.get_node("Telemetry")
	var old_scale := Engine.time_scale
	for candidate in [false, true]:
		for scale in [1.0, 5.0]:
			Engine.time_scale = scale
			main._physics_match_clock_enabled = candidate
			main.current_state = main.GameState.PLAYING
			main.game_over = false
			main.match_timer = 0.0
			main.damage_elapsed = 0.0
			main.pressure_elapsed = 0.0
			main.zone = main.ZoneControllerScript.new()
			main.zone.timer = 100.0
			tel.start_match()
			var delta: float = scale / 60.0
			for tick in range(3): main._physics_process(delta)
			var physics_elapsed := 3.0 * delta if candidate else 0.0
			_check(is_equal_approx(main.match_timer, physics_elapsed), "Wrong physics clock owner")
			tel.log_pickup("shotgun", "weapon", false)
			_check(is_equal_approx(tel.metrics.economy.first_upgrade_time, physics_elapsed), "Telemetry did not use current canonical time")
			main._process(0.4)
			var expected := physics_elapsed if candidate else 0.4
			_check(is_equal_approx(main.match_timer, expected), "Clock double advanced or multiplied time_scale again")
			_check(is_equal_approx(main.zone.timer, 100.0 - expected), "Zone clock diverged")
			_check(is_equal_approx(main.damage_elapsed, expected) and is_equal_approx(main.pressure_elapsed, expected), "Damage/mission clock diverged")
			paused = true
			main._physics_process(1.0)
			main._process(1.0)
			paused = false
			_check(is_equal_approx(main.match_timer, expected), "Clock advanced while paused")
			for state in [main.GameState.MENU, main.GameState.RESULT]:
				main.current_state = state
				main._physics_process(1.0)
				main._process(1.0)
				_check(is_equal_approx(main.match_timer, expected), "Clock advanced outside PLAYING")
			main.current_state = main.GameState.PLAYING
			main.game_over = true
			main._physics_process(1.0)
			main._process(1.0)
			_check(is_equal_approx(main.match_timer, expected), "Clock advanced after game over")
	# 실제 ZoneController의 stage 경계와 보급 timer도 같은 physics delta를 소비한다.
	main._physics_match_clock_enabled = true
	main.game_over = false
	main.match_timer = 0.0
	main.zone = main.ZoneControllerScript.new()
	main.zone.timer = 0.125
	main.zone.shrink_time = 0.25
	var stage_times: Array = []
	main.zone.stage_advanced.connect(func(_stage): stage_times.append(main.match_timer))
	main._physics_process(0.125)
	main._physics_process(0.125)
	main._physics_process(0.125)
	_check(stage_times == [0.375], "Zone boundary did not observe advanced canonical time")
	_check(main.supply_telegraphed and is_equal_approx(main.supply_timer, 0.125), "Supply clock did not follow stage boundary")
	main._process(3.0)
	_check(is_equal_approx(main.supply_timer, 0.125), "Render advanced supply timer")
	main._physics_process(0.125)
	_check(main.supply_spawned and main.supply_activations == 1, "Supply activation did not follow physics time")
	Engine.time_scale = old_scale
	tel.match_in_progress = false
	main.free()
	if not failures.is_empty():
		for failure in failures: push_error(failure)
		quit(1)
		return
	print("Match clock passed: process default/physics candidate, 1x/5x, no double advance, pause/menu/result/end, zone boundary, damage/mission/supply delta, canonical telemetry.")
	quit(0)
