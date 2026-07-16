extends SceneTree


class MockZone:
	extends RefCounted
	var current_center := Vector2.ZERO
	var current_radius := 100.0
	var stage := 1


class MockMain:
	extends Node
	var zone = MockZone.new()


func _init():
	call_deferred("_run")


func _run() -> void:
	var runtime_tuning_script = load("res://src/systems/match/MatchRuntimeTuning.gd")
	var default_bot: Dictionary = runtime_tuning_script.bot({})
	if not is_equal_approx(float(default_bot.get("stage1_inside_zone_escape_release_ratio", 0.0)), 0.75):
		_fail("Default inside-zone escape release ratio should preserve the existing deep return.")
		return

	var candidate_bot: Dictionary = runtime_tuning_script.bot({
		"bot": {"stage1_inside_zone_escape_release_ratio": 0.90},
	})
	var main := MockMain.new()
	main.name = "Main"
	root.add_child(main)

	var inside_bot = _new_bot(candidate_bot)
	root.add_child(inside_bot)
	inside_bot.set_process(false)
	inside_bot.set_physics_process(false)
	inside_bot.global_position = Vector3(95.0, 0.0, 0.0)
	var outside_bot = _new_bot(candidate_bot)
	root.add_child(outside_bot)
	outside_bot.set_process(false)
	outside_bot.set_physics_process(false)
	outside_bot.global_position = Vector3(101.0, 0.0, 0.0)
	await create_timer(0.25).timeout

	inside_bot.change_state(3) # ZONE_ESCAPE
	if bool(inside_bot.get("_zone_escape_requires_deep_recovery")):
		_fail("Inside-edge ZONE_ESCAPE should not require deep recovery.")
		return
	if not is_equal_approx(float(inside_bot._zone_escape_release_ratio(main.zone)), 0.90):
		_fail("Stage 1 inside-edge ZONE_ESCAPE should use the runtime release ratio.")
		return

	outside_bot.change_state(3) # ZONE_ESCAPE
	if not bool(outside_bot.get("_zone_escape_requires_deep_recovery")):
		_fail("Outside-zone ZONE_ESCAPE should retain deep recovery.")
		return
	outside_bot.global_position = Vector3(90.0, 0.0, 0.0)
	if not is_equal_approx(float(outside_bot._zone_escape_release_ratio(main.zone)), 0.75):
		_fail("A bot that entered outside the zone must keep the deep release ratio after crossing inside.")
		return

	main.zone.stage = 2
	if not is_equal_approx(float(inside_bot._zone_escape_release_ratio(main.zone)), 0.75):
		_fail("The opening release candidate must remain limited to stage 1.")
		return

	inside_bot.free()
	outside_bot.free()
	main.free()
	print("Bot zone escape runtime smoke passed: inside=0.90 outside=0.75 stage2=0.75.")
	quit(0)


func _new_bot(bot_tuning: Dictionary):
	var bot_script = load("res://src/entities/bot/Bot.gd")
	var stats_script = load("res://src/core/StatsData.gd")
	var bot = bot_script.new()
	bot.stats = stats_script.new()
	var ray_cast := RayCast3D.new()
	ray_cast.name = "RayCast3D"
	bot.add_child(ray_cast)
	bot.configure_runtime_bot(bot_tuning)
	bot.set_process(false)
	bot.set_physics_process(false)
	return bot


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
