extends RefCounted
class_name MissionTuning

const SUPPLY_KILL_RADIUS: float = 12.0
const FULL_DETECTION_THRESHOLD: float = 1.0
const DETECTED_BOT_COUNT: int = 2
const HEAVILY_DETECTED_BOT_COUNT: int = 3
const LOW_HP_KILL_RATIO: float = 0.3
const ALL_WEAPON_KILL_TARGET: int = 1
const ALL_WEAPON_KILL_TYPES = ["pistol", "ar", "shotgun", "railgun"]


static func supply_kill_radius_label() -> String:
	return "%dm" % int(SUPPLY_KILL_RADIUS)


static func detection_threshold_label() -> String:
	return "%.1f" % FULL_DETECTION_THRESHOLD
