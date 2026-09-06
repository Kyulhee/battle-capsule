class_name ItemDisplayFormatter
extends RefCounted

const Display = preload("res://src/core/DropDisplayCatalog.gd")

static func pickup_name(item: ItemData) -> String:
	if not item:
		return ""
	if item.type == ItemData.Type.WEAPON and item.weapon_stats:
		return weapon_display_name(item.weapon_stats)
	if item.type == ItemData.Type.ARMOR and not item.equipment_id.is_empty():
		return "[T%d] %s" % [item.equipment_tier, item.item_name]
	return pickup_prefix(item) + item.item_name

static func weapon_display_name(wstats: StatsData) -> String:
	if not wstats:
		return "근접 무기"
	return "[%s] %s" % [Display.weapon_badge(wstats.weapon_type, wstats.weapon_tier),
		Display.weapon_name(wstats.weapon_type, wstats.weapon_tier)]

static func weapon_pickup_comparison(wstats: StatsData, slots: WeaponSlotManager) -> String:
	if not wstats or not slots:
		return ""
	for i in range(1, slots.weapon_slots.size()):
		var held = slots.weapon_slots[i]
		if held and held.weapon_type == wstats.weapon_type:
			if wstats.weapon_tier > held.weapon_tier:
				return "보유 T%d → T%d 업그레이드" % [held.weapon_tier, wstats.weapon_tier]
			return "보유 T%d · %s" % [held.weapon_tier,
				"동급 보유" if wstats.weapon_tier == held.weapon_tier else "하위 등급"]
	for i in range(1, slots.weapon_slots.size()):
		if slots.weapon_slots[i] == null:
			return "새 무기 · 빈 슬롯"
	if slots.active_slot >= 1:
		return "교체: " + weapon_display_name(slots.weapon_slots[slots.active_slot])
	return "교체할 무기 슬롯 선택 필요"

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
				display_text += "\n호환: " + Display.weapon_name(item.ammo_weapon_type)
		ItemData.Type.HEAL:
			display_text += " ×%d" % item.amount
		ItemData.Type.ARMOR:
			if item.equipment_id.is_empty():
				display_text += " +%d" % item.amount
			else:
				display_text += "\n방어 %d%% · 이동 %d%%" % [
					int(round(item.damage_reduction * 100.0)),
					int(round(item.movement_multiplier * 100.0)),
				]
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
