extends Entity

const MUZZLE_FLASH_SCN   = preload("res://src/fx/MuzzleFlash.tscn")
const BULLET_TRAIL_SCN   = preload("res://src/fx/BulletTrail.tscn")
const PICKUP_SCN         = preload("res://src/entities/pickup/Pickup.tscn")
const IMPACT_EFFECT_SCN  = preload("res://src/fx/ImpactEffect.tscn")
const BOT_DOCTRINE       = preload("res://src/entities/bot/BotDoctrine.gd")
const BOT_VISUAL_KIT     = preload("res://src/entities/bot/BotVisualKit.gd")

const MELEE_RANGE: float  = 1.8
const MELEE_DAMAGE: float = 20.0
const ATTACK_BOUT_REPOSITION_LIMIT: float = 16.0
const RETREAT_THREAT_SCAN_RANGE: float = 10.0
const RETREAT_COUNTERFIRE_MAX_RANGE: float = 16.0
const RETREAT_MELEE_COUNTER_RANGE: float = 2.35
const RETREAT_COUNTERFIRE_SPREAD: float = 0.34
const RETREAT_COUNTERFIRE_MIN_COOLDOWN: float = 0.85
const DEBUG_ARCHETYPE_MARKERS: bool = false

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

# Individual combat doctrine. Bots periodically pick a plan instead of
# sliding in a constant pattern while shooting.
var _combat_plan: String = BOT_DOCTRINE.PLAN_STRAFE
var _combat_plan_timer: float = 0.0
var _combat_move_target: Vector3 = Vector3.ZERO
var _combat_cover: Vector3 = Vector3.ZERO
var _strafe_dir: float = 1.0
var _strafe_timer: float = 0.0
var _peek_side: float = 1.0
var _recover_cover: Vector3 = Vector3.ZERO

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
var _scan_interval_max: float = 3.0  # idle scan max interval — difficulty-scaled
var _scan_phase: int = 0             # cycles: right flank → left flank → random
var _scan_alert: bool = false        # true when sound/event set scan_target; use full rotation speed

# Stuck detection
var _stuck_timer: float = 0.0
var _stuck_override_dir: Vector3 = Vector3.ZERO
var _stuck_override_timer: float = 0.0

# Zone tracking
var _zone_outside_timer: float = 0.0  # continuous seconds spent outside zone
var _zone_thrash_cooldown: float = 0.0  # throttle random thrash bursts in ZONE_ESCAPE

const DEBUG_PRINT = false

var _state_label: Label3D = null
var _archetype_marker: Label3D = null
var _skin_root: Node3D = null
var _doctrine_profile: Dictionary = {}
var _difficulty_params: Dictionary = {}
var _base_attack_range: float = -1.0
var _base_vision_range: float = -1.0

# ─── ARCHETYPE ───────────────────────────────────────────────────────────────
enum BotArchetype { AGGRESSIVE, DEFENSIVE, SNIPER, OPPORTUNIST }
var archetype: BotArchetype = BotArchetype.AGGRESSIVE
var _disengage_threshold: int = 2  # visible enemies needed to trigger DISENGAGE
var _fire_rate_mult: float = 1.0   # multiplier applied to fire_cooldown post-shot when allies attack same target
var _footstep_range: float = 12.0  # radius to hear running actors
var _loot_radius: float = 70.0     # pickup search radius in RECOVER
var _combat_loot_threshold: float = 0.0  # ammo ratio below which bot breaks combat to grab nearby loot
var _flee_hp_ratio: float = 0.25         # HP ratio below which bot exits combat to RECOVER
var _sniper_min_engage_range: float = 0.0  # SNIPER: retreat if target closes within this distance

# ─── DIFFICULTY ──────────────────────────────────────────────────────────────
var _reaction_delay: float = 0.0   # seconds between spotting and reacting
var _pending_target: Entity = null
var _reaction_timer: float = 0.0
var _aim_spread_mult: float = 1.0  # multiplier for predictive-shot spread
# 0=none 1=periodic scan(3s) 2=periodic scan(1.5s)+instant reaction on hit
var _awareness_level: int = 0
var _peripheral_scan_timer: float = 0.0
var _ambient_scan_timer: float = 0.0
var _head_sweep_angle: float = 0.0  # continuously advances for Hard+ 360° sweep
var is_crouching: bool = false
var _mesh_origin_y: float = 0.0
var _combat_jump_timer: float = 0.0
var _nav_agent: NavigationAgent3D = null

# Post-kill scan & opportunistic looting
var _post_kill_scan_timer: float = 0.0
var _post_kill_loot_attempted: bool = false
# Reload retreat (low ammo → cover → reload → re-engage)
var _retreating_to_reload: bool = false
# Fight-or-flight: estimated damage exchange this engagement
var _engagement_dmg_dealt: float = 0.0
var _engagement_dmg_taken: float = 0.0
var _last_damage_tick: int = 0
# Late-game shift (alive ≤ 3) — applied once
var _late_game_applied: bool = false

@onready var ray_cast = $RayCast3D

func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE
	super._ready()
	_capture_base_stats()
	add_to_group("bots")
	# 아키타입은 Main.gd에서 스폰 후 배정. 여기서는 기본값만 유지.
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
	_archetype_marker = Label3D.new()
	_archetype_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_archetype_marker.double_sided = true
	_archetype_marker.font_size = 38
	_archetype_marker.pixel_size = 0.006
	_archetype_marker.outline_size = 8
	_archetype_marker.position = Vector3(0, 2.85, 0)
	_archetype_marker.visible = false
	add_child(_archetype_marker)
	_update_archetype_marker()
	_nav_agent = NavigationAgent3D.new()
	_nav_agent.path_desired_distance = 0.5
	_nav_agent.target_desired_distance = 1.5
	_nav_agent.avoidance_enabled = false
	add_child(_nav_agent)
	if has_node("MeshInstance3D"):
		_mesh_origin_y = $MeshInstance3D.position.y
	await get_tree().create_timer(randf_range(0.05, 0.2)).timeout
	if ray_cast:
		ray_cast.enabled = true
		ray_cast.add_exception(self)
		ray_cast.collision_mask = 2 | 8

func _on_died_zone_log():
	if _zone_outside_timer <= 0.5 or not has_node("/root/Telemetry"):
		return
	var main = get_tree().root.get_node_or_null("Main")
	var actual_outside = false
	if main and main.zone:
		actual_outside = main.zone.is_outside(Vector2(global_position.x, global_position.z))
	if last_damage_source != "zone" and not actual_outside:
		return
	var tel = get_node("/root/Telemetry")
	var state_name = State.keys()[current_state]
	tel.log_zone_death(state_name, _zone_outside_timer)
	if last_damage_source != "zone":
		tel.log_tactics("zone_assisted_death")

