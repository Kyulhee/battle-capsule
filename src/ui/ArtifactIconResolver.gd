extends RefCounted

var _cache: Dictionary = {}
var _catalog_icon_cache: Dictionary = {}


func make_artifact_icon(artifact: Dictionary, asset_catalog = null, size: int = 36) -> Texture2D:
	var artifact_id := String(artifact.get("id", ""))
	var icon_id := "artifact.%s" % artifact_id
	var catalog_texture := _load_catalog_texture(icon_id, asset_catalog)
	if catalog_texture != null:
		return catalog_texture
	var color: Color = artifact.get("color", Color.WHITE)
	if asset_catalog != null and asset_catalog.has_method("get_color"):
		color = asset_catalog.get_color("icons", icon_id, color)
	var shape := _get_fallback_shape(icon_id, artifact_id, asset_catalog)
	var cache_key := "%s:%s:%d:%s" % [icon_id, shape, size, color.to_html()]
	if _cache.has(cache_key):
		return _cache[cache_key] as Texture2D
	var texture := _draw_fallback_icon(size, color, shape)
	_cache[cache_key] = texture
	return texture


func _load_catalog_texture(icon_id: String, asset_catalog) -> Texture2D:
	if asset_catalog == null or not asset_catalog.has_method("get_path"):
		return null
	var path := String(asset_catalog.get_path("icons", icon_id, ""))
	var cache_key := "%s:%s" % [icon_id, path]
	if _catalog_icon_cache.has(cache_key):
		return _catalog_icon_cache[cache_key] as Texture2D

	var texture: Texture2D = null
	if not path.is_empty() and ResourceLoader.exists(path):
		var loaded := load(path)
		if loaded is Texture2D:
			texture = loaded
	elif not path.is_empty() and FileAccess.file_exists(path):
		var image := Image.new()
		if image.load(path) == OK:
			texture = ImageTexture.create_from_image(image)
	_catalog_icon_cache[cache_key] = texture
	return texture


func _get_fallback_shape(icon_id: String, artifact_id: String, asset_catalog) -> String:
	if asset_catalog != null and asset_catalog.has_method("get_entry"):
		var entry: Dictionary = asset_catalog.get_entry("icons", icon_id)
		if not entry.is_empty():
			return String(entry.get("fallback_shape", artifact_id))
	match artifact_id:
		"emergency_shell":
			return "capsule"
		"ghost_grass":
			return "grass"
		"armor_sponge":
			return "shield"
		"silent_core":
			return "core"
		"zone_battery":
			return "battery"
		_:
			return artifact_id


