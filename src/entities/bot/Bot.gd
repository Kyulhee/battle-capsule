extends Entity

const MUZZLE_FLASH_SCN = preload("res://src/fx/MuzzleFlash.tscn")
const BULLET_TRAIL_SCN = preload("res://src/fx/BulletTrail.tscn")
const PICKUP_SCN       = preload("res://src/entities/pickup/Pickup.tscn")

enum State { IDLE, CHASE, ATTACK, ZONE_ESCAPE, RECOVER }
var current_state: State = State.IDLE
var target_actor: Node3D = null

var state_timer: float = 0.0
var attack_bout_timer: float = 0.0
var is_targeting_loot: bool = false
var scan_timer: float = 0.0
var scan_target_rotation: float = 0.0
var fire_cooldown: float = 0.0
var last_known_target_pos: Vector3 = Vector3.ZERO

# Recovery
var recovery_substate: String = "seek_cover"
var recovery_timer: float = 0.0
var patrol_target: Vector3 = Vector3.ZERO

# Reserve ammo: filled by ammo pickups, drained on reload
var reserve_ammo: int = 0

# Stuck detection
var _stuck_timer: float = 0.0
var _stuck_override_dir: Vector3 = Vector3.ZERO
var _stuck_override_timer: float = 0.0

const DEBUG_PRINT = false

@onready var ray_cast = $RayCast3D

func _ready():
	super._ready()
	await get_tree().create_timer(randf_range(0.05, 0.2)).timeout
	if ray_cast:
		ray_cast.enabled = true
		ray_cast.add_exception(self)
		ray_cast.collision_mask = 2 | 8

func _physics_process(delta):
	if is_dead: return
	if fire_cooldown > 0: fire_cooldown -= delta
	state_timer += delta

	if current_state == State.ATTACK:
		attack_bout_timer += delta
	elif attack_bout_timer > 0:
		if has_node("/root/Telemetry"):
			get_node("/root/Telemetry").log_combat_audit("attack_max_continuous", attack_bout_timer)
		attack_bout_timer = 0.0

	if current_health < 60.0 and stats.heal_items > 0:
		use_heal()

	_check_state_overrides(delta)
	_update_stuck(delta)

	match current_state:
		State.IDLE:        handle_idle_state(delta)
		State.CHASE:       handle_chase_state(delta)
		State.ATTACK:      handle_attack_state(delta)
		State.ZONE_ESCAPE: handle_zone_escape_state(delta)
		State.RECOVER:     handle_recover_state(delta)

	super._physics_process(delta)

func use_heal():
	stats.heal_items -= 1
	current_health = min(stats.max_health, current_health + 40.0)
	health_changed.emit(current_health, stats.max_health)
	if has_node("/root/Telemetry"):
		get_node("/root/Telemetry").log_economy("heals_used")

# ─── AMMO ────────────────────────────────────────────────────────────────────

func receive_ammo(weapon_type: String, amount: int):
	if weapon_type == "" or weapon_type == stats.weapon_type:
		reserve_ammo = min(stats.max_ammo, reserve_ammo + amount)

func _try_reload():
	if reserve_ammo <= 0: return
	var space = stats.max_ammo - stats.current_ammo
	if space <= 0: return
	var transfer = min(reserve_ammo, space)
	stats.current_ammo += transfer
	reserve_ammo -= transfer

# ─── STUCK DETECTION ─────────────────────────────────────────────────────────
# If the bot tries to move but barely travels, inject a short perpendicular
# burst to dislodge it from walls. Each bot gets a unique deflection side
# based on its instance ID so multiple stuck bots scatter in different directions.

