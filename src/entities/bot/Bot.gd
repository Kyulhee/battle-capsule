extends Entity

const MUZZLE_FLASH_SCN   = preload("res://src/fx/MuzzleFlash.tscn")
const BULLET_TRAIL_SCN   = preload("res://src/fx/BulletTrail.tscn")
const PICKUP_SCN         = preload("res://src/entities/pickup/Pickup.tscn")
const IMPACT_EFFECT_SCN  = preload("res://src/fx/ImpactEffect.tscn")

const MELEE_RANGE: float  = 1.8
const MELEE_DAMAGE: float = 20.0

enum State { IDLE, CHASE, ATTACK, ZONE_ESCAPE, RECOVER, DISENGAGE }
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

# True only when loot chase was triggered from RECOVER state (not IDLE opportunistic looting)
var _recovering: bool = false
# True when bot decided to rush with knife instead of retreating to RECOVER
var _knife_mode: bool = false
# Cover target used in DISENGAGE state
var _disengage_cover: Vector3 = Vector3.ZERO
# Cooldown after leaving DISENGAGE — prevents re-entry cascade
var _disengage_cooldown: float = 0.0
var _combat_loot_radius: float = 15.0

# Stuck detection
var _stuck_timer: float = 0.0
var _stuck_override_dir: Vector3 = Vector3.ZERO
var _stuck_override_timer: float = 0.0

# Zone tracking
var _zone_outside_timer: float = 0.0  # continuous seconds spent outside zone
var _zone_thrash_cooldown: float = 0.0  # throttle random thrash bursts in ZONE_ESCAPE

const DEBUG_PRINT = false

var _state_label: Label3D = null

# ─── PERSONALITY ─────────────────────────────────────────────────────────────
enum Personality { AGGRESSIVE, DEFENSIVE, SCAVENGER }
var personality: Personality = Personality.AGGRESSIVE
var _disengage_threshold: int = 2  # visible enemies needed to trigger DISENGAGE
var _fire_rate_mult: float = 1.0   # multiplier applied to fire_cooldown post-shot when allies attack same target
var _footstep_range: float = 12.0  # radius to hear running actors
var _loot_radius: float = 70.0     # pickup search radius in RECOVER
var _combat_loot_threshold: float = 0.0  # ammo ratio below which bot breaks combat to grab nearby loot
var _flee_hp_ratio: float = 0.25         # HP ratio below which bot exits combat to RECOVER

# ─── DIFFICULTY ──────────────────────────────────────────────────────────────
var _reaction_delay: float = 0.0   # seconds between spotting and reacting
var _pending_target: Entity = null
var _reaction_timer: float = 0.0
var _aim_spread_mult: float = 1.0  # multiplier for predictive-shot spread
# 0=none 1=periodic scan(3s) 2=periodic scan(1.5s)+instant reaction on hit
var _awareness_level: int = 0
var _peripheral_scan_timer: float = 0.0
var _combat_jump_timer: float = 0.0
var _nav_agent: NavigationAgent3D = null

@onready var ray_cast = $RayCast3D

func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE
	super._ready()
	add_to_group("bots")
	_apply_personality([Personality.AGGRESSIVE, Personality.DEFENSIVE, Personality.SCAVENGER][randi() % 3])
	died.connect(_on_died_zone_log)
	_state_label = Label3D.new()
	_state_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_state_label.double_sided = true
	_state_label.font_size = 52
	_state_label.pixel_size = 0.006
	_state_label.outline_size = 10
	_state_label.position = Vector3(0, 2.4, 0)
	_state_label.visible = false
	add_child(_state_label)
	_nav_agent = NavigationAgent3D.new()
	_nav_agent.path_desired_distance = 0.5
	_nav_agent.target_desired_distance = 1.5
	_nav_agent.avoidance_enabled = false
	add_child(_nav_agent)
	await get_tree().create_timer(randf_range(0.05, 0.2)).timeout
	if ray_cast:
		ray_cast.enabled = true
		ray_cast.add_exception(self)
		ray_cast.collision_mask = 2 | 8

func _on_died_zone_log():
	if _zone_outside_timer > 0.5 and has_node("/root/Telemetry"):
		var state_name = State.keys()[current_state]
		get_node("/root/Telemetry").log_zone_death(state_name, _zone_outside_timer)

