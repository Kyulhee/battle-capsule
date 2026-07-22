class_name PlayerHealthPolicy
extends RefCounted


static func starting_state(max_health: float, requested_health: float = 1.0) -> Dictionary:
	var safe_max_health := maxf(1.0, max_health)
	return {
		"current_health": clampf(requested_health, 1.0, safe_max_health),
		"max_health": safe_max_health,
	}


static func capacity_locked_state(
	current_health: float,
	requested_max_health: float = 1.0
) -> Dictionary:
	var safe_max_health := maxf(1.0, requested_max_health)
	return {
		"current_health": minf(safe_max_health, maxf(1.0, current_health)),
		"max_health": safe_max_health,
	}
