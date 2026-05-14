class_name HellEventController
extends RefCounted

signal event_text_requested(message: String, color: Color)

const MOD_SCARCITY := 0
const MOD_BARRAGE := 1
const MOD_ALL_AGGRESSIVE := 2

const MODIFIER_DESCRIPTIONS := {
	MOD_SCARCITY: ["아이템 희귀화", "힐·장비 드롭 확률이 크게 낮아집니다"],
	MOD_BARRAGE: ["포격 강화", "포격 범위와 폭탄 수가 크게 늘어납니다"],
	MOD_ALL_AGGRESSIVE: ["전원 경계", "모든 봇이 처음부터 당신을 추적합니다"],
}

const BARRAGE_OUTER_RADIUS := 14.0
const BARRAGE_PELLET_RADIUS := 2.5
const BARRAGE_PELLET_DAMAGE := 22.0
const BARRAGE_PELLET_COUNT := 10
const BARRAGE_BASE_DELAY := 0.7
const BARRAGE_PELLET_GAP := 0.06

# Standard bombardment stays low-damage until bot dodge AI exists.
const STANDARD_ZONE_RADIUS := 15.0
const STANDARD_BOMB_RADIUS := 3.0
const STANDARD_BOMB_DAMAGE := 18.0
const STANDARD_WARN_DELAY := 1.5
const STANDARD_PELLET_COUNT := 10
const STANDARD_PELLET_GAP := 0.18

var modifier: int = MOD_SCARCITY

var _host: Node = null
var _game_config = null
var _telemetry: Node = null
var _overlay: ColorRect = null
var _blackout_timer: float = 0.0
var _blackout_active: bool = false
var _bomb_timer: float = 0.0

static func modifier_description(modifier_value: int) -> Array:
	return MODIFIER_DESCRIPTIONS.get(modifier_value, MODIFIER_DESCRIPTIONS[MOD_SCARCITY])

func configure(game_config_ref) -> void:
	_game_config = game_config_ref

func start_match(host: Node, modifier_value: int, overlay_parent: Control, telemetry: Node = null) -> void:
	_host = host
	_telemetry = telemetry
	modifier = modifier_value
	_blackout_active = false
	_blackout_timer = _hell_range("blackout_initial_min", "blackout_initial_max", 12.0, 20.0)
	_bomb_timer = _hell_value("bomb_initial_timer", 20.0)
	_create_overlay(overlay_parent)

func tick(delta: float, match_timer: float, zone_controller) -> void:
	if not _host or not zone_controller:
		return
	if not _blackout_active:
		_blackout_timer -= delta
		if _blackout_timer <= 0.0:
			_trigger_blackout()
	if match_timer > 10.0:
		_bomb_timer -= delta
		if _bomb_timer <= 0.0:
			_bomb_timer = _hell_range("bomb_repeat_min", "bomb_repeat_max", 18.0, 28.0)
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
	var hold = randf_range(2.0, 4.0)
	var tw = _host.create_tween()
	tw.tween_property(_overlay, "color:a", 0.88, 0.3)
	tw.tween_interval(hold)
	tw.tween_property(_overlay, "color:a", 0.0, 0.5)
	tw.tween_callback(func():
		_blackout_active = false
		_blackout_timer = _hell_range("blackout_repeat_min", "blackout_repeat_max", 15.0, 28.0)
	)
	_log_hell_event("blackout")

func _start_bombardment(zone_controller) -> void:
	if not _host:
		return
	event_text_requested.emit("BOMBARDMENT INCOMING", Color(1.0, 0.35, 0.0))
	_log_hell_event("bombardment_warned")

	var angle = randf() * TAU
	var dist = randf() * zone_controller.current_radius * 0.85
	var center = Vector3(
		zone_controller.current_center.x + cos(angle) * dist,
		0.05,
		zone_controller.current_center.y + sin(angle) * dist
	)

	if modifier == MOD_BARRAGE:
		_start_barrage(center)
	else:
		_start_standard_bombardment(center)

func _start_barrage(center: Vector3) -> void:
	var outer = _make_bomb_disc(BARRAGE_OUTER_RADIUS, Color(1.0, 0.1, 0.1, 0.3))
	_host.add_child(outer)
	outer.global_position = center

	for i in range(BARRAGE_PELLET_COUNT):
		var pa = randf() * TAU
		var pr = randf() * BARRAGE_OUTER_RADIUS
		var pos = Vector3(center.x + cos(pa) * pr, 0.05, center.z + sin(pa) * pr)
		var disc = _make_bomb_disc(BARRAGE_PELLET_RADIUS, Color(1.0, 0.45, 0.0, 0.75))
		_host.add_child(disc)
		disc.global_position = pos
		var delay = BARRAGE_BASE_DELAY + i * BARRAGE_PELLET_GAP
		_host.get_tree().create_timer(delay).timeout.connect(func():
			if is_instance_valid(disc):
				disc.queue_free()
			_damage_actors_in_radius(pos, BARRAGE_PELLET_RADIUS, BARRAGE_PELLET_DAMAGE)
		)

	_host.get_tree().create_timer(BARRAGE_BASE_DELAY + BARRAGE_PELLET_COUNT * BARRAGE_PELLET_GAP).timeout.connect(func():
		if is_instance_valid(outer):
			outer.queue_free()
		_flash_overlay(Color(0.9, 0.3, 0.0, 0.5), 0.3)
		_log_hell_event("bombardment_hit")
	)

func _start_standard_bombardment(center: Vector3) -> void:
	for i in range(STANDARD_PELLET_COUNT):
		var spread_a = randf() * TAU
		var spread_r = randf_range(0.0, STANDARD_ZONE_RADIUS)
		var pos = Vector3(
			center.x + cos(spread_a) * spread_r,
			0.05,
			center.z + sin(spread_a) * spread_r
		)
		var disc = _make_bomb_disc(STANDARD_BOMB_RADIUS, Color(1.0, 0.1, 0.1, 0.55))
		_host.add_child(disc)
		disc.global_position = pos
		var fire_at = STANDARD_WARN_DELAY + i * STANDARD_PELLET_GAP
		_host.get_tree().create_timer(fire_at).timeout.connect(func():
			if is_instance_valid(disc):
				disc.queue_free()
			_damage_actors_in_radius(pos, STANDARD_BOMB_RADIUS, STANDARD_BOMB_DAMAGE)
			_flash_overlay(Color(0.9, 0.3, 0.0, 0.4), 0.25)
		)

	_host.get_tree().create_timer(
		STANDARD_WARN_DELAY + (STANDARD_PELLET_COUNT - 1) * STANDARD_PELLET_GAP + 0.05
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
	var marker = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.12
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g * 0.4, 0.0)
	mat.emission_energy_multiplier = 1.2
	mesh.surface_set_material(0, mat)
	marker.mesh = mesh
	return marker

func _hell_range(min_key: String, max_key: String, fallback_min: float, fallback_max: float) -> float:
	if not _game_config:
		return randf_range(fallback_min, fallback_max)
	var a = float(_game_config.hell_value(min_key, fallback_min))
	var b = float(_game_config.hell_value(max_key, fallback_max))
	return randf_range(minf(a, b), maxf(a, b))

func _hell_value(key: String, fallback: float) -> float:
	return float(_game_config.hell_value(key, fallback)) if _game_config else fallback

func _log_hell_event(event: String) -> void:
	if _telemetry and _telemetry.has_method("log_hell_event"):
		_telemetry.log_hell_event(event)
