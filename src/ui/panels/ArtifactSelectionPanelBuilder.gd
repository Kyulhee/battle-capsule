class_name ArtifactSelectionPanelBuilder
extends RefCounted

static func show(
	parent: Control,
	catalog: Array,
	on_selected: Callable,
	on_skip: Callable,
	apply_button_style: Callable
) -> Control:
	if not parent:
		return null

	var overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(overlay)

	var center = VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.add_theme_constant_override("separation", 18)
	overlay.add_child(center)

	var title = Label.new()
	title.text = "아티팩트 선택"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 6)
	center.add_child(title)

	var sub = Label.new()
	sub.text = "원하는 아티팩트를 골라 시작하세요"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.60, 0.60, 0.60))
	center.add_child(sub)

	var card_row = HBoxContainer.new()
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 14)
	center.add_child(card_row)

	for artifact in catalog:
		card_row.add_child(_make_artifact_card(artifact, on_selected, apply_button_style))

	var skip_btn = Button.new()
	skip_btn.text = "선택하지 않기"
	skip_btn.add_theme_font_size_override("font_size", 14)
	skip_btn.custom_minimum_size = Vector2(150, 36)
	if on_skip.is_valid():
		skip_btn.pressed.connect(on_skip)
	_call_if_valid(apply_button_style, skip_btn)
	center.add_child(skip_btn)

	return overlay

static func _make_artifact_card(
	artifact: Dictionary,
	on_selected: Callable,
	apply_button_style: Callable
) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(148, 168)
	panel.add_theme_stylebox_override("panel", _card_style(artifact.get("color", Color.WHITE)))

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = artifact.get("label", "")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", artifact.get("color", Color.WHITE))
	name_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	name_lbl.add_theme_constant_override("outline_size", 5)
	vbox.add_child(name_lbl)

	vbox.add_child(HSeparator.new())

	for key in ["line1", "line2"]:
		if artifact.has(key):
			var lbl = Label.new()
			lbl.text = artifact[key]
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 13)
			lbl.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vbox.add_child(lbl)

	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var pick_btn = Button.new()
	pick_btn.text = "선택"
	pick_btn.add_theme_font_size_override("font_size", 14)
	var selected_artifact = artifact.duplicate(true)
	if on_selected.is_valid():
		pick_btn.pressed.connect(func():
			on_selected.call(selected_artifact)
		)
	_call_if_valid(apply_button_style, pick_btn)
	vbox.add_child(pick_btn)

	return panel

static func _card_style(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.12, 0.16, 0.96)
	style.border_color = color * 0.75
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

static func _call_if_valid(callable: Callable, arg: Variant) -> void:
	if callable.is_valid():
		callable.call(arg)
