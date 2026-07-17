extends SceneTree


class MockZone:
	extends RefCounted
	var current_center := Vector2.ZERO
	var current_radius := 100.0
	var stage := 1


class MockMain:
	extends Node
	var zone = MockZone.new()
	var alive_count := 100
	var map_spec = null
	var map_spec_path := ""


func _init():
	call_deferred("_run")


func _run() -> void:
	if not _verify_low_ammo_need_threshold():
		quit(1)
		return
	if not await _verify_immediate_value_loot_priority():
		quit(1)
		return
	if not await _verify_idle_loot_interrupt_grace():
		quit(1)
		return
	if not await _verify_opening_idle_reaction_grace():
		quit(1)
		return
	if not await _verify_opening_close_range_reveal_guard():
		quit(1)
		return
	if not await _verify_player_proximity_threat_contract():
		quit(1)
		return
	if not await _verify_opening_idle_loot_safety():
		quit(1)
		return
	if not await _verify_opening_zone_escape_counteraction_guard():
		quit(1)
		return
	print("Bot opening loot rules smoke passed.")
	quit(0)


func _verify_low_ammo_need_threshold() -> bool:
	var bot = _new_bot()
	bot.stats.max_health = 80.0
	bot.current_health = 80.0
	bot.stats.weapon_type = "pistol"
	bot.stats.current_ammo = 20
	bot.stats.max_ammo = 100
	bot._combat_loot_threshold = 0.2
	if bot._loot_need_key() != "ammo_low":
		var actual: String = bot._loot_need_key()
		bot.free()
		return _fail("Opening ammo at the combat threshold should be ammo_low, got %s." % actual)
	bot.stats.current_ammo = 19
	if bot._loot_need_key() != "combat_low_ammo":
		bot.free()
		return _fail("Ammo below the combat threshold should remain combat_low_ammo.")
	bot.free()
	return true


func _verify_immediate_value_loot_priority() -> bool:
	var bot = _new_tree_bot()
	var healthy_heal = _new_pickup("res://src/items/heal_pickup.tres")
	var same_weapon_ammo = _new_pickup(_new_ammo_item("pistol"))
	root.add_child(bot)
	root.add_child(healthy_heal)
	root.add_child(same_weapon_ammo)
	bot.global_position = Vector3.ZERO
	healthy_heal.global_position = Vector3(0.0, 0.0, -4.0)
	same_weapon_ammo.global_position = Vector3(0.0, 0.0, -9.0)
	bot.current_health = bot.stats.max_health
	bot.stats.weapon_type = "pistol"
	bot.stats.current_ammo = 20
	bot.stats.max_ammo = 100
	var chosen = bot._find_best_pickup(35.0, true)
	var failure := ""
	if chosen != same_weapon_ammo:
		failure = "Healthy opening loot should prefer same-weapon ammo over a closer heal."
	else:
		bot.current_health = bot.stats.max_health * 0.35
		chosen = bot._find_best_pickup(35.0, true)
		if chosen != healthy_heal:
			failure = "Wounded opening loot should still prefer a nearby heal."
	await _cleanup_tree_nodes([bot, healthy_heal, same_weapon_ammo])
	if failure != "":
		return _fail(failure)
	return true


func _verify_idle_loot_interrupt_grace() -> bool:
	var bot = _new_tree_bot()
	var enemy = _new_entity()
	enemy.set_process(false)
	enemy.set_physics_process(false)
	root.add_child(bot)
	root.add_child(enemy)
	bot.global_position = Vector3.ZERO
	enemy.global_position = Vector3(7.5, 0.0, 0.0)
	bot.set("_loot_objective_source", "idle_loot")
	bot.set("_spawn_age", 7.1)
	bot.state_timer = 1.0
	var failure := ""
	if not bot._should_defer_idle_loot_interrupt(enemy):
		failure = "Idle loot should defer medium-range enemy interrupts during the opening grace window."
	else:
		enemy.global_position = Vector3(5.5, 0.0, 0.0)
		if not bot._should_defer_idle_loot_interrupt(enemy):
			failure = "Idle loot should defer enemies just outside the close-range cutoff."
	if failure == "":
		enemy.global_position = Vector3(4.0, 0.0, 0.0)
		if bot._should_defer_idle_loot_interrupt(enemy):
			failure = "Idle loot should not defer close-range enemy interrupts."
		else:
			enemy.global_position = Vector3(7.5, 0.0, 0.0)
			bot.state_timer = 2.1
			if bot._should_defer_idle_loot_interrupt(enemy):
				failure = "Idle loot should not defer interrupts after the grace window."
	await _cleanup_tree_nodes([bot, enemy])
	if failure != "":
		return _fail(failure)
	return true


