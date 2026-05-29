extends Area3D

const RUSTLE_DECAY := 2.4
const RUSTLE_MOVEMENT_THRESHOLD := 0.65
const CATALOG_VISUAL_ALPHA := 0.66
const CATALOG_VISUAL_ALPHA_INSIDE := 0.34

var _catalog_visual_active := false
var _local_player_inside := false
var _occupants: Array = []
var _rustle_amount := 0.0
var _feedback_material: StandardMaterial3D = null
var _catalog_visual_materials: Array = []

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
	_configure_catalog_visual()
	_update_feedback_visibility()

func debug_state() -> Dictionary:
	return {
		"catalog_visual_active": _catalog_visual_active,
		"local_player_inside": _local_player_inside,
		"occupants": _occupants.size(),
		"rustle_amount": _rustle_amount,
		"feedback_visible": _feedback_mesh != null and _feedback_mesh.visible,
		"catalog_visual_alpha": _catalog_visual_alpha(),
		"catalog_material_count": _catalog_visual_materials.size(),
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
			_feedback_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_feedback_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
			_feedback_material.cull_mode = BaseMaterial3D.CULL_DISABLED
			_feedback_material.albedo_color = Color(0.03, 0.07, 0.035, 0.42)
			_feedback_material.roughness = 1.0
		_feedback_mesh.set_surface_override_material(0, _feedback_material)
		_update_feedback_visibility()
	else:
		_feedback_mesh.visible = true

func _configure_catalog_visual() -> void:
	_catalog_visual_materials.clear()
	var catalog_visual := _get_catalog_visual()
	if catalog_visual == null:
		return
	_configure_catalog_visual_node(catalog_visual)
	_set_catalog_visual_alpha(_catalog_visual_alpha())

func _configure_catalog_visual_node(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh_instance.mesh:
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				var material := _make_catalog_visual_material(mesh_instance, surface_index)
				mesh_instance.set_surface_override_material(surface_index, material)
				_catalog_visual_materials.append(material)
	for child in node.get_children():
		_configure_catalog_visual_node(child)

func _make_catalog_visual_material(mesh_instance: MeshInstance3D, surface_index: int) -> StandardMaterial3D:
	var source: Material = mesh_instance.get_surface_override_material(surface_index)
	if source == null and mesh_instance.mesh:
		source = mesh_instance.mesh.surface_get_material(surface_index)

	var source_color := Color(0.18, 0.30, 0.16, CATALOG_VISUAL_ALPHA)
	if source is BaseMaterial3D:
		var source_base := source as BaseMaterial3D
		source_color = source_base.albedo_color
	if source_color.a <= 0.0:
		source_color.a = CATALOG_VISUAL_ALPHA

	var material := StandardMaterial3D.new()
	material.resource_local_to_scene = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.albedo_color = _normalize_catalog_color(source_color, CATALOG_VISUAL_ALPHA)
	return material

func _normalize_catalog_color(color: Color, alpha: float) -> Color:
	var target := Color(0.18, 0.28, 0.15, alpha)
	return Color(
		lerpf(color.r, target.r, 0.45),
		lerpf(color.g, target.g, 0.35),
		lerpf(color.b, target.b, 0.45),
		alpha
	)

func _set_catalog_visual_alpha(alpha: float) -> void:
	for material in _catalog_visual_materials:
		if material is BaseMaterial3D:
			var c = material.albedo_color
			c.a = alpha
			material.albedo_color = c

func _catalog_visual_alpha() -> float:
	return CATALOG_VISUAL_ALPHA_INSIDE if _local_player_inside else CATALOG_VISUAL_ALPHA

func _update_feedback_visibility() -> void:
	if _feedback_mesh == null:
		return
	if _catalog_visual_active:
		_feedback_mesh.visible = _local_player_inside
		_set_catalog_visual_alpha(_catalog_visual_alpha())
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
	var catalog_visual := _get_catalog_visual()
	if catalog_visual:
		return catalog_visual
	return _feedback_mesh

func _get_catalog_visual() -> Node3D:
	return get_node_or_null("CatalogPropVisual") as Node3D
