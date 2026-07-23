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
	"cover": 80.0,
	"transit": 70.0,
	"mixed": 60.0,
	"loot_hub": 50.0,
}
const ROAD_EXPOSURE_SECONDS := {
	"transit": 2.0,
	"mixed": 5.0,
	"loot_hub": 4.0,
	"cover": 8.0,
}
const ROAD_DOCTRINE_BIAS_SECONDS := {
	"transit": -1.5,
	"mixed": 0.0,
	"loot_hub": -0.5,
	"cover": 2.0,
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
	planning_mode: String = "roam",
	utility_context: Dictionary = {}
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
		var density := clampf(float(poi.get("item_density", 0.5)), 0.05, 1.5)
		var capacity := maxi(1, int(poi.get(
			"strategic_capacity",
			DEFAULT_ROLE_CAPACITY.get(role, 2)
		)))
		var occupancy := maxi(0, int(occupancy_by_name.get(String(poi.get("name", "")), 0)))
		var weight := destination_utility(
			role,
			preference,
			density,
			distance,
			occupancy,
			capacity,
			planning_mode,
			utility_context
		)
		if weight <= 0.0:
			continue
		var travel_seconds := _estimated_travel_seconds(distance, utility_context)
		total_weight += weight
		candidates.append({
			"poi": poi,
			"position": poi_position,
			"radius": poi_radius,
			"weight": weight,
			"capacity": capacity,
			"occupancy": occupancy,
			"travel_seconds": travel_seconds,
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
		planning_mode,
		utility_context
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
		"utility": float(selected["weight"]),
		"estimated_travel_seconds": float(selected["travel_seconds"]),
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


static func destination_utility(
	role: String,
	preference: String,
	item_density: float,
	distance: float,
	occupancy: int,
	capacity: int,
	planning_mode: String,
	context: Dictionary = {}
) -> float:
	var utility := _role_weight(role, preference)
	if planning_mode == "preposition":
		utility *= _preposition_role_weight(role)
	if utility <= 0.0:
		return 0.0
	utility *= 0.55 + clampf(item_density, 0.05, 1.5)
	utility *= occupancy_multiplier(occupancy, capacity)
	if context.is_empty():
		return utility

	var equipment_need := clampf(float(context.get("equipment_need", 0.0)), 0.0, 1.0)
	var survival_need := clampf(float(context.get("survival_need", 0.0)), 0.0, 1.0)
	var threat_pressure := clampf(float(context.get("threat_pressure", 0.0)), 0.0, 1.0)
	var combat_readiness := clampf(float(context.get("combat_readiness", 1.0)), 0.0, 1.0)
	match role:
		"loot_hub":
			utility *= maxf(0.35, 0.65 + equipment_need * 1.35 - threat_pressure * 0.40)
		"recovery_pocket":
			utility *= 0.55 + survival_need * 1.25 + threat_pressure * 0.50
		"concealment_field":
			utility *= 0.65 + threat_pressure * 1.05 + survival_need * 0.45
		"transit_choke":
			utility *= maxf(0.35, 0.65 + combat_readiness * 0.85 - threat_pressure * 0.35)

	var travel_seconds := _estimated_travel_seconds(distance, context)
	var time_budget := maxf(12.0, float(context.get("time_budget_seconds", 60.0)))
	if planning_mode == "preposition" and travel_seconds > time_budget * 1.35:
		return 0.0
	var effective_budget := minf(time_budget, 60.0)
	var arrival_factor := clampf(
		1.15 - (travel_seconds / maxf(1.0, effective_budget)) * 0.50,
		0.45,
		1.10
	)
	return utility * arrival_factor


static func preposition_lead_seconds(preference: String, context: Dictionary = {}) -> float:
	var lead := float(PREPOSITION_LEAD_SECONDS.get(preference, PREPOSITION_LEAD_SECONDS["mixed"]))
	var equipment_need := clampf(float(context.get("equipment_need", 0.0)), 0.0, 1.0)
	var threat_pressure := clampf(float(context.get("threat_pressure", 0.0)), 0.0, 1.0)
	return clampf(lead - equipment_need * 12.0 + threat_pressure * 8.0, 36.0, 87.0)


static func choose_route(
	preference: String,
	direct_distance: float,
	road_distance: float,
	context: Dictionary = {}
) -> Dictionary:
	var move_speed := maxf(0.1, float(context.get("move_speed", 5.0)))
	var terrain_multiplier := clampf(float(context.get(
		"terrain_multiplier",
		context.get("movement_multiplier", 0.84)
	)), 0.5, 1.0)
	var road_multiplier := clampf(float(context.get("road_multiplier", 1.0)), 0.5, 1.2)
	var direct_seconds := maxf(0.0, direct_distance) / (move_speed * terrain_multiplier)
	var road_seconds := maxf(0.0, road_distance) / (move_speed * road_multiplier)
	var time_budget := maxf(8.0, float(context.get("time_budget_seconds", 60.0)))
	var urgency := clampf(direct_seconds / time_budget, 0.0, 1.5)
	var threat_pressure := clampf(float(context.get("threat_pressure", 0.0)), 0.0, 1.0)
	var equipment_need := clampf(float(context.get("equipment_need", 0.0)), 0.0, 1.0)
	var exposure_seconds := float(ROAD_EXPOSURE_SECONDS.get(
		preference,
		ROAD_EXPOSURE_SECONDS["mixed"]
	))
	var exposure_relief := clampf(urgency / 1.5, 0.0, 1.0) * 0.75
	var road_score := road_seconds \
		+ threat_pressure * exposure_seconds * (1.0 - exposure_relief) \
		+ float(ROAD_DOCTRINE_BIAS_SECONDS.get(
			preference,
			ROAD_DOCTRINE_BIAS_SECONDS["mixed"]
		))
	if String(context.get("destination_role", "")) == "loot_hub":
		road_score -= equipment_need * 1.25
	return {
		"use_road": road_distance > 0.0 and road_score < direct_seconds,
		"road_seconds": road_seconds,
		"direct_seconds": direct_seconds,
		"road_score": road_score,
		"urgency": urgency,
	}


static func _select_anchor(
	poi: Dictionary,
	preference: String,
	selection_ticket: float,
	spread_phase: int,
	zone_center: Vector2,
	zone_radius: float,
	planning_mode: String,
	utility_context: Dictionary = {}
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
		var threat_pressure := clampf(float(utility_context.get("threat_pressure", 0.0)), 0.0, 1.0)
		var equipment_need := clampf(float(utility_context.get("equipment_need", 0.0)), 0.0, 1.0)
		if role == "outer":
			weight *= 1.0 + threat_pressure * 0.55
		elif role == "objective":
			weight *= maxf(0.35, 1.0 + equipment_need * 0.45 - threat_pressure * 0.55)
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


static func _estimated_travel_seconds(distance: float, context: Dictionary) -> float:
	var move_speed := maxf(0.1, float(context.get("move_speed", 5.0)))
	var movement_multiplier := clampf(float(context.get("movement_multiplier", 0.92)), 0.5, 1.2)
	return maxf(0.0, distance) / (move_speed * movement_multiplier)


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
