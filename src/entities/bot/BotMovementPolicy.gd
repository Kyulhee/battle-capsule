extends RefCounted


const LOCAL_SEPARATION_RADIUS := 2.75
const LOCAL_SEPARATION_STRENGTH := 1.35


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
