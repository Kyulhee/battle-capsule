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