func _verify_opening_idle_reaction_grace() -> bool:
	var bot = _new_tree_bot()
	var enemy = _new_entity()
	enemy.set_process(false)
	enemy.set_physics_process(false)
	root.add_child(bot)
	root.add_child(enemy)
	bot.global_position = Vector3.ZERO
	enemy.global_position = Vector3(3.0, 0.0, 0.0)
	bot.current_state = 0 # IDLE
	bot.set("_spawn_age", 1.0)
	var failure := ""
	if not bot._should_defer_opening_idle_reaction(enemy):
		failure = "Opening idle reaction should defer visible enemies outside bump range."
	else:
		enemy.global_position = Vector3(1.8, 0.0, 0.0)
		if not bot._should_defer_opening_idle_reaction(enemy):
			failure = "Opening idle reaction should defer near-bump enemies during the opening window."
	if failure == "":
		enemy.global_position = Vector3(0.8, 0.0, 0.0)
		if not bot._should_defer_opening_idle_reaction(enemy):
			failure = "Opening idle reaction should defer hard-bump enemies during the brush grace."
	if failure == "":
		bot.set("_spawn_age", 4.1)
		if bot._should_defer_opening_idle_reaction(enemy):
			failure = "Opening idle reaction should not defer hard-bump enemies after the brush grace."
	if failure == "":
		enemy.global_position = Vector3(3.0, 0.0, 0.0)
		bot.set("_spawn_age", 3.1)
		if not bot._should_defer_opening_idle_reaction(enemy):
			failure = "Opening idle reaction should keep visible enemies outside close range deferred through the visual grace window."
	if failure == "":
		bot.set("_spawn_age", 10.1)
		if bot._should_defer_opening_idle_reaction(enemy):
			failure = "Opening idle reaction should not defer enemies outside close range after the visual grace window."
	if failure == "":
		enemy.global_position = Vector3(1.8, 0.0, 0.0)
		bot.set("_spawn_age", 3.1)
		if not bot._should_defer_opening_idle_reaction(enemy):
			failure = "Opening idle reaction should keep near-bump deferral after the wider idle grace expires."
	if failure == "":
		bot.set("_spawn_age", 7.1)
		if bot._should_defer_opening_idle_reaction(enemy):
			failure = "Opening near-bump reaction should not defer after the opening reveal window."
	if failure == "":
		bot.current_state = 1 # CHASE
		bot.set("_spawn_age", 1.0)
		if bot._should_defer_opening_idle_reaction(enemy):
			failure = "Opening idle reaction grace should only apply while idle."
	await _cleanup_tree_nodes([bot, enemy])
	if failure != "":
		return _fail(failure)
	return true


func _verify_opening_close_range_reveal_guard() -> bool:
	var bot = _new_tree_bot()
	var enemy = _new_entity()
	enemy.set_process(false)
	enemy.set_physics_process(false)
	root.add_child(bot)
	root.add_child(enemy)
	bot.global_position = Vector3.ZERO
	bot.current_state = 0 # IDLE
	bot.set("_spawn_age", 5.0)
	enemy.global_position = Vector3(1.5, 0.0, 0.0)
	var failure := ""
	bot._check_close_range(0.1)
	if float(bot.perception_meters.get(enemy, 0.0)) >= 1.0:
		failure = "Opening close-range reveal should not instantly detect near-bump enemies."
	if failure == "":
		bot.perception_meters.clear()
		bot.set("_close_range_check_timer", 0.0)
		enemy.global_position = Vector3(0.8, 0.0, 0.0)
		bot._check_close_range(0.1)
		if float(bot.perception_meters.get(enemy, 0.0)) < 1.0:
			failure = "Opening close-range reveal should still detect hard-bump enemies."
	if failure == "":
		bot.perception_meters.clear()
		bot.set("_close_range_check_timer", 0.0)
		bot.set("_spawn_age", 7.1)
		enemy.global_position = Vector3(1.5, 0.0, 0.0)
		bot._check_close_range(0.1)
		if float(bot.perception_meters.get(enemy, 0.0)) < 1.0:
			failure = "Opening close-range reveal should restore 2m detection after the reveal window."
	await _cleanup_tree_nodes([bot, enemy])
	if failure != "":
		return _fail(failure)
	return true