func _physics_process(delta):
	if is_dead: return
	if fire_cooldown > 0: fire_cooldown -= delta
	if _disengage_cooldown > 0: _disengage_cooldown -= delta
	if _reaction_timer > 0: _reaction_timer -= delta
	if _zone_thrash_cooldown > 0: _zone_thrash_cooldown -= delta
	state_timer += delta
	_log_doctrine_state_time(delta)

	if current_state == State.ATTACK:
		attack_bout_timer += delta
	elif attack_bout_timer > 0:
		if has_node("/root/Telemetry"):
			get_node("/root/Telemetry").log_combat_audit("attack_max_continuous", attack_bout_timer)
		attack_bout_timer = 0.0

	if current_health < stats.max_health * 0.82 and (stats.heal_items > 0 or stats.advanced_heals > 0):
		use_heal()

	_check_late_game()
	_check_state_overrides(delta)
	_check_survival_overrides()
	_update_stuck(delta)
	_check_footstep_sounds()
	_check_close_range()
	_check_gunshot_sounds()
	_check_ambient_awareness(delta)
	_update_state_label_visibility()
	_update_archetype_marker_visibility()

	match current_state:
		State.IDLE:        handle_idle_state(delta)
		State.CHASE:       handle_chase_state(delta)
		State.ATTACK:      handle_attack_state(delta)
		State.ZONE_ESCAPE: handle_zone_escape_state(delta)
		State.RECOVER:     handle_recover_state(delta)
		State.DISENGAGE:   handle_disengage_state(delta)

	super._physics_process(delta)

	# Crouch: RECOVER, DISENGAGE, or IDLE while stationary — reduces player visibility
	is_crouching = current_state in [State.RECOVER, State.DISENGAGE] or \
		(current_state == State.IDLE and Vector2(velocity.x, velocity.z).length() < 1.0)
	if is_crouching and reveal_timer <= 0:
		stealth_modifier = min(stealth_modifier, 0.45)
	if has_node("MeshInstance3D"):
		$MeshInstance3D.scale.y = 0.62 if is_crouching else 1.0
		$MeshInstance3D.position.y = _mesh_origin_y - 0.19 if is_crouching else _mesh_origin_y
	_sync_visual_skin()

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
			var threat = _find_retreat_threat(RETREAT_THREAT_SCAN_RANGE)
			_stuck_override_dir = _pick_stuck_escape_dir(threat)
			_stuck_override_timer = 1.2
			_stuck_timer = 0.0
			if has_node("/root/Telemetry"):
				var tel = get_node("/root/Telemetry")
				tel.log_tactics("stuck_triggered")
				if threat:
					tel.log_tactics("stuck_while_threatened")
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
	# Post-kill scan: fast 360° sweep + nearby loot grab before resuming normal IDLE
	if _post_kill_scan_timer > 0.0:
		_post_kill_scan_timer -= delta
		_head_sweep_angle += 2.2 * delta
		scan_target_rotation = _head_sweep_angle
		rotation.y = lerp_angle(rotation.y, scan_target_rotation, stats.rotation_speed * delta)
		if not _post_kill_loot_attempted:
			_post_kill_loot_attempted = true
			var nearby = _find_best_pickup(8.0)
			if nearby and _count_visible_enemies() <= 1:
				target_actor = nearby; is_targeting_loot = true; _recovering = false
				change_state(State.CHASE); return
		var kill_scan_enemy = _find_nearest_target()
		if kill_scan_enemy:
			target_actor = kill_scan_enemy
			change_state(State.CHASE)
		return

	if _awareness_level >= 2:
		# Hard+: continuous 360° sweep — head turns at constant speed, fully independent of movement
		_head_sweep_angle += 1.1 * delta  # ~1.75 rad/s ≈ full rotation every 3.6s
		if not _scan_alert:
			scan_target_rotation = _head_sweep_angle
		var rot_speed = stats.rotation_speed if _scan_alert else stats.rotation_speed * 0.65
		rotation.y = lerp_angle(rotation.y, scan_target_rotation, rot_speed * delta)
		if _scan_alert and abs(angle_difference(rotation.y, scan_target_rotation)) < 0.15:
			_scan_alert = false
	else:
		scan_timer -= delta
		if scan_timer <= 0:
			scan_timer = randf_range(_scan_interval_max * 0.4, _scan_interval_max)
			_scan_phase = (_scan_phase + 1) % 3
			match _scan_phase:
				0: scan_target_rotation = rotation.y + randf_range(PI * 0.3, PI * 0.8)
				1: scan_target_rotation = rotation.y - randf_range(PI * 0.3, PI * 0.8)
				_: scan_target_rotation = rotation.y + randf_range(-PI, PI)
		var rot_speed = stats.rotation_speed if _scan_alert else stats.rotation_speed * 0.5
		rotation.y = lerp_angle(rotation.y, scan_target_rotation, rot_speed * delta)
		if _scan_alert and abs(angle_difference(rotation.y, scan_target_rotation)) < 0.15:
			_scan_alert = false

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
		if _should_pursue_supply(main):
			var dir = (main.supply_pos - global_position).normalized()
			_move_or_unstick(dir, delta, true)
			if has_node("/root/Telemetry") and state_timer < 0.1:
				get_node("/root/Telemetry").log_supply_event("preannounce_interest")
			return

	# Late game: actively close on last known player position when no other target
	if _late_game_applied and last_known_target_pos != Vector3.ZERO:
		if global_position.distance_to(last_known_target_pos) > 6.0:
			_nav_move_toward(last_known_target_pos, delta, true)

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
		# Detect kill vs target-lost for post-kill scan
		var was_killed = target_actor != null and target_actor is Entity and target_actor.is_dead
		if was_killed:
			_post_kill_scan_timer = 2.5
			_post_kill_loot_attempted = false
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

	# Fight-or-flight: when HP is marginal but above flee threshold,
	# estimate exchange ratio to decide whether to disengage
	if not _knife_mode and _disengage_cooldown <= 0 and _engagement_dmg_taken > 10.0:
		var hp_ratio = current_health / stats.max_health
		if hp_ratio < _flee_hp_ratio + 0.22 and target_actor is Entity:
			# Bot estimates enemy HP from shots fired (55% assumed hit rate = imprecise estimate)
			var est_enemy_remaining = maxf(0.0, target_actor.stats.max_health - _engagement_dmg_dealt)
			var est_enemy_ratio = est_enemy_remaining / target_actor.stats.max_health
			if est_enemy_ratio > hp_ratio + 0.15:
				if has_node("/root/Telemetry"):
					get_node("/root/Telemetry").log_tactics("disengage_losing_fight")
				change_state(State.DISENGAGE)
				return

	# Low ammo retreat: ≤25% mag left but reserve available → duck to cover and reload
	if not _retreating_to_reload and _disengage_cooldown <= 0 and reserve_ammo > 0 \
			and stats.max_ammo > 0 \
			and float(stats.current_ammo) / float(stats.max_ammo) <= 0.25:
		_retreating_to_reload = true
		if has_node("/root/Telemetry"):
			get_node("/root/Telemetry").log_tactics("reload_retreat")
		change_state(State.DISENGAGE)
		return

	# Proactive combat looting: break off when nearly out of ammo AND a pickup is close
	if _combat_loot_threshold > 0 and stats.max_ammo > 0 and \
			float(stats.current_ammo) / float(stats.max_ammo) <= _combat_loot_threshold:
		var nearby = _find_best_pickup(_combat_loot_radius)
		if nearby:
			target_actor = nearby; is_targeting_loot = true; _recovering = true
			if has_node("/root/Telemetry"):
				get_node("/root/Telemetry").log_tactics("recovery_start")
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
		var zone_dist = Vector2(global_position.x, global_position.z).distance_to(main.zone.current_center)
		var atk_threshold = 0.9 - min(main.zone.stage - 1, 3) * 0.05  # 0.90 → 0.75
		if zone_dist > main.zone.current_radius * atk_threshold:
			change_state(State.ZONE_ESCAPE); return

	# SNIPER: retreat if target closes within minimum engage range
	if _sniper_min_engage_range > 0.0 and _disengage_cooldown <= 0:
		var cur_dist = global_position.distance_to(target_actor.global_position) if is_instance_valid(target_actor) else INF
		if cur_dist < _sniper_min_engage_range:
			change_state(State.DISENGAGE); return

	# Human-like reset: prolonged face-to-face trades should break into a
	# short reposition instead of becoming a stationary DPS contest.
	if attack_bout_timer > ATTACK_BOUT_REPOSITION_LIMIT and _disengage_cooldown <= 0.0:
		if has_node("/root/Telemetry"):
			var tel = get_node("/root/Telemetry")
			tel.log_combat_audit("attack_disengage")
			tel.log_tactics("combat_reposition")
		_retreating_to_reload = reserve_ammo > 0 and stats.max_ammo > 0 \
			and float(stats.current_ammo) / float(stats.max_ammo) <= 0.5
		change_state(State.DISENGAGE)
		return

	var dir_to_target = (last_known_target_pos - global_position).normalized()
	rotation.y = lerp_angle(rotation.y, atan2(dir_to_target.x, dir_to_target.z) + PI, stats.rotation_speed * delta)

	# Hard+ (awareness 2): occasional combat hops when committing in the open.
	if _awareness_level >= 2:
		_combat_jump_timer -= delta
		if _combat_jump_timer <= 0 and is_on_floor() and _combat_plan in [BOT_DOCTRINE.PLAN_ADVANCE, BOT_DOCTRINE.PLAN_STRAFE]:
			velocity.y = 5.0
			_combat_jump_timer = randf_range(2.0, 4.0)

	_update_combat_plan(delta, can_see, dist, pref_range)
	_apply_combat_movement(delta, can_see, dist, pref_range, dir_to_target)

	if fire_cooldown <= 0 and _should_fire_for_plan(can_see):
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
		# Break line-of-sight first, then loot. Running straight to ammo while
		# wounded makes RECOVER deaths spike and looks less human.
		if not nearest_enemy:
			recovery_substate = "seek_loot"
			recovery_timer = 0.0
			return

		if _recover_cover == Vector3.ZERO:
			_recover_cover = _find_cover_point(nearest_enemy.global_position)

		var cover_time_limit = 4.2 if current_health / stats.max_health < 0.45 else 2.6
		if _recover_cover != Vector3.ZERO:
			var cover_dist = global_position.distance_to(_recover_cover)
			if cover_dist > 2.0:
				_nav_move_toward(_recover_cover, delta, true)
			else:
				handle_movement(Vector3.ZERO, delta, false)
				if recovery_timer > 1.1:
					recovery_substate = "seek_loot"
					recovery_timer = 0.0
					_recover_cover = Vector3.ZERO
			if recovery_timer > cover_time_limit:
				recovery_substate = "seek_loot"
				recovery_timer = 0.0
				_recover_cover = Vector3.ZERO
		else:
			_move_or_unstick(_scatter_dir_from(nearest_enemy.global_position), delta, true)
			if recovery_timer > cover_time_limit:
				recovery_substate = "seek_loot"
				recovery_timer = 0.0

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
			if _awareness_level >= 2:
				# Hard+: head sweeps independently while body walks to patrol target
				_head_sweep_angle += 1.1 * delta
				rotation.y = lerp_angle(rotation.y, _head_sweep_angle, stats.rotation_speed * 0.6 * delta)
				_nav_move_toward(patrol_target, delta, false)
			else:
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
	var zone_c = main.zone.current_center
	var self_2d = Vector2(global_position.x, global_position.z)
	if self_2d.distance_to(zone_c) < main.zone.current_radius * 0.75:
		change_state(State.IDLE); return
	var zone_center_3d = Vector3(zone_c.x, global_position.y, zone_c.y)
	var threat = _find_retreat_threat(RETREAT_THREAT_SCAN_RANGE)
	var countering = threat != null
	# When stuck, use wall-slide escape direction rather than random stuck override
	if _stuck_override_timer > 0:
		handle_movement(_sample_zone_escape_dir(zone_c, threat), delta, not countering)
	else:
		_nav_move_toward(zone_center_3d, delta, not countering)
	if countering:
		_try_retreat_counteraction(threat, delta, "zone_escape_fire")

