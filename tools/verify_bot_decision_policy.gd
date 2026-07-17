extends SceneTree


const POLICY := preload("res://src/entities/bot/BotDecisionPolicy.gd")


func _init() -> void:
	if not _verify_threat_policy():
		return
	if not _verify_target_policy():
		return
	if not _verify_position_policy():
		return
	print("Bot decision policy smoke passed: threat, target, position.")
	quit(0)


func _verify_threat_policy() -> bool:
	if POLICY.is_additional_threat({
		"is_current_target": true,
		"is_visible_living": true,
		"recent_attacker": true,
	}):
		return _fail_bool("The current target must not count as an additional threat.")
	if POLICY.is_additional_threat({
		"is_visible_living": true,
	}):
		return _fail_bool("A visible bystander must not count as an active threat.")
	if not POLICY.is_additional_threat({
		"is_visible_living": true,
		"recent_attacker": true,
	}):
		return _fail_bool("A recent attacker must count as an active threat.")
	if not POLICY.is_additional_threat({
		"is_visible_living": true,
		"pressuring_self": true,
	}):
		return _fail_bool("An actor pressuring this bot must count as an active threat.")

	var player_context := {
		"targeting_player": true,
		"additional_threats": 0,
		"visible_enemies": 4,
		"disengage_threshold": 1,
	}
	if POLICY.should_disengage(player_context):
		return _fail_bool("Player commitment must ignore visible non-pressuring bystanders.")
	player_context["additional_threats"] = 1
	if not POLICY.should_disengage(player_context):
		return _fail_bool("Player commitment must yield to an active additional threat.")
	return true


func _verify_target_policy() -> bool:
	var near_healthy := RefCounted.new()
	var far_wounded := RefCounted.new()
	var candidates := [
		{"actor": near_healthy, "distance": 10.0, "hp_ratio": 1.0},
		{"actor": far_wounded, "distance": 18.0, "hp_ratio": 0.1},
	]
	var nearest_profile := {"distance_weight": 1.0, "hp_weight": 0.0}
	if POLICY.choose_target(candidates, nearest_profile) != near_healthy:
		return _fail_bool("Distance-only target policy must preserve nearest-target behavior.")
	var opportunist_profile := {"distance_weight": 0.4, "hp_weight": 0.6}
	if POLICY.choose_target(candidates, opportunist_profile) != far_wounded:
		return _fail_bool("Opportunist target policy must preserve wounded-target preference.")
	return true


func _verify_position_policy() -> bool:
	var clear_utility := POLICY.position_utility({
		"travel_distance": 6.0,
		"threat_distance": 9.0,
		"minimum_threat_distance": 5.0,
	})
	var crowded_utility := POLICY.position_utility({
		"travel_distance": 4.0,
		"threat_distance": 9.0,
		"minimum_threat_distance": 5.0,
		"crowding_penalty": 10.0,
	})
	if clear_utility <= crowded_utility:
		return _fail_bool("Position utility must prefer an uncrowded cover point.")
	var unsafe_utility := POLICY.position_utility({
		"travel_distance": 1.0,
		"threat_distance": 4.9,
		"minimum_threat_distance": 5.0,
	})
	if unsafe_utility != -INF:
		return _fail_bool("Position utility must reject cover inside threat clearance.")
	return true


func _fail_bool(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
