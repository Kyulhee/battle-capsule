extends RefCounted


const ROLE_ORDER := {
	"recovery_exit": 0,
	"loot_flow": 1,
	"flank": 2,
	"primary_choke": 3,
}


static func route_source(map_definition, map_spec: Resource) -> Array[Dictionary]:
	if map_definition != null and map_definition.has_method("get_route_descriptors"):
		return map_definition.get_route_descriptors()
	var routes: Array[Dictionary] = []
	if map_spec == null:
		return routes
	for route in map_spec.routes:
		if typeof(route) == TYPE_DICTIONARY:
			routes.append(route.duplicate(true))
	return routes


static func sorted_routes(map_definition, map_spec: Resource) -> Array[Dictionary]:
	var routes := route_source(map_definition, map_spec)
	routes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var order_a := int(ROLE_ORDER.get(String(a.get("role", "")), -1))
		var order_b := int(ROLE_ORDER.get(String(b.get("role", "")), -1))
		if order_a == order_b:
			return String(a.get("id", "")) < String(b.get("id", ""))
		return order_a < order_b
	)
	return routes


static func route_points(route: Dictionary) -> Array[Vector2]:
	var descriptor_points = route.get("points_2d", null)
	if typeof(descriptor_points) == TYPE_ARRAY:
		var points: Array[Vector2] = []
		for point in descriptor_points:
			if typeof(point) == TYPE_VECTOR2:
				points.append(point)
		return points

	var points: Array[Vector2] = []
	var raw_points = route.get("points", [])
	if typeof(raw_points) != TYPE_ARRAY:
		return points
	for point in raw_points:
		if typeof(point) == TYPE_ARRAY and point.size() >= 2:
			points.append(Vector2(float(point[0]), float(point[1])))
	return points


static func style_for(role: String, compact: bool = false) -> Dictionary:
	var width := 1.4 if compact else 2.6
	var halo_width := width + (1.4 if compact else 2.4)
	var style := {
		"color": Color(0.68, 0.72, 0.72, 0.62),
		"halo": Color(0.02, 0.025, 0.03, 0.66),
		"width": width,
		"halo_width": halo_width,
		"dash": 0.0,
		"gap": 0.0,
	}
	match role:
		"primary_choke":
			style["color"] = Color(0.30, 0.82, 0.88, 0.82)
			style["width"] = 1.8 if compact else 3.2
			style["halo_width"] = 3.4 if compact else 5.8
		"flank":
			style["color"] = Color(0.95, 0.67, 0.25, 0.74)
			style["dash"] = 5.0 if compact else 10.0
			style["gap"] = 3.0 if compact else 6.0
		"loot_flow":
			style["color"] = Color(0.42, 0.80, 0.48, 0.76)
		"recovery_exit":
			style["color"] = Color(0.78, 0.48, 0.90, 0.76)
			style["dash"] = 3.0 if compact else 6.0
			style["gap"] = 3.0 if compact else 5.0
	return style