func _update_stuck(delta):
	if _stuck_override_timer > 0:
		_stuck_override_timer -= delta
		return

	var is_moving_state = current_state in [State.CHASE, State.RECOVER, State.ZONE_ESCAPE]
	if not is_moving_state:
		_stuck_timer = 0.0
		return

	if Vector2(velocity.x, velocity.z).length() < 0.35:
		_stuck_timer += delta
		if _stuck_timer >= 1.0:
			var fwd = Vector3(sin(rotation.y), 0, cos(rotation.y))
			var side = 1.0 if get_instance_id() % 2 == 0 else -1.0
			_stuck_override_dir = Vector3(-fwd.z * side, 0, fwd.x * side).normalized()
			_stuck_override_timer = 0.65
			_stuck_timer = 0.0
	else:
		_stuck_timer = 0.0

# Replaces direct handle_movement calls in movement states.
# Applies the stuck override direction when active.
func _move_or_unstick(desired_dir: Vector3, delta: float, should_rotate: bool = true):
	if _stuck_override_timer > 0:
		handle_movement(_stuck_override_dir, delta, should_rotate)
	else:
		handle_movement(desired_dir, delta, should_rotate)

# ─── PREFERRED ENGAGEMENT RANGE ──────────────────────────────────────────────
func _get_preferred_range() -> float:
	if stats.weapon_type == "shotgun":
		return stats.attack_range * 0.6
	return stats.attack_range * 0.8

# ─── STATE HANDLERS ──────────────────────────────────────────────────────────

func handle_idle_state(delta):
	scan_timer -= delta
	if scan_timer <= 0:
		scan_timer = randf_range(1.0, 3.0)
		scan_target_rotation = rotation.y + randf_range(-PI, PI)
	rotation.y = lerp_angle(rotation.y, scan_target_rotation, stats.rotation_speed * 0.5 * delta)

	var nearest_enemy = _find_nearest_target()
	if nearest_enemy:
		target_actor = nearest_enemy
		if stats.current_ammo > 0:
			change_state(State.CHASE)
		else:
			change_state(State.RECOVER)
		return

	var nearest_loot = _find_nearest_pickup(35.0)
	if nearest_loot:
		target_actor = nearest_loot
		is_targeting_loot = true
		change_state(State.CHASE)
		return

	var main = get_tree().root.get_node_or_null("Main")
	if main and (main.supply_telegraphed or main.supply_spawned):
		if global_position.distance_to(main.supply_pos) < 35.0:
			var dir = (main.supply_pos - global_position).normalized()
			_move_or_unstick(dir, delta, true)
			if has_node("/root/Telemetry") and state_timer < 0.1:
				get_node("/root/Telemetry").log_supply_event("preannounce_interest")

func handle_chase_state(delta):
	if not _is_target_valid(target_actor):
		target_actor = null; is_targeting_loot = false; change_state(State.IDLE); return

	var dist = global_position.distance_to(target_actor.global_position)

	if stats.current_ammo <= 0 and not is_targeting_loot:
		if has_node("/root/Telemetry"):
			get_node("/root/Telemetry").log_tactics("ammo_empty")
		change_state(State.RECOVER); return

	var engage_dist = _get_preferred_range()
	if not is_targeting_loot and dist <= engage_dist:
		change_state(State.ATTACK); return

	var dir = (target_actor.global_position - global_position).normalized()
	dir.y = 0
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z) + PI, stats.rotation_speed * delta)

	if is_targeting_loot:
		if dist > 1.5:
			_move_or_unstick(dir, delta, false)
		else:
			if target_actor.has_method("collect"):
				target_actor.collect(self)
				_try_reload()
				if stats.current_ammo > 0:
					if has_node("/root/Telemetry"): get_node("/root/Telemetry").log_tactics("recovery_success")
			target_actor = null; is_targeting_loot = false; change_state(State.IDLE)
	else:
		_move_or_unstick(dir, delta, false)

