class_name PressureEffectApplier
extends RefCounted

const PressureEffectCatalogScript = preload("res://src/core/PressureEffectCatalog.gd")

static func apply(effects: Array, context: Dictionary) -> Dictionary:
	var player = context.get("player")
	if not is_instance_valid(player):
		return {}
	var zone = context.get("zone")
	var actors: Array = context.get("actors", [])
	var updates: Dictionary = {}
	for effect in effects:
		if not effect.has("type"):
			continue
		var effect_type = int(effect["type"])
		if not PressureEffectCatalogScript.is_known_type(effect_type):
			push_warning("PressureEffectApplier: unknown effect type %d" % effect_type)
			continue
		match effect_type:
			PressureEffectCatalogScript.AMMO_REFILL:
				player.slots.fill_all_ammo()
			PressureEffectCatalogScript.AMMO_CLEAR:
				player.slots.clear_all_ammo()
			PressureEffectCatalogScript.AMMO_ACTIVE_CLEAR:
				player.slots.clear_active_ammo()
			PressureEffectCatalogScript.HP_RESTORE:
				_apply_hp_restore(player, effect)
			PressureEffectCatalogScript.HP_DAMAGE:
				_apply_hp_damage(player, effect)
			PressureEffectCatalogScript.SHIELD_ADD:
				_apply_shield_add(player, effect)
			PressureEffectCatalogScript.HEAL_ADD:
				player.stats.heal_items += int(effect.get("count", 1))
				player._update_hud()
			PressureEffectCatalogScript.HEAL_CLEAR:
				player.stats.heal_items = 0
				player.stats.advanced_heals = 0
				player._update_hud()
			PressureEffectCatalogScript.HEAL_PICKUP_BAN:
				updates["heal_pickup_banned"] = true
				updates["heal_ban_until_stage"] = int(zone.stage) + 1 if zone else 1
			PressureEffectCatalogScript.ALL_BOTS_DETECT:
				_reveal_player_to_bots(player, actors)
			PressureEffectCatalogScript.BOT_AGGRO:
				_aggro_nearest_bot(player, actors)
			PressureEffectCatalogScript.ZONE_EXTEND:
				if zone:
					zone.timer += zone.wait_time * (float(effect.get("mult", 1.0)) - 1.0)
			PressureEffectCatalogScript.RAILGUN_UNLIMITED:
				updates["railgun_unlimited_until_stage"] = int(zone.stage) + int(effect.get("stages", 1)) if zone else int(effect.get("stages", 1))
	return updates

static func _apply_hp_restore(player, effect: Dictionary) -> void:
	if effect.get("full", false):
		player.current_health = player.stats.max_health
	else:
		player.current_health = min(
			player.stats.max_health,
			player.current_health + float(effect.get("amount", 30.0))
		)
	player.health_changed.emit(player.current_health, player.stats.max_health)

static func _apply_hp_damage(player, effect: Dictionary) -> void:
	var amount = float(effect.get("amount", 20.0))
	var fraction = float(effect.get("fraction", 0.0))
	if fraction > 0.0:
		amount = player.current_health * fraction
	player.current_health = max(1.0, player.current_health - amount)
	player.health_changed.emit(player.current_health, player.stats.max_health)

static func _apply_shield_add(player, effect: Dictionary) -> void:
	player.current_shield = min(
		player.stats.max_shield,
		player.current_shield + float(effect.get("amount", 50.0))
	)
	player.shield_changed.emit(player.current_shield, player.stats.max_shield)

static func _reveal_player_to_bots(player, actors: Array) -> void:
	for actor in actors:
		if _is_active_bot(actor):
			actor.perception_meters[player] = 1.0

static func _aggro_nearest_bot(player, actors: Array) -> void:
	var nearest = null
	var nearest_dist = INF
	for actor in actors:
		if not _is_active_bot(actor):
			continue
		var dist = actor.global_position.distance_to(player.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = actor
	if nearest and nearest.has_method("handle_idle_state"):
		nearest.target_actor = player
		nearest.is_targeting_loot = false
		nearest.last_known_target_pos = player.global_position
		nearest.current_state = nearest.State.CHASE

static func _is_active_bot(actor) -> bool:
	return is_instance_valid(actor) \
		and not actor.is_in_group("players") \
		and not actor.is_dead
