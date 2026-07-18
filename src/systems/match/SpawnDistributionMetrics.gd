class_name SpawnDistributionMetrics
extends RefCounted


static func summarize(
	positions: Array,
	requested_count: int,
	spawn_radius: float,
	inner_radius: float,
	entity_clearance: float,
	world_size: float,
	fallback_count: int,
	attempt_total: int,
	attempt_max: int,
	fixed_count: int,
	map_definition = null
) -> Dictionary:
	var count := positions.size()
	var min_nearest := INF
	var nearest_total := 0.0
	var min_origin := INF
	var max_origin := 0.0
	var origin_total := 0.0
	var origin_band_counts := {}
	var poi_role_counts := {}
	var poi_name_counts := {}
	var nearest_poi_role_counts := {}
	var route_role_counts := {}
	var nearest_route_role_counts := {}
	var inside_poi_count := 0
	var on_route_count := 0
	var radial_inner_half_count := 0

	for i in range(count):
		var spawn_pos: Vector3 = positions[i]
		var pos := Vector2(spawn_pos.x, spawn_pos.z)
		var origin_dist := pos.length()
		min_origin = minf(min_origin, origin_dist)
		max_origin = maxf(max_origin, origin_dist)
		origin_total += origin_dist

		var radial_t := clampf(
			(origin_dist - inner_radius) / maxf(0.001, spawn_radius - inner_radius),
			0.0,
			1.0
		)
		_increment(origin_band_counts, _origin_band(radial_t))
		if radial_t <= 0.5:
			radial_inner_half_count += 1

		var nearest := INF
		for j in range(count):
			if i == j:
				continue
			var other_spawn: Vector3 = positions[j]
			var other := Vector2(other_spawn.x, other_spawn.z)
			nearest = minf(nearest, pos.distance_to(other))
		if nearest < INF:
			min_nearest = minf(min_nearest, nearest)
			nearest_total += nearest

		if map_definition and map_definition.has_method("describe_strategic_position"):
			var strategic: Dictionary = map_definition.describe_strategic_position(pos)
			_increment(poi_role_counts, String(strategic.get("poi_role", "open")))
			_increment(poi_name_counts, String(strategic.get("poi_name", "none")))
			_increment(nearest_poi_role_counts, String(strategic.get("nearest_poi_role", "none")))
			_increment(route_role_counts, String(strategic.get("route_role", "off_route")))
			_increment(nearest_route_role_counts, String(strategic.get("nearest_route_role", "none")))
			if bool(strategic.get("poi_inside", false)):
				inside_poi_count += 1
			if bool(strategic.get("route_on", false)):
				on_route_count += 1

	var annulus_area := maxf(
		1.0,
		PI * maxf(1.0, spawn_radius * spawn_radius - inner_radius * inner_radius)
	)
	var clearance_area := PI * entity_clearance * entity_clearance * count
	return {
		"requested_count": requested_count,
		"placed_count": count,
		"spawn_radius": spawn_radius,
		"inner_radius": inner_radius,
		"entity_clearance": entity_clearance,
		"world_size": world_size,
		"fallback_count": fallback_count,
		"attempt_total": attempt_total,
		"attempt_max": attempt_max,
		"fixed_count": fixed_count,
		"avg_attempts": float(attempt_total) / max(1, count),
		"min_nearest_distance": min_nearest if min_nearest < INF else 0.0,
		"avg_nearest_distance": nearest_total / max(1, count),
		"min_origin_distance": min_origin if min_origin < INF else 0.0,
		"avg_origin_distance": origin_total / max(1, count),
		"max_origin_distance": max_origin,
		"annulus_saturation": clearance_area / annulus_area,
		"origin_band_counts": origin_band_counts,
		"radial_inner_half_count": radial_inner_half_count,
		"radial_inner_half_share": float(radial_inner_half_count) / max(1, count),
		"inside_poi_count": inside_poi_count,
		"inside_poi_share": float(inside_poi_count) / max(1, count),
		"on_route_count": on_route_count,
		"on_route_share": float(on_route_count) / max(1, count),
		"poi_role_counts": poi_role_counts,
		"poi_name_counts": poi_name_counts,
		"nearest_poi_role_counts": nearest_poi_role_counts,
		"route_role_counts": route_role_counts,
		"nearest_route_role_counts": nearest_route_role_counts,
	}


static func _origin_band(radial_t: float) -> String:
	if radial_t < 1.0 / 3.0:
		return "inner"
	if radial_t < 2.0 / 3.0:
		return "middle"
	return "outer"


static func _increment(counter: Dictionary, key: String) -> void:
	var normalized := key if not key.is_empty() else "none"
	counter[normalized] = int(counter.get(normalized, 0)) + 1