func handle_attack_state(delta):
	if not _is_target_valid(target_actor):
		target_actor = null; change_state(State.IDLE); return

	if stats.current_ammo <= 0:
		if has_node("/root/Telemetry"):
			get_node("/root/Telemetry").log_tactics("ammo_empty")
		change_state(State.RECOVER); return

	var can_see = target_actor.is_revealed_to(self)
	if can_see:
		last_known_target_pos = target_actor.global_position
		if state_timer > 0.1: state_timer = 0.0

	if not can_see and state_timer > 2.5:
		target_actor = null
		change_state(State.IDLE)
		return

	var dist = global_position.distance_to(last_known_target_pos)
	var pref_range = _get_preferred_range()

	var main = get_tree().root.get_node_or_null("Main")
	if main:
		var zone_dist = Vector2(global_position.x, global_position.z).distance_to(main.current_zone_center)
		if zone_dist > main.current_zone_radius * 0.9:
			change_state(State.ZONE_ESCAPE); return

	var dir_to_target = (last_known_target_pos - global_position).normalized()
	rotation.y = lerp_angle(rotation.y, atan2(dir_to_target.x, dir_to_target.z) + PI, stats.rotation_speed * delta)

	var strafe = Vector3(-dir_to_target.z, 0, dir_to_target.x) * sin(state_timer * 2.5)
	if dist > pref_range * 1.2:
		_move_or_unstick(dir_to_target + strafe * 0.4, delta, false)
	elif dist < pref_range * 0.5:
		_move_or_unstick(-dir_to_target + strafe * 0.4, delta, false)
	else:
		_move_or_unstick(strafe, delta, false)

	if fire_cooldown <= 0:
		if not can_see:
			shoot_predictive(last_known_target_pos)
		else:
			shoot()

func handle_recover_state(delta):
	recovery_timer += delta
	var nearest_enemy = _find_nearest_target()

	if recovery_substate == "seek_cover":
		# Sprint away from threat using an instance-unique scatter direction.
		# After 2.5 s (or immediately if no threat visible), widen search.
		if not nearest_enemy or recovery_timer > 2.5:
			recovery_substate = "seek_loot"
			recovery_timer = 0.0
			return
		var scatter = _scatter_dir_from(nearest_enemy.global_position)
		_move_or_unstick(scatter, delta, true)

	elif recovery_substate == "seek_loot":
		# Wider search radius when actively looking for ammo
		var loot = _find_nearest_pickup(70.0)
		if loot:
			target_actor = loot
			is_targeting_loot = true
			change_state(State.CHASE)
			if has_node("/root/Telemetry"):
				get_node("/root/Telemetry").log_tactics("recovery_start")
		elif recovery_timer > 4.0:
			recovery_substate = "patrol"
			recovery_timer = 0.0
			patrol_target = _random_zone_point()

	elif recovery_substate == "patrol":
		# Wander to a random zone point until loot appears or timeout
		var loot = _find_nearest_pickup(70.0)
		if loot:
			target_actor = loot
			is_targeting_loot = true
			change_state(State.CHASE)
			return

		var dist_to_patrol = global_position.distance_to(patrol_target)
		if dist_to_patrol > 2.5:
			var dir = (patrol_target - global_position).normalized()
			dir.y = 0
			_move_or_unstick(dir, delta, true)
		else:
			patrol_target = _random_zone_point()

		if recovery_timer > 8.0:
			change_state(State.IDLE)

func handle_zone_escape_state(delta):
	var main = get_tree().root.get_node_or_null("Main")
	if not main: change_state(State.IDLE); return
	var target_pos = Vector3(main.current_zone_center.x, global_position.y, main.current_zone_center.y)
	var dir = (target_pos - global_position).normalized()
	_move_or_unstick(dir, delta, true)
	if global_position.distance_to(target_pos) < main.current_zone_radius * 0.75:
		change_state(State.IDLE)

func _check_state_overrides(_delta):
	var main = get_tree().root.get_node_or_null("Main")
	if not main: return
	var dist = Vector2(global_position.x, global_position.z).distance_to(main.current_zone_center)
	if dist > main.current_zone_radius and current_state != State.ZONE_ESCAPE:
		change_state(State.ZONE_ESCAPE)

