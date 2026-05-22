extends RefCounted

static func build_top_hud(root: Control) -> Dictionary:
	var zone_timer_label = Label.new()
	zone_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_timer_label.add_theme_font_size_override("font_size", 26)
	zone_timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
	zone_timer_label.add_theme_constant_override("outline_size", 8)

	var zone_panel = PanelContainer.new()
	root.add_child(zone_panel)
	zone_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	zone_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	zone_panel.position.y += 6
	var zone_style = StyleBoxFlat.new()
	zone_style.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	zone_style.set_corner_radius_all(6)
	zone_style.content_margin_left = 14
	zone_style.content_margin_right = 14
	zone_style.content_margin_top = 4
	zone_style.content_margin_bottom = 4
	zone_panel.add_theme_stylebox_override("panel", zone_style)
	zone_panel.add_child(zone_timer_label)

	var mission_hud_label = Label.new()
	mission_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_hud_label.add_theme_font_size_override("font_size", 15)
	mission_hud_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	mission_hud_label.add_theme_color_override("font_outline_color", Color.BLACK)
	mission_hud_label.add_theme_constant_override("outline_size", 6)
	mission_hud_label.visible = false
	root.add_child(mission_hud_label)
	mission_hud_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	mission_hud_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mission_hud_label.position.y += 46

	var pressure_hud_label = Label.new()
	pressure_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pressure_hud_label.add_theme_font_size_override("font_size", 15)
	pressure_hud_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.1))
	pressure_hud_label.add_theme_color_override("font_outline_color", Color.BLACK)
	pressure_hud_label.add_theme_constant_override("outline_size", 8)
	pressure_hud_label.visible = false
	root.add_child(pressure_hud_label)
	pressure_hud_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	pressure_hud_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pressure_hud_label.position.y += 96

	var flash_panel = PanelContainer.new()
	flash_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	flash_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	flash_panel.grow_vertical = Control.GROW_DIRECTION_END
	flash_panel.position.y += 110
	var flash_style = StyleBoxFlat.new()
	flash_style.bg_color = Color(0.05, 0.05, 0.05, 0.78)
	flash_style.set_corner_radius_all(6)
	flash_style.content_margin_left = 18
	flash_style.content_margin_right = 18
	flash_style.content_margin_top = 7
	flash_style.content_margin_bottom = 7
	flash_panel.add_theme_stylebox_override("panel", flash_style)

	var flash_label = Label.new()
	flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flash_label.add_theme_font_size_override("font_size", 16)
	flash_label.add_theme_color_override("font_outline_color", Color.BLACK)
	flash_label.add_theme_constant_override("outline_size", 6)
	flash_panel.add_child(flash_label)
	flash_panel.modulate.a = 0.0
	root.add_child(flash_panel)

	var kill_feed_container = VBoxContainer.new()
	root.add_child(kill_feed_container)
	kill_feed_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	kill_feed_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	kill_feed_container.position.x -= 220
	kill_feed_container.position.y += 280
	kill_feed_container.custom_minimum_size = Vector2(200, 0)

	return {
		"zone_timer_label": zone_timer_label,
		"mission_hud_label": mission_hud_label,
		"pressure_hud_label": pressure_hud_label,
		"flash_panel": flash_panel,
		"flash_label": flash_label,
		"kill_feed_container": kill_feed_container,
	}

static func build_status_hud(root: Control) -> Dictionary:
	var hud_a = VBoxContainer.new()
	root.add_child(hud_a)
	hud_a.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	hud_a.position = Vector2(12, 12)
	hud_a.add_theme_constant_override("separation", 3)

	var hp_row = HBoxContainer.new()
	hud_a.add_child(hp_row)
	hp_row.add_theme_constant_override("separation", 6)

	var hp_lbl = Label.new()
	hp_lbl.text = "HP"
	hp_lbl.add_theme_font_size_override("font_size", 14)
	hp_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	hp_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	hp_lbl.add_theme_constant_override("outline_size", 5)
	hp_row.add_child(hp_lbl)

	var hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(140, 14)
	hp_bar.show_percentage = false
	var hp_bg = StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.12, 0.12, 0.12, 0.85)
	hp_bg.set_corner_radius_all(3)
	hp_bg.border_color = Color(0.4, 0.4, 0.4, 0.7)
	hp_bg.set_border_width_all(1)
	hp_bar.add_theme_stylebox_override("background", hp_bg)
	var hp_fill = StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.2, 1.0, 0.35)
	hp_fill.set_corner_radius_all(3)
	hp_bar.add_theme_stylebox_override("fill", hp_fill)
	hp_row.add_child(hp_bar)

	var hp_val = Label.new()
	hp_val.add_theme_font_size_override("font_size", 14)
	hp_val.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	hp_val.add_theme_color_override("font_outline_color", Color.BLACK)
	hp_val.add_theme_constant_override("outline_size", 5)
	hp_row.add_child(hp_val)

	var sh_row = HBoxContainer.new()
	hud_a.add_child(sh_row)
	sh_row.add_theme_constant_override("separation", 6)

	var sh_lbl = Label.new()
	sh_lbl.text = "SH"
	sh_lbl.add_theme_font_size_override("font_size", 14)
	sh_lbl.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	sh_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	sh_lbl.add_theme_constant_override("outline_size", 5)
	sh_row.add_child(sh_lbl)

	var sh_bar = ProgressBar.new()
	sh_bar.custom_minimum_size = Vector2(140, 14)
	sh_bar.show_percentage = false
	var sh_bg = StyleBoxFlat.new()
	sh_bg.bg_color = Color(0.06, 0.08, 0.18, 0.85)
	sh_bg.set_corner_radius_all(3)
	sh_bg.border_color = Color(0.3, 0.4, 0.7, 0.7)
	sh_bg.set_border_width_all(1)
	sh_bar.add_theme_stylebox_override("background", sh_bg)
	var sh_fill = StyleBoxFlat.new()
	sh_fill.bg_color = Color(0.3, 0.6, 1.0)
	sh_fill.set_corner_radius_all(3)
	sh_bar.add_theme_stylebox_override("fill", sh_fill)
	sh_row.add_child(sh_bar)

	var sh_val = Label.new()
	sh_val.add_theme_font_size_override("font_size", 14)
	sh_val.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	sh_val.add_theme_color_override("font_outline_color", Color.BLACK)
	sh_val.add_theme_constant_override("outline_size", 5)
	sh_row.add_child(sh_val)

	var stat_row = HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", 4)
	hud_a.add_child(stat_row)

	var artifact_label = Label.new()
	artifact_label.add_theme_font_size_override("font_size", 12)
	artifact_label.add_theme_color_override("font_outline_color", Color.BLACK)
	artifact_label.add_theme_constant_override("outline_size", 5)
	artifact_label.visible = false
	hud_a.add_child(artifact_label)

	var stat_heal_val = _stat_pair(stat_row, "♥", Color(0.95, 0.25, 0.25))
	var stat_mk_val = _stat_pair(stat_row, "◆", Color(1.0, 0.85, 0.1))
	var sp1 = Label.new()
	sp1.text = "  "
	stat_row.add_child(sp1)
	var stat_kill_val = _stat_pair_icon(stat_row, _make_hud_icon("skull"), Color(1.0, 0.92, 0.15))
	var stat_asst_val = _stat_pair_icon(stat_row, _make_hud_icon("hand"), Color(1.0, 0.6, 0.2))
	var sp2 = Label.new()
	sp2.text = "  "
	stat_row.add_child(sp2)
	var stat_alive_val = _stat_pair_icon(stat_row, _make_hud_icon("person"), Color(0.72, 0.72, 0.72))

	return {
		"hp_bar": hp_bar,
		"hp_fill": hp_fill,
		"hp_val": hp_val,
		"sh_bar": sh_bar,
		"sh_val": sh_val,
		"artifact_label": artifact_label,
		"stat_heal_val": stat_heal_val,
		"stat_mk_val": stat_mk_val,
		"stat_kill_val": stat_kill_val,
		"stat_asst_val": stat_asst_val,
		"stat_alive_val": stat_alive_val,
	}

