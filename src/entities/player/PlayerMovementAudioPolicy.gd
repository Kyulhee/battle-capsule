extends RefCounted

const CROUCH_FOOTSTEP_VOLUME_DB := -10.0
const CROUCH_FOOTSTEP_RADIUS_MULT := 0.45


static func footstep_volume_offset_db(crouching: bool) -> float:
	return CROUCH_FOOTSTEP_VOLUME_DB if crouching else 0.0


static func footstep_stance_radius_mult(crouching: bool) -> float:
	return CROUCH_FOOTSTEP_RADIUS_MULT if crouching else 1.0