func _sample_zone_escape_dir(zone_c: Vector2, threat: Entity = null) -> Vector3:
	var to_center = Vector3(zone_c.x - global_position.x, 0, zone_c.y - global_position.z).normalized()
	# Blend center direction with a perpendicular wall-slide component.
	# Instance-unique sign ensures neighboring stuck bots slide to opposite sides
	# rather than all piling against the same wall segment.
	var perp = Vector3(-to_center.z, 0, to_center.x)
	var sign = 1.0 if (get_instance_id() % 2 == 0) else -1.0
	var dir = to_center + perp * sign * 0.6
	if _is_target_valid(threat):
		var away = global_position - threat.global_position
		away.y = 0
		if away.length_squared() > 0.01:
			dir += away.normalized() * 0.7
	return dir.normalized()

func _pick_stuck_escape_dir(threat: Entity = null) -> Vector3:
	var dir = Vector3.ZERO
	var main = get_tree().root.get_node_or_null("Main")
	if main and main.zone:
		var zone_c = main.zone.current_center
		var to_center = Vector3(zone_c.x - global_position.x, 0, zone_c.y - global_position.z)
		to_center.y = 0
		if to_center.length_squared() > 0.01:
			var pos_2d = Vector2(global_position.x, global_position.z)
			var outside_or_escaping = current_state == State.ZONE_ESCAPE or main.zone.is_outside(pos_2d)
			dir += to_center.normalized() * (1.2 if outside_or_escaping else 0.45)

	if _is_target_valid(threat):
		var away = global_position - threat.global_position
		away.y = 0
		if away.length_squared() > 0.01:
			dir += away.normalized() * 0.9

	var fwd = Vector3(sin(rotation.y), 0, cos(rotation.y))
	if dir.length_squared() < 0.01:
		var angle = randf_range(-PI * 0.75, PI * 0.75)
		dir = Vector3(
			fwd.x * cos(angle) - fwd.z * sin(angle),
			0,
			fwd.x * sin(angle) + fwd.z * cos(angle)
		)
	else:
		var side = Vector3(-dir.z, 0, dir.x)
		var sign = 1.0 if (get_instance_id() % 2 == 0) else -1.0
		dir += side.normalized() * sign * 0.65
	return dir.normalized()

