class_name HellEventController
extends RefCounted

signal event_text_requested(message: String, color: Color)

const HellTuningScript = preload("res://src/systems/hell/HellTuning.gd")

const MOD_SCARCITY := 0
const MOD_BARRAGE := 1
const MOD_ALL_AGGRESSIVE := 2

const MODIFIER_DESCRIPTIONS := {
	MOD_SCARCITY: ["아이템 희귀화", "힐·장비 드롭 확률이 크게 낮아집니다"],
	MOD_BARRAGE: ["포격 강화", "포격 범위와 폭탄 수가 크게 늘어납니다"],
	MOD_ALL_AGGRESSIVE: ["전원 경계", "모든 봇이 처음부터 당신을 추적합니다"],
}

var modifier: int = MOD_SCARCITY

var _host: Node = null
var _game_config = null
var _tuning: Dictionary = HellTuningScript.from_game_config(null)
var _telemetry: Node = null
var _overlay: ColorRect = null
var _blackout_timer: float = 0.0
var _blackout_active: bool = false
var _bomb_timer: float = 0.0

static func modifier_description(modifier_value: int) -> Array:
	return MODIFIER_DESCRIPTIONS.get(modifier_value, MODIFIER_DESCRIPTIONS[MOD_SCARCITY])

func configure(game_config_ref) -> void:
	_game_config = game_config_ref
	_tuning = HellTuningScript.from_game_config(game_config_ref)

func start_match(host: Node, modifier_value: int, overlay_parent: Control, telemetry: Node = null) -> void:
	_host = host
	_telemetry = telemetry
	modifier = modifier_value
	_blackout_active = false
	var timers = HellTuningScript.timers(_tuning)
	_blackout_timer = randf_range(float(timers["blackout_initial_min"]), float(timers["blackout_initial_max"]))
	_bomb_timer = float(timers["bomb_initial_timer"])
	_create_overlay(overlay_parent)

func tick(delta: float, match_timer: float, zone_controller) -> void:
	if not _host or not zone_controller:
		return
	if not _blackout_active:
		_blackout_timer -= delta
		if _blackout_timer <= 0.0:
			_trigger_blackout()
	var timers = HellTuningScript.timers(_tuning)
	if match_timer > float(timers["bomb_start_after"]):
		_bomb_timer -= delta
		if _bomb_timer <= 0.0:
			_bomb_timer = randf_range(float(timers["bomb_repeat_min"]), float(timers["bomb_repeat_max"]))
			_start_bombardment(zone_controller)

func clear() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_host = null
	_telemetry = null
	_blackout_active = false

func _create_overlay(parent: Control) -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	if not parent:
		_overlay = null
		return
	_overlay = ColorRect.new()
	_overlay.layout_mode = 1
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.z_index = 10
	parent.add_child(_overlay)

func _trigger_blackout() -> void:
	if _blackout_active or not is_instance_valid(_overlay) or not _host:
		return
	_blackout_active = true
	var blackout = HellTuningScript.blackout(_tuning)
	var timers = HellTuningScript.timers(_tuning)
	var hold = randf_range(float(blackout["hold_min"]), float(blackout["hold_max"]))
	var tw = _host.create_tween()
	tw.tween_property(_overlay, "color:a", float(blackout["fade_in_alpha"]), float(blackout["fade_in_seconds"]))
	tw.tween_interval(hold)
	tw.tween_property(_overlay, "color:a", float(blackout["fade_out_alpha"]), float(blackout["fade_out_seconds"]))
	tw.tween_callback(func():
		_blackout_active = false
		_blackout_timer = randf_range(float(timers["blackout_repeat_min"]), float(timers["blackout_repeat_max"]))
	)
	_log_hell_event("blackout")

func _start_bombardment(zone_controller) -> void:
	if not _host:
		return
	var bomb = HellTuningScript.bombardment(_tuning)
	var event_text_color: Color = bomb["event_text_color"]
	event_text_requested.emit(str(bomb["event_text"]), event_text_color)
	_log_hell_event("bombardment_warned")

	var angle = randf() * TAU
	var dist = randf() * zone_controller.current_radius * float(bomb["center_radius_mult"])
	var center_height = float(bomb["center_height"])
	var center = Vector3(
		zone_controller.current_center.x + cos(angle) * dist,
		center_height,
		zone_controller.current_center.y + sin(angle) * dist
	)

	if modifier == MOD_BARRAGE:
		_start_barrage(center)
	else:
		_start_standard_bombardment(center)

