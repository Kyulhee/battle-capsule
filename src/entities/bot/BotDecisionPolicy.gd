extends RefCounted


const TARGET_MEMORY_SECONDS := 2.5
const PLAYER_TARGET_MEMORY_SECONDS := 5.0


static func target_memory_seconds(targeting_player: bool) -> float:
	return PLAYER_TARGET_MEMORY_SECONDS if targeting_player else TARGET_MEMORY_SECONDS


static func is_additional_threat(context: Dictionary) -> bool:
	if bool(context.get("is_current_target", false)):
		return false
	if not bool(context.get("is_visible_living", false)):
		return false
	return bool(context.get("recent_attacker", false)) \
		or bool(context.get("pressuring_self", false))


static func should_disengage(context: Dictionary) -> bool:
	var threshold := maxi(1, int(context.get("disengage_threshold", 1)))
	if bool(context.get("targeting_player", false)):
		return int(context.get("additional_threats", 0)) >= threshold
	return int(context.get("visible_enemies", 0)) >= threshold


static func can_reengage(context: Dictionary) -> bool:
	if bool(context.get("targeting_player", false)):
		return int(context.get("additional_threats", 0)) == 0
	return int(context.get("visible_enemies", 0)) <= 1


static func should_join_engagement(context: Dictionary) -> bool:
	if bool(context.get("already_targeting", false)) \
			or bool(context.get("direct_threat", false)) \
			or bool(context.get("forced_response", false)):
		return true
	var distance := maxf(0.0, float(context.get("distance", INF)))
	var immediate_range := maxf(0.0, float(context.get("immediate_range", 0.0)))
	if distance <= immediate_range:
		return true
	var join_capacity := maxi(1, int(context.get("join_capacity", 1)))
	if int(context.get("target_commitments", 0)) >= join_capacity:
		return false
	var local_combatant_limit := maxi(2, int(context.get("local_combatant_limit", 2)))
	return int(context.get("local_combatants", 0)) < local_combatant_limit


static func is_heavily_outnumbered(context: Dictionary) -> bool:
	if bool(context.get("targeting_player", false)):
		return int(context.get("additional_threats", 0)) >= 3
	return int(context.get("visible_enemies", 0)) >= 4


static func choose_target(candidates: Array, target_profile: Dictionary) -> Variant:
	var best_target: Variant = null
	var best_score := INF
	for candidate in candidates:
		if not candidate is Dictionary:
			continue
		var score := target_score(candidate, target_profile)
		if score < best_score:
			best_score = score
			best_target = candidate.get("actor")
	return best_target


static func target_score(context: Dictionary, target_profile: Dictionary) -> float:
	var distance := maxf(0.0, float(context.get("distance", INF)))
	var hp_ratio := clampf(float(context.get("hp_ratio", 1.0)), 0.0, 1.0)
	var distance_weight := maxf(0.0, float(target_profile.get("distance_weight", 1.0)))
	var hp_weight := maxf(0.0, float(target_profile.get("hp_weight", 0.0)))
	return distance * (distance_weight + hp_ratio * hp_weight)


static func position_utility(context: Dictionary) -> float:
	if not bool(context.get("valid", true)):
		return -INF
	var threat_distance := float(context.get("threat_distance", INF))
	var minimum_threat_distance := maxf(0.0, float(context.get("minimum_threat_distance", 0.0)))
	if threat_distance < minimum_threat_distance:
		return -INF
	return -maxf(0.0, float(context.get("travel_distance", 0.0))) \
		- maxf(0.0, float(context.get("crowding_penalty", 0.0))) \
		- maxf(0.0, float(context.get("fallback_penalty", 0.0))) \
		- maxf(0.0, float(context.get("zone_penalty", 0.0))) \
		- maxf(0.0, float(context.get("exposure_penalty", 0.0)))
