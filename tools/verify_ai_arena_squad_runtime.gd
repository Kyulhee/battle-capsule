extends SceneTree


const NATURAL_OBSERVE_SECONDS := 2.0
const COMMIT_OBSERVE_SECONDS := 3.0
const SAMPLE_INTERVAL_SECONDS := 0.05
const PLAYER_PROBE_HEALTH := 10000.0
const MIN_RETENTION_RATIO := 0.98
const MIN_CONCURRENT_PLAYER_TARGETS := 4
const MIN_ATTACKING_BOTS := 3
const MIN_DAMAGE := 20.0


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
	if not is_instance_valid(player) or bots.size() != 4:
		await _cleanup(main)
		_fail("Squad runtime must spawn one active player and four bots.")
		return
	var spawn_summary: Dictionary = main._spawn_distribution_summary()
	if int(spawn_summary.get("fixed_count", 0)) != 5 \
			or int(spawn_summary.get("fallback_count", -1)) != 0:
		await _cleanup(main)
		_fail("Squad runtime must consume all five fixed spawns without fallback.")
		return
	var initial_pickups := get_nodes_in_group("pickups").size()
	if initial_pickups <= 0:
		await _cleanup(main)
		_fail("Squad runtime must keep initial loot enabled.")
		return

	player.set_process(false)
	player.set_physics_process(false)
	player.stats.max_health = PLAYER_PROBE_HEALTH
	player.current_health = PLAYER_PROBE_HEALTH

	var natural_target_ids: Dictionary = {}
	var natural_attack_ids: Dictionary = {}
	var natural_elapsed := 0.0
	while natural_elapsed < NATURAL_OBSERVE_SECONDS:
		await create_timer(SAMPLE_INTERVAL_SECONDS).timeout
		natural_elapsed += SAMPLE_INTERVAL_SECONDS
		for bot in bots:
			if not is_instance_valid(bot):
				continue
			if bot.target_actor == player:
				natural_target_ids[bot.get_instance_id()] = true
			if bot.current_state == bot.State.ATTACK and bot.target_actor == player:
				natural_attack_ids[bot.get_instance_id()] = true

	for bot in bots:
		var bot_ray: RayCast3D = bot.get_node_or_null("RayCast3D")
		if bot_ray:
			for other_bot in bots:
				if other_bot != bot:
					bot_ray.add_exception(other_bot)

	for bot in bots:
		if not is_instance_valid(bot):
			await _cleanup(main)
			_fail("A squad bot died before the commitment probe.")
			return
		bot.stats.max_health = PLAYER_PROBE_HEALTH
		bot.current_health = PLAYER_PROBE_HEALTH
		bot.stats.current_ammo = bot.stats.max_ammo
		bot.reserve_ammo = bot.stats.max_ammo
		bot.set("_awareness_level", 0)
		bot.set("_combat_loot_threshold", 0.0)
		bot.set("_sniper_min_engage_range", 0.0)
		bot.damage_history.clear()
		bot.set("_engagement_dmg_taken", 0.0)
		bot.set("_engagement_dmg_dealt", 0.0)
		bot.perception_meters[player] = 1.0
		if not bot.acquire_enemy_target(player, "arena_squad_probe"):
			await _cleanup(main)
			_fail("A squad bot rejected the forced player target.")
			return
		bot.change_state(bot.State.CHASE)

	var target_samples := 0
	var total_samples := 0
	var null_target_samples := 0
	var other_entity_target_samples := 0
	var objective_target_samples := 0
	var switched_away_ids: Dictionary = {}
	var minimum_concurrent_targets := bots.size()
	var attack_ids: Dictionary = {}
	var disengage_ids: Dictionary = {}
	var state_samples: Dictionary = {}
	var minimum_pairwise_distance := INF
	var commit_elapsed := 0.0
	while commit_elapsed < COMMIT_OBSERVE_SECONDS:
		await create_timer(SAMPLE_INTERVAL_SECONDS).timeout
		commit_elapsed += SAMPLE_INTERVAL_SECONDS
		var concurrent_targets := 0
		var living_bots: Array = []
		for bot in bots:
			if not is_instance_valid(bot) or bot.is_dead:
				continue
			living_bots.append(bot)
			total_samples += 1
			if bot.target_actor == player:
				target_samples += 1
				concurrent_targets += 1
			elif not is_instance_valid(bot.target_actor):
				null_target_samples += 1
				switched_away_ids[bot.get_instance_id()] = true
			elif bot.target_actor is Entity:
				other_entity_target_samples += 1
				switched_away_ids[bot.get_instance_id()] = true
			else:
				objective_target_samples += 1
				switched_away_ids[bot.get_instance_id()] = true
			var state_name := String(bot.State.keys()[bot.current_state])
			state_samples[state_name] = int(state_samples.get(state_name, 0)) + 1
			if bot.current_state == bot.State.ATTACK and bot.target_actor == player:
				attack_ids[bot.get_instance_id()] = true
			if bot.current_state == bot.State.DISENGAGE:
				disengage_ids[bot.get_instance_id()] = true
		minimum_concurrent_targets = mini(minimum_concurrent_targets, concurrent_targets)
		minimum_pairwise_distance = minf(
			minimum_pairwise_distance,
			_minimum_pairwise_bot_distance(living_bots)
		)

	var retention_ratio := float(target_samples) / maxf(1.0, float(total_samples))
	var damage_dealt := PLAYER_PROBE_HEALTH - player.current_health
	var result := {
		"natural_targets": natural_target_ids.size(),
		"natural_attackers": natural_attack_ids.size(),
		"retention_ratio": retention_ratio,
		"minimum_concurrent_targets": minimum_concurrent_targets,
		"switched_away": switched_away_ids.size(),
		"null_target_samples": null_target_samples,
		"other_entity_target_samples": other_entity_target_samples,
		"objective_target_samples": objective_target_samples,
		"attackers": attack_ids.size(),
		"disengagers": disengage_ids.size(),
		"minimum_pairwise_distance": minimum_pairwise_distance,
		"damage": damage_dealt,
		"state_samples": state_samples,
		"initial_pickups": initial_pickups,
	}
	var failure := ""
	if retention_ratio < MIN_RETENTION_RATIO:
		failure = "Squad player-target retention fell below 98%%: %.1f%%." % (retention_ratio * 100.0)
	elif minimum_concurrent_targets < MIN_CONCURRENT_PLAYER_TARGETS:
		failure = "Squad player commitment fell below four concurrent targets."
	elif null_target_samples > 0 or other_entity_target_samples > 0 or objective_target_samples > 0:
		failure = "The isolated squad commitment probe changed away from the player target."
	elif attack_ids.size() < MIN_ATTACKING_BOTS:
		failure = "Fewer than three squad bots attacked the committed player."
	elif damage_dealt < MIN_DAMAGE:
		failure = "Squad bots dealt less than 20 damage during the commitment probe."
	await _cleanup(main)
	if failure != "":
		_fail("%s Result: %s" % [failure, result])
		return
	print("AI arena squad runtime smoke passed: %s" % result)
	quit(0)


func _minimum_pairwise_bot_distance(bots: Array) -> float:
	if bots.size() < 2:
		return INF
	var minimum_distance := INF
	for i in range(bots.size()):
		for j in range(i + 1, bots.size()):
			minimum_distance = minf(
				minimum_distance,
				bots[i].global_position.distance_to(bots[j].global_position)
			)
	return minimum_distance


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
