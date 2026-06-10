extends SceneTree


class FakeMain:
	extends Node

	var map_spec = {
		"metadata": {
			"id": "night_artificial_forest_candidate",
			"theme": "night_artificial_forest",
			"layout": "diagonal_night_probe",
		}
	}
	var map_spec_path := "res://data/mapSpec_night_forest_candidate.json"


func _init():
	call_deferred("_run")


func _run() -> void:
	if not _verify_night_awareness_modifiers():
		quit(1)
		return
	if not _verify_player_night_signature():
		quit(1)
		return

	print("Bot night awareness smoke passed.")
	quit(0)


func _verify_night_awareness_modifiers() -> bool:
	var entity_script = load("res://src/entities/Entity.gd")
	var stats_script = load("res://src/core/StatsData.gd")
	var main := FakeMain.new()
	main.name = "Main"
	root.add_child(main)

	var bot = _make_entity(entity_script, stats_script, "NightBot", Vector3.ZERO)
	bot.add_to_group("bots")
	var target = _make_entity(entity_script, stats_script, "Target", Vector3(0.0, 0.0, -10.0))
	root.add_child(bot)
	root.add_child(target)

	var dark_state: Dictionary = bot.debug_night_awareness_for(target)
	if not bool(dark_state.get("active", false)):
		_free_nodes([main, bot, target])
		return _fail("Night candidate did not activate abstract bot night awareness.")
	if float(dark_state.get("range_mult", 1.0)) >= 1.0:
		_free_nodes([main, bot, target])
		return _fail("Dark target should reduce bot night awareness range.")
	if float(dark_state.get("dwell_mult", 1.0)) <= 1.0:
		_free_nodes([main, bot, target])
		return _fail("Dark target should increase bot night awareness dwell.")

	target.velocity = Vector3(target.stats.move_speed, 0.0, 0.0)
	var moving_state: Dictionary = bot.debug_night_awareness_for(target)
	if float(moving_state.get("target_signature", 0.0)) <= 0.0:
		_free_nodes([main, bot, target])
		return _fail("Moving target did not produce a night awareness signature.")
	if float(moving_state.get("range_mult", 0.0)) <= float(dark_state.get("range_mult", 0.0)):
		_free_nodes([main, bot, target])
		return _fail("Moving target should be easier to range-detect than a quiet dark target.")
	if float(moving_state.get("dwell_mult", 9.0)) >= float(dark_state.get("dwell_mult", 9.0)):
		_free_nodes([main, bot, target])
		return _fail("Moving target should reduce night awareness dwell compared to a quiet target.")

	target.reveal_timer = 2.0
	var revealed_state: Dictionary = bot.debug_night_awareness_for(target)
	if float(revealed_state.get("range_mult", 0.0)) <= 1.0:
		_free_nodes([main, bot, target])
		return _fail("Revealed target should overcome the night range penalty.")
	if float(revealed_state.get("dwell_mult", 9.0)) >= 1.0:
		_free_nodes([main, bot, target])
		return _fail("Revealed target should reduce bot dwell below the normal baseline.")

	main.map_spec = {"metadata": {"id": "day_forest", "theme": "forest", "layout": "default"}}
	bot._night_awareness_checked = false
	var day_state: Dictionary = bot.debug_night_awareness_for(target)
	if bool(day_state.get("active", true)):
		_free_nodes([main, bot, target])
		return _fail("Default forest map should not activate bot night awareness.")
	if absf(float(day_state.get("range_mult", 0.0)) - 1.0) > 0.001:
		_free_nodes([main, bot, target])
		return _fail("Default forest map should keep normal range multiplier.")

	_free_nodes([main, bot, target])
	return true


func _verify_player_night_signature() -> bool:
	var player_script = load("res://src/entities/player/Player.gd")
	var stats_script = load("res://src/core/StatsData.gd")
	var player = player_script.new()
	player.stats = stats_script.new()

	if float(player.get_night_awareness_signature()) != 0.0:
		player.free()
		return _fail("Inactive player night readability should not add a light signature.")

	player._night_readability.set_active(true)
	var lit_signature := float(player.get_night_awareness_signature())
	if lit_signature < 0.45:
		player.free()
		return _fail("Active player night readability should add a minimum light signature.")

	player.velocity = Vector3(player.stats.move_speed, 0.0, 0.0)
	var running_signature := float(player.get_night_awareness_signature())
	if running_signature <= lit_signature:
		player.free()
		return _fail("Running with night readability should increase the player signature.")

	player.free()
	return true


func _make_entity(entity_script: Script, stats_script: Script, entity_name: String, pos: Vector3):
	var entity = entity_script.new()
	entity.name = entity_name
	entity.stats = stats_script.new()
	entity.stats.vision_range = 25.0
	entity.stats.fov_near_range = 3.0
	entity.stats.fov_angle = 120.0
	entity.stats.dwell_time_open = 0.3
	entity.stats.dwell_time_bush = 0.8
	entity.position = pos
	return entity


func _free_nodes(nodes: Array) -> void:
	for node in nodes:
		if node == null:
			continue
		if node is Node and node.get_parent() != null:
			node.get_parent().remove_child(node)
		if node is Object:
			node.free()


func _fail(message: String) -> bool:
	push_error(message)
	return false
