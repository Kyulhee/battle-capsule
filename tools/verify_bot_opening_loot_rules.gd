extends SceneTree


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