func _find_retreat_threat(max_range: float) -> Entity:
	var best: Entity = null
	var best_score = INF
	for actor in get_tree().get_nodes_in_group("actors"):
		if actor == self or not actor is Entity or actor.is_dead: continue
		var dist = global_position.distance_to(actor.global_position)
		if dist > max_range: continue
		var perceived = perception_meters.get(actor, 0.0)
		var close = dist <= RETREAT_MELEE_COUNTER_RANGE * 2.0
		var visible = perceived >= 0.75 or close or _can_i_see(actor)
		if not visible: continue
		var score = dist - perceived * 2.0
		if actor == target_actor:
			score -= 1.0
		if close:
			score -= 3.0
		if score < best_score:
			best_score = score
			best = actor
	return best

func _try_retreat_counteraction(threat: Entity, delta: float, gun_event: String) -> bool:
	if not _is_target_valid(threat):
		return false
	var dist = global_position.distance_to(threat.global_position)
	if dist > RETREAT_THREAT_SCAN_RANGE:
		return false
	target_actor = threat
	last_known_target_pos = threat.global_position
	_face_retreat_threat(threat, delta)

	if fire_cooldown <= 0.0 and dist <= MELEE_RANGE * 1.05:
		_bot_melee()
		if has_node("/root/Telemetry"):
			get_node("/root/Telemetry").log_tactics("retreat_melee_counter")
		return true

	if stats.current_ammo <= 0 and reserve_ammo > 0 and dist > MELEE_RANGE * 2.0:
		var before = stats.current_ammo
		_try_reload()
		if stats.current_ammo > before and has_node("/root/Telemetry"):
			get_node("/root/Telemetry").log_tactics("reserve_reload")

	var fire_range = minf(stats.attack_range, RETREAT_COUNTERFIRE_MAX_RANGE)
	if fire_cooldown <= 0.0 and stats.current_ammo > 0 and dist <= fire_range \
			and stats.weapon_type != "" and stats.weapon_type != "knife" and has_los_to(threat):
		_retreat_fire_at(threat, gun_event)
		return true
	return false

func _face_retreat_threat(threat: Entity, delta: float):
	var dir_to = threat.global_position - global_position
	dir_to.y = 0
	if dir_to.length_squared() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(dir_to.x, dir_to.z) + PI, stats.rotation_speed * 1.25 * delta)

func _retreat_fire_at(threat: Entity, event: String):
	if stats.current_ammo <= 0 or not ray_cast:
		return
	stats.current_ammo -= 1
	fire_cooldown = maxf(stats.fire_rate * 1.85, RETREAT_COUNTERFIRE_MIN_COOLDOWN)
	reveal()
	if has_node("/root/Telemetry"):
		var tel = get_node("/root/Telemetry")
		tel.log_shot()
		tel.log_tactics(event)
	if MUZZLE_FLASH_SCN:
		var flash = MUZZLE_FLASH_SCN.instantiate()
		add_child(flash)
		flash.position = Vector3(0, 0.5, -0.5)

	var target_point = threat.global_position + Vector3(0, 1.0, 0)
	var spread = RETREAT_COUNTERFIRE_SPREAD * _aim_spread_mult
	if current_state == State.ZONE_ESCAPE:
		spread *= 1.4
	var pellets = max(1, stats.pellet_count) if stats.weapon_type == "shotgun" else 1
	for _i in range(pellets):
		var pellet_spread = spread + (0.18 if stats.weapon_type == "shotgun" else 0.0)
		_cast_and_visualize(_retreat_local_aim(target_point, pellet_spread))

func _retreat_local_aim(world_pos: Vector3, spread: float) -> Vector3:
	var local = ray_cast.to_local(world_pos)
	if local.length() > stats.attack_range:
		local = local.normalized() * stats.attack_range
	local.x += randf_range(-spread, spread)
	local.y += randf_range(-spread * 0.35, spread * 0.35)
	return local

func _should_pursue_supply(main: Node) -> bool:
	_ensure_doctrine_profile()
	var dist = global_position.distance_to(main.supply_pos)
	var hp_ratio = current_health / maxf(1.0, stats.max_health)
	var ammo_ratio = 1.0
	if stats.max_ammo > 0:
		ammo_ratio = float(stats.current_ammo) / float(stats.max_ammo)
	var decision = BOT_DOCTRINE.choose_supply_decision({
		"distance": dist,
		"telegraphed": main.supply_telegraphed,
		"spawned": main.supply_spawned,
		"hp_ratio": hp_ratio,
		"ammo_ratio": ammo_ratio,
		"bucket": get_instance_id(),
	}, _doctrine_profile)
	if decision != "deny" and has_node("/root/Telemetry") and state_timer < 0.1:
		get_node("/root/Telemetry").log_doctrine_supply(decision)
	return decision != "deny"

func handle_disengage_state(delta):
	# Reload retreat: once behind cover long enough, reload and re-engage
	if _retreating_to_reload and state_timer > 1.5:
		_try_reload()
		_retreating_to_reload = false
		var still_fragile = current_health / stats.max_health < _flee_hp_ratio + 0.12 and state_timer < 4.5
		if not still_fragile:
			if stats.current_ammo > 0:
				var reload_enemy = _find_nearest_target()
				if reload_enemy:
					target_actor = reload_enemy
					change_state(State.CHASE)
					return
			change_state(State.IDLE)
			return

	# Return to action if threat count drops
	if _count_visible_enemies() <= 1 and state_timer > 2.0:
		var still_fragile = current_health / stats.max_health < _flee_hp_ratio + 0.12 and state_timer < 4.5
		if not still_fragile:
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
		var zone_dist = Vector2(global_position.x, global_position.z).distance_to(main.zone.current_center)
		if zone_dist > main.zone.current_radius:
			change_state(State.ZONE_ESCAPE); return

	var nearest_threat = _find_nearest_target()
	if not nearest_threat: change_state(State.IDLE); return
	var counter_threat = _find_retreat_threat(RETREAT_THREAT_SCAN_RANGE)
	if not counter_threat:
		counter_threat = nearest_threat
	var countering = counter_threat != null and global_position.distance_to(counter_threat.global_position) <= RETREAT_THREAT_SCAN_RANGE

	# Heavily outnumbered (4+): scatter in unique directions rather than pile onto one cover spot
	if _count_visible_enemies() >= 4:
		_move_or_unstick(_scatter_dir_from(nearest_threat.global_position), delta, not countering)
		if countering:
			_try_retreat_counteraction(counter_threat, delta, "retreat_counterfire")
		return

	# Normal disengage: seek tall cover
	if _disengage_cover == Vector3.ZERO or global_position.distance_to(_disengage_cover) < 2.0:
		_disengage_cover = _find_cover_point(nearest_threat.global_position)

	if _disengage_cover != Vector3.ZERO:
		_nav_move_toward(_disengage_cover, delta, not countering)
	else:
		_move_or_unstick(_scatter_dir_from(nearest_threat.global_position), delta, not countering)
	if countering:
		_try_retreat_counteraction(counter_threat, delta, "retreat_counterfire")