func _verify_player_proximity_threat_contract() -> bool:
	var main := MockMain.new()
	main.name = "Main"
	var bot = _new_tree_bot()
	var player = _new_entity()
	player.set_process(false)
	player.set_physics_process(false)
	root.add_child(main)
	root.add_child(bot)
	root.add_child(player)
	player.add_to_group("players")
	bot.global_position = Vector3.ZERO
	player.global_position = Vector3(1.5, 0.0, 0.0)
	bot.current_state = 0 # IDLE
	bot.set("_spawn_age", 1.0)
	bot.stats.weapon_type = "pistol"
	bot.stats.current_ammo = 10
	var failure := ""
	player.global_position = Vector3(0.0, 0.0, 4.5)
	if not bot._can_i_see(player):
		failure = "A player inside 5m should be visible even behind the bot."
	else:
		bot._update_perception(0.35)
		if float(bot.perception_meters.get(player, 0.0)) < 1.0:
			failure = "Near-range 360-degree vision should complete normal dwell detection."
	if failure == "":
		player.global_position = Vector3(1.5, 0.0, 0.0)
	if failure == "" and bot._should_defer_opening_idle_reaction(player):
		failure = "Opening idle reaction must not defer a player."
	elif bot._should_defer_opening_close_range_reveal(player, 1.5):
		failure = "Opening close-range reveal must not defer a player."
	elif bot._should_defer_opening_idle_loot_interrupt(player):
		failure = "Opening loot safety must not defer a player interrupt."
	else:
		player.global_position = Vector3(0.8, 0.0, 0.0)
		if bot._should_defer_opening_hard_bump_combat(player, 0.8):
			failure = "Opening hard-bump grace must only apply to bot-vs-bot contact."
	if failure == "":
		bot.current_state = 3 # ZONE_ESCAPE
		bot.global_position = Vector3(95.0, 0.0, 0.0)
		player.global_position = Vector3(101.0, 0.0, 0.0)
		if bot._should_defer_opening_zone_escape_counteraction(player):
			failure = "Opening zone escape must not defer counteraction against a player."
	if failure == "":
		bot.current_state = 0 # IDLE
		bot.global_position = Vector3.ZERO
		player.global_position = Vector3(1.5, 0.0, 0.0)
		bot.perception_meters.clear()
		bot.set("_close_range_check_timer", 0.0)
		bot._check_close_range(0.1)
		if float(bot.perception_meters.get(player, 0.0)) < 1.0:
			failure = "An adjacent player should be fully detected during the opening window."
	if failure == "":
		bot.set("_reaction_delay", 0.0)
		bot.handle_idle_state(0.1)
		bot.handle_idle_state(0.1)
		if bot.target_actor != player or bot.current_state != 1: # CHASE
			failure = "An adjacent player should become the idle bot's combat target."
	await _cleanup_tree_nodes([bot, player, main])
	if failure != "":
		return _fail(failure)
	return await _verify_recovery_player_proximity_contract()


func _verify_recovery_player_proximity_contract() -> bool:
	var bot = _new_tree_bot()
	var player = _new_entity()
	player.set_process(false)
	player.set_physics_process(false)
	root.add_child(bot)
	root.add_child(player)
	player.add_to_group("players")
	bot.global_position = Vector3.ZERO
	player.global_position = Vector3(0.0, 0.0, 4.5)
	bot.stats.weapon_type = "pistol"
	bot.stats.current_ammo = 10
	bot._update_perception(0.35)
	bot.current_state = 4 # RECOVER
	bot.recovery_substate = "patrol"
	bot.handle_recover_state(0.1)
	var failure := ""
	if float(bot.perception_meters.get(player, 0.0)) < 1.0:
		failure = "A player 4.5m behind a recovering bot should complete near-range detection."
	elif bot.target_actor != player or bot.current_state != 5: # DISENGAGE
		failure = "A recovering bot should counter a revealed player inside its near range."
	await _cleanup_tree_nodes([bot, player])
	if failure != "":
		return _fail(failure)
	return await _verify_recovery_loot_player_interrupt()


