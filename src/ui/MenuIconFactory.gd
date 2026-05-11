class_name MenuIconFactory
extends RefCounted

static func make_capsule_logo(logo_size: int = 80) -> ImageTexture:
	var img = Image.create(logo_size, logo_size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx = logo_size / 2
	var cy = logo_size / 2
	var rx = 18
	var ry = 32
	for py in range(logo_size):
		for px in range(logo_size):
			var dx = float(px - cx) / rx
			var dy = float(py - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				var top_half = py < cy
				var border = (dx * dx + dy * dy) > 0.80
				if border:
					img.set_pixel(px, py, Color(0.15, 0.15, 0.22, 1.0))
				elif top_half:
					img.set_pixel(px, py, Color(0.25, 0.55, 1.0, 1.0))
				else:
					img.set_pixel(px, py, Color(0.9, 0.25, 0.25, 1.0))

	for px in range(cx - rx + 2, cx + rx - 1):
		img.set_pixel(px, cy, Color(0.15, 0.15, 0.22, 1.0))
		img.set_pixel(px, cy - 1, Color(0.15, 0.15, 0.22, 1.0))
	return ImageTexture.create_from_image(img)

static func make_icon(shape: String) -> ImageTexture:
	const S = 12
	var img = Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var px: Array
	match shape:
		"skull":
			px = [
				[0,0,1,1,1,1,1,1,0,0,0,0],
				[0,1,1,1,1,1,1,1,1,0,0,0],
				[1,1,1,1,1,1,1,1,1,1,0,0],
				[1,1,0,0,1,1,0,0,1,1,0,0],
				[1,1,0,0,1,1,0,0,1,1,0,0],
				[1,1,1,1,1,1,1,1,1,1,0,0],
				[1,1,1,1,1,1,1,1,1,1,0,0],
				[0,1,0,1,1,0,1,1,0,1,0,0],
				[0,1,0,1,1,0,1,1,0,1,0,0],
				[0,0,0,0,0,0,0,0,0,0,0,0],
				[0,0,0,0,0,0,0,0,0,0,0,0],
				[0,0,0,0,0,0,0,0,0,0,0,0],
			]
		"hand":
			px = [
				[0,0,1,1,0,0,0,0,0,0,0,0],
				[0,1,1,1,0,0,0,0,0,0,0,0],
				[0,1,1,1,0,1,1,0,0,0,0,0],
				[0,1,1,1,1,1,1,0,1,1,0,0],
				[0,1,1,1,1,1,1,1,1,1,0,0],
				[1,1,1,1,1,1,1,1,1,1,0,0],
				[1,1,1,1,1,1,1,1,1,1,0,0],
				[0,1,1,1,1,1,1,1,1,0,0,0],
				[0,0,1,1,1,1,1,1,0,0,0,0],
				[0,0,0,1,1,1,1,0,0,0,0,0],
				[0,0,0,0,0,0,0,0,0,0,0,0],
				[0,0,0,0,0,0,0,0,0,0,0,0],
			]
		"person":
			px = [
				[0,0,0,1,1,1,0,0,0,0,0,0],
				[0,0,0,1,1,1,0,0,0,0,0,0],
				[0,0,0,1,1,1,0,0,0,0,0,0],
				[0,0,1,1,1,1,1,0,0,0,0,0],
				[0,0,0,1,1,1,0,0,0,0,0,0],
				[0,0,0,1,1,1,0,0,0,0,0,0],
				[0,0,1,1,1,1,1,0,0,0,0,0],
				[0,0,1,1,1,1,1,0,0,0,0,0],
				[0,1,1,1,0,1,1,1,0,0,0,0],
				[0,1,1,0,0,0,1,1,0,0,0,0],
				[0,1,0,0,0,0,0,1,0,0,0,0],
				[0,0,0,0,0,0,0,0,0,0,0,0],
			]
		_:
			px = []
	for y in range(S):
		for x in range(S):
			if y < px.size() and x < px[y].size() and px[y][x]:
				img.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(img)