# ─── PERSONAL COMBAT DOCTRINE ────────────────────────────────────────────────

func _update_combat_plan(delta: float, can_see: bool, dist: float, pref_range: float):
	_ensure_doctrine_profile()
	_combat_plan_timer -= delta
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_dir = -_strafe_dir if randf() < 0.75 else (1.0 if randf() < 0.5 else -1.0)
		_strafe_timer = randf_range(0.55, 1.35)
	if _combat_plan_timer > 0.0:
		return

	var previous_plan = _combat_plan
	var combat = _doctrine_profile.get("combat", {})
	_combat_plan_timer = randf_range(
		float(combat.get("plan_seconds_min", 0.9)),
		float(combat.get("plan_seconds_max", 1.8))
	)
	_combat_plan = BOT_DOCTRINE.PLAN_STRAFE
	_combat_move_target = Vector3.ZERO
	_combat_cover = Vector3.ZERO

	var hp_ratio = current_health / maxf(1.0, stats.max_health)
	var ammo_ratio = 1.0
	if stats.max_ammo > 0:
		ammo_ratio = float(stats.current_ammo) / float(stats.max_ammo)
	var visible_enemies = _count_visible_enemies()
	var target_pos = target_actor.global_position if is_instance_valid(target_actor) else last_known_target_pos
	var losing_trade = _engagement_dmg_taken > _engagement_dmg_dealt + 15.0
	var candidate_cover = _find_cover_point(target_pos)
	var context = {
		"can_see": can_see,
		"has_last_known": last_known_target_pos != Vector3.ZERO,
		"hp_ratio": hp_ratio,
		"ammo_ratio": ammo_ratio,
		"visible_enemies": visible_enemies,
		"losing_trade": losing_trade,
		"weapon_type": stats.weapon_type,
		"distance": dist,
		"preferred_range": pref_range,
		"reserve_ammo": reserve_ammo,
		"target_hp_ratio": _target_hp_ratio(),
		"has_cover": candidate_cover != Vector3.ZERO,
		"cover_probe": randf() < float(combat.get("cover_probe_chance", 0.28)),
		"reposition_probe": randf() < float(combat.get("reposition_probe_chance", 0.22)),
		"advance_probe": randf() < float(combat.get("advance_probe_chance", 0.0)),
		"kite_probe": randf() < float(combat.get("kite_probe_chance", 0.0)),
	}
	_combat_plan = BOT_DOCTRINE.choose_combat_plan(context, _doctrine_profile)
	if _combat_plan == BOT_DOCTRINE.PLAN_PEEK_COVER:
		_combat_cover = candidate_cover
	elif _combat_plan == BOT_DOCTRINE.PLAN_REPOSITION:
		_combat_move_target = _pick_combat_reposition_point(target_pos, pref_range)

	if has_node("/root/Telemetry"):
		var archetype_name = _archetype_name()
		var tel = get_node("/root/Telemetry")
		tel.log_doctrine_plan(_combat_plan, archetype_name)
		tel.log_doctrine_engage_range(archetype_name, dist)

	if _combat_plan != previous_plan and has_node("/root/Telemetry"):
		var tel = get_node("/root/Telemetry")
		match _combat_plan:
			BOT_DOCTRINE.PLAN_PEEK_COVER:
				_peek_side = _strafe_dir
				tel.log_tactics("cover_peek")
			BOT_DOCTRINE.PLAN_REPOSITION:
				tel.log_tactics("combat_reposition")
			BOT_DOCTRINE.PLAN_KITE:
				tel.log_tactics("combat_kite")

func _apply_combat_movement(delta: float, _can_see: bool, dist: float, pref_range: float, dir_to_target: Vector3):
	var strafe_scale = clamp(0.25 + _awareness_level * 0.16, 0.25, 0.55)
	var strafe = Vector3(-dir_to_target.z, 0, dir_to_target.x) * _strafe_dir
	match _combat_plan:
		BOT_DOCTRINE.PLAN_ADVANCE:
			_move_or_unstick((dir_to_target + strafe * 0.25).normalized(), delta, false)
		BOT_DOCTRINE.PLAN_KITE:
			_move_or_unstick((-dir_to_target + strafe * 0.45).normalized(), delta, false)
		BOT_DOCTRINE.PLAN_PEEK_COVER:
			if _combat_cover == Vector3.ZERO:
				_move_or_unstick(strafe, delta, false)
			elif global_position.distance_to(_combat_cover) > 2.0:
				_nav_move_toward(_combat_cover, delta, true)
			else:
				var peek_dir = strafe * _peek_side
				if _is_peeking_out():
					_move_or_unstick((peek_dir * 0.8 + dir_to_target * 0.15).normalized(), delta, false)
				else:
					_move_or_unstick((-peek_dir * 0.5 - dir_to_target * 0.2).normalized(), delta, false)
		BOT_DOCTRINE.PLAN_REPOSITION:
			if _combat_move_target == Vector3.ZERO or global_position.distance_to(_combat_move_target) < 2.0:
				_combat_plan_timer = 0.0
				_move_or_unstick(strafe * strafe_scale, delta, false)
			else:
				_nav_move_toward(_combat_move_target, delta, false)
		BOT_DOCTRINE.PLAN_HOLD_ANGLE:
			if dist > pref_range * 1.25:
				_move_or_unstick((dir_to_target + strafe * 0.2).normalized(), delta, false)
			elif dist < pref_range * 0.65:
				_move_or_unstick((-dir_to_target + strafe * 0.25).normalized(), delta, false)
			else:
				handle_movement(strafe * 0.2, delta, false)
		_:
			if dist > pref_range * 1.2:
				_move_or_unstick((dir_to_target + strafe * strafe_scale).normalized(), delta, false)
			elif dist < pref_range * 0.55:
				_move_or_unstick((-dir_to_target + strafe * strafe_scale).normalized(), delta, false)
			else:
				_move_or_unstick(strafe * strafe_scale, delta, false)

func _should_fire_for_plan(can_see: bool) -> bool:
	if _combat_plan == BOT_DOCTRINE.PLAN_PEEK_COVER and not _is_peeking_out():
		return false
	if _combat_plan == BOT_DOCTRINE.PLAN_REPOSITION and _combat_move_target != Vector3.ZERO \
			and global_position.distance_to(_combat_move_target) > 3.5:
		return false
	if not can_see and state_timer > 1.1:
		return false
	return true

func _target_hp_ratio() -> float:
	if target_actor is Entity:
		return target_actor.current_health / maxf(1.0, target_actor.stats.max_health)
	return 1.0

