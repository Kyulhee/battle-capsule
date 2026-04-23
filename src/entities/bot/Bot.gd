extends Entity

const MUZZLE_FLASH_SCN = preload("res://src/fx/MuzzleFlash.tscn")
const BULLET_TRAIL_SCN = preload("res://src/fx/BulletTrail.tscn")

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

# Debug (set to false in production)
const DEBUG_PRINT = false

@onready var ray_cast = $RayCast3D

func _ready():
	# Entity._ready() handles stats.duplicate()
	super._ready()
	await get_tree().create_timer(randf_range(0.05, 0.2)).timeout
	if ray_cast:
		ray_cast.enabled = true
		ray_cast.add_exception(self)
		# Hit Layer 2 (Actors) and Layer 4 (High Obstacles)
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

# ─── PREFERRED ENGAGEMENT RANGE ──────────────────────────────────────────────
# Keep engage range INSIDE attack_range so the raycast actually hits.
# Shotgun: engage at 60% of attack_range. AR/Pistol: engage at 80%.
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

	var nearest_loot = _find_nearest_pickup()
	if nearest_loot:
		target_actor = nearest_loot
		is_targeting_loot = true
		change_state(State.CHASE)
		return

	# Move toward pre-announced supply zone only if idle and no other objective
	var main = get_tree().root.get_node_or_null("Main")
	if main and (main.supply_telegraphed or main.supply_spawned):
		if global_position.distance_to(main.supply_pos) < 35.0:
			var dir = (main.supply_pos - global_position).normalized()
			handle_movement(dir, delta, true)
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

	# Enter ATTACK when within preferred range
	var engage_dist = _get_preferred_range()
	if not is_targeting_loot and dist <= engage_dist:
		change_state(State.ATTACK); return

	var dir = (target_actor.global_position - global_position).normalized()
	dir.y = 0
	# Rotate to face movement direction
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z) + PI, stats.rotation_speed * delta)

	if is_targeting_loot:
		if dist > 1.5:
			handle_movement(dir, delta, false)
		else:
			if target_actor.has_method("collect"):
				target_actor.collect(self)
				if stats.current_ammo > 0:
					if has_node("/root/Telemetry"): get_node("/root/Telemetry").log_tactics("recovery_success")
			target_actor = null; is_targeting_loot = false; change_state(State.IDLE)
	else:
		handle_movement(dir, delta, false)

func handle_attack_state(delta):
	if not _is_target_valid(target_actor):
		target_actor = null; change_state(State.IDLE); return

	# Ammo check — exit BEFORE doing anything else
	if stats.current_ammo <= 0:
		if has_node("/root/Telemetry"):
			get_node("/root/Telemetry").log_tactics("ammo_empty")
		change_state(State.RECOVER); return

	# ── Vision & Prediction ───────────────────────────────────────────────
	var can_see = target_actor.is_revealed_to(self)
	if can_see:
		last_known_target_pos = target_actor.global_position
		# Reset state_timer for fresh LOS
		if state_timer > 0.1: state_timer = 0.0
	
	# If we can't see the target and the grace window (2.5s) is over, give up
	if not can_see and state_timer > 2.5:
		target_actor = null
		change_state(State.IDLE)
		return

	var dist = global_position.distance_to(last_known_target_pos)
	var pref_range = _get_preferred_range()

	# Zone urgency override
	var main = get_tree().root.get_node_or_null("Main")
	if main:
		var zone_dist = Vector2(global_position.x, global_position.z).distance_to(main.current_zone_center)
		if zone_dist > main.current_zone_radius * 0.9:
			change_state(State.ZONE_ESCAPE); return

	# Always face the target position (actual or last known)
	var dir_to_target = (last_known_target_pos - global_position).normalized()
	rotation.y = lerp_angle(rotation.y, atan2(dir_to_target.x, dir_to_target.z) + PI, stats.rotation_speed * delta)

	# Movement: Maintain distance relative to target/last known pos
	var strafe = Vector3(-dir_to_target.z, 0, dir_to_target.x) * sin(state_timer * 2.5)
	if dist > pref_range * 1.2:
		handle_movement(dir_to_target + strafe * 0.4, delta, false)
	elif dist < pref_range * 0.5:
		handle_movement(-dir_to_target + strafe * 0.4, delta, false)
	else:
		handle_movement(strafe, delta, false)

	# Shoot when cooldown is ready
	if fire_cooldown <= 0:
		# If we don't have LOS, apply suppressive fire (blind fire with spread)
		if not can_see:
			shoot_predictive(last_known_target_pos)
		else:
			shoot()

func handle_recover_state(delta):
	recovery_timer += delta
	var nearest_enemy = _find_nearest_target()

	if recovery_substate == "seek_cover":
		if not nearest_enemy or recovery_timer > 3.0:
			recovery_substate = "seek_loot"; recovery_timer = 0.0; return
		var escape_dir = (global_position - nearest_enemy.global_position).normalized()
		handle_movement(escape_dir, delta, true)

	elif recovery_substate == "seek_loot":
		var loot = _find_nearest_pickup()
		if loot:
			target_actor = loot; is_targeting_loot = true; change_state(State.CHASE)
			if has_node("/root/Telemetry"):
				get_node("/root/Telemetry").log_tactics("recovery_start")
		elif recovery_timer > 5.0:
			change_state(State.IDLE)

func handle_zone_escape_state(delta):
	var main = get_tree().root.get_node_or_null("Main")
	if not main: change_state(State.IDLE); return
	var target_pos = Vector3(main.current_zone_center.x, global_position.y, main.current_zone_center.y)
	var dir = (target_pos - global_position).normalized()
	handle_movement(dir, delta, true)
	if global_position.distance_to(target_pos) < main.current_zone_radius * 0.75:
		change_state(State.IDLE)

func _check_state_overrides(_delta):
	var main = get_tree().root.get_node_or_null("Main")
	if not main: return
	var dist = Vector2(global_position.x, global_position.z).distance_to(main.current_zone_center)
	if dist > main.current_zone_radius and current_state != State.ZONE_ESCAPE:
		change_state(State.ZONE_ESCAPE)

# ─── HELPERS ─────────────────────────────────────────────────────────────────
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

func _find_nearest_pickup() -> Node3D:
	var pickups = get_tree().get_nodes_in_group("pickups")
	var nearest: Node3D = null
	var min_dist = 35.0
	for p in pickups:
		var d = global_position.distance_to(p.global_position)
		if d < min_dist: min_dist = d; nearest = p
	return nearest

func _is_target_valid(t: Variant) -> bool:
	return is_instance_valid(t) and (not t is Entity or not t.is_dead)

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
	# Fire forward in LOCAL space — range must be <= attack_range
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
	
	# Add increasing spread over time while out of LOS
	var base_spread = 0.1
	var spread_growth = state_timer * 0.4 # Grows to ~1.0 spread over 2.5s
	var total_spread = base_spread + spread_growth
	
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

# ─── STATE MACHINE ────────────────────────────────────────────────────────────
func change_state(new_state: State):
	if current_state == new_state: return
	if DEBUG_PRINT:
		print("[BOT] %s → %s (ammo=%d hp=%.0f)" % [
			State.keys()[current_state], State.keys()[new_state],
			stats.current_ammo, current_health
		])
	current_state = new_state
	state_timer = 0.0
	if new_state == State.RECOVER:
		recovery_substate = "seek_cover"
		recovery_timer = 0.0