func _start_barrage(center: Vector3) -> void:
	var barrage = HellTuningScript.barrage(_tuning)
	var outer_radius = float(barrage["outer_radius"])
	var pellet_radius = float(barrage["pellet_radius"])
	var pellet_damage = float(barrage["pellet_damage"])
	var pellet_count = int(barrage["pellet_count"])
	var base_delay = float(barrage["base_delay"])
	var pellet_gap = float(barrage["pellet_gap"])
	var outer_color: Color = barrage["outer_color"]
	var pellet_color: Color = barrage["pellet_color"]
	var flash_color: Color = barrage["flash_color"]
	var outer = _make_bomb_disc(outer_radius, outer_color)
	_host.add_child(outer)
	outer.global_position = center

	for i in range(pellet_count):
		var pa = randf() * TAU
		var pr = randf() * outer_radius
		var pos = Vector3(center.x + cos(pa) * pr, center.y, center.z + sin(pa) * pr)
		var disc = _make_bomb_disc(pellet_radius, pellet_color)
		_host.add_child(disc)
		disc.global_position = pos
		var delay = base_delay + i * pellet_gap
		_host.get_tree().create_timer(delay).timeout.connect(func():
			if is_instance_valid(disc):
				disc.queue_free()
			_damage_actors_in_radius(pos, pellet_radius, pellet_damage)
		)

	_host.get_tree().create_timer(base_delay + pellet_count * pellet_gap).timeout.connect(func():
		if is_instance_valid(outer):
			outer.queue_free()
		_flash_overlay(flash_color, float(barrage["flash_duration"]))
		_log_hell_event("bombardment_hit")
	)

func _start_standard_bombardment(center: Vector3) -> void:
	var standard = HellTuningScript.standard(_tuning)
	var zone_radius = float(standard["zone_radius"])
	var bomb_radius = float(standard["bomb_radius"])
	var bomb_damage = float(standard["bomb_damage"])
	var warn_delay = float(standard["warn_delay"])
	var pellet_count = int(standard["pellet_count"])
	var pellet_gap = float(standard["pellet_gap"])
	var marker_color: Color = standard["marker_color"]
	var flash_color: Color = standard["flash_color"]
	for i in range(pellet_count):
		var spread_a = randf() * TAU
		var spread_r = randf_range(0.0, zone_radius)
		var pos = Vector3(
			center.x + cos(spread_a) * spread_r,
			center.y,
			center.z + sin(spread_a) * spread_r
		)
		var disc = _make_bomb_disc(bomb_radius, marker_color)
		_host.add_child(disc)
		disc.global_position = pos
		var fire_at = warn_delay + i * pellet_gap
		_host.get_tree().create_timer(fire_at).timeout.connect(func():
			if is_instance_valid(disc):
				disc.queue_free()
			_damage_actors_in_radius(pos, bomb_radius, bomb_damage)
			_flash_overlay(flash_color, float(standard["flash_duration"]))
		)

	_host.get_tree().create_timer(
		warn_delay + (pellet_count - 1) * pellet_gap + float(standard["completion_delay"])
	).timeout.connect(func():
		_log_hell_event("bombardment_hit")
	)

func _damage_actors_in_radius(pos: Vector3, radius: float, damage: float) -> void:
	if not _host:
		return
	for actor in _host.get_tree().get_nodes_in_group("actors"):
		if not is_instance_valid(actor):
			continue
		if actor is Entity and actor.is_dead:
			continue
		if actor.global_position.distance_to(pos) <= radius:
			actor.take_damage(damage, "zone")

func _flash_overlay(color: Color, duration: float) -> void:
	if not is_instance_valid(_overlay) or not _host:
		return
	_overlay.color = color
	_host.create_tween().tween_property(_overlay, "color:a", 0.0, duration)

func _make_bomb_disc(radius: float, color: Color) -> MeshInstance3D:
	var disc = HellTuningScript.disc(_tuning)
	var marker = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = float(disc["height"])
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g * float(disc["emission_green_mult"]), float(disc["emission_blue"]))
	mat.emission_energy_multiplier = float(disc["emission_energy"])
	mesh.surface_set_material(0, mat)
	marker.mesh = mesh
	return marker

func _log_hell_event(event: String) -> void:
	if _telemetry and _telemetry.has_method("log_hell_event"):
		_telemetry.log_hell_event(event)
