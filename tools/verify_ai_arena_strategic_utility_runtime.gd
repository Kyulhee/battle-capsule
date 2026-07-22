extends SceneTree


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

	var bots := get_nodes_in_group("bots")
	if bots.size() != 1:
		await _cleanup(main)
		_fail("Strategic utility arena must spawn exactly one bot.")
		return
	var bot = bots[0]
	bot.set_process(false)
	bot.set_physics_process(false)

	bot.stats.weapon_type = "ar"
	bot.stats.current_ammo = bot.stats.max_ammo
	bot.reserve_ammo = bot.stats.max_ammo
	bot.current_health = bot.stats.max_health
	bot.current_shield = bot.stats.max_shield
	bot.set("_last_damage_tick", 0)
	var ready_context: Dictionary = bot.call(
		"_strategic_utility_context",
		main,
		"roam",
		false
	)

	bot.stats.weapon_type = "knife"
	bot.stats.current_ammo = 0
	bot.reserve_ammo = 0
	bot.current_shield = 0.0
	var stripped_context: Dictionary = bot.call(
		"_strategic_utility_context",
		main,
		"roam",
		false
	)

	bot.stats.weapon_type = "ar"
	bot.stats.current_ammo = bot.stats.max_ammo
	bot.reserve_ammo = bot.stats.max_ammo
	bot.current_health = bot.stats.max_health * 0.25
	bot.current_shield = bot.stats.max_shield
	bot.set("_last_damage_tick", Time.get_ticks_msec())
	var threatened_context: Dictionary = bot.call(
		"_strategic_utility_context",
		main,
		"roam",
		false
	)

	await _cleanup(main)
	if not _normalized_context(ready_context):
		_fail("Ready strategic context contains values outside the normalized contract.")
		return
	if float(stripped_context.get("equipment_need", 0.0)) \
			<= float(ready_context.get("equipment_need", 0.0)) + 0.4:
		_fail("Removing weapons, ammunition, and armor must materially raise equipment need.")
		return
	if float(threatened_context.get("survival_need", 0.0)) \
			<= float(ready_context.get("survival_need", 0.0)) + 0.4:
		_fail("Severe health loss must materially raise strategic survival need.")
		return
	if float(threatened_context.get("threat_pressure", 0.0)) < 0.6:
		_fail("A fresh damage event must create immediate strategic threat pressure.")
		return
	if float(stripped_context.get("combat_readiness", 1.0)) \
			>= float(ready_context.get("combat_readiness", 0.0)):
		_fail("Stripped equipment must lower strategic combat readiness.")
		return
	print("AI arena strategic utility smoke passed: equipment, survival, and threat inputs react.")
	quit(0)


func _normalized_context(context: Dictionary) -> bool:
	for key in [
		"health_ratio",
		"shield_ratio",
		"ammo_ratio",
		"equipment_need",
		"survival_need",
		"threat_pressure",
		"combat_readiness",
	]:
		var value := float(context.get(key, -1.0))
		if value < 0.0 or value > 1.0:
			return false
	return float(context.get("move_speed", 0.0)) > 0.0 \
		and float(context.get("movement_multiplier", 0.0)) > 0.0 \
		and float(context.get("time_budget_seconds", 0.0)) > 0.0


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
