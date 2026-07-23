extends RefCounted

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
	if not item:
		return Color.WHITE
	match item.type:
		ItemData.Type.WEAPON:
			return item.color.darkened(0.10)
		ItemData.Type.AMMO:
			return item.color.lightened(0.08)
		ItemData.Type.HEAL:
			return Color(0.25, 0.95, 0.45, 1.0) if item.rarity != ItemData.Rarity.RARE else Color(0.30, 1.0, 0.72, 1.0)
		ItemData.Type.ARMOR:
			return item.color.darkened(0.05) if not item.equipment_id.is_empty() \
				else Color(0.35, 0.62, 1.0, 1.0)
	return item.color


static func visual_params(item: ItemData) -> Dictionary:
	if not item:
		return {"emission": 0.18, "light_energy": 0.6, "light_range": 2.0}
	var high_value_color = _is_high_value_color(item.color)
	match item.type:
		ItemData.Type.WEAPON:
			if high_value_color:
				return {"emission": 0.36, "light_energy": 1.35, "light_range": 2.8}
			return {"emission": 0.18, "light_energy": 0.75, "light_range": 2.1}
		ItemData.Type.AMMO:
			if high_value_color:
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
	if is_focused:
		return Color(1.0, 0.95, 0.55) if item and item.rarity == ItemData.Rarity.RARE else Color(1.0, 1.0, 0.86)
	return Color(1.0, 0.86, 0.22) if item and item.rarity == ItemData.Rarity.RARE else Color(0.88, 0.90, 0.86)


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


static func _is_high_value_color(color: Color) -> bool:
	var is_purple = color.r >= 0.65 and color.b >= 0.65
	var is_orange = color.r >= 0.85 and color.g >= 0.35 and color.g <= 0.75 and color.b <= 0.30
	var is_cyan = color.g >= 0.55 and color.b >= 0.75
	return is_purple or is_orange or is_cyan
