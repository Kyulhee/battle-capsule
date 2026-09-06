extends SceneTree

const STEP := 1.0 / 60.0
var failure := ""

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var main = load("res://src/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	if main._nav_region.is_baking():
		await main._nav_region.bake_finished
	main.start_game()
	main.set_process(false)
	main.set_physics_process(false)
	var player = main.player_ref
	var bot = get_nodes_in_group("bots")[0]
	player.set_process(false)
	player.set_physics_process(false)
	bot.set_physics_process(false)
	await create_timer(0.25).timeout
	for cue in ["footstep", "gunshot", "damage"]:
		for mode in ["idle", "post_kill", "recover", "loot"]:
			_reset(bot, player, mode)
			if cue == "footstep":
				player.velocity = Vector3(4.0, 0.0, 0.0)
				bot._footstep_check_timer = 0.0
				bot._check_footstep_sounds(STEP)
			elif cue == "gunshot":
				player.reveal_timer = 2.0
				bot._gunshot_check_timer = 0.0
				bot._check_gunshot_sounds(STEP)
			else:
				bot.take_damage(1.0, "gun", "pistol", player)
			# One cue only: ordinary scans/movement must not erase its bearing.
			bot._footstep_check_timer = 100.0
			bot._gunshot_check_timer = 100.0
			for frame in range(24):
				bot._physics_process(STEP)
			var direction: Vector3 = player.global_position - bot.global_position
			var error := absf(angle_difference(bot.rotation.y, atan2(direction.x, direction.z) + PI))
			print("SOUND_RESPONSE cue=%s state=%s after=0.40s bearing_error=%.1fdeg" % [cue, mode, rad_to_deg(error)])
			if error > deg_to_rad(15.0):
				failure = "%s/%s did not turn toward the cue within 0.40s." % [cue, mode]
				break
		if not failure.is_empty():
			break
	if failure.is_empty():
		_reset(bot, player, "idle")
		player.reveal_timer = 2.0
		bot.perception_meters[player] = 1.0
		bot._gunshot_check_timer = 0.0
		bot._check_gunshot_sounds(STEP)
		if float(bot.perception_meters[player]) < 1.0:
			failure = "Hearing the known player must not lower confirmed perception."
	if failure.is_empty():
		_reset(bot, player, "idle")
		player.global_position = Vector3(5.0, 1.0, 2.5)
		player.velocity = Vector3(4.0, 0.0, 0.0)
		bot.perception_meters[player] = 0.95
		bot._footstep_check_timer = 0.0
		bot._check_footstep_sounds(STEP)
		bot._ambient_scan_timer = 0.0
		bot._check_ambient_awareness(STEP)
		if float(bot.perception_meters[player]) < 0.95:
			failure = "Footstep/ambient cues must not erase partial visual confirmation."
	if failure.is_empty():
		_reset(bot, player, "idle")
		player.reveal_timer = 2.0
		bot._gunshot_check_timer = 0.0
		bot._check_gunshot_sounds(STEP)
		if bot.target_actor != null or float(bot.perception_meters[player]) >= 1.0:
			failure = "Normal gunshot cue must require visual confirmation before acquiring."
		var sampled_position: Vector3 = bot._player_sound_look_position
		player.global_position += Vector3(0.0, 0.0, 8.0)
		player.velocity = Vector3(4.0, 0.0, 0.0)
		bot._footstep_check_timer = 0.0
		bot._check_footstep_sounds(STEP)
		if not bot._player_sound_look_position.is_equal_approx(sampled_position):
			failure = "A weaker footstep must not override the recent gunshot bearing."
		bot._gunshot_check_timer = 100.0
		bot._footstep_check_timer = 100.0
		for frame in range(24):
			bot._physics_process(STEP)
		if not bot._player_sound_look_position.is_equal_approx(sampled_position):
			failure = "Unseen movement must not update the sampled sound position."
		for frame in range(20):
			bot._physics_process(STEP)
		if bot._player_sound_look_remaining > 0.0:
			failure = "A one-shot sound cue must expire."
	if failure.is_empty():
		# A bot sound cannot activate the player-facing change or alter bot pacing.
		_reset(bot, player, "idle")
		player.remove_from_group("players")
		player.reveal_timer = 2.0
		bot.perception_meters[player] = 1.0
		bot._gunshot_check_timer = 0.0
		bot._check_gunshot_sounds(STEP)
		if bot._player_sound_look_remaining > 0.0:
			failure = "Bot-only sounds must retain the baseline facing contract."
		if not is_equal_approx(float(bot.perception_meters[player]), 0.75):
			failure = "Bot-only gunshot perception must retain its baseline cap."
		player.add_to_group("players")
	if failure.is_empty():
		_reset(bot, player, "idle")
		var wall := StaticBody3D.new()
		wall.collision_layer = 1 | 8 | 16
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.0, 6.0, 12.0)
		shape.shape = box
		wall.add_child(shape)
		main.add_child(wall)
		wall.global_position = Vector3(4.0, 1.0, 2.5)
		await physics_frame
		await physics_frame
		bot._perception_timer = 0.0
		bot._perception_accumulated_delta = 0.0
		bot._target_search_timer = 0.0
		bot._gunshot_check_timer = 0.0
		player.reveal_timer = 2.0
		var initial_ammo: int = bot.stats.current_ammo
		for frame in range(36):
			await physics_frame
			bot._physics_process(STEP)
			player.reveal_timer = maxf(0.0, player.reveal_timer - STEP)
		if bot.has_los_to(player) or bot.target_actor == player or bot.stats.current_ammo != initial_ammo:
			failure = "Hearing through hard cover must not acquire or shoot the unseen player on Normal."
		wall.queue_free()
		await physics_frame
		await physics_frame
		bot._request_player_sound_look(player, 2)
		if bot._player_sound_look_remaining <= 0.0:
			failure = "Combat ownership probe requires an active passive cue."
		bot.current_state = bot.State.ATTACK
		bot._apply_player_sound_look(STEP, bot.rotation.y)
		if bot._player_sound_look_remaining > 0.0:
			failure = "Combat must clear passive facing ownership."
	if failure.is_empty():
		# Integrate actual visual perception, state transitions and raycast fire.
		_reset(bot, player, "idle")
		bot._perception_timer = 0.0
		bot._perception_accumulated_delta = 0.0
		bot._target_search_timer = 0.0
		bot._reaction_delay = 0.2
		bot._pending_target = null
		bot.fire_cooldown = 0.0
		bot._gunshot_check_timer = 0.0
		player.reveal_timer = 2.0
		var initial_ammo: int = bot.stats.current_ammo
		var acquired_at := -1.0
		var fired_at := -1.0
		for frame in range(90):
			await physics_frame
			bot._physics_process(STEP)
			player.reveal_timer = maxf(0.0, player.reveal_timer - STEP)
			if bot.target_actor == player and acquired_at < 0.0:
				acquired_at = (frame + 1) * STEP
			if bot.stats.current_ammo < initial_ammo:
				fired_at = (frame + 1) * STEP
				break
		print("SOUND_COMBAT normal acquired=%.3fs fired=%.3fs" % [acquired_at, fired_at])
		if acquired_at < 0.0 or acquired_at > 0.8 or fired_at < 0.0 or fired_at > 1.2:
			failure = "Normal exposed shooter must be acquired within 0.8s and answered within 1.2s."
	main.queue_free()
	await process_frame
	await process_frame
	if not failure.is_empty():
		push_error(failure)
		quit(1)
		return
	print("Player sound response runtime passed.")
	quit(0)