func _physics_process(delta):
	if is_dead: return
	if fire_cooldown > 0: fire_cooldown -= delta
	if _disengage_cooldown > 0: _disengage_cooldown -= delta
	if _reaction_timer > 0: _reaction_timer -= delta
	if _zone_thrash_cooldown > 0: _zone_thrash_cooldown -= delta
	state_timer += delta

	if current_state == State.ATTACK:
		attack_bout_timer += delta
	elif attack_bout_timer > 0:
		if has_node("/root/Telemetry"):
			get_node("/root/Telemetry").log_combat_audit("attack_max_continuous", attack_bout_timer)
		attack_bout_timer = 0.0

	if current_health < 60.0 and (stats.heal_items > 0 or stats.advanced_heals > 0):
		use_heal()

	_check_state_overrides(delta)
	_check_survival_overrides()
	_update_stuck(delta)
	_check_footstep_sounds()
	_update_state_label_visibility()

	match current_state:
		State.IDLE:        handle_idle_state(delta)
		State.CHASE:       handle_chase_state(delta)
		State.ATTACK:      handle_attack_state(delta)
		State.ZONE_ESCAPE: handle_zone_escape_state(delta)
		State.RECOVER:     handle_recover_state(delta)
		State.DISENGAGE:   handle_disengage_state(delta)

	super._physics_process(delta)

func use_heal():
	if stats.advanced_heals > 0:
		stats.advanced_heals -= 1
		current_health = min(stats.max_health, current_health + 60.0)
	elif stats.heal_items > 0:
		stats.heal_items -= 1
		current_health = min(stats.max_health, current_health + 30.0)
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

	var is_moving_state = current_state in [State.CHASE, State.RECOVER, State.ZONE_ESCAPE, State.DISENGAGE]
	if not is_moving_state:
		_stuck_timer = 0.0
		return

	if Vector2(velocity.x, velocity.z).length() < 0.35:
		_stuck_timer += delta
		if _stuck_timer >= 1.0:
			var fwd = Vector3(sin(rotation.y), 0, cos(rotation.y))
			var angle = randf_range(-PI * 0.75, PI * 0.75)
			_stuck_override_dir = Vector3(
				fwd.x * cos(angle) - fwd.z * sin(angle),
				0,
				fwd.x * sin(angle) + fwd.z * cos(angle)
			).normalized()
			_stuck_override_timer = 1.2
			_stuck_timer = 0.0
			if has_node("/root/Telemetry"):
				get_node("/root/Telemetry").log_tactics("stuck_triggered")
	else:
		_stuck_timer = 0.0

# Replaces direct handle_movement calls in movement states.
# Applies the stuck override direction when active.
func _move_or_unstick(desired_dir: Vector3, delta: float, should_rotate: bool = true):
	if _stuck_override_timer > 0:
		handle_movement(_stuck_override_dir, delta, should_rotate)
	else:
		handle_movement(desired_dir, delta, should_rotate)

# Navigate to target_pos via navmesh. Falls back to direct _move_or_unstick if no path.
func _nav_move_toward(target_pos: Vector3, delta: float, should_rotate: bool = true):
	var fallback = target_pos - global_position
	fallback.y = 0
	if fallback.length() < 0.05: return
	if _nav_agent:
		_nav_agent.set_target_position(target_pos)
		if not _nav_agent.is_navigation_finished():
			var next_pos = _nav_agent.get_next_path_position()
			var nav_dir = next_pos - global_position
			nav_dir.y = 0
			if nav_dir.length() > 0.05:
				handle_movement(nav_dir.normalized(), delta, should_rotate)
				return
	_move_or_unstick(fallback.normalized(), delta, should_rotate)

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
		if nearest_enemy != _pending_target:
			_pending_target = nearest_enemy
			_reaction_timer = _reaction_delay
		elif _reaction_timer <= 0:
			target_actor = _pending_target
			_pending_target = null
			if stats.current_ammo > 0:
				change_state(State.CHASE)
			else:
				change_state(State.RECOVER)
		return
	if _pending_target != null:
		_pending_target = null

	# Wounded bots use priority-scored pickup (heals first); healthy bots use nearest
	var nearest_loot: Node3D = null
	if current_health / stats.max_health < 0.5:
		nearest_loot = _find_best_pickup(55.0)  # wider range, scores heals highest
	else:
		nearest_loot = _find_nearest_pickup(35.0)
	if nearest_loot:
		var loot_dist = global_position.distance_to(nearest_loot.global_position)
		if loot_dist <= 2.5 and nearest_loot.has_method("collect"):
			nearest_loot.collect(self)
			_try_reload()
		else:
			target_actor = nearest_loot
			is_targeting_loot = true
			_recovering = false
			change_state(State.CHASE)
		return

	var main = get_tree().root.get_node_or_null("Main")
	if main and (main.supply_telegraphed or main.supply_spawned):
		var supply_range = 70.0 if personality == Personality.SCAVENGER else 50.0
		if global_position.distance_to(main.supply_pos) < supply_range:
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
		# Give up if stuck chasing loot too long — switch to a different target
		if state_timer > 5.0:
			var alt = _find_best_pickup(_loot_radius)
			if is_instance_valid(alt) and alt != target_actor:
				target_actor = alt; state_timer = 0.0
			else:
				target_actor = null; is_targeting_loot = false; _recovering = false
				change_state(State.IDLE)
			return
		if dist > 2.5:
			_nav_move_toward(target_actor.global_position, delta, false)
		else:
			if target_actor.has_method("collect"):
				target_actor.collect(self)
				_try_reload()
				if _recovering and stats.current_ammo > 0:
					if has_node("/root/Telemetry"): get_node("/root/Telemetry").log_tactics("recovery_success")
			target_actor = null; is_targeting_loot = false; _recovering = false; change_state(State.IDLE)
	else:
		_nav_move_toward(target_actor.global_position, delta, false)

