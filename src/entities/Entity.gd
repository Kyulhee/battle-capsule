extends CharacterBody3D
class_name Entity

@export var stats: StatsData

signal health_changed(current: float, max: float)
signal shield_changed(current: float, max: float)
signal died

const DEATH_EFFECT = preload("res://src/fx/DeathEffect.tscn")
const ITEM_LOS_MASK: int = 1 | 8
const PERCEPTION_UPDATE_INTERVAL_DEFAULT := 0.08
const PERCEPTION_UPDATE_INTERVAL_PLAYER := 0.05
const NEARBY_ACTOR_CACHE_RANGE := 3.0
const NIGHT_AWARENESS_THEME_PREFIX := "night_artificial_forest"
const NIGHT_AWARENESS_DARK_RANGE_MULT := 0.86
const NIGHT_AWARENESS_SIGNATURE_RANGE_BONUS := 0.18
const NIGHT_AWARENESS_REVEAL_RANGE_MULT := 1.12
const NIGHT_AWARENESS_DARK_DWELL_MULT := 1.15
const NIGHT_AWARENESS_SIGNATURE_DWELL_RELIEF := 0.10
const NIGHT_AWARENESS_REVEAL_DWELL_MULT := 0.75

var display_name: String = ""
var kill_streak: int = 0

var current_health: float = 0.0
var current_shield: float = 0.0
var is_dead: bool = false
var last_damage_source: String = "unknown"
var last_damage_weapon: String = ""
var last_damage_dist: float = -1.0
var last_killer: Node3D = null
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# Stealth / Concealment
var is_in_bush: bool = false
var stealth_modifier: float = 1.0
var reveal_timer: float = 0.0
var _bush_areas: Array = []

# Perception
var perception_meters: Dictionary = {}
var _nearby_actors: Array = []
var _perception_timer: float = 0.0
var _perception_accumulated_delta: float = 0.0
var _night_awareness_checked: bool = false
var _night_awareness_active: bool = false

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
	_update_perception_lod(delta)

func _update_perception_lod(delta: float) -> void:
	_perception_accumulated_delta += delta
	_perception_timer -= delta
	if _perception_timer > 0.0:
		return
	var perception_delta := _perception_accumulated_delta
	_perception_accumulated_delta = 0.0
	_perception_timer = maxf(0.0, _perception_update_interval())
	_update_perception(perception_delta)

func _perception_update_interval() -> float:
	if is_in_group("players"):
		return PERCEPTION_UPDATE_INTERVAL_PLAYER
	return PERCEPTION_UPDATE_INTERVAL_DEFAULT

func _update_perception(delta):
	var actors = get_tree().get_nodes_in_group("actors")
	var cache_nearby_actors := _should_cache_nearby_actors()
	_nearby_actors.clear()
	for target in actors:
		if not target is Entity or target == self or target.is_dead:
			if perception_meters.has(target): perception_meters.erase(target)
			continue
		var can_see_target := _can_i_see(target)
		if cache_nearby_actors and can_see_target \
				and global_position.distance_squared_to(target.global_position) \
				<= NEARBY_ACTOR_CACHE_RANGE * NEARBY_ACTOR_CACHE_RANGE:
			_nearby_actors.append(target)
		if not perception_meters.has(target): perception_meters[target] = 0.0
		var before = float(perception_meters[target])
		if can_see_target:
			var dwell := _perception_dwell_for(target)
			perception_meters[target] = clamp(perception_meters[target] + (delta / dwell), 0.0, 1.0)
		else:
			var decay = stats.detection_decay if perception_meters[target] >= 1.0 else 0.2
			perception_meters[target] = clamp(perception_meters[target] - (delta / decay), 0.0, 1.0)
		if before < 1.0 and float(perception_meters[target]) >= 1.0:
			_debug_log("perception", "%s revealed %s" % [_debug_name(), target._debug_name()])


func _should_cache_nearby_actors() -> bool:
	return false


# Can THIS entity see 'target'? Uses THIS entity's stats for range/FOV.
func _can_i_see(target: Entity) -> bool:
	var dist = global_position.distance_to(target.global_position)
	if dist > stats.vision_range: return false
	if dist > stats.fov_near_range:
		var my_forward = -global_transform.basis.z
		var target_diff = (target.global_position - global_position).normalized()
		if rad_to_deg(acos(clamp(my_forward.dot(target_diff), -1.0, 1.0))) > (stats.fov_angle / 2.0):
			return false
	var same_bush := is_in_same_bush_as(target)
	if target.is_in_bush and not same_bush and target.reveal_timer <= 0.0 and dist > stats.fov_near_range:
		return false
	var target_stealth := 1.0 if same_bush or target.reveal_timer > 0.0 else target.stealth_modifier
	var effective_range = stats.vision_range * target_stealth * _night_awareness_range_mult(target)
	if dist > effective_range and dist > stats.fov_near_range: return false
	return has_los_to(target)

func _perception_dwell_for(target: Entity) -> float:
	var dwell := target.stats.dwell_time_open
	if target.is_in_bush and not is_in_same_bush_as(target):
		dwell = target.stats.dwell_time_bush
	return dwell * _night_awareness_dwell_mult(target)