func _verify_recovery_loot_player_interrupt() -> bool:
	var bot = _new_tree_bot()
	var player = _new_entity()
	var loot = _new_pickup(_new_ammo_item("pistol"))
	player.set_process(false)
	player.set_physics_process(false)
	loot.set_process(false)
	loot.set_physics_process(false)
	root.add_child(bot)
	root.add_child(player)
	root.add_child(loot)
	player.add_to_group("players")
	bot.global_position = Vector3.ZERO
	player.global_position = Vector3(0.0, 0.0, 4.5)
	loot.global_position = Vector3(12.0, 0.0, 0.0)
	bot.stats.weapon_type = "pistol"
	bot.stats.current_ammo = 10
	bot._update_perception(0.35)
	bot.current_state = 1 # CHASE
	bot._start_loot_objective(loot, "recover_seek_loot", true)
	var interrupted: bool = bool(bot._maybe_interrupt_objective_for_enemy())
	var failure := ""
	if not interrupted or bot.target_actor != player or bot.is_targeting_loot:
		failure = "Recovery loot must yield to a revealed player inside the near range."
	await _cleanup_tree_nodes([bot, player, loot])
	if failure != "":
		return _fail(failure)
	return true


func _verify_opening_idle_loot_safety() -> bool:
	var bot = _new_tree_bot()
	var enemy = _new_entity()
	var loot = _new_pickup(_new_ammo_item("pistol"))
	enemy.set_process(false)
	enemy.set_physics_process(false)
	loot.set_process(false)
	loot.set_physics_process(false)
	root.add_child(bot)
	root.add_child(enemy)
	root.add_child(loot)
	bot.global_position = Vector3.ZERO
	enemy.global_position = Vector3(4.8, 0.0, 0.0)
	loot.global_position = Vector3(12.0, 0.0, 0.0)
	bot.set("_loot_objective_source", "idle_loot")
	bot.state_timer = 1.0
	bot.set("_spawn_age", 1.0)
	var failure := ""
	if not bot._should_defer_opening_idle_loot_objective(loot):
		failure = "Opening idle loot should defer far objectives when an actor is inside the safety radius."
	elif not bot._should_defer_idle_loot_interrupt(enemy):
		failure = "Opening idle loot should defer objective interrupts outside bump range."
	else:
		enemy.global_position = Vector3(5.5, 0.0, 0.0)
		if bot._should_defer_opening_idle_loot_objective(loot):
			failure = "Opening idle loot should not defer when nearby actors are outside the safety radius."
	if failure == "":
		enemy.global_position = Vector3(4.8, 0.0, 0.0)
		loot.global_position = Vector3(2.0, 0.0, 0.0)
		if bot._should_defer_opening_idle_loot_objective(loot):
			failure = "Opening idle loot should allow immediate collection range pickups."
	if failure == "":
		enemy.global_position = Vector3(1.8, 0.0, 0.0)
		if not bot._should_defer_idle_loot_interrupt(enemy):
			failure = "Opening idle loot should defer near-bump objective interrupts."
	if failure == "":
		enemy.global_position = Vector3(0.8, 0.0, 0.0)
		if not bot._should_defer_idle_loot_interrupt(enemy):
			failure = "Opening idle loot should defer hard-bump objective interrupts during the brush grace."
	if failure == "":
		bot.set("_spawn_age", 4.1)
		if bot._should_defer_idle_loot_interrupt(enemy):
			failure = "Opening idle loot should not defer hard-bump objective interrupts after the brush grace."
	if failure == "":
		enemy.global_position = Vector3(4.8, 0.0, 0.0)
		loot.global_position = Vector3(12.0, 0.0, 0.0)
		bot.set("_spawn_age", 3.1)
		if bot._should_defer_opening_idle_loot_objective(loot):
			failure = "Opening idle loot safety should expire after the spawn window."
		elif not bot._should_defer_idle_loot_interrupt(enemy):
			failure = "Opening idle loot interrupt safety should remain active after the objective-start window."
	if failure == "":
		bot.set("_spawn_age", 7.1)
		if bot._should_defer_idle_loot_interrupt(enemy):
			failure = "Opening idle loot interrupt safety should expire after the wider interrupt window."
	await _cleanup_tree_nodes([bot, enemy, loot])
	if failure != "":
		return _fail(failure)
	return true


