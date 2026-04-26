extends CharacterBody3D
class_name Entity

@export var stats: StatsData

signal health_changed(current: float, max: float)
signal shield_changed(current: float, max: float)
signal died

const DEATH_EFFECT = preload("res://src/fx/DeathEffect.tscn")

var current_health: float = 0.0
var current_shield: float = 0.0
var is_dead: bool = false
var last_damage_source: String = "unknown"
var last_damage_weapon: String = ""
var last_damage_dist: float = -1.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# Stealth / Concealment
var is_in_bush: bool = false
var stealth_modifier: float = 1.0
var reveal_timer: float = 0.0

# Perception
var perception_meters: Dictionary = {}

# Assist tracking: attacker node -> last hit timestamp
var damage_history: Dictionary = {}
const ASSIST_WINDOW_MS = 5000 # 5 seconds

func _ready():
	if stats:
		stats = stats.duplicate()
		current_health = stats.max_health
		current_shield = 0.0  # No starting shield — must be gained from armor pickups
		emit_signal("health_changed", current_health, stats.max_health)
		emit_signal("shield_changed", current_shield, stats.max_shield)
	add_to_group("actors")

func _physics_process(delta):
	if is_dead: return
	if reveal_timer > 0:
		reveal_timer -= delta
	if reveal_timer > 0:
		stealth_modifier = 1.0
	elif is_in_bush:
		stealth_modifier = 0.2 if velocity.length() < 0.5 else 0.5
	else:
		stealth_modifier = 1.0
	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()
	_update_perception(delta)

func _update_perception(delta):
	var actors = get_tree().get_nodes_in_group("actors")
	for target in actors:
		if not target is Entity or target == self or target.is_dead:
			if perception_meters.has(target): perception_meters.erase(target)
			continue
		if not perception_meters.has(target): perception_meters[target] = 0.0
		if _can_i_see(target):
			var dwell = target.stats.dwell_time_bush if target.is_in_bush else target.stats.dwell_time_open
			perception_meters[target] = clamp(perception_meters[target] + (delta / dwell), 0.0, 1.0)
		else:
			var decay = stats.detection_decay if perception_meters[target] >= 1.0 else 0.2
			perception_meters[target] = clamp(perception_meters[target] - (delta / decay), 0.0, 1.0)

# Can THIS entity see 'target'? Uses THIS entity's stats for range/FOV.
func _can_i_see(target: Entity) -> bool:
	var dist = global_position.distance_to(target.global_position)
	if dist > stats.vision_range: return false
	if dist > stats.fov_near_range:
		var my_forward = -global_transform.basis.z
		var target_diff = (target.global_position - global_position).normalized()
		if rad_to_deg(acos(clamp(my_forward.dot(target_diff), -1.0, 1.0))) > (stats.fov_angle / 2.0):
			return false
	var effective_range = stats.vision_range * target.stealth_modifier
	if dist > effective_range and dist > stats.fov_near_range: return false
	return has_los_to(target)

# Legacy compatibility: kept so old code calling can_be_seen_by still works
func can_be_seen_by(viewer: Entity) -> bool:
	return viewer._can_i_see(self)

func is_revealed_to(viewer: Entity) -> bool:
	return viewer.perception_meters.has(self) and viewer.perception_meters[self] >= 1.0

func has_los_to(target: Node3D) -> bool:
	var ray = get_node_or_null("RayCast3D")
	if not ray: return true
	ray.target_position = ray.to_local(target.global_position + Vector3(0, 1, 0))
	ray.force_raycast_update()
	return not ray.is_colliding() or ray.get_collider() == target

func reveal(duration: float = 2.0):
	reveal_timer = duration
	stealth_modifier = 1.0

func set_in_bush(value: bool):
	is_in_bush = value

# should_rotate: if false, velocity is applied but rotation is NOT changed.
# Use this for strafing while manually controlling facing direction.
func handle_movement(direction: Vector3, delta: float, should_rotate: bool = true):
	if is_dead: return
	if direction.length() > 0.01:
		velocity.x = lerp(velocity.x, direction.x * stats.move_speed, stats.acceleration * delta)
		velocity.z = lerp(velocity.z, direction.z * stats.move_speed, stats.acceleration * delta)
		if should_rotate:
			rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), stats.rotation_speed * delta)
	else:
		velocity.x = lerp(velocity.x, 0.0, stats.friction * delta)
		velocity.z = lerp(velocity.z, 0.0, stats.friction * delta)

func take_damage(amount: float, source: String = "gun", weapon_type: String = "", source_node: Node3D = null):
	if is_dead: return
	last_damage_source = source
	last_damage_weapon = weapon_type

	if source_node and source_node != self:
		damage_history[source_node] = Time.get_ticks_msec()

	var dist = global_position.distance_to(source_node.global_position) if source_node else -1.0
	last_damage_dist = dist
	if current_shield > 0:
		var s_dmg = min(current_shield, amount)
		current_shield -= s_dmg
		amount -= s_dmg
		shield_changed.emit(current_shield, stats.max_shield)
	if amount > 0:
		current_health -= amount
		health_changed.emit(current_health, stats.max_health)
	if has_node("/root/Telemetry"):
		get_node("/root/Telemetry").log_damage(amount, source, weapon_type, dist)
	flash_hit()
	if current_health <= 0:
		die(source_node)

func flash_hit():
	if is_dead: return
	if has_node("MeshInstance3D"):
		var mesh = $MeshInstance3D
		var mat = mesh.get_surface_override_material(0)
		if not mat: mat = mesh.mesh.surface_get_material(0)
		if mat:
			var h_mat = mat.duplicate()
			h_mat.albedo_color = Color(1, 0.4, 0.4)
			mesh.set_surface_override_material(0, h_mat)
			create_tween().tween_interval(0.1).finished.connect(
				func(): if not is_dead: mesh.set_surface_override_material(0, mat)
			)

func die(killer: Node3D = null):
	if is_dead: return
	is_dead = true
	velocity = Vector3.ZERO
	$CollisionShape3D.set_deferred("disabled", true)
	
	if has_node("/root/Telemetry"):
		var tel = get_node("/root/Telemetry")
		# Log Death
		tel.log_death(last_damage_source, "match_end")
		
		# Kill — log only when killer is confirmed to be the player
		if killer and killer.is_in_group("players"):
			tel.log_kill(last_damage_source, last_damage_weapon, last_damage_dist)

		# Assists (player dealt damage but didn't land the final shot)
		var now = Time.get_ticks_msec()
		for attacker in damage_history:
			if is_instance_valid(attacker) and attacker != killer:
				if now - damage_history[attacker] <= ASSIST_WINDOW_MS:
					if attacker.is_in_group("players"):
						tel.log_combat_audit("assists", 1)
	
	if has_node("/root/Sfx"): get_node("/root/Sfx").play("death", global_position)
	var eff = DEATH_EFFECT.instantiate()
	get_tree().root.add_child(eff)
	eff.global_position = global_position + Vector3(0, 1, 0)
	emit_signal("died")