func handle_attack_state(delta):
	if not _is_target_valid(target_actor):
		_knife_mode = false; target_actor = null; change_state(State.IDLE); return

	# Peripheral awareness: periodic scan for third-party threats
	if _awareness_level >= 1:
		_peripheral_scan_timer -= delta
		if _peripheral_scan_timer <= 0:
			_peripheral_scan_timer = 3.0 if _awareness_level == 1 else 1.5
			_peripheral_check()

	# Knife rush mode: charge and melee instead of retreating
	if _knife_mode:
		if current_health / stats.max_health < 0.25:
			_knife_mode = false; change_state(State.RECOVER); return
		var dir_to = (target_actor.global_position - global_position).normalized()
		dir_to.y = 0
		_move_or_unstick(dir_to, delta, true)
		rotation.y = lerp_angle(rotation.y, atan2(dir_to.x, dir_to.z) + PI, stats.rotation_speed * delta)
		if fire_cooldown <= 0 and global_position.distance_to(target_actor.global_position) <= MELEE_RANGE * 1.2:
			_bot_melee()
		return

	# Outnumbered: too many visible enemies → retreat to cover (threshold varies by personality)
	if not _knife_mode and _disengage_cooldown <= 0 and _count_visible_enemies() >= _disengage_threshold:
		if has_node("/root/Telemetry"):
			get_node("/root/Telemetry").log_tactics("disengage_triggered")
		change_state(State.DISENGAGE)
		return

	# Proactive combat looting: break off when nearly out of ammo AND a pickup is close
	if _combat_loot_threshold > 0 and stats.max_ammo > 0 and \
			float(stats.current_ammo) / float(stats.max_ammo) <= _combat_loot_threshold:
		var nearby = _find_best_pickup(_combat_loot_radius)
		if nearby:
			target_actor = nearby; is_targeting_loot = true; _recovering = true
			change_state(State.CHASE); return

	if stats.current_ammo <= 0:
		var hp_ratio = current_health / stats.max_health
		var dist_to_t = global_position.distance_to(target_actor.global_position)
		# Decide: knife rush (if healthy + close) or retreat to RECOVER
		if hp_ratio > 0.35 and dist_to_t < stats.attack_range * 0.6 and randf() < hp_ratio * 0.5:
			_knife_mode = true
		else:
			if has_node("/root/Telemetry"):
				get_node("/root/Telemetry").log_tactics("ammo_empty")
			change_state(State.RECOVER)
		return

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
		var atk_threshold = 0.9 - min(main.zone_stage - 1, 3) * 0.05  # 0.90 → 0.75
		if zone_dist > main.current_zone_radius * atk_threshold:
			change_state(State.ZONE_ESCAPE); return

	var dir_to_target = (last_known_target_pos - global_position).normalized()
	rotation.y = lerp_angle(rotation.y, atan2(dir_to_target.x, dir_to_target.z) + PI, stats.rotation_speed * delta)

	# Hard+ (awareness 2): periodic combat hops and tighter strafe
	if _awareness_level >= 2:
		_combat_jump_timer -= delta
		if _combat_jump_timer <= 0 and is_on_floor():
			velocity.y = 5.0
			_combat_jump_timer = randf_range(2.0, 4.0)

	var strafe_scale = clamp(0.2 + _awareness_level * 0.2, 0.2, 0.6)
	var strafe = Vector3(-dir_to_target.z, 0, dir_to_target.x) * sin(state_timer * 2.5)
	if dist > pref_range * 1.2:
		_move_or_unstick(dir_to_target + strafe * strafe_scale, delta, false)
	elif dist < pref_range * 0.5:
		_move_or_unstick(-dir_to_target + strafe * strafe_scale, delta, false)
	else:
		_move_or_unstick(strafe, delta, false)

	if fire_cooldown <= 0:
		if not can_see:
			shoot_predictive(last_known_target_pos)
		else:
			shoot()
		if _count_ally_attackers() >= 1:
			fire_cooldown *= _fire_rate_mult

