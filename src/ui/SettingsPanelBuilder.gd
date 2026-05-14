class_name SettingsPanelBuilder
extends RefCounted

static func show(
	parent: Control,
	current_volume: float,
	fullscreen: bool,
	on_volume_changed: Callable,
	on_fullscreen_toggled: Callable,
	on_close: Callable,
	apply_button_style: Callable
) -> void:
	if not parent or parent.get_node_or_null("SettingsPanel"):
		return

	var panel = PanelContainer.new()
	panel.name = "SettingsPanel"
	panel.layout_mode = 1
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -200.0
	panel.offset_right = 200.0
	panel.offset_top = -160.0
	panel.offset_bottom = 160.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.add_theme_stylebox_override("panel", _panel_style())
	parent.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.88, 0.95, 0.9))
	vbox.add_child(title)

	var vol_lbl = Label.new()
	vol_lbl.text = "VOLUME"
	vol_lbl.add_theme_font_size_override("font_size", 15)
	vol_lbl.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	vbox.add_child(vol_lbl)

	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = current_volume
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(slider)

	var vol_val_lbl = Label.new()
	vol_val_lbl.text = "%d%%" % int(current_volume * 100)
	vol_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vol_val_lbl.add_theme_font_size_override("font_size", 13)
	vol_val_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	vbox.add_child(vol_val_lbl)
	slider.value_changed.connect(func(v: float):
		vol_val_lbl.text = "%d%%" % int(v * 100)
		_call_if_valid(on_volume_changed, v)
	)

	var fs_btn = Button.new()
	fs_btn.text = _fullscreen_text(fullscreen)
	fs_btn.add_theme_font_size_override("font_size", 18)
	fs_btn.pressed.connect(func():
		var new_fullscreen = fullscreen
		if on_fullscreen_toggled.is_valid():
			new_fullscreen = bool(on_fullscreen_toggled.call())
		fs_btn.text = _fullscreen_text(new_fullscreen)
	)
	_call_if_valid(apply_button_style, fs_btn)
	vbox.add_child(fs_btn)

	var close_btn = Button.new()
	close_btn.text = "CLOSE"
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(func():
		_call_if_valid(on_close, slider.value)
		panel.queue_free()
	)
	_call_if_valid(apply_button_style, close_btn)
	vbox.add_child(close_btn)

static func _panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.10, 0.97)
	style.border_color = Color(0.25, 0.55, 0.35, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style

static func _fullscreen_text(fullscreen: bool) -> String:
	return "FULLSCREEN: ON" if fullscreen else "FULLSCREEN: OFF"

static func _call_if_valid(callable: Callable, arg: Variant) -> void:
	if callable.is_valid():
		callable.call(arg)
