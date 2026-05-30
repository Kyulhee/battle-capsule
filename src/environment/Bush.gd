extends Area3D

const RUSTLE_DECAY := 2.4
const RUSTLE_MOVEMENT_THRESHOLD := 0.65
const RUSTLE_MOVE_INTERVAL := 0.16
const RUSTLE_CHUNK_DURATION := 0.44
const RUSTLE_CHUNK_WAVE_DELAY := 0.045
const RUSTLE_ENTER_CHUNKS := 3
const RUSTLE_MOVE_CHUNKS := 2
const RUSTLE_EXIT_CHUNKS := 2
const CATALOG_VISUAL_ALPHA := 0.72
const CATALOG_VISUAL_ALPHA_INSIDE := 0.24
const INTERIOR_TINT_ALPHA := 0.18

var _catalog_visual_active := false
var _local_player_inside := false
var _occupants: Array = []
var _rustle_amount := 0.0
var _rustle_move_cooldown := 0.0
var _feedback_material: StandardMaterial3D = null
var _catalog_visual_materials: Array = []
var _rustle_chunks: Array[Dictionary] = []

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
	_kick_rustle(1.0, body.global_position, RUSTLE_ENTER_CHUNKS)

func _on_body_exited(body):
	_occupants.erase(body)
	if body.has_method("exit_bush"):
		body.exit_bush(self)
	elif body.has_method("set_in_bush"):
		body.set_in_bush(false)
	_update_local_player_inside()
	_kick_rustle(0.65, body.global_position, RUSTLE_EXIT_CHUNKS)

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
		"rustle_chunk_count": _rustle_chunks.size(),
		"active_rustle_chunks": _active_rustle_chunk_count(),
	}

func _process(delta: float) -> void:
	_clean_occupants()
	_rustle_move_cooldown = maxf(0.0, _rustle_move_cooldown - delta)
	for body in _occupants:
		if body is CharacterBody3D and body.velocity.length() > RUSTLE_MOVEMENT_THRESHOLD:
			if _rustle_move_cooldown <= 0.0:
				_kick_rustle(0.45, body.global_position, RUSTLE_MOVE_CHUNKS)
				_rustle_move_cooldown = RUSTLE_MOVE_INTERVAL
			break
	_apply_rustle(delta)

func _configure_feedback_mesh() -> void:
	if _feedback_mesh == null:
		_feedback_mesh = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if _feedback_mesh == null:
		return
	if _catalog_visual_active:
		_feedback_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_configure_feedback_mesh_as_floor_tint()
		if _feedback_material == null:
			_feedback_material = StandardMaterial3D.new()
			_feedback_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_feedback_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_feedback_material.albedo_color = Color(0.015, 0.04, 0.02, INTERIOR_TINT_ALPHA)
			_feedback_material.roughness = 1.0
		_feedback_mesh.set_surface_override_material(0, _feedback_material)
		_update_feedback_visibility()
	else:
		_feedback_mesh.visible = true

func _configure_feedback_mesh_as_floor_tint() -> void:
	if _feedback_mesh == null:
		return
	if not _feedback_mesh.mesh is CylinderMesh:
		return
	var disc := CylinderMesh.new()
	disc.top_radius = 1.5
	disc.bottom_radius = 1.5
	disc.height = 0.035
	disc.radial_segments = 36
	_feedback_mesh.mesh = disc
	_feedback_mesh.position = Vector3(0.0, 0.045, 0.0)

func _configure_catalog_visual() -> void:
	_catalog_visual_materials.clear()
	_rustle_chunks.clear()
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
		_register_rustle_chunk(mesh_instance)
	for child in node.get_children():
		_configure_catalog_visual_node(child)

func _register_rustle_chunk(mesh_instance: MeshInstance3D) -> void:
	_rustle_chunks.append({
		"node": mesh_instance,
		"base_transform": mesh_instance.transform,
		"amount": 0.0,
		"time": 0.0,
		"delay": 0.0,
		"duration": RUSTLE_CHUNK_DURATION,
		"phase": float(_rustle_chunks.size()) * 0.71 + float(get_instance_id() % 19),
	})

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

func _kick_rustle(amount: float, world_pos: Vector3, max_chunks: int) -> void:
	_rustle_amount = clampf(maxf(_rustle_amount, amount), 0.0, 1.0)
	if not _rustle_chunks.is_empty():
		var indexes := _nearest_rustle_chunk_indexes(world_pos, max_chunks)
		for order in range(indexes.size()):
			_activate_rustle_chunk(indexes[order], amount, order)