func _is_peeking_out() -> bool:
	var offset = float(get_instance_id() % 17) * 0.047
	return fmod(Time.get_ticks_msec() / 1000.0 + offset, 1.25) < 0.55

func _pick_combat_reposition_point(anchor: Vector3, pref_range: float) -> Vector3:
	var to_target = anchor - global_position
	to_target.y = 0
	if to_target.length() < 0.1:
		to_target = -global_transform.basis.z
	to_target = to_target.normalized()
	var side = Vector3(-to_target.z, 0, to_target.x) * _strafe_dir * randf_range(5.0, 8.0)
	var range_adjust = Vector3.ZERO
	var combat = _doctrine_profile.get("combat", {})
	if stats.weapon_type == "shotgun" or bool(combat.get("reposition_forward_bias", false)):
		range_adjust = to_target * randf_range(1.5, 3.5)
	elif global_position.distance_to(anchor) < pref_range:
		range_adjust = -to_target * randf_range(2.0, 4.0)
	var candidate = global_position + side + range_adjust
	return _clamp_to_safe_zone(candidate)

func _clamp_to_safe_zone(pos: Vector3) -> Vector3:
	var main = get_tree().root.get_node_or_null("Main")
	if not main:
		return pos
	var center = main.zone.current_center
	var radius = main.zone.current_radius * 0.85
	var p2 = Vector2(pos.x, pos.z)
	var offset = p2 - center
	if offset.length() > radius:
		p2 = center + offset.normalized() * radius
	return Vector3(p2.x, global_position.y, p2.y)

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

func _update_archetype_marker():
	if not _archetype_marker:
		return
	var name = _archetype_name()
	match name:
		"AGGRESSIVE":
			_archetype_marker.text = _archetype_marker_text("AGG")
			_archetype_marker.modulate = Color(1.0, 0.22, 0.12)
		"DEFENSIVE":
			_archetype_marker.text = _archetype_marker_text("DEF")
			_archetype_marker.modulate = Color(0.25, 0.62, 1.0)
		"SNIPER":
			_archetype_marker.text = _archetype_marker_text("SNP")
			_archetype_marker.modulate = Color(0.88, 0.52, 1.0)
		"OPPORTUNIST":
			_archetype_marker.text = _archetype_marker_text("OPP")
			_archetype_marker.modulate = Color(0.25, 1.0, 0.48)
		_:
			_archetype_marker.text = _archetype_marker_text("BOT")
			_archetype_marker.modulate = Color(1.0, 1.0, 1.0)

func _update_archetype_marker_visibility():
	if not _archetype_marker:
		return
	if not DEBUG_ARCHETYPE_MARKERS or is_dead:
		_archetype_marker.visible = false
		return
	var player = get_tree().get_first_node_in_group("players")
	if not player or not player is Entity:
		_archetype_marker.visible = false
		return
	_update_archetype_marker()
	_archetype_marker.visible = is_revealed_to(player)

func _archetype_marker_text(prefix: String) -> String:
	return "%s %s" % [prefix, _combat_plan_marker()]

func _combat_plan_marker() -> String:
	match _combat_plan:
		BOT_DOCTRINE.PLAN_ADVANCE:
			return "ADV"
		BOT_DOCTRINE.PLAN_KITE:
			return "KITE"
		BOT_DOCTRINE.PLAN_PEEK_COVER:
			return "PEEK"
		BOT_DOCTRINE.PLAN_REPOSITION:
			return "FLK"
		BOT_DOCTRINE.PLAN_HOLD_ANGLE:
			return "HOLD"
		_:
			return "STR"

func _archetype_name() -> String:
	return BotArchetype.keys()[archetype] if archetype >= 0 and archetype < BotArchetype.size() else "AGGRESSIVE"

func _log_doctrine_state_time(delta: float):
	if not has_node("/root/Telemetry"):
		return
	get_node("/root/Telemetry").log_doctrine_state_time(_archetype_name(), State.keys()[current_state], delta)

# ─── DOCTRINE & DIFFICULTY ───────────────────────────────────────────────────

func configure_ai(archetype_id: int, difficulty_params: Dictionary = {}):
	_capture_base_stats()
	_difficulty_params = difficulty_params.duplicate(true)
	_doctrine_profile = BOT_DOCTRINE.build_profile(archetype_id, _difficulty_params)
	archetype = int(_doctrine_profile.get("archetype_id", archetype))
	_apply_doctrine_profile(_doctrine_profile)
	_update_archetype_marker()
	_apply_visual_skin()
	if has_node("/root/Telemetry"):
		get_node("/root/Telemetry").log_doctrine_profile(BOT_DOCTRINE.explain_profile(_doctrine_profile))

func _apply_archetype(p: BotArchetype):
	configure_ai(int(p), _difficulty_params)

func apply_difficulty(params: Dictionary):
	configure_ai(int(archetype), params)

func _capture_base_stats():
	if not stats:
		return
	if _base_attack_range < 0.0:
		_base_attack_range = stats.attack_range
	if _base_vision_range < 0.0:
		_base_vision_range = stats.vision_range

func _apply_doctrine_profile(profile: Dictionary):
	if stats:
		stats.attack_range = _base_attack_range * float(profile.get("attack_range_mult", 1.0))
		stats.vision_range = _base_vision_range * float(profile.get("vision_range_mult", 1.0))
	_disengage_threshold = int(profile.get("disengage_threshold", 2))
	_fire_rate_mult = float(profile.get("fire_rate_mult", 1.0))
	_footstep_range = float(profile.get("footstep_range", 12.0))
	_loot_radius = float(profile.get("loot_radius", 70.0))
	_combat_loot_threshold = float(profile.get("combat_loot_threshold", 0.0))
	_combat_loot_radius = float(profile.get("combat_loot_radius", 15.0))
	_flee_hp_ratio = float(profile.get("flee_hp_ratio", 0.25))
	_sniper_min_engage_range = float(profile.get("sniper_min_engage_range", 0.0))
	_reaction_delay = float(profile.get("reaction_delay", 0.0))
	_aim_spread_mult = float(profile.get("aim_spread_mult", 1.0))
	_awareness_level = int(profile.get("awareness_level", 0))
	_scan_interval_max = float(profile.get("scan_interval_max", 3.0))

func _ensure_doctrine_profile():
	if _doctrine_profile.is_empty():
		configure_ai(int(archetype), _difficulty_params)

func _apply_visual_skin():
	if not BOT_VISUAL_KIT:
		return
	_skin_root = BOT_VISUAL_KIT.apply_skin(self, int(archetype), get_instance_id())
	_sync_visual_skin()

func _sync_visual_skin():
	if not _skin_root:
		return
	_skin_root.visible = has_node("MeshInstance3D") and $MeshInstance3D.visible and not is_dead
	if is_crouching:
		_skin_root.position = Vector3(0.0, 0.08, 0.0)
		_skin_root.scale = Vector3(0.92, 0.72, 0.92)
	else:
		_skin_root.position = Vector3.ZERO
		_skin_root.scale = Vector3.ONE

