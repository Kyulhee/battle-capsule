class_name ItemDisplayFormatter
extends RefCounted

static func pickup_name(item: ItemData) -> String:
	if not item:
		return ""
	return pickup_prefix(item) + item.item_name

static func pickup_detail(item: ItemData) -> String:
	if not item:
		return ""
	var display_text = pickup_name(item)
	match item.type:
		ItemData.Type.WEAPON:
			if item.weapon_stats:
				display_text += "\n%s" % weapon_ammo_text(
					item.weapon_stats.current_ammo,
					item.weapon_stats.max_ammo
				)
		ItemData.Type.AMMO:
			if item.ammo_weapon_type != "":
				display_text += " +%d" % item.amount
		ItemData.Type.HEAL:
			display_text += " ×%d" % item.amount
		ItemData.Type.ARMOR:
			display_text += " +%d" % item.amount
	return display_text

static func pickup_prefix(item: ItemData) -> String:
	if not item:
		return ""
	match item.type:
		ItemData.Type.HEAL:
			return "◆ " if item.rarity == ItemData.Rarity.RARE else "♥ "
		ItemData.Type.ARMOR:
			return "◈ "
		ItemData.Type.AMMO:
			return "● "
	return ""

static func weapon_ammo_text(current_ammo: int, max_ammo: int) -> String:
	return "%d/%d" % [current_ammo, max_ammo]

static func slot_ammo_text(current_ammo: int, max_ammo: int, reserve_ammo: int) -> String:
	return "%s+%d" % [weapon_ammo_text(current_ammo, max_ammo), reserve_ammo]
