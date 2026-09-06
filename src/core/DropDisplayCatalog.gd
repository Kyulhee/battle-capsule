class_name DropDisplayCatalog
extends RefCounted

# Presentation only: do not use this palette to select loot or tune combat.
const TIER_GRAY := Color(0.76, 0.79, 0.82)
const TIER_GREEN := Color(0.35, 0.92, 0.49)
const TIER_BLUE := Color(0.36, 0.66, 1.0)
const SPECIAL_PURPLE := Color(0.82, 0.52, 1.0)

static func tier_color(tier: int) -> Color:
	match tier:
		2: return TIER_GREEN
		3: return TIER_BLUE
	return TIER_GRAY

static func weapon_badge(wtype: String, tier: int) -> String:
	if wtype == "railgun":
		return "특수"
	return "T%d" % tier

static func weapon_grade_name(wtype: String, tier: int) -> String:
	if wtype == "railgun":
		return "특수"
	if tier <= 1:
		return "기본" if wtype == "pistol" else "노후"
	return "표준" if tier == 2 else "보급"

static func item_color(item: ItemData) -> Color:
	if not item:
		return Color.WHITE
	if item.type == ItemData.Type.WEAPON and item.weapon_stats:
		return weapon_color(item.weapon_stats.weapon_type, item.weapon_stats.weapon_tier)
	if item.type == ItemData.Type.ARMOR and not item.equipment_id.is_empty():
		return tier_color(item.equipment_tier)
	if item.type == ItemData.Type.HEAL and item.rarity == ItemData.Rarity.RARE:
		return TIER_GREEN
	# Ammo has compatibility, not a weapon performance tier (including rail ammo).
	return TIER_GRAY

static func weapon_name(wtype: String, tier: int = 2) -> String:
	match wtype:
		"pistol":  return "피스톨"
		"ar":      return "노후 돌격소총" if tier <= 1 else "돌격소총"
		"shotgun": return "낡은 산탄총" if tier <= 1 else "산탄총"
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

static func should_drop_weapon_type(weapon_type: String) -> bool:
	return weapon_type.strip_edges().to_lower() not in ["", "none", "empty", "knife", "pistol"]

static func should_drop_ammo_for_weapon_type(weapon_type: String) -> bool:
	return weapon_type.strip_edges().to_lower() not in ["", "none", "empty", "knife"]

static func weapon_color(wtype: String, tier: int = 2) -> Color:
	return SPECIAL_PURPLE if wtype == "railgun" else tier_color(tier)
