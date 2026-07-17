extends RefCounted


const LOCAL_SEPARATION_RADIUS := 2.75
const LOCAL_SEPARATION_STRENGTH := 1.35
const NAV_TARGET_REFRESH_DISTANCE := 0.35


static func should_separate(
	targeting_player: bool,
	in_attack: bool,
	in_combat_chase: bool
) -> bool:
	return targeting_player and (in_attack or in_combat_chase)


static func should_refresh_navigation_target(
	has_target: bool,
	current_target: Vector3,
	requested_target: Vector3,
	navigation_finished: bool,
	distance_to_requested: float,
	target_desired_distance: float
) -> bool:
	if not has_target:
		return true
	if current_target.distance_squared_to(requested_target) \
			>= NAV_TARGET_REFRESH_DISTANCE * NAV_TARGET_REFRESH_DISTANCE:
		return true
	return navigation_finished and distance_to_requested > target_desired_distance


static func separated_direction(desired_direction: Vector3, neighbor_offsets: Array) -> Vector3:
	var desired := Vector3(desired_direction.x, 0.0, desired_direction.z)
	var separation := Vector3.ZERO
	for value in neighbor_offsets:
		if not value is Vector3:
			continue
		var offset := value as Vector3
		offset.y = 0.0
		var distance := offset.length()
		if distance <= 0.001 or distance >= LOCAL_SEPARATION_RADIUS:
			continue
		var proximity := 1.0 - distance / LOCAL_SEPARATION_RADIUS
		separation += offset / distance * proximity

	if separation.length_squared() <= 0.0001:
		return desired
	separation = separation.limit_length(1.0)
	return (desired + separation * LOCAL_SEPARATION_STRENGTH).limit_length(1.0)