func handle_recover_state(delta):
	recovery_timer += delta
	# Knife retaliation: if an enemy closes in while bot is unarmed, don't just stand there
	if stats.current_ammo <= 0 and reserve_ammo <= 0:
		var nearby_enemy = _find_nearest_target()
		if nearby_enemy and global_position.distance_to(nearby_enemy.global_position) < MELEE_RANGE * 2.5:
			target_actor = nearby_enemy
			_knife_mode = true
			change_state(State.ATTACK)
			return
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
		var loot = _find_best_pickup(_loot_radius)
		if loot:
			target_actor = loot
			is_targeting_loot = true
			_recovering = true
			change_state(State.CHASE)
			if has_node("/root/Telemetry"):
				get_node("/root/Telemetry").log_tactics("recovery_start")
		elif recovery_timer > 4.0:
			recovery_substate = "patrol"
			recovery_timer = 0.0
			patrol_target = _pick_patrol_target()
			if has_node("/root/Telemetry"):
				get_node("/root/Telemetry").log_tactics("patrol_entered")

	elif recovery_substate == "patrol":
		# Wander to a random zone point until loot appears or timeout
		var loot = _find_best_pickup(_loot_radius)
		if loot:
			target_actor = loot
			is_targeting_loot = true
			_recovering = true
			if has_node("/root/Telemetry"):
				get_node("/root/Telemetry").log_tactics("recovery_start")
			change_state(State.CHASE)
			return

		var dist_to_patrol = global_position.distance_to(patrol_target)
		if dist_to_patrol > 2.5:
			_nav_move_toward(patrol_target, delta, true)
		else:
			patrol_target = _pick_patrol_target()

		if recovery_timer > 8.0:
			if has_node("/root/Telemetry"):
				get_node("/root/Telemetry").log_tactics("patrol_timeout")
			change_state(State.IDLE)

func handle_zone_escape_state(delta):
	var main = get_tree().root.get_node_or_null("Main")
	if not main: change_state(State.IDLE); return
	var zone_c = main.current_zone_center
	var self_2d = Vector2(global_position.x, global_position.z)
	if self_2d.distance_to(zone_c) < main.current_zone_radius * 0.75:
		change_state(State.IDLE); return
	var zone_center_3d = Vector3(zone_c.x, global_position.y, zone_c.y)
	_nav_move_toward(zone_center_3d, delta, true)

func _sample_zone_escape_dir(zone_c: Vector2) -> Vector3:
	var to_center = Vector3(zone_c.x - global_position.x, 0, zone_c.y - global_position.z).normalized()
	# Blend center direction with a perpendicular wall-slide component.
	# Instance-unique sign ensures neighboring stuck bots slide to opposite sides
	# rather than all piling against the same wall segment.
	var perp = Vector3(-to_center.z, 0, to_center.x)
	var sign = 1.0 if (get_instance_id() % 2 == 0) else -1.0
	return (to_center + perp * sign * 0.6).normalized()

func handle_disengage_state(delta):
	# Return to action if threat count drops
	if _count_visible_enemies() <= 1 and state_timer > 2.0:
		target_actor = _find_nearest_target()
		if target_actor:
			change_state(State.CHASE)
		else:
			change_state(State.IDLE)
		return

	# No ammo while disengaging — recover instead
	if stats.current_ammo <= 0 and reserve_ammo <= 0:
		change_state(State.RECOVER); return

	# Timeout safety valve
	if state_timer > 8.0:
		change_state(State.IDLE); return

	# Zone override still applies
	var main = get_tree().root.get_node_or_null("Main")
	if main:
		var zone_dist = Vector2(global_position.x, global_position.z).distance_to(main.current_zone_center)
		if zone_dist > main.current_zone_radius:
			change_state(State.ZONE_ESCAPE); return

	var nearest_threat = _find_nearest_target()
	if not nearest_threat: change_state(State.IDLE); return

	# Heavily outnumbered (4+): scatter in unique directions rather than pile onto one cover spot
	if _count_visible_enemies() >= 4:
		_move_or_unstick(_scatter_dir_from(nearest_threat.global_position), delta, true)
		return

	# Normal disengage: seek tall cover
	if _disengage_cover == Vector3.ZERO or global_position.distance_to(_disengage_cover) < 2.0:
		_disengage_cover = _find_cover_point(nearest_threat.global_position)

	if _disengage_cover != Vector3.ZERO:
		_nav_move_toward(_disengage_cover, delta, true)
	else:
		_move_or_unstick(_scatter_dir_from(nearest_threat.global_position), delta, true)