func _draw_fallback_icon(size: int, color: Color, shape: String) -> Texture2D:
	var icon_size := maxi(size, 16)
	var image := Image.create(icon_size, icon_size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	_draw_badge(image, color)
	match shape:
		"capsule":
			_draw_capsule(image, color)
		"grass":
			_draw_grass(image, color)
		"shield":
			_draw_shield(image, color)
		"battery":
			_draw_battery(image, color)
		"core":
			_draw_core(image, color)
		_:
			_draw_core(image, color)
	return ImageTexture.create_from_image(image)


func _draw_badge(image: Image, color: Color) -> void:
	var size := image.get_width()
	var center := Vector2((size - 1) * 0.5, (size - 1) * 0.5)
	var outer_radius := size * 0.48
	var inner_radius := size * 0.40
	var dark := Color(0.04, 0.05, 0.06, 0.88)
	var edge := color.lightened(0.20)
	for x in range(size):
		for y in range(size):
			var dist := Vector2(x, y).distance_to(center)
			if dist <= outer_radius:
				image.set_pixel(x, y, edge if dist >= inner_radius else dark)


func _draw_capsule(image: Image, color: Color) -> void:
	var size := image.get_width()
	var left := int(size * 0.24)
	var right := int(size * 0.76)
	var top := int(size * 0.34)
	var bottom := int(size * 0.66)
	var center_y := (top + bottom) * 0.5
	var radius := (bottom - top) * 0.5
	for x in range(left, right + 1):
		for y in range(top, bottom + 1):
			var cap_dist := 0.0
			if x < left + radius:
				cap_dist = Vector2(x, y).distance_to(Vector2(left + radius, center_y))
			elif x > right - radius:
				cap_dist = Vector2(x, y).distance_to(Vector2(right - radius, center_y))
			if (x >= left + radius and x <= right - radius) or cap_dist <= radius:
				_set_pixel_safe(image, x, y, color.lightened(0.08))
	var mark := Color(1, 1, 1, 0.86)
	_draw_rect(image, int(size * 0.47), int(size * 0.40), maxi(2, int(size * 0.06)), int(size * 0.20), mark)
	_draw_rect(image, int(size * 0.40), int(size * 0.47), int(size * 0.20), maxi(2, int(size * 0.06)), mark)


func _draw_grass(image: Image, color: Color) -> void:
	var size := image.get_width()
	var base := int(size * 0.72)
	var blades := [
		[Vector2(size * 0.28, base), Vector2(size * 0.36, size * 0.34)],
		[Vector2(size * 0.48, base), Vector2(size * 0.50, size * 0.24)],
		[Vector2(size * 0.68, base), Vector2(size * 0.60, size * 0.36)],
	]
	for blade in blades:
		_draw_line(image, blade[0], blade[1], color.lightened(0.10), maxi(2, int(size * 0.06)))
	_draw_rect(image, int(size * 0.25), base, int(size * 0.50), maxi(2, int(size * 0.07)), color.darkened(0.10))


func _draw_shield(image: Image, color: Color) -> void:
	var size := image.get_width()
	var points := PackedVector2Array([
		Vector2(size * 0.50, size * 0.22),
		Vector2(size * 0.72, size * 0.32),
		Vector2(size * 0.66, size * 0.62),
		Vector2(size * 0.50, size * 0.78),
		Vector2(size * 0.34, size * 0.62),
		Vector2(size * 0.28, size * 0.32),
	])
	_fill_polygon(image, points, color.lightened(0.06))
	_draw_rect(image, int(size * 0.47), int(size * 0.32), maxi(2, int(size * 0.06)), int(size * 0.34), Color(1, 1, 1, 0.35))


func _draw_battery(image: Image, color: Color) -> void:
	var size := image.get_width()
	_draw_rect(image, int(size * 0.28), int(size * 0.34), int(size * 0.38), int(size * 0.32), color.lightened(0.06))
	_draw_rect(image, int(size * 0.66), int(size * 0.43), int(size * 0.08), int(size * 0.14), color.lightened(0.06))
	_draw_rect(image, int(size * 0.36), int(size * 0.41), int(size * 0.10), int(size * 0.18), Color(1, 1, 1, 0.72))
	_draw_rect(image, int(size * 0.49), int(size * 0.41), int(size * 0.10), int(size * 0.18), Color(1, 1, 1, 0.38))


func _draw_core(image: Image, color: Color) -> void:
	var size := image.get_width()
	var center := Vector2((size - 1) * 0.5, (size - 1) * 0.5)
	var radius := size * 0.18
	for x in range(size):
		for y in range(size):
			if Vector2(x, y).distance_to(center) <= radius:
				image.set_pixel(x, y, color.lightened(0.12))
	_draw_line(image, Vector2(size * 0.34, size * 0.30), Vector2(size * 0.66, size * 0.70), Color(1, 1, 1, 0.55), maxi(2, int(size * 0.05)))
	_draw_line(image, Vector2(size * 0.66, size * 0.30), Vector2(size * 0.34, size * 0.70), Color(1, 1, 1, 0.55), maxi(2, int(size * 0.05)))


func _draw_rect(image: Image, left: int, top: int, width: int, height: int, color: Color) -> void:
	for x in range(left, left + width):
		for y in range(top, top + height):
			_set_pixel_safe(image, x, y, color)


func _draw_line(image: Image, from: Vector2, to: Vector2, color: Color, width: int) -> void:
	var steps := int(maxf(absf(to.x - from.x), absf(to.y - from.y)))
	var half_width := int(width / 2)
	for i in range(steps + 1):
		var t := 0.0 if steps == 0 else float(i) / float(steps)
		var point := from.lerp(to, t)
		_draw_rect(image, int(point.x) - half_width, int(point.y) - half_width, width, width, color)


func _fill_polygon(image: Image, points: PackedVector2Array, color: Color) -> void:
	var size := image.get_width()
	for x in range(size):
		for y in range(size):
			if Geometry2D.is_point_in_polygon(Vector2(x, y), points):
				image.set_pixel(x, y, color)


func _set_pixel_safe(image: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return
	image.set_pixel(x, y, color)
