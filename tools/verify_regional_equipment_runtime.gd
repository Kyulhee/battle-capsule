extends SceneTree


const ITEM_CATALOG = preload("res://src/core/ItemResourceCatalog.gd")
const MATCH_RUNTIME_TUNING = preload("res://src/systems/match/MatchRuntimeTuning.gd")
const PICKUP_SCENE = preload("res://src/entities/pickup/Pickup.tscn")
const WEAPON_SLOTS = preload("res://src/core/WeaponSlotManager.gd")
const ENTITY = preload("res://src/entities/Entity.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	if not _verify_catalog_and_weapon_upgrade():
		return
	var main_scene: PackedScene = load("res://src/Main.tscn")
	if main_scene == null:
		_fail("Could not load Main.tscn.")
		return
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await _wait_for_navigation(main)
	main.start_game()

	var regional_counts := _regional_weapon_counts(main)
	if regional_counts.is_empty():
		await _cleanup(main)
		return
	if int(regional_counts["field"]) < 1:
		await _cleanup(main)
		_fail("M1 initial loot must expose at least one contested field-grade weapon.")
		return

	var player = main.player_ref
	if not is_instance_valid(player):
		await _cleanup(main)
		_fail("Equipment runtime did not spawn a player.")
		return
	player.set_physics_process(false)
	player.set("_last_combat_activity_msec", -1)
	var vest_pickup = _spawn_pickup(ITEM_CATALOG.BALLISTIC_VEST)
	if not vest_pickup.collect(player):
		await _cleanup(main)
		_fail("Player could not equip the ballistic vest.")
		return
	if player.equipped_armor_id != "ballistic_vest" \
			or player.equipped_armor_tier != 1 \
			or not is_equal_approx(player.armor_damage_reduction, 0.15) \
			or not is_equal_approx(player.get_equipment_movement_multiplier(), 0.96):
		await _cleanup(main)
		_fail("Ballistic vest stats were not applied.")
		return

	player.current_health = 100.0
	player.current_shield = 0.0
	player.take_damage(20.0, "gun", "pistol")
	if not is_equal_approx(player.current_health, 83.0):
		await _cleanup(main)
		_fail("Ballistic vest must reduce 20 gun damage to 17 health damage.")
		return
	player.take_damage(10.0, "zone")
	if not is_equal_approx(player.current_health, 73.0):
		await _cleanup(main)
		_fail("Ballistic vest must not reduce zone damage.")
		return

	player.set("_last_combat_activity_msec", -1)
	var duplicate_vest = _spawn_pickup(ITEM_CATALOG.BALLISTIC_VEST)
	if duplicate_vest.collect(player):
		await _cleanup(main)
		_fail("Equal-tier armor must remain on the ground.")
		return
	duplicate_vest.queue_free()

	var loot_tuning: Dictionary = MATCH_RUNTIME_TUNING.loot(main.match_runtime_tuning)
	if not _verify_regional_tuning(loot_tuning):
		await _cleanup(main)
		return

	await _cleanup(main)
	print(
		"Regional equipment runtime smoke passed: field=%d scavenged=%d armor=15%% move=96%%."
		% [regional_counts["field"], regional_counts["scavenged"]]
	)
	quit(0)


func _verify_catalog_and_weapon_upgrade() -> bool:
	if ITEM_CATALOG.SHIELD_PICKUP.item_name != "실드 충전" \
			or not ITEM_CATALOG.SHIELD_PICKUP.equipment_id.is_empty():
		_fail("Legacy armor pickup must be identified as a shield charge.")
		return false
	if ITEM_CATALOG.BALLISTIC_VEST.equipment_id != "ballistic_vest":
		_fail("Ballistic vest resource is missing.")
		return false
	var slots = WEAPON_SLOTS.new()
	if not slots.receive_weapon(ITEM_CATALOG.WEAPON_AR_WORN.weapon_stats) \
			or not slots.receive_weapon(ITEM_CATALOG.WEAPON_AR.weapon_stats):
		_fail("A standard AR must replace a worn AR of the same family.")
		return false
	if slots.receive_weapon(ITEM_CATALOG.WEAPON_AR_WORN.weapon_stats) \
			or slots.weapon_slots[1].weapon_tier != 2:
		_fail("A worn AR must not replace a standard AR.")
		return false
	var bot_like = ENTITY.new()
	bot_like.stats = ITEM_CATALOG.WEAPON_AR.weapon_stats.duplicate()
	var accepts_worn_shotgun := bot_like.can_receive_weapon(
		ITEM_CATALOG.WEAPON_SHOTGUN_WORN.weapon_stats
	)
	var accepts_standard_shotgun := bot_like.can_receive_weapon(
		ITEM_CATALOG.WEAPON_SHOTGUN.weapon_stats
	)
	bot_like.free()
	if accepts_worn_shotgun or not accepts_standard_shotgun:
		_fail("Bots must reject lower-tier cross-family swaps and allow equal-tier swaps.")
		return false
	return true


func _regional_weapon_counts(main) -> Dictionary:
	var counts := {"field": 0, "scavenged": 0}
	var field_roles := ["loot_hub", "transit_choke"]
	for child in main.get_node("Loot").get_children():
		if not child is Pickup or child.item == null \
				or child.item.type != ItemData.Type.WEAPON:
			continue
		var context: Dictionary = main.map_definition.describe_strategic_position(
			Vector2(child.global_position.x, child.global_position.z)
		)
		var role := String(context.get("nearest_poi_role", "none"))
		var tier := int(child.item.weapon_stats.weapon_tier)
		if field_roles.has(role):
			if tier != 2:
				_fail("Contested initial weapon must be field grade, role=%s tier=%d." % [role, tier])
				return {}
			counts["field"] += 1
		else:
			if tier != 1:
				_fail("Outer initial weapon must be scavenged grade, role=%s tier=%d." % [role, tier])
				return {}
			counts["scavenged"] += 1
	return counts


func _verify_regional_tuning(loot_tuning: Dictionary) -> bool:
	var chances: Dictionary = loot_tuning.get("role_initial_weapon_chance", {})
	var pools: Dictionary = loot_tuning.get("role_initial_weapon_pool", {})
	var armor_chances: Dictionary = loot_tuning.get("role_initial_equipment_chance", {})
	if not is_equal_approx(float(chances.get("loot_hub", 0.0)), 0.65) \
			or not is_equal_approx(float(chances.get("transit_choke", 0.0)), 0.40) \
			or String(pools.get("loot_hub", "")) != "field" \
			or String(pools.get("concealment_field", "")) != "scavenged" \
			or not is_equal_approx(float(armor_chances.get("loot_hub", 0.0)), 0.34):
		_fail("M1 regional weapon and equipment tuning changed.")
		return false
	return true


func _spawn_pickup(item: ItemData):
	var pickup = PICKUP_SCENE.instantiate()
	root.add_child(pickup)
	pickup.init(item.duplicate(true), "equipment_runtime")
	return pickup


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