# ─── STATE INDICATOR ─────────────────────────────────────────────────────────

func _update_state_label():
	if not _state_label: return
	if is_dead: _state_label.visible = false; return
	match current_state:
		State.CHASE:
			_state_label.text = "?"
			_state_label.modulate = Color(1.0, 0.90, 0.0)
		State.ATTACK:
			_state_label.text = "!"
			_state_label.modulate = Color(1.0, 0.18, 0.12)
		State.DISENGAGE:
			_state_label.text = "?"
			_state_label.modulate = Color(1.0, 0.60, 0.0)
		_:
			_state_label.visible = false
			return
	_state_label.visible = true

func _update_state_label_visibility():
	if not _state_label or not _state_label.visible: return
	if is_dead: _state_label.visible = false; return
	var player = get_tree().get_first_node_in_group("players")
	if not player or not player is Entity:
		_state_label.visible = false; return
	if not player._can_i_see(self):
		_state_label.visible = false

# ─── PERSONALITY & DIFFICULTY ────────────────────────────────────────────────

func _apply_personality(p: Personality):
	personality = p
	match p:
		Personality.AGGRESSIVE:
			_disengage_threshold = 3
			_fire_rate_mult = 0.8
			_footstep_range = 10.0
			_loot_radius = 70.0
			_combat_loot_threshold = 0.0
			_flee_hp_ratio = 0.15  # fights until nearly dead
		Personality.DEFENSIVE:
			_disengage_threshold = 1
			_fire_rate_mult = 1.0
			_footstep_range = 15.0
			_loot_radius = 60.0
			_combat_loot_threshold = 0.20
			_flee_hp_ratio = 0.35  # retreats early, values survival
		Personality.SCAVENGER:
			_disengage_threshold = 2
			_fire_rate_mult = 1.15
			_footstep_range = 18.0
			_loot_radius = 90.0
			_combat_loot_threshold = 0.30
			_flee_hp_ratio = 0.25  # balanced survival instinct

func apply_difficulty(params: Dictionary):
	if params.has("vision_mult"):
		stats.vision_range *= params.vision_mult
	if params.has("reaction_delay"):
		_reaction_delay = params.reaction_delay
	if params.has("aim_spread"):
		_aim_spread_mult = params.aim_spread
	if params.has("loot_break_mult"):
		_combat_loot_threshold *= params.loot_break_mult
	if params.has("combat_loot_floor"):
		_combat_loot_threshold = max(_combat_loot_threshold, params.combat_loot_floor)
	if params.has("combat_loot_radius"):
		_combat_loot_radius = params.combat_loot_radius
	if params.has("awareness_level"):
		_awareness_level = params.awareness_level

# ─── FOOTSTEP DETECTION ───────────────────────────────────────────────────────
# Running actors (velocity > 50% of move_speed) emit audible footsteps.
# Nearby idle/recovering bots boost their perception toward the source,
# making running stealthy risky near bots.

func _check_footstep_sounds():
	if current_state not in [State.IDLE, State.RECOVER]: return
	var actors = get_tree().get_nodes_in_group("actors")
	for actor in actors:
		if actor == self or not actor is Entity or actor.is_dead: continue
		if perception_meters.get(actor, 0.0) >= 1.0: continue
		var spd = Vector2(actor.velocity.x, actor.velocity.z).length()
		if spd < actor.stats.move_speed * 0.5: continue
		var dist = global_position.distance_to(actor.global_position)
		if dist > _footstep_range: continue
		if not perception_meters.has(actor): perception_meters[actor] = 0.0
		perception_meters[actor] = min(perception_meters[actor] + 0.4, 0.85)
		last_known_target_pos = actor.global_position
		# Turn idle bots toward the sound source so perception can build naturally
		if current_state == State.IDLE:
			var dir_to = (actor.global_position - global_position).normalized()
			scan_target_rotation = atan2(dir_to.x, dir_to.z) + PI

# ─── LOOT PRIORITY ────────────────────────────────────────────────────────────
# Scores each pickup by distance, then adjusts priority based on current need.
# Lower score = higher priority.

