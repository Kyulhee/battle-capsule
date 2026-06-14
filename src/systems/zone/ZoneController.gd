class_name ZoneController
extends RefCounted

signal stage_advanced(new_stage: int)
signal zone_warning()

var current_center: Vector2 = Vector2.ZERO
var current_radius: float = 50.0
var next_center: Vector2 = Vector2.ZERO
var next_radius: float = 25.0
var stage: int = 1
var timer: float = 0.0
var shrinking: bool = false
var wait_time: float = 30.0
var shrink_time: float = 20.0
var damage_per_second: float = 2.0
var stage_configs: Dictionary = {}

var _center_start: Vector2 = Vector2.ZERO
var _radius_start: float = 50.0
var _outside_time: Dictionary = {}
var _warning_played: bool = false
var _damage_tick_timer: float = 0.0

func configure_initial_zone(initial_radius: float) -> void:
	current_radius = maxf(1.0, initial_radius)
	_radius_start = current_radius

func configure_stage_configs(configs: Dictionary) -> void:
	stage_configs = configs.duplicate(true)

func generate_next(next_radius_override: float = -1.0) -> void:
	if next_radius_override > 0.0:
		next_radius = minf(next_radius_override, current_radius - 0.1)
	else:
		next_radius = current_radius * 0.6
	next_radius = maxf(1.0, next_radius)
	var max_offset = current_radius - next_radius
	var angle = randf() * TAU
	var dist = randf() * max_offset
	next_center = current_center + Vector2(cos(angle), sin(angle)) * dist

func tick_lifecycle(delta: float) -> void:
	timer -= delta
	if timer <= 0:
		if not shrinking:
			shrinking = true
			timer = shrink_time
			_radius_start = current_radius
			_center_start = current_center
		else:
			current_center = next_center
			current_radius = next_radius
			stage += 1
			_apply_stage_config()
			generate_next()
			shrinking = false
			timer = wait_time
			_warning_played = false
			stage_advanced.emit(stage)
	if not shrinking and timer <= 10.0 and not _warning_played:
		_warning_played = true
		zone_warning.emit()
	if shrinking:
		var t = 1.0 - (timer / shrink_time)
		current_radius = lerp(_radius_start, next_radius, t)
		current_center = _center_start.lerp(next_center, t)

func tick_damage(delta: float, actors: Array, mission_tracker, player_ref) -> void:
	_damage_tick_timer += delta
	if _damage_tick_timer < 1.0: return
	_damage_tick_timer = 0.0
	for a in actors:
		if not is_instance_valid(a): continue
		if a is Entity and not a.is_dead:
			var pos_2d = Vector2(a.global_position.x, a.global_position.z)
			var uid = a.get_instance_id()
			var is_out = is_outside(pos_2d)
			if is_out:
				_outside_time[uid] = _outside_time.get(uid, 0.0) + 1.0
				var time_mult = 1.0 + min(_outside_time[uid], 10.0) * 0.1
				a.take_damage(damage_per_second * time_mult, "zone")
			else:
				_outside_time.erase(uid)
			if mission_tracker and a == player_ref:
				mission_tracker.on_player_zone_tick(is_out)
				mission_tracker.on_pressure_zone_tick(is_out, 1.0)

func is_outside(pos_2d: Vector2) -> bool:
	return pos_2d.distance_to(current_center) > current_radius

func get_outside_time(uid: int) -> float:
	return _outside_time.get(uid, 0.0)

func on_entity_died(uid: int) -> void:
	_outside_time.erase(uid)

func _apply_stage_config() -> void:
	var config = _stage_config(stage)
	if config.is_empty():
		return
	wait_time = maxf(1.0, float(config.get("wait_time", wait_time)))
	shrink_time = maxf(1.0, float(config.get("shrink_time", shrink_time)))
	damage_per_second = maxf(0.0, float(config.get("damage_per_second", damage_per_second)))

func _stage_config(stage_index: int) -> Dictionary:
	var exact_key = str(stage_index)
	var config = stage_configs.get(exact_key, stage_configs.get(stage_index, {}))
	if typeof(config) == TYPE_DICTIONARY and not config.is_empty():
		return config
	if stage_index >= 4:
		config = stage_configs.get("4", stage_configs.get(4, {}))
		if typeof(config) == TYPE_DICTIONARY:
			return config
	return {}
