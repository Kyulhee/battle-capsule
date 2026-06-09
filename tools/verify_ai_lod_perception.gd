extends SceneTree


func _init():
	call_deferred("_run")


func _run() -> void:
	if not _verify_entity_perception_lod():
		quit(1)
		return
	if not _verify_bot_perception_intervals():
		quit(1)
		return

	print("AI perception LOD smoke passed.")
	quit(0)


func _verify_entity_perception_lod() -> bool:
	var entity_script = load("res://src/entities/Entity.gd")
	var stats_script = load("res://src/core/StatsData.gd")
	var viewer = _make_entity(entity_script, stats_script, "Viewer", Vector3.ZERO)
	var target = _make_entity(entity_script, stats_script, "Target", Vector3(0.0, 0.0, -6.0))
	root.add_child(viewer)
	root.add_child(target)

	if absf(viewer._perception_update_interval() - 0.08) > 0.001:
		_free_nodes([viewer, target])
		return _fail("Default entity perception interval changed unexpectedly.")

	for _i in range(5):
		viewer._update_perception_lod(0.01)
	if float(viewer.perception_meters.get(target, 0.0)) >= 0.5:
		_free_nodes([viewer, target])
		return _fail("Perception LOD updated too aggressively before enough accumulated time.")

	for _i in range(35):
		viewer._update_perception_lod(0.01)
	if float(viewer.perception_meters.get(target, 0.0)) < 1.0:
		_free_nodes([viewer, target])
		return _fail("Perception LOD did not preserve accumulated dwell time.")

	var player_viewer = _make_entity(entity_script, stats_script, "PlayerViewer", Vector3(3.0, 0.0, 0.0))
	player_viewer.add_to_group("players")
	root.add_child(player_viewer)
	if absf(player_viewer._perception_update_interval() - 0.05) > 0.001:
		_free_nodes([viewer, target, player_viewer])
		return _fail("Player perception interval should stay more responsive than default.")

	_free_nodes([viewer, target, player_viewer])
	return true


func _verify_bot_perception_intervals() -> bool:
	var bot_script = load("res://src/entities/bot/Bot.gd")
	var bot = bot_script.new()
	bot.current_state = 0 # IDLE
	var idle_interval := float(bot._perception_update_interval())
	bot.current_state = 1 # CHASE
	var moving_interval := float(bot._perception_update_interval())
	bot.current_state = 2 # ATTACK
	var attack_interval := float(bot._perception_update_interval())
	bot.current_state = 4 # RECOVER
	var recover_interval := float(bot._perception_update_interval())

	if absf(idle_interval - 0.12) > 0.001:
		bot.free()
		return _fail("Bot idle perception interval should be the slowest LOD tier.")
	if absf(moving_interval - 0.08) > 0.001:
		bot.free()
		return _fail("Bot moving perception interval should use the middle LOD tier.")
	if absf(recover_interval - moving_interval) > 0.001:
		bot.free()
		return _fail("Bot recover perception should stay in the moving LOD tier.")
	if absf(attack_interval - 0.05) > 0.001:
		bot.free()
		return _fail("Bot attack perception interval should stay the fastest LOD tier.")
	if not (attack_interval < moving_interval and moving_interval < idle_interval):
		bot.free()
		return _fail("Bot perception LOD ordering should be attack < moving < idle.")

	bot.free()
	return true


func _make_entity(entity_script: Script, stats_script: Script, entity_name: String, pos: Vector3):
	var entity = entity_script.new()
	entity.name = entity_name
	entity.stats = stats_script.new()
	entity.stats.vision_range = 25.0
	entity.stats.fov_near_range = 2.0
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
