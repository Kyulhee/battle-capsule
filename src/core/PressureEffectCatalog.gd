class_name PressureEffectCatalog
extends RefCounted

const AMMO_REFILL := 0
const AMMO_CLEAR := 1
const AMMO_ACTIVE_CLEAR := 2
const HP_RESTORE := 3
const HP_DAMAGE := 4
const SHIELD_ADD := 5
const HEAL_ADD := 6
const HEAL_CLEAR := 7
const HEAL_PICKUP_BAN := 8
const ALL_BOTS_DETECT := 9
const BOT_AGGRO := 10
const ZONE_EXTEND := 11
const RAILGUN_UNLIMITED := 12

const KNOWN_TYPES := [
	AMMO_REFILL,
	AMMO_CLEAR,
	AMMO_ACTIVE_CLEAR,
	HP_RESTORE,
	HP_DAMAGE,
	SHIELD_ADD,
	HEAL_ADD,
	HEAL_CLEAR,
	HEAL_PICKUP_BAN,
	ALL_BOTS_DETECT,
	BOT_AGGRO,
	ZONE_EXTEND,
	RAILGUN_UNLIMITED,
]

static func is_known_type(effect_type: int) -> bool:
	return KNOWN_TYPES.has(effect_type)

static func format_effects(effects: Array) -> String:
	var parts: Array = []
	for effect in effects:
		var text = format_effect(effect)
		if text != "":
			parts.append(text)
	return "  ".join(parts) if not parts.is_empty() else "없음"

static func format_effect(effect: Dictionary) -> String:
	if not effect.has("type"):
		return ""
	match int(effect["type"]):
		AMMO_REFILL:
			return "탄약 충전"
		AMMO_CLEAR:
			return "탄약 전소"
		AMMO_ACTIVE_CLEAR:
			return "현 탄약 전소"
		HP_RESTORE:
			if effect.get("full", false):
				return "HP 풀회복"
			return "HP+%d" % int(effect.get("amount", 0))
		HP_DAMAGE:
			if effect.has("fraction"):
				return "HP -%d%%" % int(float(effect["fraction"]) * 100.0)
			return "HP-%d" % int(effect.get("amount", 0))
		SHIELD_ADD:
			return "방어막+%d" % int(effect.get("amount", 0))
		HEAL_ADD:
			return "힐+%d" % int(effect.get("count", 1))
		HEAL_CLEAR:
			return "힐 전소"
		HEAL_PICKUP_BAN:
			return "힐픽업 금지"
		ALL_BOTS_DETECT:
			return "전봇 탐지"
		BOT_AGGRO:
			return "근접 봇 어그로"
		ZONE_EXTEND:
			var percent = int(round((float(effect.get("mult", 1.0)) - 1.0) * 100.0))
			return ("존 시간+%d%%" % percent) if percent != 0 else "존 시간 유지"
		RAILGUN_UNLIMITED:
			return "레일건 무제한"
	return "알 수 없는 효과(%d)" % int(effect["type"])
