extends SceneTree


const PLAYER_SURVIVAL_POLICY = preload(
	"res://src/entities/player/PlayerSurvivalPolicy.gd"
)
const PICKUP_SCENE = preload("res://src/entities/pickup/Pickup.tscn")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	if not _verify_policy():
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
	var player = main.player_ref
	if not is_instance_valid(player):
		await _cleanup(main)
		_fail("Survival runtime did not spawn a player.")
		return
	player.set_physics_process(false)

	player.current_health = 20.0
	player.stats.advanced_heals = 1
	player.stats.heal_items = 1
	player.call("_mark_combat_activity")
	player.handle_healing()
	if player.stats.advanced_heals != 1 \
			or player.stats.heal_items != 0 \
			or not is_equal_approx(player.current_health, 20.0) \
			or float(player.get("_heal_regen")) <= 0.0:
		await _cleanup(main)
		_fail("Combat healing must preserve the medkit and consume one bandage.")
		return

	player.set("_heal_regen", 0.0)
	player.stats.heal_items = 0
	player.set(
		"_last_combat_activity_msec",
		Time.get_ticks_msec() - PLAYER_SURVIVAL_POLICY.COMBAT_LOCK_MSEC
	)
	player.handle_healing()
	if player.stats.advanced_heals != 0 or not is_equal_approx(player.current_health, 70.0):
		await _cleanup(main)
		_fail("A safe medkit use must consume one item and restore exactly 50 HP.")
		return

	player.stats.advanced_heals = 1
	var blocked_medkit = _spawn_pickup(ItemData.Type.HEAL, ItemData.Rarity.RARE, 1)
	if blocked_medkit.collect(player):
		await _cleanup(main)
		_fail("The player must not collect a second medkit.")
		return
	blocked_medkit.queue_free()

	player.current_shield = 0.0
	player.call("_mark_combat_activity")
	var blocked_shield = _spawn_pickup(ItemData.Type.ARMOR, ItemData.Rarity.COMMON, 20)
	if blocked_shield.collect(player) or not is_zero_approx(player.current_shield):
		await _cleanup(main)
		_fail("A shield pickup must remain on the ground during combat.")
		return
	blocked_shield.queue_free()

	player.set(
		"_last_combat_activity_msec",
		Time.get_ticks_msec() - PLAYER_SURVIVAL_POLICY.COMBAT_LOCK_MSEC
	)
	var safe_shield = _spawn_pickup(ItemData.Type.ARMOR, ItemData.Rarity.COMMON, 20)
	if not safe_shield.collect(player) or not is_equal_approx(player.current_shield, 20.0):
		await _cleanup(main)
		_fail("A safe shield pickup must apply normally.")
		return

	await _cleanup(main)
	print("Player survival runtime smoke passed: combat lock, medkit 1/50, bandage, shield, injury speed.")
	quit(0)


func _verify_policy() -> bool:
	if not PLAYER_SURVIVAL_POLICY.is_in_combat(10_000, 4_001) \
			or PLAYER_SURVIVAL_POLICY.is_in_combat(10_000, 4_000):
		_fail("Combat lock must last exactly six seconds.")
		return false
	if PLAYER_SURVIVAL_POLICY.can_collect_medkit(1) \
			or PLAYER_SURVIVAL_POLICY.clamped_medkit_count(0, 3) != 1:
		_fail("Medkit inventory must be capped at one.")
		return false
	if not is_equal_approx(PLAYER_SURVIVAL_POLICY.medkit_heal_amount(false), 50.0):
		_fail("Normal through Hard medkits must restore 50 HP.")
		return false
	if not is_equal_approx(
		PLAYER_SURVIVAL_POLICY.health_movement_multiplier(50.0, 100.0),
		0.92
	) or not is_equal_approx(
		PLAYER_SURVIVAL_POLICY.health_movement_multiplier(25.0, 100.0),
		0.82
	) or not is_equal_approx(
		PLAYER_SURVIVAL_POLICY.health_movement_multiplier(51.0, 100.0),
		1.0
	):
		_fail("Injury movement multipliers must preserve 100/92/82 percent bands.")
		return false
	return true


func _spawn_pickup(type: int, rarity: int, amount: int):
	var item := ItemData.new()
	item.type = type
	item.rarity = rarity
	item.amount = amount
	var pickup = PICKUP_SCENE.instantiate()
	root.add_child(pickup)
	pickup.init(item, "survival_runtime")
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
