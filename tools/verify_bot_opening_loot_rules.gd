extends SceneTree


func _init():
	call_deferred("_run")


func _run() -> void:
	if not _verify_low_ammo_need_threshold():
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


func _verify_idle_loot_interrupt_grace() -> bool:
	var bot = _new_bot()
	var enemy = _new_entity()
	var ray_cast := RayCast3D.new()
	ray_cast.name = "RayCast3D"
	bot.add_child(ray_cast)
	bot.set_process(false)
	bot.set_physics_process(false)
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
		enemy.global_position = Vector3(4.0, 0.0, 0.0)
		if bot._should_defer_idle_loot_interrupt(enemy):
			failure = "Idle loot should not defer close-range enemy interrupts."
		else:
			enemy.global_position = Vector3(7.5, 0.0, 0.0)
			bot.state_timer = 2.1
			if bot._should_defer_idle_loot_interrupt(enemy):
				failure = "Idle loot should not defer interrupts after the grace window."
	for _frame in range(20):
		await process_frame
	bot.queue_free()
	enemy.queue_free()
	await process_frame
	if failure != "":
		return _fail(failure)
	return true


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


func _fail(message: String) -> bool:
	push_error(message)
	return false