func _apply_rustle(delta: float) -> void:
	if not _rustle_chunks.is_empty():
		_apply_chunk_rustle(delta)
		return

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

func _nearest_rustle_chunk_indexes(world_pos: Vector3, max_chunks: int) -> Array[int]:
	var candidates: Array[Dictionary] = []
	for i in range(_rustle_chunks.size()):
		var chunk := _rustle_chunks[i]
		var node = chunk.get("node")
		if not is_instance_valid(node):
			continue
		var mesh_node := node as Node3D
		candidates.append({
			"index": i,
			"dist": mesh_node.global_position.distance_squared_to(world_pos),
		})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.get("dist", 0.0)) < float(b.get("dist", 0.0)))

	var result: Array[int] = []
	var count = mini(max_chunks, candidates.size())
	for i in range(count):
		result.append(int(candidates[i].get("index", 0)))
	return result

func _activate_rustle_chunk(index: int, amount: float, order: int) -> void:
	if index < 0 or index >= _rustle_chunks.size():
		return
	var chunk := _rustle_chunks[index]
	var falloff = lerpf(1.0, 0.58, clampf(float(order) / maxf(1.0, float(RUSTLE_ENTER_CHUNKS - 1)), 0.0, 1.0))
	chunk["amount"] = clampf(maxf(float(chunk.get("amount", 0.0)), amount * falloff), 0.0, 1.0)
	chunk["time"] = 0.0
	chunk["delay"] = float(order) * RUSTLE_CHUNK_WAVE_DELAY
	chunk["duration"] = RUSTLE_CHUNK_DURATION + amount * 0.08
	_rustle_chunks[index] = chunk

func _apply_chunk_rustle(delta: float) -> void:
	for i in range(_rustle_chunks.size()):
		var chunk := _rustle_chunks[i]
		var node = chunk.get("node")
		if not is_instance_valid(node):
			continue
		var mesh_node := node as Node3D
		var base_transform: Transform3D = chunk.get("base_transform", Transform3D.IDENTITY)
		var amount := float(chunk.get("amount", 0.0))
		if amount <= 0.001:
			mesh_node.transform = base_transform
			continue

		var delay := maxf(0.0, float(chunk.get("delay", 0.0)) - delta)
		if delay > 0.0:
			chunk["delay"] = delay
			_rustle_chunks[i] = chunk
			continue

		var duration := maxf(0.001, float(chunk.get("duration", RUSTLE_CHUNK_DURATION)))
		var time := float(chunk.get("time", 0.0)) + delta
		var progress := clampf(time / duration, 0.0, 1.0)
		var envelope := sin(progress * PI) * (1.0 - progress * 0.18)
		var active_amount := amount * maxf(0.0, envelope)
		var phase := Time.get_ticks_msec() * 0.018 + float(chunk.get("phase", 0.0))
		var sway := sin(phase) * active_amount
		var lift: float = abs(cos(phase * 0.8)) * active_amount

		var next_transform := base_transform
		next_transform.origin += Vector3(sway * 0.03, lift * 0.06, cos(phase * 0.7) * active_amount * 0.022)
		next_transform.basis = base_transform.basis * Basis.from_euler(Vector3(
			cos(phase * 0.8) * active_amount * 0.035,
			sin(phase * 0.5) * active_amount * 0.018,
			sway * 0.042
		))
		mesh_node.transform = next_transform

		if progress >= 1.0:
			chunk["amount"] = 0.0
			chunk["time"] = 0.0
			chunk["delay"] = 0.0
			mesh_node.transform = base_transform
		else:
			chunk["time"] = time
		_rustle_chunks[i] = chunk

	_rustle_amount = move_toward(_rustle_amount, 0.0, delta * RUSTLE_DECAY)

func _active_rustle_chunk_count() -> int:
	var count := 0
	for chunk in _rustle_chunks:
		if float(chunk.get("amount", 0.0)) > 0.001:
			count += 1
	return count

func _get_rustle_visual() -> Node3D:
	var catalog_visual := _get_catalog_visual()
	if catalog_visual:
		return catalog_visual
	return _feedback_mesh

func _get_catalog_visual() -> Node3D:
	return get_node_or_null("CatalogPropVisual") as Node3D