func _verify_opening_zone_escape_counteraction_guard() -> bool:
	var main := MockMain.new()
	main.name = "Main"
	main.zone.current_center = Vector2.ZERO
	main.zone.current_radius = 100.0
	var bot = _new_tree_bot()
	var enemy = _new_entity()
	enemy.set_process(false)
	enemy.set_physics_process(false)
	root.add_child(main)
	root.add_child(bot)
	root.add_child(enemy)
	bot.current_state = 3 # ZONE_ESCAPE
	bot.set("_spawn_age", 6.0)
	bot.global_position = Vector3(95.0, 0.0, 0.0)
	enemy.global_position = Vector3(101.0, 0.0, 0.0)
	var failure := ""
	if not bot._should_defer_opening_zone_escape_counteraction(enemy):
		failure = "Opening zone-edge escape should defer retreat counteraction while still inside the zone."
	if failure == "":
		enemy.global_position = Vector3(95.8, 0.0, 0.0)
		bot.set("_spawn_age", 3.5)
		if not bot._should_defer_opening_zone_escape_counteraction(enemy):
			failure = "Opening zone-edge escape should defer hard-bump counteraction during the brush grace."
	if failure == "":
		enemy.global_position = Vector3(95.8, 0.0, 0.0)
		bot.set("_spawn_age", 6.0)
		if bot._should_defer_opening_zone_escape_counteraction(enemy):
			failure = "Opening zone-edge escape should not defer hard-bump threats."
	if failure == "":
		enemy.global_position = Vector3(101.0, 0.0, 0.0)
		bot.set("_spawn_age", 10.1)
		if bot._should_defer_opening_zone_escape_counteraction(enemy):
			failure = "Opening zone-edge escape should not defer retreat counteraction after the opening window."
	if failure == "":
		bot.set("_spawn_age", 6.0)
		bot.global_position = Vector3(101.0, 0.0, 0.0)
		enemy.global_position = Vector3(107.0, 0.0, 0.0)
		if bot._should_defer_opening_zone_escape_counteraction(enemy):
			failure = "Opening zone-edge escape should not defer counteraction when actually outside the zone."
	await _cleanup_tree_nodes([bot, enemy, main])
	if failure != "":
		return _fail(failure)
	return true


func _new_tree_bot():
	var bot = _new_bot()
	var ray_cast := RayCast3D.new()
	ray_cast.name = "RayCast3D"
	bot.add_child(ray_cast)
	bot.set_process(false)
	bot.set_physics_process(false)
	return bot


func _new_bot():
	var bot_script = load("res://src/entities/bot/Bot.gd")
	var stats_script = load("res://src/core/StatsData.gd")
	var bot = bot_script.new()
	bot.stats = stats_script.new()
	return bot


func _new_entity():
	var entity_script = load("res://src/entities/Entity.gd")
	var stats_script = load("res://src/core/StatsData.gd")
	var entity = entity_script.new()
	entity.stats = stats_script.new()
	return entity


func _new_pickup(item_source):
	var pickup_script = load("res://src/entities/pickup/Pickup.gd")
	var pickup = pickup_script.new()
	pickup.item = load(item_source) if item_source is String else item_source
	pickup.set_process(false)
	pickup.set_physics_process(false)
	return pickup


func _new_ammo_item(weapon_type: String):
	var item_script = load("res://src/core/ItemData.gd")
	var item = item_script.new()
	item.type = ItemData.Type.AMMO
	item.item_name = "%s ammo" % weapon_type
	item.amount = 15
	item.ammo_weapon_type = weapon_type
	return item


func _cleanup_tree_nodes(nodes: Array) -> void:
	for node in nodes:
		if is_instance_valid(node):
			node.set_process(false)
			node.set_physics_process(false)
	var wait_until := Time.get_ticks_msec() + 250
	while Time.get_ticks_msec() < wait_until:
		await process_frame
	for node in nodes:
		if is_instance_valid(node):
			node.queue_free()
	for _frame in range(3):
		await process_frame


func _fail(message: String) -> bool:
	push_error(message)
	return false
