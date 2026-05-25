extends RefCounted

var _icon_cache: Dictionary = {}


func texture_for_item(item: ItemData, asset_catalog = null) -> Texture2D:
	var icon_id = icon_id_for_item(item)
	return texture_for_id(icon_id, asset_catalog)


func texture_for_id(icon_id: String, asset_catalog = null) -> Texture2D:
	if icon_id == "":
		return null
	if _icon_cache.has(icon_id):
		return _icon_cache[icon_id]

	var texture: Texture2D = null
	if asset_catalog and asset_catalog.has_method("get_path"):
		var path = asset_catalog.get_path("icons", icon_id, "")
		if path != "" and ResourceLoader.exists(path):
			var loaded = load(path)
			if loaded is Texture2D:
				texture = loaded
		elif path != "" and FileAccess.file_exists(path):
			var image = Image.new()
			if image.load(path) == OK:
				texture = ImageTexture.create_from_image(image)

	_icon_cache[icon_id] = texture
	return texture


static func icon_id_for_item(item: ItemData) -> String:
	if not item:
		return ""
	match item.type:
		ItemData.Type.WEAPON:
			if item.weapon_stats:
				return "weapon.%s" % item.weapon_stats.weapon_type
		ItemData.Type.AMMO:
			if item.ammo_weapon_type != "":
				return "ammo.%s" % item.ammo_weapon_type
		ItemData.Type.HEAL:
			return "item.medkit" if item.rarity == ItemData.Rarity.RARE else "item.heal"
		ItemData.Type.ARMOR:
			return "item.armor"
	return ""
