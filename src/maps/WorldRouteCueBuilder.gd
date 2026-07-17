extends RefCounted


const CUE_HEIGHT_BASE := 0.018
const ROLE_ORDER := {
	"recovery_exit": 0,
	"loot_flow": 1,
	"flank": 2,
	"primary_choke": 3,
}


static func build(parent: Node3D, map_spec: Resource) -> Array[Dictionary]:
	var descriptors: Array[Dictionary] = []
	if map_spec == null:
		return descriptors

	var container := Node3D.new()
	container.name = "GeneratedRouteCues"
	parent.add_child(container)

	for route in map_spec.routes:
		if typeof(route) != TYPE_DICTIONARY:
			continue
		var route_data: Dictionary = route
		var route_id := String(route_data.get("id", "route"))
		var role := String(route_data.get("role", ""))
		var style := _style_for(role)
		var points := _route_points(route_data)
		for i in range(points.size() - 1):
			_describe_route_segment(
				route_id,
				role,
				points[i],
				points[i + 1],
				style,
				descriptors
			)
	_build_batches(container, descriptors)
	return descriptors


static func _describe_route_segment(
	route_id: String,
	role: String,
	start: Vector2,
	end: Vector2,
	style: Dictionary,
	descriptors: Array[Dictionary]
) -> void:
	var segment := end - start
	var total_length := segment.length()
	if total_length <= 0.01:
		return
	var direction := segment / total_length
	var dash := float(style["dash"])
	var gap := float(style["gap"])
	if dash <= 0.0:
		_append_strip(route_id, role, start, end, style, descriptors)
		return

	var cursor := 0.0
	while cursor < total_length:
		var cue_end := minf(cursor + dash, total_length)
		_append_strip(
			route_id,
			role,
			start + direction * cursor,
			start + direction * cue_end,
			style,
			descriptors
		)
		cursor += dash + gap


static func _append_strip(
	route_id: String,
	role: String,
	start: Vector2,
	end: Vector2,
	style: Dictionary,
	descriptors: Array[Dictionary]
) -> void:
	var delta := end - start
	var length := delta.length()
	if length <= 0.01:
		return

	descriptors.append({
		"route_id": route_id,
		"role": role,
		"start": start,
		"end": end,
		"length": length,
		"width": float(style["width"]),
		"order": int(style["order"]),
	})


static func _build_batches(parent: Node3D, descriptors: Array[Dictionary]) -> void:
	var descriptors_by_role := {}
	for descriptor in descriptors:
		var role := String(descriptor.get("role", ""))
		var role_descriptors: Array = descriptors_by_role.get(role, [])
		role_descriptors.append(descriptor)
		descriptors_by_role[role] = role_descriptors

	for role in descriptors_by_role:
		var role_descriptors: Array = descriptors_by_role[role]
		var style := _style_for(String(role))
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE
		plane.material = _material_for(style["color"])

		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = plane
		multimesh.instance_count = role_descriptors.size()

		var batch := MultiMeshInstance3D.new()
		batch.name = "RouteCues_%s" % String(role)
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.set_meta("route_role", role)
		batch.add_to_group("route_cues")
		batch.multimesh = multimesh
		parent.add_child(batch)

		for i in range(role_descriptors.size()):
			var descriptor: Dictionary = role_descriptors[i]
			var start: Vector2 = descriptor["start"]
			var end: Vector2 = descriptor["end"]
			var delta := end - start
			var midpoint := (start + end) * 0.5
			var basis := Basis(Vector3.UP, atan2(delta.x, delta.y))
			basis = basis.scaled_local(
				Vector3(float(descriptor["width"]), 1.0, float(descriptor["length"]))
			)
			var origin := Vector3(
				midpoint.x,
				CUE_HEIGHT_BASE + float(descriptor["order"]) * 0.002,
				midpoint.y
			)
			var instance_transform := Transform3D(basis, origin)
			multimesh.set_instance_transform(i, instance_transform)
			descriptor["node"] = batch
			descriptor["instance_index"] = i
			descriptor["instance_transform"] = instance_transform


static func _style_for(role: String) -> Dictionary:
	var style := {
		"color": Color(0.46, 0.48, 0.48, 0.34),
		"width": 1.0,
		"dash": 0.0,
		"gap": 0.0,
		"order": int(ROLE_ORDER.get(role, -1)),
	}
	match role:
		"primary_choke":
			style["color"] = Color(0.08, 0.30, 0.34, 0.32)
			style["width"] = 0.36
		"flank":
			style["color"] = Color(0.34, 0.21, 0.05, 0.30)
			style["width"] = 0.30
			style["dash"] = 2.4
			style["gap"] = 2.0
		"loot_flow":
			style["color"] = Color(0.08, 0.24, 0.10, 0.28)
			style["width"] = 0.28
		"recovery_exit":
			style["color"] = Color(0.25, 0.10, 0.30, 0.30)
			style["width"] = 0.26
			style["dash"] = 1.8
			style["gap"] = 1.5
	return style


static func _material_for(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


static func _route_points(route: Dictionary) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var raw_points = route.get("points", [])
	if typeof(raw_points) != TYPE_ARRAY:
		return points
	for point in raw_points:
		if typeof(point) == TYPE_ARRAY and point.size() >= 2:
			points.append(Vector2(float(point[0]), float(point[1])))
	return points
