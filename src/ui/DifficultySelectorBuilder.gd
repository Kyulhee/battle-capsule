class_name DifficultySelectorBuilder
extends RefCounted

const DifficultyCatalogScript = preload("res://src/core/DifficultyCatalog.gd")

static func insert(
	vbox: VBoxContainer,
	menu_panel: Control,
	start_button: Button,
	current_difficulty: int,
	on_difficulty_selected: Callable,
	on_pressure_toggled: Callable,
	apply_button_style: Callable
) -> Dictionary:
	if not vbox or not menu_panel or not start_button:
		return {}

	var start_idx = start_button.get_index()

	var diff_lbl = Label.new()
	diff_lbl.name = "DifficultyLabel"
	diff_lbl.text = "난이도"
	diff_lbl.custom_minimum_size = Vector2(0, 18)
	diff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_lbl.add_theme_font_size_override("font_size", 13)
	diff_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	vbox.add_child(diff_lbl)
	vbox.move_child(diff_lbl, start_idx)

	var diff_hbox = HBoxContainer.new()
	diff_hbox.name = "DifficultyButtons"
	diff_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	diff_hbox.add_theme_constant_override("separation", 6)
	diff_hbox.custom_minimum_size = Vector2(0, 38)
	vbox.add_child(diff_hbox)
	vbox.move_child(diff_hbox, start_idx + 1)

	var tooltip = _make_tooltip()
	var tooltip_label = tooltip.get_node("TooltipLabel") as Label
	menu_panel.add_child(tooltip)

	var buttons: Array[Button] = []
	for i in range(4):
		var diff_idx = i
		var btn = Button.new()
		btn.text = DifficultyCatalogScript.label(diff_idx)
		btn.custom_minimum_size = Vector2(68, 0)
		btn.add_theme_font_size_override("font_size", 14)
		if on_difficulty_selected.is_valid():
			btn.pressed.connect(on_difficulty_selected.bind(diff_idx))
		btn.mouse_entered.connect(func():
			_show_tooltip(tooltip, tooltip_label, btn, diff_idx)
		)
		btn.mouse_exited.connect(func():
			if is_instance_valid(tooltip):
				tooltip.visible = false
		)
		diff_hbox.add_child(btn)
		buttons.append(btn)
		_call_if_valid(apply_button_style, btn)

	var pressure_check = CheckButton.new()
	pressure_check.name = "PressureOptInCheck"
	pressure_check.text = "압박 미션 활성화"
	pressure_check.custom_minimum_size = Vector2(310, 24)
	pressure_check.add_theme_font_size_override("font_size", 12)
	pressure_check.button_pressed = false
	pressure_check.visible = (current_difficulty == 2)
	if on_pressure_toggled.is_valid():
		pressure_check.toggled.connect(on_pressure_toggled)
	vbox.add_child(pressure_check)
	vbox.move_child(pressure_check, start_idx + 2)

	var selector = {
		"buttons": buttons,
		"pressure_check": pressure_check,
		"tooltip": tooltip,
	}
	update_highlights(selector, current_difficulty)
	return selector

static func update_highlights(selector: Dictionary, selected_diff: int) -> void:
	var buttons: Array = selector.get("buttons", [])
	for i in range(buttons.size()):
		var btn = buttons[i]
		if not is_instance_valid(btn):
			continue
		btn.modulate = DifficultyCatalogScript.color(i) if i == selected_diff else DifficultyCatalogScript.dim_color()

static func set_pressure_visible(selector: Dictionary, visible: bool) -> void:
	var pressure_check = selector.get("pressure_check", null)
	if is_instance_valid(pressure_check):
		pressure_check.visible = visible

static func _make_tooltip() -> PanelContainer:
	var tooltip = PanelContainer.new()
	tooltip.name = "DifficultyTooltip"
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.10, 0.95)
	style.border_color = Color(0.35, 0.60, 0.45, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	tooltip.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	label.name = "TooltipLabel"
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.82, 0.90, 0.84))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tooltip.add_child(label)
	tooltip.custom_minimum_size = Vector2(240, 0)
	tooltip.visible = false
	return tooltip

static func _show_tooltip(
	tooltip: PanelContainer,
	label: Label,
	source_button: Button,
	diff: int
) -> void:
	if not is_instance_valid(tooltip) or not is_instance_valid(label) or not is_instance_valid(source_button):
		return
	label.text = DifficultyCatalogScript.description(diff)
	var gr = source_button.get_global_rect()
	tooltip.global_position = Vector2(gr.position.x - 10, gr.end.y + 6)
	tooltip.visible = true

static func _call_if_valid(callable: Callable, arg: Variant) -> void:
	if callable.is_valid():
		callable.call(arg)
