extends RefCounted

const NO_WEAPON_RELOAD_TIME: float = 1.5
const DEFAULT_WEAPON_RELOAD_TIME: float = 1.3
const DEFAULT_RESERVE_MAX: int = 30

const RELOAD_TIME_BY_WEAPON := {
	"shotgun": 2.8,
	"railgun": 4.5,
	"ar": 2.0,
}

const RESERVE_MAX_BY_WEAPON := {
	"pistol": 30,
	"ar": 60,
	"shotgun": 12,
	"railgun": 4,
}


static func reload_time(weapon_type: String) -> float:
	return float(RELOAD_TIME_BY_WEAPON.get(weapon_type, DEFAULT_WEAPON_RELOAD_TIME))


static func reserve_max(weapon_type: String) -> int:
	return int(RESERVE_MAX_BY_WEAPON.get(weapon_type, DEFAULT_RESERVE_MAX))