func _find_best_pickup(search_radius: float) -> Node3D:
	var pickups = get_tree().get_nodes_in_group("pickups")
	var best: Node3D = null
	var best_score: float = INF
	for p in pickups:
		if not is_instance_valid(p): continue
		var d = global_position.distance_to(p.global_position)
		if d > search_radius: continue
		var score = d
		var item = p.get("item")
		if item:
			match item.type:
				ItemData.Type.HEAL:
					if current_health / stats.max_health < 0.4:
						score *= 0.3
				ItemData.Type.AMMO:
					if stats.current_ammo == 0 and reserve_ammo == 0:
						score *= 0.25
					elif item.ammo_weapon_type != "" and item.ammo_weapon_type != stats.weapon_type:
						score *= 3.0
				ItemData.Type.WEAPON:
					if stats.weapon_type == "knife" or stats.weapon_type == "":
						score *= 0.5
		if score < best_score:
			best_score = score
			best = p
	return best

# ─── GROUP ATTACK ─────────────────────────────────────────────────────────────
# Count bots in ATTACK state targeting the same actor as this bot.

func _count_ally_attackers() -> int:
	if not is_instance_valid(target_actor): return 0
	var count = 0
	for bot in get_tree().get_nodes_in_group("bots"):
		if bot == self or not is_instance_valid(bot): continue
		if bot.get("current_state") == State.ATTACK and bot.get("target_actor") == target_actor:
			count += 1
	return count

# ─── OUTNUMBERED / COVER ─────────────────────────────────────────────────────

func _count_visible_enemies() -> int:
	var count = 0
	for target in perception_meters:
		if not is_instance_valid(target): continue
		if target is Entity and not target.is_dead and perception_meters[target] >= 1.0:
			count += 1
	return count

func _find_cover_point(threat_pos: Vector3) -> Vector3:
	var obstacles = get_tree().get_nodes_in_group("obstacles")
	var best_pos = Vector3.ZERO
	var best_score = INF
	var my_dist_to_threat = global_position.distance_to(threat_pos)
	# Per-bot angular sector so multiple bots spread around the same obstacle
	var sector_angle = float(get_instance_id() % 8) * (TAU / 8.0)

	for obs in obstacles:
		if not is_instance_valid(obs): continue
		# Skip obstacles too low to actually provide cover (log_pile, bush_patch, etc.)
		if not _obs_provides_cover(obs): continue

		var obs_pos = Vector3(obs.global_position.x, global_position.y, obs.global_position.z)
		var dist_to_obs = global_position.distance_to(obs_pos)
		if dist_to_obs > 20.0 or dist_to_obs < 0.5: continue

		var threat_to_obs = (obs_pos - threat_pos).normalized()
		threat_to_obs.y = 0
		# Spread cover positions around the obstacle using a per-bot sector offset
		var spread = Vector3(cos(sector_angle), 0, sin(sector_angle)) * 1.5
		var cover = obs_pos + threat_to_obs * 2.0 + spread
		cover.y = global_position.y

		if cover.distance_to(threat_pos) <= my_dist_to_threat: continue

		# Penalise cover spots already targeted by allied bots
		var crowding = 0.0
		for b in get_tree().get_nodes_in_group("bots"):
			if b != self and is_instance_valid(b) and b.get("_disengage_cover") != Vector3.ZERO:
				if (b._disengage_cover as Vector3).distance_to(cover) < 4.0:
					crowding += 10.0

		var score = dist_to_obs + crowding
		if score < best_score:
			best_score = score
			best_pos = cover

	return best_pos

# True when the obstacle is tall enough (collision layer 8 = bullet-blocking height > 2.5m).
func _obs_provides_cover(obs: Node3D) -> bool:
	if obs is StaticBody3D:
		return (obs.collision_layer & 8) != 0
	# rock_cluster root is a Node3D — check immediate children
	for child in obs.get_children():
		if child is StaticBody3D and (child.collision_layer & 8) != 0:
			return true
	return false

func _check_state_overrides(delta):
	var main = get_tree().root.get_node_or_null("Main")
	if not main: return
	var dist = Vector2(global_position.x, global_position.z).distance_to(main.current_zone_center)
	# Shrink trigger threshold as zone stage rises: 0.95 → 0.80 over stages 1-4.
	# At high stages zone damage is severe, so bots must react before reaching the edge.
	var threshold = 0.95 - min(main.zone_stage - 1, 3) * 0.05
	if dist > main.current_zone_radius * threshold:
		_zone_outside_timer += delta
		if current_state != State.ZONE_ESCAPE:
			change_state(State.ZONE_ESCAPE)
	else:
		_zone_outside_timer = 0.0

