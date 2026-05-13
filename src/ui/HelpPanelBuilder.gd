class_name HelpPanelBuilder
extends RefCounted

const HelpCatalogScript = preload("res://src/core/HelpCatalog.gd")
const MenuIconFactoryScript = preload("res://src/ui/MenuIconFactory.gd")

static func build(vbox: VBoxContainer) -> void:
	for child in vbox.get_children():
		if child.name == "Text":
			child.queue_free()

	var close_btn = vbox.get_node_or_null("CloseHelpBtn")
	var close_idx = close_btn.get_index() if close_btn else vbox.get_child_count()

	var scroll = ScrollContainer.new()
	scroll.layout_mode = 2
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 300)
	vbox.add_child(scroll)
	vbox.move_child(scroll, close_idx)

	var content = VBoxContainer.new()
	content.layout_mode = 2
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	scroll.add_child(content)

	for section in HelpCatalogScript.sections():
		_help_section(content, section.get("title", ""))
		for row in section.get("rows", []):
			match row.get("type", ""):
				"key":
					_make_key_row(content, row.get("keys", []), row.get("desc", ""))
				"icon":
					_make_icon_row(content, row.get("shape", ""), row.get("color", Color.WHITE), row.get("desc", ""))
				"text":
					_make_text_row(content, row.get("symbol", ""), row.get("color", Color.WHITE), row.get("desc", ""))
				"desc":
					_make_desc_row(content, row.get("label", ""), row.get("desc", ""))

static func _help_section(parent: VBoxContainer, title: String) -> void:
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	parent.add_child(spacer)

	var lbl = Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.9, 0.65))
	parent.add_child(lbl)

	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(0.3, 0.55, 0.35, 0.6)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sep)

static func _make_key_row(parent: VBoxContainer, keys: Array, desc: String) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)

	for k in keys:
		var kp = PanelContainer.new()
		var ks = StyleBoxFlat.new()
		ks.bg_color = Color(0.18, 0.20, 0.25)
		ks.border_color = Color(0.62, 0.65, 0.72)
		ks.set_border_width_all(1)
		ks.set_corner_radius_all(3)
		ks.content_margin_left = 6
		ks.content_margin_right = 6
		ks.content_margin_top = 2
		ks.content_margin_bottom = 2
		kp.add_theme_stylebox_override("panel", ks)

		var kl = Label.new()
		kl.text = k
		kl.add_theme_font_size_override("font_size", 12)
		kl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
		kp.add_child(kl)
		row.add_child(kp)

	var dl = Label.new()
	dl.text = "  " + desc
	dl.add_theme_font_size_override("font_size", 13)
	dl.add_theme_color_override("font_color", Color(0.78, 0.82, 0.78))
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(dl)

static func _make_icon_row(parent: VBoxContainer, shape: String, col: Color, desc: String) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var icon = TextureRect.new()
	icon.texture = MenuIconFactoryScript.make_icon(shape)
	icon.custom_minimum_size = Vector2(16, 16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.modulate = col
	row.add_child(icon)

	var dl = Label.new()
	dl.text = desc
	dl.add_theme_font_size_override("font_size", 13)
	dl.add_theme_color_override("font_color", Color(0.78, 0.82, 0.78))
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(dl)

static func _make_text_row(parent: VBoxContainer, symbol: String, col: Color, desc: String) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var sym = Label.new()
	sym.text = symbol
	sym.add_theme_font_size_override("font_size", 15)
	sym.add_theme_color_override("font_color", col)
	sym.custom_minimum_size = Vector2(16, 0)
	sym.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(sym)

	var dl = Label.new()
	dl.text = desc
	dl.add_theme_font_size_override("font_size", 13)
	dl.add_theme_color_override("font_color", Color(0.78, 0.82, 0.78))
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(dl)

static func _make_desc_row(parent: VBoxContainer, label: String, desc: String) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var ll = Label.new()
	ll.text = label
	ll.add_theme_font_size_override("font_size", 13)
	ll.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	ll.custom_minimum_size = Vector2(72, 0)
	row.add_child(ll)

	var dl = Label.new()
	dl.text = desc
	dl.add_theme_font_size_override("font_size", 12)
	dl.add_theme_color_override("font_color", Color(0.72, 0.75, 0.72))
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(dl)
