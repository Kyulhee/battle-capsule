extends SceneTree


class NoWeaponWaveSpawner:
	extends RefCounted

	func wave_weapon_chance(_hotspot: Dictionary) -> float:
		return -1.0


const BotScript = preload("res://src/entities/bot/Bot.gd")
const DropDisplayCatalogScript = preload("res://src/core/DropDisplayCatalog.gd")
const LootSpawnDirectorScript = preload("res://src/systems/loot/LootSpawnDirector.gd")
const PickupScript = preload("res://src/entities/pickup/Pickup.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _verify_bot_drop_filters():
		quit(1)
		return
	if not _verify_wave_consumable_contract():
		quit(1)
		return
	if not await _verify_pickup_lifetime_contract():
		quit(1)
		return
	print("Loot drop stability smoke passed.")
	quit(0)


func _verify_bot_drop_filters() -> bool:
	for blocked_type in ["", "none", "empty", "knife", "pistol", " PISTOL "]:
		if BotScript.should_drop_weapon_type(blocked_type):
			return _fail("Bot weapon drops must exclude '%s'." % blocked_type)
		if DropDisplayCatalogScript.should_drop_weapon_type(blocked_type):
			return _fail("Shared weapon drop policy must exclude '%s'." % blocked_type)
	for allowed_type in ["smg", "shotgun", "ar", "sniper"]:
		if not BotScript.should_drop_weapon_type(allowed_type):
			return _fail("Bot weapon drops unexpectedly excluded '%s'." % allowed_type)
		if not DropDisplayCatalogScript.should_drop_weapon_type(allowed_type):
			return _fail("Shared weapon drop policy unexpectedly excluded '%s'." % allowed_type)
	if not BotScript.should_drop_ammo_for_weapon_type("pistol"):
		return _fail("Pistol ammo must remain eligible for bot death drops.")
	if not DropDisplayCatalogScript.should_drop_ammo_for_weapon_type("pistol"):
		return _fail("Pistol ammo must remain eligible under the shared death-drop policy.")
	for blocked_ammo_type in ["", "none", "empty", "knife"]:
		if BotScript.should_drop_ammo_for_weapon_type(blocked_ammo_type):
			return _fail("Bot ammo drops must exclude '%s'." % blocked_ammo_type)
		if DropDisplayCatalogScript.should_drop_ammo_for_weapon_type(blocked_ammo_type):
			return _fail("Shared ammo drop policy must exclude '%s'." % blocked_ammo_type)
	return true


func _verify_wave_consumable_contract() -> bool:
	var weapon := ItemData.new()
	weapon.type = ItemData.Type.WEAPON
	weapon.item_name = "Contaminating weapon"
	var ammo := ItemData.new()
	ammo.type = ItemData.Type.AMMO
	ammo.item_name = "Wave ammo"
	ammo.ammo_weapon_type = "smg"
	ammo.amount = 15

	var pool := LootSpawnDirectorScript.wave_consumable_pool([weapon, null, ammo])
	if pool.size() != 1 or pool[0] != ammo:
		return _fail("Stage-wave consumable pool must strip weapons and null templates.")

	var pickup_scene: PackedScene = load("res://src/entities/pickup/Pickup.tscn")
	if pickup_scene == null:
		return _fail("Pickup.tscn could not be loaded for the wave contract.")
	var loot_parent := Node3D.new()
	root.add_child(loot_parent)
	var spawned := LootSpawnDirectorScript.spawn_loot_wave(
		pickup_scene,
		loot_parent,
		1,
		NoWeaponWaveSpawner.new(),
		Callable(self, "_fixed_hotspot"),
		Callable(self, "_fixed_loot_position"),
		[weapon],
		[weapon, ammo]
	)
	var failure := ""
	if spawned != 1 or loot_parent.get_child_count() != 1:
		failure = "A non-weapon wave roll should spawn from the consumable-only pool."
	else:
		var pickup = loot_parent.get_child(0)
		if pickup.item == null or pickup.item.type == ItemData.Type.WEAPON:
			failure = "A non-weapon wave roll leaked a weapon template."
		elif String(pickup.get("_spawn_source")) != "stage_wave":
			failure = "Stage-wave pickup did not preserve its spawn source."
		elif not is_equal_approx(
			float(pickup.get("_lifetime_deadline_seconds")),
			PickupScript.STAGE_WAVE_LIFETIME_SECONDS
		):
			failure = "Stage-wave pickups must use the bounded wave lifetime."
	loot_parent.queue_free()
	if failure != "":
		return _fail(failure)
	return true


func _verify_pickup_lifetime_contract() -> bool:
	if not is_equal_approx(
		PickupScript.lifetime_seconds_for_source(" BOT_DROP "),
		PickupScript.BOT_DROP_LIFETIME_SECONDS
	):
		return _fail("Bot death drops must receive the default 120-second lifetime.")
	if not is_equal_approx(
		PickupScript.lifetime_seconds_for_source("stage_wave"),
		PickupScript.STAGE_WAVE_LIFETIME_SECONDS
	):
		return _fail("Stage-wave pickups must expire after 180 seconds by default.")
	if not is_equal_approx(
		PickupScript.hard_lifetime_seconds_for_source("bot_drop"),
		PickupScript.BOT_DROP_HARD_LIFETIME_SECONDS
	):
		return _fail("Bot death drops must have an absolute hard lifetime.")
	if not is_equal_approx(
		PickupScript.hard_lifetime_seconds_for_source("stage_wave"),
		PickupScript.STAGE_WAVE_HARD_LIFETIME_SECONDS
	):
		return _fail("Stage-wave pickups must have an absolute hard lifetime.")
	for permanent_source in ["initial_loot", "supply", "unknown", ""]:
		if PickupScript.lifetime_seconds_for_source(permanent_source) >= 0.0:
			return _fail("'%s' pickups must remain permanent for now." % permanent_source)

	var pickup_scene: PackedScene = load("res://src/entities/pickup/Pickup.tscn")
	var actor_script = load("res://src/entities/Entity.gd")
	if pickup_scene == null or actor_script == null:
		return _fail("Pickup or Entity runtime dependency could not be loaded.")

	var nearby_actor = actor_script.new()
	nearby_actor.set_process(false)
	nearby_actor.set_physics_process(false)
	root.add_child(nearby_actor)
	nearby_actor.global_position = Vector3.ZERO

	var proximity_pickup = _new_bot_drop_pickup(pickup_scene)
	proximity_pickup.global_position = Vector3(0.0, 0.0, 7.9)
	proximity_pickup.set("_lifetime_age_seconds", PickupScript.BOT_DROP_LIFETIME_SECONDS - 0.1)
	proximity_pickup.set("_lifetime_deadline_seconds", PickupScript.BOT_DROP_LIFETIME_SECONDS)
	proximity_pickup._update_lifetime(0.2)
	if proximity_pickup.is_queued_for_deletion():
		return _fail("A bot drop must not disappear beside a living actor.")
	if float(proximity_pickup.get("_lifetime_deadline_seconds")) \
			< float(proximity_pickup.get("_lifetime_age_seconds")) + PickupScript.BOT_DROP_HOLD_GRACE_SECONDS - 0.01:
		return _fail("Nearby living actor did not extend the bot-drop lifetime grace.")

	nearby_actor.is_dead = true
	proximity_pickup._update_lifetime(PickupScript.BOT_DROP_HOLD_GRACE_SECONDS + 0.1)
	if not proximity_pickup.is_queued_for_deletion():
		return _fail("Dead actors must not keep an expired bot drop alive.")

	var focused_pickup = _new_bot_drop_pickup(pickup_scene)
	focused_pickup.global_position = Vector3(20.0, 0.0, 20.0)
	focused_pickup.set("_lifetime_age_seconds", PickupScript.BOT_DROP_LIFETIME_SECONDS - 0.1)
	focused_pickup.set("_lifetime_deadline_seconds", PickupScript.BOT_DROP_LIFETIME_SECONDS)
	focused_pickup.set_focused(true)
	focused_pickup._update_lifetime(0.2)
	if focused_pickup.is_queued_for_deletion():
		return _fail("A focused bot drop must not disappear from under the reticle.")
	focused_pickup.set_focused(false)
	focused_pickup._update_lifetime(PickupScript.BOT_DROP_HOLD_GRACE_SECONDS + 0.1)
	if not focused_pickup.is_queued_for_deletion():
		return _fail("An unfocused expired bot drop must despawn after its grace.")

	var hard_cap_pickup = _new_bot_drop_pickup(pickup_scene)
	nearby_actor.is_dead = false
	hard_cap_pickup.global_position = Vector3(0.0, 0.0, 7.9)
	hard_cap_pickup.set(
		"_lifetime_age_seconds",
		PickupScript.BOT_DROP_HARD_LIFETIME_SECONDS - 0.1
	)
	hard_cap_pickup.set(
		"_lifetime_deadline_seconds",
		PickupScript.BOT_DROP_HARD_LIFETIME_SECONDS
	)
	hard_cap_pickup._update_lifetime(0.2)
	if not hard_cap_pickup.is_queued_for_deletion():
		return _fail("Nearby actors must not extend a bot drop beyond its hard lifetime.")

	var stage_hard_cap_pickup = _new_drop_pickup(pickup_scene, "stage_wave")
	stage_hard_cap_pickup.global_position = Vector3(0.0, 0.0, 7.9)
	stage_hard_cap_pickup.set(
		"_lifetime_age_seconds",
		PickupScript.STAGE_WAVE_HARD_LIFETIME_SECONDS - 0.1
	)
	stage_hard_cap_pickup.set(
		"_lifetime_deadline_seconds",
		PickupScript.STAGE_WAVE_HARD_LIFETIME_SECONDS
	)
	stage_hard_cap_pickup._update_lifetime(0.2)
	if not stage_hard_cap_pickup.is_queued_for_deletion():
		return _fail("Nearby actors must not extend a stage-wave pickup beyond its hard lifetime.")

	nearby_actor.queue_free()
	for _frame in range(2):
		await process_frame
	return true


func _new_bot_drop_pickup(pickup_scene: PackedScene):
	return _new_drop_pickup(pickup_scene, "bot_drop")


func _new_drop_pickup(pickup_scene: PackedScene, spawn_source: String):
	var item := ItemData.new()
	item.type = ItemData.Type.AMMO
	item.item_name = "TTL test ammo"
	item.ammo_weapon_type = "pistol"
	item.amount = 12
	var pickup = pickup_scene.instantiate()
	pickup.init(item, spawn_source)
	root.add_child(pickup)
	return pickup


func _fixed_hotspot() -> Dictionary:
	return {"pos": Vector2.ZERO, "rare_bias": 0.0}


func _fixed_loot_position(_hotspot: Dictionary) -> Vector2:
	return Vector2.ZERO


func _fail(message: String) -> bool:
	push_error(message)
	return false