# HP-based survival override — runs after zone override, before state handlers.
# Pulls bots out of combat when critically wounded.
func _check_survival_overrides():
	if current_state == State.ZONE_ESCAPE or current_state == State.RECOVER: return
	var hp_ratio = current_health / stats.max_health
	if hp_ratio > _flee_hp_ratio: return
	match current_state:
		State.ATTACK:
			if not _knife_mode:  # knife rush is an intentional last stand, don't interrupt
				change_state(State.RECOVER)
		State.CHASE:
			if not is_targeting_loot:  # don't cancel a life-saving loot run
				target_actor = null
				change_state(State.RECOVER)
		State.DISENGAGE:
			if state_timer > 1.5:  # give time to find cover first, then switch to full RECOVER
				change_state(State.RECOVER)

# ─── PERIPHERAL AWARENESS ────────────────────────────────────────────────────

func _peripheral_check():
	var actors = get_tree().get_nodes_in_group("actors")
	var best: Entity = null
	var best_dist = INF
	for a in actors:
		if a == self or not a is Entity or a.is_dead: continue
		if a == target_actor: continue
		if not a.is_revealed_to(self): continue
		var d = global_position.distance_to(a.global_position)
		if d < best_dist: best_dist = d; best = a
	if not best: return
	if _awareness_level == 1:
		# Normal: only switch if new threat is >30% closer than current target
		var cur_dist = global_position.distance_to(target_actor.global_position) \
			if (target_actor != null and is_instance_valid(target_actor)) else INF
		if best_dist < cur_dist * 0.7:
			_switch_target(best)
	else:
		# Hard+: switch to any visible new threat unless current target is nearly dead
		var cur_hp_ratio = 1.0
		if target_actor != null and is_instance_valid(target_actor) and target_actor is Entity:
			cur_hp_ratio = target_actor.current_health / target_actor.stats.max_health
		if cur_hp_ratio >= 0.25:
			_switch_target(best)

func _switch_target(new_target: Entity):
	target_actor = new_target
	last_known_target_pos = new_target.global_position
	state_timer = 0.0

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

func _pick_patrol_target() -> Vector3:
	var main = get_tree().root.get_node_or_null("Main")
	if main and (main.supply_telegraphed or main.supply_spawned):
		return Vector3(main.supply_pos.x, global_position.y, main.supply_pos.z)
	match personality:
		Personality.DEFENSIVE:
			var bush = _find_nearest_bush()
			if bush != Vector3.ZERO: return bush
		Personality.SCAVENGER:
			var hotspot = _find_nearest_hotspot()
			if hotspot != Vector3.ZERO: return hotspot
	return _random_zone_point()

func _find_nearest_bush() -> Vector3:
	var main = get_tree().root.get_node_or_null("Main")
	if not main or not main.map_spec: return Vector3.ZERO
	var best = Vector3.ZERO
	var best_dist = INF
	for obs in main.map_spec.obstacles:
		if obs.get("type", "") != "bush_patch": continue
		var op = obs.get("pos", [0, 0])
		var bpos = Vector3(op[0], global_position.y, op[1])
		var d = global_position.distance_to(bpos)
		if d < best_dist: best_dist = d; best = bpos
	return best

func _find_nearest_hotspot() -> Vector3:
	var main = get_tree().root.get_node_or_null("Main")
	if not main or not main.map_spec: return Vector3.ZERO
	var best = Vector3.ZERO
	var best_dist = INF
	for poi in main.map_spec.pois:
		var pp = poi.get("pos", [0, 0])
		var ppos = Vector3(pp[0], global_position.y, pp[1])
		var d = global_position.distance_to(ppos)
		if d < best_dist: best_dist = d; best = ppos
	return best

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

# ─── MELEE ───────────────────────────────────────────────────────────────────

func _bot_melee():
	fire_cooldown = 0.65
	if not _is_target_valid(target_actor): return
	if global_position.distance_to(target_actor.global_position) > MELEE_RANGE: return
	target_actor.take_damage(MELEE_DAMAGE, "melee", "knife", self)
	var impact = IMPACT_EFFECT_SCN.instantiate()
	get_tree().root.add_child(impact)
	impact.global_position = target_actor.global_position + Vector3(0, 0.8, 0)
	if has_node("/root/Sfx"):
		get_node("/root/Sfx").play("hit", target_actor.global_position)

# ─── DEATH & WEAPON DROP ─────────────────────────────────────────────────────

