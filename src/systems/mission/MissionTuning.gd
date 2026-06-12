extends RefCounted
class_name MissionTuning

const SUPPLY_KILL_RADIUS: float = 12.0
const FULL_DETECTION_THRESHOLD: float = 1.0
const DETECTED_BOT_COUNT: int = 2
const HEAVILY_DETECTED_BOT_COUNT: int = 3
const CLEAN_WIN_HP_RATIO: float = 0.5
const LOW_HP_KILL_RATIO: float = 0.3
const ALL_WEAPON_KILL_TARGET: int = 1
const ALL_WEAPON_KILL_TYPES = ["pistol", "ar", "shotgun", "railgun"]
const PRESSURE_DETECTED_SURVIVE_MIN_BOTS: int = DETECTED_BOT_COUNT
const PRESSURE_LONG_ZONE_FILTER_STAGE: int = 3
const PRESSURE_LONG_ZONE_OUTSIDE_TARGET: int = 10


static func supply_kill_radius_label() -> String:
	return "%dm" % int(SUPPLY_KILL_RADIUS)


static func detection_threshold_label() -> String:
	return "%.1f" % FULL_DETECTION_THRESHOLD


static func low_hp_ratio_label() -> String:
	return "%d%%" % int(round(LOW_HP_KILL_RATIO * 100.0))


static func clean_win_ratio_label() -> String:
	return "%d%%" % int(round(CLEAN_WIN_HP_RATIO * 100.0))


static func should_filter_long_zone_pressure(zone_stage: int, target: int) -> bool:
	return zone_stage >= PRESSURE_LONG_ZONE_FILTER_STAGE and target >= PRESSURE_LONG_ZONE_OUTSIDE_TARGET