# ─── HELPERS ─────────────────────────────────────────────────────────────────

# Each bot rotates the "away" vector by a unique 45° sector so groups of
# out-of-ammo bots scatter to 8 different directions instead of piling on one wall.
func _scatter_dir_from(threat_pos: Vector3) -> Vector3:
	var away = global_position - threat_pos
	away.y = 0
	if away.length() < 0.1:
		away = Vector3(1, 0, 0)
	away = away.normalized()
	var angle = (get_instance_id() % 8) * (PI / 4.0)
	return Vector3(
		away.x * cos(angle) - away.z * sin(angle),
		0,
		away.x * sin(angle) + away.z * cos(angle)
	).normalized()

func _random_zone_point() -> Vector3:
	var main = get_tree().root.get_node_or_null("Main")
	var cx: float = 0.0
	var cz: float = 0.0
	var r: float = 30.0
	if main:
		cx = main.current_zone_center.x
		cz = main.current_zone_center.y
		r = main.current_zone_radius * 0.8
	var angle = randf() * TAU
	var dist  = randf() * r
	return Vector3(cx + cos(angle) * dist, global_position.y, cz + sin(angle) * dist)

func _find_nearest_target() -> Entity:
	var actors = get_tree().get_nodes_in_group("actors")
	var nearest: Entity = null
	var min_dist = stats.vision_range
	for a in actors:
		if a == self or not a is Entity or a.is_dead: continue
		if a.is_revealed_to(self):
			var d = global_position.distance_to(a.global_position)
			if d < min_dist: min_dist = d; nearest = a
	return nearest

func _find_nearest_pickup(search_radius: float = 35.0) -> Node3D:
	var pickups = get_tree().get_nodes_in_group("pickups")
	var nearest: Node3D = null
	var min_dist = search_radius
	for p in pickups:
		var d = global_position.distance_to(p.global_position)
		if d < min_dist: min_dist = d; nearest = p
	return nearest

func _is_target_valid(t: Variant) -> bool:
	return is_instance_valid(t) and (not t is Entity or not t.is_dead)

# ─── DEATH & WEAPON DROP ─────────────────────────────────────────────────────

func die(killer: Node3D = null):
	_drop_weapon()
	super.die(killer)

func _drop_weapon():
	if stats.weapon_type == "" or stats.weapon_type == "knife": return
	if not PICKUP_SCN: return
	var item = ItemData.new()
	item.type = ItemData.Type.WEAPON
	item.rarity = ItemData.Rarity.COMMON
	item.item_name = _weapon_display_name(stats.weapon_type)
	item.color = _weapon_color(stats.weapon_type)
	var wstats = stats.duplicate() as StatsData
	wstats.current_ammo = stats.current_ammo
	item.weapon_stats = wstats
	var pickup = PICKUP_SCN.instantiate()
	get_tree().root.add_child(pickup)
	pickup.global_position = global_position + Vector3(randf_range(-0.5, 0.5), 0.3, randf_range(-0.5, 0.5))
	pickup.init(item)

func _weapon_display_name(wtype: String) -> String:
	match wtype:
		"pistol":  return "Pistol"
		"ar":      return "Assault Rifle"
		"shotgun": return "Shotgun"
		"railgun": return "Railgun"
	return wtype.capitalize()

func _weapon_color(wtype: String) -> Color:
	match wtype:
		"pistol":  return Color(0.55, 0.78, 1.0)
		"ar":      return Color(0.2, 0.88, 0.35)
		"shotgun": return Color(1.0, 0.6, 0.1)
		"railgun": return Color(0.85, 0.2, 1.0)
	return Color.WHITE

# ─── DAMAGE OVERRIDE ─────────────────────────────────────────────────────────
# Force immediate RECOVER when hit with no ammo left — prevents bots from
# standing still against a player while out of ammo.