func _reset(bot, player, mode: String) -> void:
	bot.global_position = Vector3(0.0, 1.0, 2.5)
	player.global_position = Vector3(8.0, 1.0, 2.5)
	player.velocity = Vector3.ZERO
	player.reveal_timer = 0.0
	bot.rotation.y = 0.0
	bot.velocity = Vector3.ZERO
	bot.current_health = bot.stats.max_health
	bot.stats.current_ammo = bot.stats.max_ammo
	bot.reserve_ammo = 0
	bot._combat_loot_threshold = 0.0
	bot._awareness_level = 1
	bot._footstep_range = 12.0
	bot.current_state = bot.State.IDLE
	bot.state_timer = 0.0
	bot.target_actor = null
	bot.is_targeting_loot = false
	bot._recovering = false
	bot.perception_meters.clear()
	bot._cached_nearest_target = null
	bot._target_search_timer = 100.0
	bot._perception_timer = 100.0
	bot._ambient_scan_timer = 100.0
	bot._close_range_check_timer = 100.0
	bot._footstep_check_timer = 100.0
	bot._gunshot_check_timer = 100.0
	bot._pickup_search_timer = 100.0
	bot._post_kill_scan_timer = 0.0
	bot._post_kill_loot_attempted = true
	bot.scan_timer = 0.0
	bot._scan_alert = false
	bot._player_sound_look_remaining = 0.0
	bot._player_sound_look_priority = 0
	bot._spawn_age = 0.0
	match mode:
		"post_kill":
			bot._post_kill_scan_timer = 2.5
		"recover":
			bot.current_state = bot.State.RECOVER
			bot.recovery_substate = "patrol"
			bot.recovery_timer = 0.0
			bot.patrol_target = Vector3(0.0, 1.0, -10.0)
		"loot":
			# A noncollectible distant objective keeps the real loot-facing handler active.
			bot.current_state = bot.State.CHASE
			bot.is_targeting_loot = true
			var objective := Node3D.new()
			bot.get_parent().add_child(objective)
			objective.global_position = Vector3(0.0, 1.0, -10.0)
			bot.target_actor = objective