# ─── LATE GAME SHIFT ─────────────────────────────────────────────────────────
# When alive_count ≤ 3, bots escalate: tighter scans, harder to disengage,
# and actively close on the last known player position when idle.

func _check_late_game():
	if _late_game_applied: return
	var main = get_tree().root.get_node_or_null("Main")
	if not main or main.alive_count > 3: return
	_late_game_applied = true
	_awareness_level    = mini(_awareness_level + 1, 2)
	_disengage_threshold = mini(_disengage_threshold + 1, 4)
	_scan_interval_max  = maxf(_scan_interval_max * 0.5, 0.8)
	_flee_hp_ratio      = maxf(_flee_hp_ratio - 0.05, 0.10)

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
		var eff_range = _footstep_range
		if actor.has_method("get_footstep_radius_mult"):
			eff_range *= actor.get_footstep_radius_mult()
		if dist > eff_range: continue
		if not perception_meters.has(actor): perception_meters[actor] = 0.0
		perception_meters[actor] = min(perception_meters[actor] + 0.4, 0.85)
		last_known_target_pos = actor.global_position
		# Snap idle bots toward sound source at full rotation speed
		if current_state == State.IDLE:
			var dir_to = (actor.global_position - global_position).normalized()
			scan_target_rotation = atan2(dir_to.x, dir_to.z) + PI
			_scan_alert = true

# ─── GUNSHOT SOUND DETECTION ─────────────────────────────────────────────────
# Actors with reveal_timer > 1.7 fired a shot within the last 0.3s.
# Nearby bots orient toward the shooter and gain partial perception.
# Normal: 15m. Hard/Hell: 25m. Does NOT respect Silent Core (gunshots are loud).

func _check_gunshot_sounds():
	var actors = get_tree().get_nodes_in_group("actors")
	for actor in actors:
		if actor == self or not actor is Entity or actor.is_dead: continue
		if actor.reveal_timer <= 1.7: continue  # didn't just fire
		if perception_meters.get(actor, 0.0) >= 0.75: continue
		var dist = global_position.distance_to(actor.global_position)
		var range_limit = 25.0 if _awareness_level >= 2 else 15.0
		if dist > range_limit: continue
		if not perception_meters.has(actor): perception_meters[actor] = 0.0
		perception_meters[actor] = min(perception_meters[actor] + 0.5, 0.75)
		last_known_target_pos = actor.global_position
		var dir_to = (actor.global_position - global_position).normalized()
		scan_target_rotation = atan2(dir_to.x, dir_to.z) + PI
		_scan_alert = true

# ─── CLOSE RANGE INSTANT DETECTION ─────────────────────────────────────────
# Any actor within 2m is immediately fully detected — like bumping into someone.
# Runs every physics frame in all states, regardless of awareness level.

func _check_close_range():
	var actors = get_tree().get_nodes_in_group("actors")
	for actor in actors:
		if actor == self or not actor is Entity or actor.is_dead: continue
		if perception_meters.get(actor, 0.0) >= 1.0: continue
		if global_position.distance_to(actor.global_position) > 2.0: continue
		perception_meters[actor] = 1.0
		last_known_target_pos = actor.global_position
		var dir_to = (actor.global_position - global_position).normalized()
		scan_target_rotation = atan2(dir_to.x, dir_to.z) + PI
		_scan_alert = true

# ─── AMBIENT AWARENESS (사주경계) ─────────────────────────────────────────────
# Periodic 360° range scan in all states. No direction filter — truly omnidirectional.
# Easy: disabled. Normal: running actors at 6m every 3s. Hard+: any actor at 10m every 1.5s.

func _check_ambient_awareness(delta: float):
	if _awareness_level == 0: return
	_ambient_scan_timer -= delta
	if _ambient_scan_timer > 0: return
	_ambient_scan_timer = 3.0 if _awareness_level == 1 else 1.5

	var actors = get_tree().get_nodes_in_group("actors")
	for actor in actors:
		if actor == self or not actor is Entity or actor.is_dead: continue
		if perception_meters.get(actor, 0.0) >= 1.0: continue
		var dist = global_position.distance_to(actor.global_position)
		var spd = Vector2(actor.velocity.x, actor.velocity.z).length()

		if _awareness_level == 1:
			# Normal: running actors within 6m, full 360°
			if dist > 6.0: continue
			if spd < actor.stats.move_speed * 0.5: continue
		else:
			# Hard/Hell: any actor; running extends range
			var range_limit = 10.0 if spd >= actor.stats.move_speed * 0.3 else 5.0
			if dist > range_limit: continue

		if not perception_meters.has(actor): perception_meters[actor] = 0.0
		var boost = 0.2 if _awareness_level == 1 else 0.35
		perception_meters[actor] = min(perception_meters[actor] + boost, 0.75)
		last_known_target_pos = actor.global_position
		if current_state == State.IDLE or current_state == State.RECOVER:
			var dir_to = (actor.global_position - global_position).normalized()
			scan_target_rotation = atan2(dir_to.x, dir_to.z) + PI
			_scan_alert = true

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
		if not can_sense_item(p.global_position): continue
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
	# Per-bot angular sector so multiple bots spread around the same obstacle
	var sector_angle = float(get_instance_id() % 8) * (TAU / 8.0)

	for obs in obstacles:
		if not is_instance_valid(obs): continue
		# Skip obstacles too low to actually provide cover (log_pile, bush_patch, etc.)
		if not _obs_provides_cover(obs): continue

		var obs_pos = Vector3(obs.global_position.x, global_position.y, obs.global_position.z)
		var dist_to_obs = global_position.distance_to(obs_pos)
		if dist_to_obs > 40.0 or dist_to_obs < 0.5: continue

		var threat_to_obs = (obs_pos - threat_pos).normalized()
		threat_to_obs.y = 0
		# Spread cover positions around the obstacle using a per-bot sector offset
		var spread = Vector3(cos(sector_angle), 0, sin(sector_angle)) * 1.5
		var cover = obs_pos + threat_to_obs * 2.0 + spread
		cover.y = global_position.y

		if cover.distance_to(threat_pos) < 5.0: continue

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

	if best_pos == Vector3.ZERO:
		var main = get_tree().root.get_node_or_null("Main")
		if main and main.map_spec:
			for o in main.map_spec.obstacles:
				var type_str = o.get("type", "")
				if type_str == "bush_patch" or type_str == "log_pile": continue
				var scale_vec = o.get("scale", [1, 1, 1])
				if scale_vec[1] < 2.5 and type_str != "tree_cluster" and type_str != "canyon_wall": continue
				var op = o.get("pos", [0, 0])
				var spec_obs_pos = Vector3(op[0], global_position.y, op[1])
				var spec_dist = global_position.distance_to(spec_obs_pos)
				if spec_dist > 40.0 or spec_dist < 0.5: continue
				var spec_threat_to_obs = spec_obs_pos - threat_pos
				spec_threat_to_obs.y = 0
				if spec_threat_to_obs.length() < 0.1: continue
				spec_threat_to_obs = spec_threat_to_obs.normalized()
				var spec_spread = Vector3(cos(sector_angle), 0, sin(sector_angle)) * 1.5
				var spec_cover = spec_obs_pos + spec_threat_to_obs * 2.0 + spec_spread
				spec_cover.y = global_position.y
				if spec_cover.distance_to(threat_pos) < 5.0: continue
				var spec_score = spec_dist + 3.0
				if spec_score < best_score:
					best_score = spec_score
					best_pos = spec_cover

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
	var dist = Vector2(global_position.x, global_position.z).distance_to(main.zone.current_center)
	# Shrink trigger threshold as zone stage rises: 0.95 → 0.80 over stages 1-4.
	# At high stages zone damage is severe, so bots must react before reaching the edge.
	var threshold = 0.95 - min(main.zone.stage - 1, 3) * 0.05
	if dist > main.zone.current_radius * threshold:
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
	var can_still_fight = stats.current_ammo > 0 or reserve_ammo > 0
	match current_state:
		State.ATTACK:
			if not _knife_mode:  # knife rush is an intentional last stand, don't interrupt
				if can_still_fight:
					_retreating_to_reload = reserve_ammo > 0 and stats.current_ammo < stats.max_ammo
					if has_node("/root/Telemetry"):
						get_node("/root/Telemetry").log_tactics("survival_break")
					change_state(State.DISENGAGE)
				else:
					change_state(State.RECOVER)
		State.CHASE:
			if not is_targeting_loot:  # don't cancel a life-saving loot run
				target_actor = null
				if can_still_fight:
					if has_node("/root/Telemetry"):
						get_node("/root/Telemetry").log_tactics("survival_break")
					change_state(State.DISENGAGE)
				else:
					change_state(State.RECOVER)
		State.DISENGAGE:
			if not can_still_fight and state_timer > 1.5:
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
		cx = main.zone.current_center.x
		cz = main.zone.current_center.y
		r = main.zone.current_radius * 0.8
	var angle = randf() * TAU
	var dist  = randf() * r
	return Vector3(cx + cos(angle) * dist, global_position.y, cz + sin(angle) * dist)

