extends Area3D

const RUSTLE_DECAY := 2.4
const RUSTLE_MOVEMENT_THRESHOLD := 0.65

var _catalog_visual_active := false
var _local_player_inside := false
var _occupants: Array = []
var _rustle_amount := 0.0
var _feedback_material: StandardMaterial3D = null

@onready var _feedback_mesh := $MeshInstance3D as MeshInstance3D

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if get_node_or_null("CatalogPropVisual") != null:
		_catalog_visual_active = true
	_configure_feedback_mesh()

func _on_body_entered(body):
	if not _occupants.has(body):
		_occupants.append(body)
	if body.has_method("enter_bush"):
		body.enter_bush(self)
	elif body.has_method("set_in_bush"):
		body.set_in_bush(true)
	_update_local_player_inside()
	_kick_rustle(1.0)

func _on_body_exited(body):
	_occupants.erase(body)
	if body.has_method("exit_bush"):
		body.exit_bush(self)
	elif body.has_method("set_in_bush"):
		body.set_in_bush(false)
	_update_local_player_inside()
	_kick_rustle(0.65)

func set_catalog_visual_active(active: bool) -> void:
	_catalog_visual_active = active
	_configure_feedback_mesh()
	_update_feedback_visibility()

func debug_state() -> Dictionary:
	return {
		"catalog_visual_active": _catalog_visual_active,
		"local_player_inside": _local_player_inside,
		"occupants": _occupants.size(),
		"rustle_amount": _rustle_amount,
		"feedback_visible": _feedback_mesh != null and _feedback_mesh.visible,
	}

func _process(delta: float) -> void:
	_clean_occupants()
	for body in _occupants:
		if body is CharacterBody3D and body.velocity.length() > RUSTLE_MOVEMENT_THRESHOLD:
			_kick_rustle(0.45)
			break
	_apply_rustle(delta)

func _configure_feedback_mesh() -> void:
	if _feedback_mesh == null:
		_feedback_mesh = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if _feedback_mesh == null:
		return
	if _catalog_visual_active:
		_feedback_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if _feedback_material == null:
			_feedback_material = StandardMaterial3D.new()
			_feedback_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_feedback_material.albedo_color = Color(0.03, 0.07, 0.035, 0.42)
			_feedback_material.roughness = 1.0
		_feedback_mesh.set_surface_override_material(0, _feedback_material)
		_update_feedback_visibility()
	else:
		_feedback_mesh.visible = true

func _update_feedback_visibility() -> void:
	if _feedback_mesh == null:
		return
	if _catalog_visual_active:
		_feedback_mesh.visible = _local_player_inside
	else:
		_feedback_mesh.visible = true

func _update_local_player_inside() -> void:
	_local_player_inside = false
	_clean_occupants()
	for body in _occupants:
		if body.is_in_group("players"):
			_local_player_inside = true
			break
	_update_feedback_visibility()

func _clean_occupants() -> void:
	for i in range(_occupants.size() - 1, -1, -1):
		if not is_instance_valid(_occupants[i]):
			_occupants.remove_at(i)

func _kick_rustle(amount: float) -> void:
	_rustle_amount = clampf(maxf(_rustle_amount, amount), 0.0, 1.0)

func _apply_rustle(delta: float) -> void:
	var visual := _get_rustle_visual()
	if visual == null:
		return
	if _rustle_amount <= 0.001:
		visual.scale = Vector3.ONE
		visual.rotation.x = 0.0
		visual.rotation.z = 0.0
		return

	var phase := Time.get_ticks_msec() * 0.018 + float(get_instance_id() % 23)
	var sway := sin(phase) * _rustle_amount
	var lift: float = abs(cos(phase * 0.8)) * _rustle_amount
	visual.scale = Vector3(1.0 + sway * 0.025, 1.0 + lift * 0.055, 1.0 - sway * 0.02)
	visual.rotation.x = cos(phase * 0.7) * _rustle_amount * 0.035
	visual.rotation.z = sway * 0.035
	_rustle_amount = move_toward(_rustle_amount, 0.0, delta * RUSTLE_DECAY)

func _get_rustle_visual() -> Node3D:
	var catalog_visual := get_node_or_null("CatalogPropVisual") as Node3D
	if catalog_visual:
		return catalog_visual
	return _feedback_mesh
