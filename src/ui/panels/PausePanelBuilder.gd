class_name PausePanelBuilder
extends RefCounted

static func build(
	on_resume: Callable,
	on_restart: Callable,
	on_main_menu: Callable,
	style_button: Callable
) -> Control:
	var panel = ColorRect.new()
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.layout_mode = 1
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.color = Color(0.0, 0.0, 0.0, 0.55)
	panel.z_index = 15

	var box = VBoxContainer.new()
	box.process_mode = Node.PROCESS_MODE_ALWAYS
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -110.0
	box.offset_right = 110.0
	box.offset_top = -80.0
	box.offset_bottom = 80.0
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title = Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	box.add_child(title)

	for button_spec in [
		{"label": "RESUME", "callback": on_resume},
		{"label": "RESTART", "callback": on_restart},
		{"label": "MAIN MENU", "callback": on_main_menu},
	]:
		box.add_child(_make_button(button_spec, style_button))

	return panel

static func _make_button(button_spec: Dictionary, style_button: Callable) -> Button:
	var button = Button.new()
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.text = str(button_spec.get("label", ""))
	button.add_theme_font_size_override("font_size", 20)
	var callback: Callable = button_spec.get("callback", Callable())
	if callback.is_valid():
		button.pressed.connect(callback)
	if style_button.is_valid():
		style_button.call(button)
	return button