func _pick_patrol_target() -> Vector3:
	_ensure_doctrine_profile()
	var main = get_tree().root.get_node_or_null("Main")
	if main and (main.supply_telegraphed or main.supply_spawned) and _should_pursue_supply(main):
		return Vector3(main.supply_pos.x, global_position.y, main.supply_pos.z)
	var patrol_preference = String(_doctrine_profile.get("patrol_preference", "random"))
	if patrol_preference == "bush":
		var bush = _find_nearest_bush()
		if bush != Vector3.ZERO: return bush
	elif patrol_preference == "hotspot":
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
	_ensure_doctrine_profile()
	var actors = get_tree().get_nodes_in_group("actors")
	var best: Entity = null
	var best_score = INF
	var target_profile = _doctrine_profile.get("target", {})
	var distance_weight = float(target_profile.get("distance_weight", 1.0))
	var hp_weight = float(target_profile.get("hp_weight", 0.0))
	for a in actors:
		if a == self or not a is Entity or a.is_dead: continue
		if a.is_revealed_to(self):
			var d = global_position.distance_to(a.global_position)
			if d >= stats.vision_range: continue
			var hp_ratio = a.current_health / maxf(1.0, a.stats.max_health)
			var score = d * (distance_weight + hp_ratio * hp_weight)
			if score < best_score: best_score = score; best = a
	return best

func _find_nearest_pickup(search_radius: float = 35.0) -> Node3D:
	var pickups = get_tree().get_nodes_in_group("pickups")
	var nearest: Node3D = null
	var min_dist = search_radius
	for p in pickups:
		var d = global_position.distance_to(p.global_position)
		if not can_sense_item(p.global_position): continue
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
	_engagement_dmg_dealt += MELEE_DAMAGE  # melee is guaranteed on hit
	var impact = IMPACT_EFFECT_SCN.instantiate()
	get_tree().root.add_child(impact)
	impact.global_position = target_actor.global_position + Vector3(0, 0.8, 0)
	if has_node("/root/Sfx"):
		get_node("/root/Sfx").play("hit", target_actor.global_position)

# ─── DEATH & WEAPON DROP ─────────────────────────────────────────────────────

func die(killer: Node3D = null):
	if _state_label: _state_label.visible = false
	if _archetype_marker: _archetype_marker.visible = false
	if _skin_root: _skin_root.visible = false
	_drop_weapon()
	_drop_ammo()
	_drop_heals()
	super.die(killer)

func get_telemetry_state() -> String:
	return State.keys()[current_state]

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
	item.item_name = _ammo_display_name(stats.weapon_type)
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
		item.item_name = "붕대"
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
		item.item_name = "구급상자"
		item.amount = stats.advanced_heals
		item.color = Color(1.0, 0.88, 0.1)
		var pickup = PICKUP_SCN.instantiate()
		get_tree().root.add_child(pickup)
		pickup.global_position = global_position + Vector3(randf_range(-0.5, 0.5), 0.3, randf_range(-0.5, 0.5))
		pickup.init(item)

func _weapon_display_name(wtype: String) -> String:
	match wtype:
		"pistol":  return "피스톨"
		"ar":      return "돌격소총"
		"shotgun": return "샷건"
		"railgun": return "레일건"
	return wtype.capitalize()

func _ammo_display_name(wtype: String) -> String:
	match wtype:
		"ar":      return "소총 탄"
		"shotgun": return "샷건 탄"
		"railgun": return "레일 탄"
		"pistol":  return "피스톨 탄"
	return wtype.capitalize() + " 탄"

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

	# Track incoming damage for fight-or-flight estimation
	_engagement_dmg_taken += amount
	_last_damage_tick = Time.get_ticks_msec()

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
			or (current_state == State.CHASE and is_targeting_loot)
		if passive:
			target_actor = source_node
			is_targeting_loot = false
			_pending_target = null
			change_state(State.CHASE)
		elif current_state == State.DISENGAGE:
			target_actor = source_node
			last_known_target_pos = source_node.global_position
			if current_health / stats.max_health > 0.55 and _count_visible_enemies() <= 1:
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
	# Estimate damage dealt (55% assumed hit rate — intentionally imprecise)
	if current_state == State.ATTACK and is_instance_valid(target_actor) and target_actor is Entity:
		var pellets = stats.pellet_count if stats.weapon_type == "shotgun" else 1
		_engagement_dmg_dealt += stats.attack_damage * pellets * 0.55

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
	if new_state == State.ATTACK:
		_engagement_dmg_dealt = 0.0
		_engagement_dmg_taken = 0.0
		_combat_plan_timer = 0.0
		_combat_move_target = Vector3.ZERO
		_combat_cover = Vector3.ZERO
		_strafe_timer = 0.0
		_strafe_dir = 1.0 if randf() < 0.5 else -1.0
		_peek_side = _strafe_dir
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
		_recover_cover = Vector3.ZERO
	if new_state == State.DISENGAGE:
		_disengage_cover = Vector3.ZERO
