extends RefCounted

const ACTIVE_ROLES := [
	"loot_hub",
	"transit_choke",
	"recovery_pocket",
	"concealment_field",
]
const ZONE_EDGE_MARGIN := 5.0
const MIN_DEPARTURE_DISTANCE := 8.0
const DEFAULT_ROLE_CAPACITY := {
	"loot_hub": 5,
	"transit_choke": 3,
	"recovery_pocket": 2,
	"concealment_field": 2,
}
const PREPOSITION_LEAD_SECONDS := {
	"cover": 65.0,
	"transit": 55.0,
	"mixed": 45.0,
	"loot_hub": 35.0,
}
const ROAD_USE_CHANCE := {
	"transit": 0.85,
	"mixed": 0.65,
	"loot_hub": 0.55,
	"cover": 0.30,
}


static func select_destination(
	pois: Array[Dictionary],
	origin: Vector2,
	zone_center: Vector2,
	zone_radius: float,
	preference: String,
	selection_ticket: float,
	spread_phase: int,
	occupancy_by_name: Dictionary = {},
	planning_mode: String = "roam"
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
		if not _poi_has_in_zone_target(
			poi,
			poi_position,
			zone_center,
			zone_radius,
			planning_mode
		):
			continue
		var weight := _role_weight(role, preference)
		if planning_mode == "preposition":
			weight *= _preposition_role_weight(role)
		if weight <= 0.0:
			continue
		var density := clampf(float(poi.get("item_density", 0.5)), 0.05, 1.5)
		weight *= 0.55 + density
		var capacity := maxi(1, int(poi.get(
			"strategic_capacity",
			DEFAULT_ROLE_CAPACITY.get(role, 2)
		)))
		var occupancy := maxi(0, int(occupancy_by_name.get(String(poi.get("name", "")), 0)))
		weight *= occupancy_multiplier(occupancy, capacity)
		total_weight += weight
		candidates.append({
			"poi": poi,
			"position": poi_position,
			"radius": poi_radius,
			"weight": weight,
			"capacity": capacity,
			"occupancy": occupancy,
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
	var anchor := _select_anchor(
		poi,
		preference,
		selection_ticket,
		spread_phase,
		zone_center,
		zone_radius,
		planning_mode
	)
	var target: Vector2
	if anchor.is_empty():
		var spread_radius := minf(float(selected["radius"]) * 0.35, 7.0)
		var spread_angle := fposmod(float(spread_phase) * 2.39996323, TAU)
		var spread_distance := spread_radius * (0.45 + 0.5 * fposmod(selection_ticket * 7.0, 1.0))
		target = center + Vector2.from_angle(spread_angle) * spread_distance
	else:
		target = anchor.get("target", center)
	var safe_zone_radius := maxf(0.0, zone_radius - ZONE_EDGE_MARGIN)
	var target_from_zone_center := target - zone_center
	if safe_zone_radius > 0.0 and target_from_zone_center.length() > safe_zone_radius:
		target = zone_center + target_from_zone_center.normalized() * safe_zone_radius
	var result := {
		"name": String(poi.get("name", "")),
		"role": String(poi.get("role", "")),
		"center": center,
		"radius": float(selected["radius"]),
		"target": target,
		"capacity": int(selected["capacity"]),
		"occupancy": int(selected["occupancy"]),
		"planning_mode": planning_mode,
	}
	if not anchor.is_empty():
		result["anchor_id"] = String(anchor.get("id", ""))
		result["anchor_role"] = String(anchor.get("role", ""))
		result["anchor_center"] = anchor.get("center", target)
	return result


static func occupancy_multiplier(occupancy: int, capacity: int) -> float:
	var safe_capacity := maxf(1.0, float(capacity))
	var load_ratio := maxf(0.0, float(occupancy)) / safe_capacity
	return 1.0 / pow(1.0 + load_ratio, 2.0)


static func preposition_lead_seconds(preference: String) -> float:
	return float(PREPOSITION_LEAD_SECONDS.get(preference, PREPOSITION_LEAD_SECONDS["mixed"]))


static func should_use_road(preference: String, selection_ticket: float) -> bool:
	var chance := float(ROAD_USE_CHANCE.get(preference, ROAD_USE_CHANCE["mixed"]))
	return fposmod(selection_ticket, 1.0) < chance


static func _select_anchor(
	poi: Dictionary,
	preference: String,
	selection_ticket: float,
	spread_phase: int,
	zone_center: Vector2,
	zone_radius: float,
	planning_mode: String
) -> Dictionary:
	var raw_anchors = poi.get("strategic_anchors", [])
	if typeof(raw_anchors) != TYPE_ARRAY or raw_anchors.is_empty():
		return {}
	var candidates: Array[Dictionary] = []
	var total_weight := 0.0
	for raw_anchor in raw_anchors:
		if typeof(raw_anchor) != TYPE_DICTIONARY:
			continue
		var anchor: Dictionary = raw_anchor
		var center := _anchor_position(anchor)
		if not center.is_finite():
			continue
		if zone_radius > 0.0 and center.distance_to(zone_center) > zone_radius - ZONE_EDGE_MARGIN:
			continue
		var role := String(anchor.get("role", ""))
		var weight := _anchor_role_weight(role, preference, planning_mode)
		if weight <= 0.0:
			continue
		total_weight += weight
		candidates.append({
			"anchor": anchor,
			"center": center,
			"weight": weight,
		})
	if candidates.is_empty() or total_weight <= 0.0:
		return {}

	var anchor_ticket := fposmod(
		selection_ticket * 5.731 + float(spread_phase) * 0.381966,
		1.0
	) * total_weight
	var selected: Dictionary = candidates[candidates.size() - 1]
	for candidate in candidates:
		anchor_ticket -= float(candidate["weight"])
		if anchor_ticket <= 0.0:
			selected = candidate
			break
	var anchor: Dictionary = selected["anchor"]
	var center: Vector2 = selected["center"]
	var jitter_radius := clampf(float(anchor.get("jitter_radius", 1.5)), 0.0, 3.0)
	var jitter_angle := fposmod(float(spread_phase) * 2.39996323, TAU)
	var jitter_distance := jitter_radius * (0.35 + 0.6 * fposmod(selection_ticket * 11.0, 1.0))
	return {
		"id": String(anchor.get("id", "")),
		"role": String(anchor.get("role", "")),
		"center": center,
		"target": center + Vector2.from_angle(jitter_angle) * jitter_distance,
	}


static func _poi_position(poi: Dictionary) -> Vector2:
	var position_value = poi.get("pos_2d", null)
	if typeof(position_value) == TYPE_VECTOR2:
		return position_value
	var position_array = poi.get("pos", [])
	if typeof(position_array) == TYPE_ARRAY and position_array.size() >= 2:
		return Vector2(float(position_array[0]), float(position_array[1]))
	return Vector2.INF


static func _anchor_position(anchor: Dictionary) -> Vector2:
	var position_array = anchor.get("pos", [])
	if typeof(position_array) == TYPE_ARRAY and position_array.size() >= 2:
		return Vector2(float(position_array[0]), float(position_array[1]))
	return Vector2.INF


static func _anchor_role_weight(role: String, preference: String, planning_mode: String) -> float:
	if planning_mode == "preposition":
		return {"objective": 0.35, "entry": 3.0, "outer": 3.4}.get(role, 0.0)
	match preference:
		"loot_hub":
			return {"objective": 3.2, "entry": 1.7, "outer": 0.5}.get(role, 0.0)
		"cover":
			return {"objective": 0.35, "entry": 1.8, "outer": 3.0}.get(role, 0.0)
		"transit":
			return {"objective": 0.45, "entry": 3.0, "outer": 2.2}.get(role, 0.0)
		_:
			return {"objective": 1.5, "entry": 2.0, "outer": 1.2}.get(role, 0.0)


static func _poi_has_in_zone_target(
	poi: Dictionary,
	poi_position: Vector2,
	zone_center: Vector2,
	zone_radius: float,
	planning_mode: String
) -> bool:
	if zone_radius <= 0.0 \
			or poi_position.distance_to(zone_center) <= zone_radius - ZONE_EDGE_MARGIN:
		return true
	if planning_mode != "preposition":
		return false
	var raw_anchors = poi.get("strategic_anchors", [])
	if typeof(raw_anchors) != TYPE_ARRAY:
		return false
	for raw_anchor in raw_anchors:
		if typeof(raw_anchor) != TYPE_DICTIONARY:
			continue
		var anchor_position := _anchor_position(raw_anchor)
		if anchor_position.is_finite() \
				and anchor_position.distance_to(zone_center) <= zone_radius - ZONE_EDGE_MARGIN:
			return true
	return false


static func _preposition_role_weight(role: String) -> float:
	return {
		"loot_hub": 1.25,
		"transit_choke": 1.55,
		"recovery_pocket": 1.15,
		"concealment_field": 0.9,
	}.get(role, 0.0)


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
