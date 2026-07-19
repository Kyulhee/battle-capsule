extends RefCounted

const ACTIVE_ROLES := [
	"loot_hub",
	"transit_choke",
	"recovery_pocket",
	"concealment_field",
]
const ZONE_EDGE_MARGIN := 5.0
const MIN_DEPARTURE_DISTANCE := 8.0


static func select_destination(
	pois: Array[Dictionary],
	origin: Vector2,
	zone_center: Vector2,
	zone_radius: float,
	preference: String,
	selection_ticket: float,
	spread_phase: int
) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var total_weight := 0.0
	for poi in pois:
		var role := String(poi.get("role", ""))
		if role not in ACTIVE_ROLES:
			continue
		var poi_position := _poi_position(poi)
		if not poi_position.is_finite():
			continue
		var poi_radius := maxf(2.0, float(poi.get("radius", 8.0)))
		var distance := origin.distance_to(poi_position)
		if distance <= maxf(MIN_DEPARTURE_DISTANCE, poi_radius * 0.55):
			continue
		if zone_radius > 0.0 \
				and poi_position.distance_to(zone_center) > zone_radius - ZONE_EDGE_MARGIN:
			continue
		var weight := _role_weight(role, preference)
		if weight <= 0.0:
			continue
		var density := clampf(float(poi.get("item_density", 0.5)), 0.05, 1.5)
		weight *= 0.55 + density
		total_weight += weight
		candidates.append({
			"poi": poi,
			"position": poi_position,
			"radius": poi_radius,
			"weight": weight,
		})
	if candidates.is_empty() or total_weight <= 0.0:
		return {}

	var ticket := fposmod(selection_ticket, 1.0) * total_weight
	var selected: Dictionary = candidates[candidates.size() - 1]
	for candidate in candidates:
		ticket -= float(candidate["weight"])
		if ticket <= 0.0:
			selected = candidate
			break

	var poi: Dictionary = selected["poi"]
	var center: Vector2 = selected["position"]
	var spread_radius := minf(float(selected["radius"]) * 0.35, 7.0)
	var spread_angle := fposmod(float(spread_phase) * 2.39996323, TAU)
	var spread_distance := spread_radius * (0.45 + 0.5 * fposmod(selection_ticket * 7.0, 1.0))
	var target := center + Vector2.from_angle(spread_angle) * spread_distance
	return {
		"name": String(poi.get("name", "")),
		"role": String(poi.get("role", "")),
		"center": center,
		"radius": float(selected["radius"]),
		"target": target,
	}


static func _poi_position(poi: Dictionary) -> Vector2:
	var position_value = poi.get("pos_2d", null)
	if typeof(position_value) == TYPE_VECTOR2:
		return position_value
	var position_array = poi.get("pos", [])
	if typeof(position_array) == TYPE_ARRAY and position_array.size() >= 2:
		return Vector2(float(position_array[0]), float(position_array[1]))
	return Vector2.INF


static func _role_weight(role: String, preference: String) -> float:
	match preference:
		"loot_hub":
			return {
				"loot_hub": 3.2,
				"transit_choke": 0.8,
				"recovery_pocket": 0.35,
				"concealment_field": 0.25,
			}.get(role, 0.0)
		"cover":
			return {
				"loot_hub": 0.45,
				"transit_choke": 0.9,
				"recovery_pocket": 2.8,
				"concealment_field": 2.4,
			}.get(role, 0.0)
		"transit":
			return {
				"loot_hub": 0.7,
				"transit_choke": 3.0,
				"recovery_pocket": 1.0,
				"concealment_field": 0.5,
			}.get(role, 0.0)
		_:
			return {
				"loot_hub": 2.0,
				"transit_choke": 1.5,
				"recovery_pocket": 0.8,
				"concealment_field": 0.6,
			}.get(role, 0.0)
