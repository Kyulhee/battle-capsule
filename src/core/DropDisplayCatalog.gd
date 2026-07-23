class_name DropDisplayCatalog
extends RefCounted

static func weapon_name(wtype: String, tier: int = 2) -> String:
	match wtype:
		"pistol":  return "피스톨"
		"ar":      return "노후 돌격소총" if tier <= 1 else "돌격소총"
		"shotgun": return "낡은 산탄총" if tier <= 1 else "샷건"
		"railgun": return "레일건"
	return wtype.capitalize()

static func ammo_name(wtype: String) -> String:
	match wtype:
		"pistol":  return "피스톨 탄"
		"ar":      return "소총 탄"
		"shotgun": return "샷건 탄"
		"railgun": return "레일 탄"
	return wtype.capitalize() + " 탄"

static func common_heal_name() -> String:
	return "붕대"

static func rare_heal_name() -> String:
	return "구급상자"

static func weapon_color(wtype: String, tier: int = 2) -> Color:
	match wtype:
		"pistol":  return Color(0.55, 0.78, 1.0)
		"ar":      return Color(0.48, 0.55, 0.42) if tier <= 1 else Color(0.2, 0.88, 0.35)
		"shotgun": return Color(0.58, 0.48, 0.32) if tier <= 1 else Color(1.0, 0.6, 0.1)
		"railgun": return Color(0.85, 0.2, 1.0)
	return Color.WHITE
