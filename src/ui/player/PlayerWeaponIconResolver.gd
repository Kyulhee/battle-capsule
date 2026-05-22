extends RefCounted

var _catalog_icon_cache: Dictionary = {}

func make_weapon_icon(wtype: String, catalog = null) -> Texture2D:
	if wtype != "":
		var catalog_icon = _load_catalog_icon("weapon.%s" % wtype, catalog)
		if catalog_icon:
			return catalog_icon

	var W := 28
	var H := 14
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c: Color
	match wtype:
		"knife":
			c = Color(0.85, 0.85, 0.9)
			for x in range(3, 23): img.set_pixel(x, 6, c); img.set_pixel(x, 7, c)
			for x in range(22, 26): img.set_pixel(x, 7, c)
			for y in range(4, 10): img.set_pixel(2, y, c); img.set_pixel(3, y, c)
		"pistol":
			c = Color(0.55, 0.78, 1.0)
			for x in range(7, 19):
				for y in range(5, 9): img.set_pixel(x, y, c)
			for x in range(18, 26): img.set_pixel(x, 6, c); img.set_pixel(x, 7, c)
			for x in range(8, 12):
				for y in range(8, 13): img.set_pixel(x, y, c)
		"ar":
			c = Color(0.2, 0.88, 0.35)
			for x in range(2, 23):
				for y in range(6, 9): img.set_pixel(x, y, c)
			for x in range(2, 5):
				for y in range(5, 10): img.set_pixel(x, y, c)
			for x in range(22, 28): img.set_pixel(x, 7, c)
			for x in range(11, 17):
				for y in range(9, 14): img.set_pixel(x, y, c)
		"shotgun":
			c = Color(1.0, 0.6, 0.1)
			for x in range(2, 21):
				for y in range(5, 10): img.set_pixel(x, y, c)
			for y in range(4, 10): img.set_pixel(2, y, c); img.set_pixel(3, y, c)
			for x in range(20, 27):
				for y in range(5, 10): img.set_pixel(x, y, c)
			for x in range(20, 27): img.set_pixel(x, 7, Color(0, 0, 0, 0.6))
		"railgun":
			c = Color(0.85, 0.2, 1.0)
			for x in range(0, W): img.set_pixel(x, 7, c)
			for x in range(0, 6):
				for y in range(5, 10): img.set_pixel(x, y, c)
			for i in range(3):
				var cx = 9 + i * 7
				if cx + 1 < W:
					img.set_pixel(cx, 5, c); img.set_pixel(cx, 6, c)
					img.set_pixel(cx, 8, c); img.set_pixel(cx, 9, c)
					img.set_pixel(cx + 1, 5, c); img.set_pixel(cx + 1, 6, c)
					img.set_pixel(cx + 1, 8, c); img.set_pixel(cx + 1, 9, c)
		_:
			c = Color(0.45, 0.45, 0.45, 0.65)
			for i in range(3):
				var cx = 7 + i * 7
				img.set_pixel(cx, 6, c); img.set_pixel(cx + 1, 6, c)
				img.set_pixel(cx, 7, c); img.set_pixel(cx + 1, 7, c)
	return ImageTexture.create_from_image(img)

func _load_catalog_icon(icon_id: String, catalog) -> Texture2D:
	if _catalog_icon_cache.has(icon_id):
		return _catalog_icon_cache[icon_id]

	var texture: Texture2D = null
	if catalog and catalog.has_method("get_path"):
		var path = catalog.get_path("icons", icon_id, "")
		if path != "" and ResourceLoader.exists(path):
			var loaded = load(path)
			if loaded is Texture2D:
				texture = loaded
		elif path != "" and FileAccess.file_exists(path):
			var image = Image.new()
			if image.load(path) == OK:
				texture = ImageTexture.create_from_image(image)

	_catalog_icon_cache[icon_id] = texture
	return texture