func _night_awareness_range_mult(target: Entity) -> float:
	if not _uses_abstract_night_awareness() or target == null:
		return 1.0
	if target.reveal_timer > 0.0:
		return NIGHT_AWARENESS_REVEAL_RANGE_MULT
	var signature := clampf(target.get_night_awareness_signature(), 0.0, 1.0)
	return clampf(
		NIGHT_AWARENESS_DARK_RANGE_MULT + signature * NIGHT_AWARENESS_SIGNATURE_RANGE_BONUS,
		NIGHT_AWARENESS_DARK_RANGE_MULT,
		1.02
	)

func _night_awareness_dwell_mult(target: Entity) -> float:
	if not _uses_abstract_night_awareness() or target == null:
		return 1.0
	if target.reveal_timer > 0.0:
		return NIGHT_AWARENESS_REVEAL_DWELL_MULT
	var signature := clampf(target.get_night_awareness_signature(), 0.0, 1.0)
	return clampf(
		NIGHT_AWARENESS_DARK_DWELL_MULT - signature * NIGHT_AWARENESS_SIGNATURE_DWELL_RELIEF,
		1.05,
		NIGHT_AWARENESS_DARK_DWELL_MULT
	)

func get_night_awareness_signature() -> float:
	if not stats:
		return 0.0
	if reveal_timer > 0.0:
		return 1.0
	var speed := Vector2(velocity.x, velocity.z).length()
	return 0.35 if speed >= stats.move_speed * 0.5 else 0.0

func _uses_abstract_night_awareness() -> bool:
	return is_in_group("bots") and _is_night_awareness_map()

func _is_night_awareness_map() -> bool:
	if _night_awareness_checked:
		return _night_awareness_active
	_night_awareness_checked = true
	_night_awareness_active = false
	var main = get_tree().root.get_node_or_null("Main") if is_inside_tree() else null
	if not main:
		return false
	var metadata: Dictionary = {}
	var current_map_spec = main.get("map_spec")
	if current_map_spec != null:
		var raw_metadata = current_map_spec.get("metadata")
		if typeof(raw_metadata) == TYPE_DICTIONARY:
			metadata = raw_metadata
	if metadata.is_empty():
		metadata["id"] = String(main.get("map_spec_path"))
	var theme := String(metadata.get("theme", "")).strip_edges().to_lower()
	var id := String(metadata.get("id", "")).to_lower()
	var layout := String(metadata.get("layout", "")).to_lower()
	_night_awareness_active = theme.begins_with(NIGHT_AWARENESS_THEME_PREFIX) \
		or id.contains("night") \
		or layout.contains("night")
	return _night_awareness_active

func debug_night_awareness_for(target: Entity) -> Dictionary:
	return {
		"active": _uses_abstract_night_awareness(),
		"range_mult": _night_awareness_range_mult(target),
		"dwell_mult": _night_awareness_dwell_mult(target),
		"target_signature": target.get_night_awareness_signature() if target != null else 0.0,
	}

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

func can_sense_item(world_pos: Vector3) -> bool:
	if not stats:
		return false
	return can_sense_world_point(world_pos, stats.fov_near_range, stats.vision_range, stats.fov_angle)

func can_sense_world_point(world_pos: Vector3, near_range: float, far_range: float, fov_angle_deg: float) -> bool:
	var eye_pos = global_position + Vector3(0, 0.8, 0)
	var item_pos = world_pos + Vector3(0, 0.35, 0)
	var flat_to_item = item_pos - eye_pos
	flat_to_item.y = 0.0
	var dist = flat_to_item.length()
	if dist > far_range:
		return false
	if dist > near_range:
		var forward = -global_transform.basis.z
		forward.y = 0.0
		if forward.length_squared() < 0.001 or flat_to_item.length_squared() < 0.001:
			return false
		forward = forward.normalized()
		var dir = flat_to_item.normalized()
		var angle = rad_to_deg(acos(clamp(forward.dot(dir), -1.0, 1.0)))
		if angle > fov_angle_deg * 0.5:
			return false
	return _has_los_to_point(eye_pos, item_pos)

func _has_los_to_point(from: Vector3, to: Vector3) -> bool:
	var query = PhysicsRayQueryParameters3D.create(from, to, ITEM_LOS_MASK)
	query.exclude = [get_rid()]
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty()

func reveal(duration: float = 2.0):
	reveal_timer = duration
	stealth_modifier = 1.0

func set_in_bush(value: bool):
	is_in_bush = value
	if not value:
		_bush_areas.clear()

func enter_bush(bush_area: Node) -> void:
	if bush_area != null and not _bush_areas.has(bush_area):
		_bush_areas.append(bush_area)
	set_in_bush(not _bush_areas.is_empty())

func exit_bush(bush_area: Node) -> void:
	if bush_area != null:
		_bush_areas.erase(bush_area)
	_clean_bush_areas()
	set_in_bush(not _bush_areas.is_empty())

