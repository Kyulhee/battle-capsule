extends SceneTree


const EXPECTED_PLAYER_POSITION := Vector2(0.0, -2.0)
const EXPECTED_BOT_POSITION := Vector2(0.0, 2.5)
const RESPONSE_TIMEOUT_SECONDS := 3.0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var main_scene: PackedScene = load("res://src/Main.tscn")
	if main_scene == null:
		_fail("Could not load Main.tscn.")
		return
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await _wait_for_navigation(main)
	main.start_game()

	var player: Entity = main.player_ref
	var bots := get_nodes_in_group("bots")
	if not is_instance_valid(player) or bots.size() != 1:
		await _cleanup(main)
		_fail("Duel runtime must spawn one active player and one bot.")
		return
	var bot = bots[0]
	var player_spawn := Vector2(player.global_position.x, player.global_position.z)
	var bot_spawn := Vector2(bot.global_position.x, bot.global_position.z)
	if player_spawn.distance_to(EXPECTED_PLAYER_POSITION) > 0.01:
		await _cleanup(main)
		_fail("Duel runtime player did not use fixed spawn slot 0.")
		return
	if bot_spawn.distance_to(EXPECTED_BOT_POSITION) > 0.01:
		await _cleanup(main)
		_fail("Duel runtime bot did not use fixed spawn slot 1.")
		return
	if not get_nodes_in_group("pickups").is_empty():
		await _cleanup(main)
		_fail("Duel runtime must keep initial loot disabled.")
		return

	player.set_process(false)
	player.set_physics_process(false)
	var initial_health := player.current_health
	var acquired_player := false
	var damaged_player := false
	var elapsed := 0.0
	while elapsed < RESPONSE_TIMEOUT_SECONDS and is_instance_valid(player):
		await create_timer(0.05).timeout
		elapsed += 0.05
		if is_instance_valid(bot) and bot.target_actor == player:
			acquired_player = true
		if player.current_health < initial_health:
			damaged_player = true
		if acquired_player and damaged_player:
			break

	var final_health := player.current_health if is_instance_valid(player) else 0.0
	await _cleanup(main)
	if not acquired_player:
		_fail("Duel bot did not acquire the adjacent player within 3 seconds.")
		return
	if not damaged_player:
		_fail("Duel bot acquired the player but dealt no damage within 3 seconds.")
		return
	print("AI arena runtime smoke passed: fixed duel acquired player, HP %.0f -> %.0f." % [
		initial_health,
		final_health,
	])
	quit(0)


func _wait_for_navigation(main: Node) -> void:
	var nav_region = main.get("_nav_region")
	if nav_region != null and nav_region.has_method("is_baking") and nav_region.is_baking():
		await nav_region.bake_finished


func _cleanup(main: Node) -> void:
	if is_instance_valid(main):
		main.queue_free()
	await process_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