func take_damage(amount: float, source: String = "gun", weapon_type: String = "", source_node: Node3D = null):
	super.take_damage(amount, source, weapon_type, source_node)
	if is_dead: return
	if stats.current_ammo <= 0 and reserve_ammo <= 0:
		if current_state != State.RECOVER and current_state != State.ZONE_ESCAPE:
			change_state(State.RECOVER)

# ─── COMBAT ──────────────────────────────────────────────────────────────────

func shoot():
	if stats.current_ammo <= 0: return
	if has_node("/root/Telemetry"):
		get_node("/root/Telemetry").log_shot()
	if stats.weapon_type == "shotgun":
		stats.current_ammo -= 1
		for i in range(max(1, stats.pellet_count)):
			shoot_pellet(i)
		fire_cooldown = stats.fire_rate
	else:
		_internal_single_shot()

func _internal_single_shot():
	stats.current_ammo -= 1
	fire_cooldown = stats.fire_rate
	reveal()
	if MUZZLE_FLASH_SCN:
		var flash = MUZZLE_FLASH_SCN.instantiate()
		add_child(flash)
		flash.position = Vector3(0, 0.5, -0.5)
	_cast_and_visualize(Vector3(0, 0.1, -stats.attack_range))

func shoot_predictive(target_pos: Vector3):
	if stats.current_ammo <= 0: return
	stats.current_ammo -= 1
	fire_cooldown = stats.fire_rate
	reveal()
	if MUZZLE_FLASH_SCN:
		var flash = MUZZLE_FLASH_SCN.instantiate()
		add_child(flash)
		flash.position = Vector3(0, 0.5, -0.5)
	var base_spread = 0.1
	var total_spread = base_spread + state_timer * 0.4
	var local_dir = Vector3(
		randf_range(-total_spread, total_spread),
		randf_range(-total_spread * 0.2, total_spread * 0.2),
		-1.0
	).normalized() * stats.attack_range
	_cast_and_visualize(local_dir)

func shoot_pellet(_idx: int):
	reveal()
	var spread = 0.2
	var local_dir = Vector3(
		randf_range(-spread, spread),
		randf_range(-spread * 0.3, spread * 0.3),
		-1.0
	).normalized() * stats.attack_range
	_cast_and_visualize(local_dir)

func _cast_and_visualize(local_target_pos: Vector3):
	if not ray_cast: return
	ray_cast.target_position = local_target_pos
	ray_cast.force_raycast_update()
	var world_target = global_position + global_transform.basis * local_target_pos
	if ray_cast.is_colliding():
		var hit = ray_cast.get_collider()
		world_target = ray_cast.get_collision_point()
		if hit.has_method("take_damage"):
			hit.take_damage(stats.attack_damage, "gun", stats.weapon_type, self)
	if BULLET_TRAIL_SCN:
		var trail = BULLET_TRAIL_SCN.instantiate()
		get_tree().root.add_child(trail)
		trail.init(global_position + Vector3(0, 0.5, 0), world_target)

# ─── STATE MACHINE ───────────────────────────────────────────────────────────

func change_state(new_state: State):
	if current_state == new_state: return
	if DEBUG_PRINT:
		print("[BOT] %s → %s (ammo=%d reserve=%d hp=%.0f)" % [
			State.keys()[current_state], State.keys()[new_state],
			stats.current_ammo, reserve_ammo, current_health
		])
	current_state = new_state
	state_timer = 0.0
	if new_state == State.RECOVER:
		# If reserve ammo is available, reload on the spot and skip RECOVER entirely
		if reserve_ammo > 0:
			_try_reload()
			current_state = State.IDLE
			state_timer = 0.0
			return
		recovery_substate = "seek_cover"
		recovery_timer = 0.0
		patrol_target = Vector3.ZERO