func is_in_same_bush_as(target: Entity) -> bool:
	if target == null or not is_in_bush or not target.is_in_bush:
		return false
	_clean_bush_areas()
	target._clean_bush_areas()
	for bush_area in _bush_areas:
		if target._bush_areas.has(bush_area):
			return true
	return false

func _clean_bush_areas() -> void:
	for i in range(_bush_areas.size() - 1, -1, -1):
		if not is_instance_valid(_bush_areas[i]):
			_bush_areas.remove_at(i)

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
		var tel = get_node("/root/Telemetry")
		tel.log_damage(amount, source, weapon_type, dist)
		if tel.has_method("log_combat_location") and _is_combat_damage_source(source):
			tel.log_combat_location("damage", amount, _strategic_position_context(global_position))
		_debug_log("damage", "%s took %.1f source=%s weapon=%s shield=%.1f hp=%.1f dist=%.1f" % [
		_debug_name(),
		amount,
		source,
		weapon_type,
		current_shield,
		current_health,
		dist,
	])
	# Knockback impulse (applied even when shielded — feel the hit)
	if source_node and is_instance_valid(source_node) and source_node != self:
		var kb := 0.0
		match weapon_type:
			"ar":      kb = 4.0
			"railgun": kb = 8.0
			"knife":   kb = 6.0
			"shotgun": kb = 18.0 * max(0.0, 1.0 - min(dist if dist >= 0 else 0.0, 8.0) / 8.0)
		if kb > 0.0:
			var kb_dir = global_position - source_node.global_position
			kb_dir.y = 0.0
			if kb_dir.length() > 0.05:
				velocity += kb_dir.normalized() * kb
	flash_hit()
	_spawn_damage_number(amount, source)
	if current_health <= 0:
		die(source_node)

func get_telemetry_state() -> String:
	return ""

func _debug_name() -> String:
	return display_name if display_name != "" else name

func _debug_log(flag: String, message: String) -> void:
	var main = get_tree().root.get_node_or_null("Main")
	if main and main.has_method("debug_log"):
		main.debug_log(flag, message)

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

func _spawn_damage_number(amount: float, source: String = ""):
	if amount <= 0: return
	if not is_inside_tree(): return
	var lbl = Label3D.new()
	lbl.text = "-%d" % int(amount)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.double_sided = true
	lbl.font_size = 48
	lbl.pixel_size = 0.005
	lbl.outline_size = 3
	var col = Color(1.0, 0.28, 0.15) if source == "gun" else Color(1.0, 0.60, 0.1)
	lbl.modulate = col
	lbl.outline_modulate = Color(col.r * 0.3, col.g * 0.1, 0.0, 1.0)
	get_tree().root.add_child(lbl)
	lbl.global_position = global_position + Vector3(randf_range(-0.25, 0.25), 2.0, randf_range(-0.25, 0.25))
	var tween = lbl.create_tween()
	tween.tween_property(lbl, "position:y", lbl.position.y + 1.4, 0.85)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.85)
	tween.tween_callback(lbl.queue_free)

func die(killer: Node3D = null):
	if is_dead: return
	is_dead = true
	last_killer = killer
	velocity = Vector3.ZERO
	$CollisionShape3D.set_deferred("disabled", true)
	kill_streak = 0  # victim's streak resets
	if killer and killer is Entity:
		killer.kill_streak += 1  # killer extends their streak

	if has_node("/root/Telemetry"):
		var tel = get_node("/root/Telemetry")
		# Log Death
		tel.log_death(last_damage_source, get_telemetry_state())
		if killer and killer is Entity and tel.has_method("log_combat_location") and _is_combat_damage_source(last_damage_source):
			tel.log_combat_location("kill", 1.0, _strategic_position_context(global_position))
		
		# Kill — log only when killer is confirmed to be the player
		if killer and killer.is_in_group("players"):
			tel.log_kill(last_damage_source, last_damage_weapon, last_damage_dist)

		# Assists (player dealt damage but didn't land the final shot)
		var now = Time.get_ticks_msec()
		for attacker in damage_history:
			if is_instance_valid(attacker) and attacker != killer:
				if now - damage_history[attacker] <= ASSIST_WINDOW_MS:
					if attacker.is_in_group("players"):
						tel.metrics.session.assists += 1
	
	if has_node("/root/Sfx"): get_node("/root/Sfx").play("death", global_position)
	var eff = DEATH_EFFECT.instantiate()
	get_tree().root.add_child(eff)
	eff.global_position = global_position + Vector3(0, 1, 0)
	emit_signal("died")

func _is_combat_damage_source(source: String) -> bool:
	return source == "gun" or source == "melee"

func _strategic_position_context(world_pos: Vector3) -> Dictionary:
	var context := {
		"poi_role": "open",
		"poi_name": "none",
		"route_role": "off_route",
		"route_id": "off_route",
	}
	var main = get_tree().root.get_node_or_null("Main")
	if not main:
		return context
	var definition = main.get("map_definition")
	if definition and definition.has_method("describe_strategic_position"):
		return definition.describe_strategic_position(Vector2(world_pos.x, world_pos.z))
	return context
