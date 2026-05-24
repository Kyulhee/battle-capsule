extends RefCounted

const PlayerTuningScript = preload("res://src/entities/player/PlayerTuning.gd")

var _fade_states: Dictionary = {}

func tick(player_node: Node3D, camera: Camera3D, delta: float) -> void:
	if not player_node or not camera:
		restore_all()
		return

	var cam_pos = camera.global_position
	var space_state = player_node.get_world_3d().direct_space_state
	var active_meshes: Dictionary = {}
	for target_pos in _get_sample_points(player_node, camera):
		_trace_occluders(player_node, space_state, cam_pos, target_pos, active_meshes)

	_update_fades(active_meshes, delta)

func restore_all() -> void:
	var meshes = _fade_states.keys()
	for mesh in meshes:
		_restore(mesh)

func _get_sample_points(player_node: Node3D, camera: Camera3D) -> Array:
	var right = camera.global_transform.basis.x
	right.y = 0.0
	if right.length_squared() < 0.001:
		right = Vector3.RIGHT
	right = right.normalized()

	var base = player_node.global_position
	return [
		base + Vector3(0.0, 1.45, 0.0),
		base + Vector3(0.0, 1.00, 0.0),
		base + Vector3(0.0, 0.95, 0.0) + right * 0.38,
		base + Vector3(0.0, 0.95, 0.0) - right * 0.38,
		base + Vector3(0.0, 0.45, 0.0),
	]

func _trace_occluders(player_node: Node3D, space_state: PhysicsDirectSpaceState3D, ray_start: Vector3, target_pos: Vector3, active_meshes: Dictionary) -> void:
	var ray_delta = target_pos - ray_start
	if ray_delta.length_squared() < 0.001:
		return
	var dir = ray_delta.normalized()
	var ray_from = ray_start
	var exclude: Array = [player_node]
	for _i in range(PlayerTuningScript.OCCLUDER_MAX_RAY_HITS):
		var query = PhysicsRayQueryParameters3D.create(ray_from, target_pos)
		query.exclude = exclude
		query.collision_mask = 1
		var result = space_state.intersect_ray(query)
		if not result:
			break
		var collider = result.get("collider")
		for mesh in _get_occluder_meshes(collider):
			active_meshes[mesh] = true
		if collider is CollisionObject3D:
			exclude.append(collider)
		ray_from = result["position"] + dir * PlayerTuningScript.OCCLUDER_RAY_STEP
		if ray_from.distance_squared_to(target_pos) <= PlayerTuningScript.OCCLUDER_RAY_STEP * PlayerTuningScript.OCCLUDER_RAY_STEP:
			break

func _get_occluder_meshes(collider) -> Array:
	var meshes: Array = []
	if not collider is Node:
		return meshes
	var node: Node = collider
	var checks: Array = [node]
	var parent = node.get_parent()
	if parent:
		checks.append(parent)
	for check in checks:
		if check and check.is_in_group("occluder"):
			_append_mesh_instances(check, meshes)
	return meshes

func _append_mesh_instances(node: Node, out: Array) -> void:
	if node is MeshInstance3D and is_instance_valid(node):
		out.append(node)
	for child in node.get_children():
		_append_mesh_instances(child, out)

func _update_fades(active_meshes: Dictionary, delta: float) -> void:
	for mesh in active_meshes.keys():
		if not is_instance_valid(mesh):
			continue
		var state = _get_or_create_state(mesh)
		if state.is_empty():
			continue
		state["linger"] = PlayerTuningScript.OCCLUDER_FADE_LINGER
		_fade_states[mesh] = state

	var to_restore: Array = []
	for mesh in _fade_states.keys():
		if not is_instance_valid(mesh):
			to_restore.append(mesh)
			continue

		var state: Dictionary = _fade_states[mesh]
		var active = active_meshes.has(mesh)
		if not active:
			state["linger"] = maxf(0.0, float(state.get("linger", 0.0)) - delta)

		var original_alpha = float(state.get("original_alpha", 1.0))
		var target_alpha = PlayerTuningScript.OCCLUDER_FADE_ALPHA if active or float(state.get("linger", 0.0)) > 0.0 else original_alpha
		var current_alpha = float(state.get("alpha", original_alpha))
		var speed = PlayerTuningScript.OCCLUDER_FADE_IN_SPEED if target_alpha < current_alpha else PlayerTuningScript.OCCLUDER_FADE_OUT_SPEED
		var next_alpha = lerpf(current_alpha, target_alpha, minf(1.0, speed * delta))

		state["alpha"] = next_alpha
		_apply_fade_material(mesh, state, next_alpha)
		_fade_states[mesh] = state

		if not active and float(state.get("linger", 0.0)) <= 0.0 and absf(next_alpha - original_alpha) <= 0.02:
			to_restore.append(mesh)

	for mesh in to_restore:
		_restore(mesh)

func _get_or_create_state(mesh: MeshInstance3D) -> Dictionary:
	if _fade_states.has(mesh):
		return _fade_states[mesh]

	var original_override = mesh.get_surface_override_material(0)
	var source_mat: Material = original_override
	if not source_mat and mesh.mesh:
		source_mat = mesh.mesh.surface_get_material(0)

	var original_alpha = 1.0
	if source_mat is BaseMaterial3D:
		original_alpha = source_mat.albedo_color.a

	var fade_mat: Material = null
	if source_mat:
		fade_mat = source_mat.duplicate()
	if not fade_mat or not (fade_mat is BaseMaterial3D):
		var fallback = StandardMaterial3D.new()
		fallback.albedo_color = Color(0.42, 0.42, 0.42, original_alpha)
		fade_mat = fallback

	if fade_mat is BaseMaterial3D:
		fade_mat.resource_local_to_scene = true
		fade_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var c = fade_mat.albedo_color
		c.a = original_alpha
		fade_mat.albedo_color = c

	return {
		"had_override": original_override != null,
		"original_override": original_override,
		"original_alpha": original_alpha,
		"fade_mat": fade_mat,
		"alpha": original_alpha,
		"linger": 0.0,
	}

func _apply_fade_material(mesh: MeshInstance3D, state: Dictionary, alpha: float) -> void:
	var fade_mat = state.get("fade_mat")
	if not fade_mat:
		return
	if fade_mat is BaseMaterial3D:
		var c = fade_mat.albedo_color
		c.a = alpha
		fade_mat.albedo_color = c
	mesh.set_surface_override_material(0, fade_mat)

func _restore(mesh) -> void:
	if not _fade_states.has(mesh):
		return
	var state: Dictionary = _fade_states[mesh]
	_fade_states.erase(mesh)
	if not is_instance_valid(mesh):
		return
	if bool(state.get("had_override", false)):
		mesh.set_surface_override_material(0, state.get("original_override"))
	else:
		mesh.set_surface_override_material(0, null)
