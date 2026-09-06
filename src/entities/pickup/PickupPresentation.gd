extends RefCounted

const Display = preload("res://src/core/DropDisplayCatalog.gd")

const LABEL_NAME_RANGE := 3.2
const LABEL_CLUSTER_RADIUS := 2.2
const VISIBILITY_REFRESH_INTERVAL := 0.1
const LIGHT_LOD_FULL_DISTANCE := 16.0
const LIGHT_LOD_DIM_DISTANCE := 30.0
const LIGHT_LOD_DIM_ENERGY_MULT := 0.35
const LIGHT_LOD_DIM_RANGE_MULT := 0.70
const FOCUSED_LABEL_SCALE := Vector3(1.08, 1.08, 1.08)
const NORMAL_LABEL_SCALE := Vector3.ONE


static func base_color(item: ItemData) -> Color:
	return Display.item_color(item)


static func visual_params(item: ItemData) -> Dictionary:
	if not item:
		return {"emission": 0.18, "light_energy": 0.6, "light_range": 2.0}
	var high_value_weapon := item.weapon_stats != null and (
		item.weapon_stats.weapon_type == "railgun" or item.weapon_stats.weapon_tier >= 2)
	match item.type:
		ItemData.Type.WEAPON:
			if high_value_weapon:
				return {"emission": 0.36, "light_energy": 1.35, "light_range": 2.8}
			return {"emission": 0.18, "light_energy": 0.75, "light_range": 2.1}
		ItemData.Type.AMMO:
			if item.ammo_weapon_type == "railgun":
				return {"emission": 0.22, "light_energy": 0.8, "light_range": 2.0}
			return {"emission": 0.10, "light_energy": 0.45, "light_range": 1.6}
		ItemData.Type.HEAL:
			if item.rarity == ItemData.Rarity.RARE:
				return {"emission": 0.34, "light_energy": 1.25, "light_range": 2.5}
			return {"emission": 0.20, "light_energy": 0.75, "light_range": 2.0}
		ItemData.Type.ARMOR:
			if not item.equipment_id.is_empty():
				return {"emission": 0.22, "light_energy": 0.8, "light_range": 2.1}
			return {"emission": 0.34, "light_energy": 1.25, "light_range": 2.5}
	return {"emission": 0.18, "light_energy": 0.6, "light_range": 2.0}


static func label_color(item: ItemData, is_focused: bool) -> Color:
	var color := Display.item_color(item)
	return color.lightened(0.10) if is_focused else color


static func icon_plane_size(item: ItemData) -> Vector2:
	if not item:
		return Vector2(0.48, 0.48)
	match item.type:
		ItemData.Type.WEAPON:
			return Vector2(0.72, 0.44)
		ItemData.Type.AMMO:
			return Vector2(0.52, 0.52)
		ItemData.Type.HEAL:
			return Vector2(0.50, 0.50)
		ItemData.Type.ARMOR:
			return Vector2(0.56, 0.56)
	return Vector2(0.48, 0.48)


static func icon_plane_y(item: ItemData) -> float:
	if not item:
		return 0.18
	match item.type:
		ItemData.Type.WEAPON:
			return 0.176
		ItemData.Type.AMMO:
			return 0.166
		ItemData.Type.HEAL:
			return 0.176
		ItemData.Type.ARMOR:
			return 0.166
	return 0.18