func die(killer: Node3D = null):
	if _state_label: _state_label.visible = false
	_drop_weapon()
	_drop_ammo()
	_drop_heals()
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
	wstats.current_ammo = wstats.max_ammo / 3  # partial load only — actual ammo drops separately
	item.weapon_stats = wstats
	var pickup = PICKUP_SCN.instantiate()
	get_tree().root.add_child(pickup)
	pickup.global_position = global_position + Vector3(randf_range(-0.5, 0.5), 0.3, randf_range(-0.5, 0.5))
	pickup.init(item)
	if has_node("/root/Telemetry"):
		get_node("/root/Telemetry").log_weapon_drop()

func _drop_ammo():
	var total = stats.current_ammo + reserve_ammo
	if total <= 0 or stats.weapon_type == "" or stats.weapon_type == "knife": return
	var item = ItemData.new()
	item.type = ItemData.Type.AMMO
	item.rarity = ItemData.Rarity.COMMON
	item.item_name = _weapon_display_name(stats.weapon_type) + " Ammo"
	item.ammo_weapon_type = stats.weapon_type
	item.amount = total
	item.color = _weapon_color(stats.weapon_type)
	var pickup = PICKUP_SCN.instantiate()
	get_tree().root.add_child(pickup)
	pickup.global_position = global_position + Vector3(randf_range(-0.8, 0.8), 0.3, randf_range(-0.8, 0.8))
	pickup.init(item)

func _drop_heals():
	if stats.heal_items > 0:
		var item = ItemData.new()
		item.type = ItemData.Type.HEAL
		item.rarity = ItemData.Rarity.COMMON
		item.item_name = "Health Potion"
		item.amount = stats.heal_items
		item.color = Color(0.2, 1.0, 0.4)
		var pickup = PICKUP_SCN.instantiate()
		get_tree().root.add_child(pickup)
		pickup.global_position = global_position + Vector3(randf_range(-0.5, 0.5), 0.3, randf_range(-0.5, 0.5))
		pickup.init(item)
	if stats.advanced_heals > 0:
		var item = ItemData.new()
		item.type = ItemData.Type.HEAL
		item.rarity = ItemData.Rarity.RARE
		item.item_name = "MedKit"
		item.amount = stats.advanced_heals
		item.color = Color(1.0, 0.88, 0.1)
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

	# Instantly reveal attacker so _find_nearest_target picks them up
	if source_node is Entity and is_instance_valid(source_node) and not source_node.is_dead:
		perception_meters[source_node] = 1.0
		last_known_target_pos = source_node.global_position

	if stats.current_ammo <= 0 and reserve_ammo <= 0:
		if current_state != State.RECOVER and current_state != State.ZONE_ESCAPE:
			change_state(State.RECOVER)
		return

	if source_node is Entity and is_instance_valid(source_node) and not source_node.is_dead:
		# Passive states: immediately engage the attacker
		var passive = current_state == State.IDLE \
			or (current_state == State.CHASE and is_targeting_loot) \
			or current_state == State.DISENGAGE
		if passive:
			target_actor = source_node
			is_targeting_loot = false
			_pending_target = null
			change_state(State.CHASE)
		# HARD+: switch targets mid-combat when hit by a third party
		elif _awareness_level >= 2 and current_state == State.ATTACK \
				and source_node != target_actor:
			var cur_hp_ratio = 1.0
			if target_actor != null and is_instance_valid(target_actor) and target_actor is Entity:
				cur_hp_ratio = target_actor.current_health / target_actor.stats.max_health
			if cur_hp_ratio >= 0.25:
				_switch_target(source_node)

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
	var base_spread = 0.1 * _aim_spread_mult
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
	if current_state == State.DISENGAGE and new_state != State.DISENGAGE:
		_disengage_cooldown = 10.0
	if new_state != State.ATTACK: _knife_mode = false
	if DEBUG_PRINT:
		print("[BOT] %s → %s (ammo=%d reserve=%d hp=%.0f)" % [
			State.keys()[current_state], State.keys()[new_state],
			stats.current_ammo, reserve_ammo, current_health
		])
	current_state = new_state
	state_timer = 0.0
	_update_state_label()
	if new_state == State.RECOVER:
		# If reserve ammo is available, reload on the spot and skip RECOVER entirely
		if reserve_ammo > 0:
			_try_reload()
			current_state = State.IDLE
			state_timer = 0.0
			if has_node("/root/Telemetry"):
				get_node("/root/Telemetry").log_tactics("reserve_reload")
			return
		recovery_substate = "seek_cover"
		recovery_timer = 0.0
		patrol_target = Vector3.ZERO
	if new_state == State.DISENGAGE:
		_disengage_cover = Vector3.ZERO
