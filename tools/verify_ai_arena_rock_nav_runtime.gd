extends SceneTree


const EXPECTED_PLAYER_POSITION := Vector2(-19.0, -24.0)
const EXPECTED_BOT_POSITION := Vector2(-19.0, 0.0)
const PROBE_TIMEOUT_SECONDS := 8.0
const ARRIVAL_DISTANCE := 3.0
const MAX_STUCK_RECOVERIES := 1


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
		_fail("Rock nav runtime must spawn one active player and one bot.")
		return
	var bot = bots[0]
	if _flat_position(player.global_position).distance_to(EXPECTED_PLAYER_POSITION) > 0.01 \
			or _flat_position(bot.global_position).distance_to(EXPECTED_BOT_POSITION) > 0.01:
		await _cleanup(main)
		_fail("Rock nav runtime did not use the fixed cross-rock spawn pair.")
		return

	player.set_process(false)
	player.set_physics_process(false)
	bot.stats.attack_range = 1.0
	bot.stats.current_ammo = max(1, bot.stats.current_ammo)
	bot.target_actor = player
	bot.is_targeting_loot = false
	bot.change_state(bot.State.CHASE)

	var telemetry = root.get_node_or_null("Telemetry")
	var initial_stuck := int(telemetry.metrics.tactics.stuck_triggered) if telemetry else 0
	var initial_distance: float = float(bot.global_position.distance_to(player.global_position))
	var minimum_distance: float = initial_distance
	var elapsed := 0.0
	while elapsed < PROBE_TIMEOUT_SECONDS and is_instance_valid(bot) and is_instance_valid(player):
		await create_timer(0.05).timeout
		elapsed += 0.05
		minimum_distance = minf(minimum_distance, bot.global_position.distance_to(player.global_position))
		if minimum_distance <= ARRIVAL_DISTANCE:
			break

	var final_stuck := int(telemetry.metrics.tactics.stuck_triggered) if telemetry else 0
	var stuck_delta := final_stuck - initial_stuck
	var stuck_cells: Dictionary = telemetry.metrics.tactics.stuck_by_cell.duplicate() if telemetry else {}
	var stuck_states: Dictionary = telemetry.metrics.tactics.stuck_by_state.duplicate() if telemetry else {}
	var final_position: Vector3 = bot.global_position
	var final_state := String(bot.State.keys()[bot.current_state])
	await _cleanup(main)
	if minimum_distance > ARRIVAL_DISTANCE:
		_fail("Rock nav bot did not cross the high cluster: min_distance=%.2fm stuck=%d." % [
			minimum_distance,
			stuck_delta,
		])
		return
	if stuck_delta > MAX_STUCK_RECOVERIES:
		_fail(
			"Rock nav bot exceeded the stuck budget: stuck=%d pos=(%.2f,%.2f) state=%s cells=%s states=%s." % [
				stuck_delta,
				final_position.x,
				final_position.z,
				final_state,
				stuck_cells,
				stuck_states,
			]
		)
		return
	print("AI arena rock nav smoke passed: %.1fm -> %.1fm, stuck=%d." % [
		initial_distance,
		minimum_distance,
		stuck_delta,
	])
	quit(0)


func _flat_position(position: Vector3) -> Vector2:
	return Vector2(position.x, position.z)


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