static func build_slot_hud(root: Control) -> Dictionary:
	var slot_bar = HBoxContainer.new()
	root.add_child(slot_bar)
	slot_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	slot_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	slot_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	slot_bar.position.y -= 18
	slot_bar.position.x -= 201
	slot_bar.add_theme_constant_override("separation", 8)

	var slot_panels = []
	var slot_icon_rects = []
	var slot_ammo_labels = []
	var slot_labels = ["`", "1", "2", "3", "4"]
	for i in range(slot_labels.size()):
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(74, 84)
		slot_bar.add_child(panel)
		slot_panels.append(panel)

		var vbox = VBoxContainer.new()
		panel.add_child(vbox)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 1)

		var key_lbl = Label.new()
		key_lbl.text = slot_labels[i]
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_lbl.add_theme_font_size_override("font_size", 12)
		key_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		vbox.add_child(key_lbl)

		var icon_rect = TextureRect.new()
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(48, 48)
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		vbox.add_child(icon_rect)
		slot_icon_rects.append(icon_rect)

		var ammo_lbl = Label.new()
		ammo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ammo_lbl.add_theme_font_size_override("font_size", 12)
		vbox.add_child(ammo_lbl)
		slot_ammo_labels.append(ammo_lbl)

	return {
		"slot_panels": slot_panels,
		"slot_icon_rects": slot_icon_rects,
		"slot_ammo_labels": slot_ammo_labels,
	}

static func build_zone_warning_overlay(root: Control) -> StyleBoxFlat:
	var zone_warn_panel = Panel.new()
	zone_warn_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	zone_warn_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var zone_warning_style = StyleBoxFlat.new()
	zone_warning_style.draw_center = false
	zone_warning_style.bg_color = Color.TRANSPARENT
	zone_warning_style.border_color = Color(1.0, 0.08, 0.05, 0.0)
	zone_warning_style.set_border_width_all(28)
	zone_warn_panel.add_theme_stylebox_override("panel", zone_warning_style)
	root.add_child(zone_warn_panel)
	return zone_warning_style

static func _stat_pair(container: HBoxContainer, symbol: String, col: Color) -> Label:
	var sym = Label.new()
	sym.text = symbol
	sym.add_theme_font_size_override("font_size", 15)
	sym.add_theme_color_override("font_color", col)
	sym.add_theme_color_override("font_outline_color", Color.BLACK)
	sym.add_theme_constant_override("outline_size", 6)
	container.add_child(sym)
	var val = Label.new()
	val.add_theme_font_size_override("font_size", 13)
	val.add_theme_color_override("font_color", col)
	val.add_theme_color_override("font_outline_color", Color.BLACK)
	val.add_theme_constant_override("outline_size", 5)
	container.add_child(val)
	return val

static func _stat_pair_icon(container: HBoxContainer, icon_tex: ImageTexture, col: Color) -> Label:
	var icon = TextureRect.new()
	icon.texture = icon_tex
	icon.custom_minimum_size = Vector2(14, 14)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.modulate = col
	container.add_child(icon)
	var val = Label.new()
	val.add_theme_font_size_override("font_size", 13)
	val.add_theme_color_override("font_color", col)
	val.add_theme_color_override("font_outline_color", Color.BLACK)
	val.add_theme_constant_override("outline_size", 5)
	container.add_child(val)
	return val

static func _make_hud_icon(shape: String) -> ImageTexture:
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
