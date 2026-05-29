class_name ArtifactSelectionPanelBuilder
extends RefCounted

const ArtifactIconResolverScript = preload("res://src/ui/ArtifactIconResolver.gd")


static func show(
	parent: Control,
	catalog: Array,
	on_selected: Callable,
	on_skip: Callable,
	apply_button_style: Callable,
	asset_catalog = null
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
	center.add_theme_constant_override("separation", 16)
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
	sub.text = "이번 매치의 전투 규칙을 선택하세요"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.60, 0.60, 0.60))
	center.add_child(sub)

	var icon_resolver = ArtifactIconResolverScript.new()
	var selected_state: Dictionary = {"artifact": {}}
	var detail_data: Dictionary = _make_detail_card(on_selected, apply_button_style, selected_state)
	var detail_panel = detail_data.get("panel") as Control
	var detail_refs: Dictionary = detail_data.get("refs", {})

	var option_row = HBoxContainer.new()
	option_row.name = "ArtifactOptionRow"
	option_row.alignment = BoxContainer.ALIGNMENT_CENTER
	option_row.add_theme_constant_override("separation", 12)
	center.add_child(option_row)

	var option_buttons: Array[Button] = []
	var option_colors: Array[Color] = []
	var update_selection = func(index: int) -> void:
		if index < 0 or index >= catalog.size():
			return
		var artifact: Dictionary = catalog[index]
		selected_state["artifact"] = artifact.duplicate(true)
		_update_detail_card(detail_refs, artifact, asset_catalog, icon_resolver)
		for i in range(option_buttons.size()):
			_apply_option_button_style(option_buttons[i], option_colors[i], i == index)

	for i in range(catalog.size()):
		var artifact: Dictionary = catalog[i]
		var option_data: Dictionary = _make_option_cell(artifact, i, update_selection, asset_catalog, icon_resolver)
		option_row.add_child(option_data.get("cell") as Control)
		option_buttons.append(option_data.get("button") as Button)
		option_colors.append(option_data.get("color", Color.WHITE))

	center.add_child(detail_panel)
	if not catalog.is_empty():
		update_selection.call(0)

	var skip_btn = Button.new()
	skip_btn.text = "선택하지 않기"
	skip_btn.add_theme_font_size_override("font_size", 14)
	skip_btn.custom_minimum_size = Vector2(150, 36)
	skip_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if on_skip.is_valid():
		skip_btn.pressed.connect(on_skip)
	_call_if_valid(apply_button_style, skip_btn)
	center.add_child(skip_btn)

	return overlay


static func _make_option_cell(
	artifact: Dictionary,
	index: int,
	on_focus: Callable,
	asset_catalog,
	icon_resolver
) -> Dictionary:
	var color: Color = artifact.get("color", Color.WHITE)
	var cell = VBoxContainer.new()
	cell.name = "ArtifactOptionCell_%s" % String(artifact.get("id", ""))
	cell.custom_minimum_size = Vector2(146, 140)
	cell.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.add_theme_constant_override("separation", 5)

	var circle = Button.new()
	circle.name = "ArtifactOption_%s" % String(artifact.get("id", ""))
	circle.text = ""
	circle.custom_minimum_size = Vector2(82, 82)
	circle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	circle.tooltip_text = String(artifact.get("label", ""))
	_apply_option_button_style(circle, color, false)
	circle.pressed.connect(func():
		on_focus.call(index)
	)
	cell.add_child(circle)

	var icon_center = CenterContainer.new()
	icon_center.name = "ArtifactOptionIconCenter_%s" % String(artifact.get("id", ""))
	icon_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle.add_child(icon_center)

	var icon = TextureRect.new()
	icon.name = "ArtifactOptionIcon_%s" % String(artifact.get("id", ""))
	icon.texture = icon_resolver.make_artifact_icon(artifact, asset_catalog, 54)
	icon.custom_minimum_size = Vector2(56, 56)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_center.add_child(icon)

	var name_lbl = Label.new()
	name_lbl.text = String(artifact.get("label", ""))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", color)
	name_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	name_lbl.add_theme_constant_override("outline_size", 5)
	name_lbl.custom_minimum_size = Vector2(146, 18)
	name_lbl.clip_text = true
	cell.add_child(name_lbl)

	var summary_lbl = Label.new()
	summary_lbl.name = "ArtifactSummary_%s" % String(artifact.get("id", ""))
	summary_lbl.text = _summary_text(artifact)
	summary_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_lbl.add_theme_font_size_override("font_size", 11)
	summary_lbl.add_theme_color_override("font_color", Color(0.72, 0.74, 0.78))
	summary_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	summary_lbl.add_theme_constant_override("outline_size", 3)
	summary_lbl.custom_minimum_size = Vector2(146, 16)
	summary_lbl.clip_text = true
	cell.add_child(summary_lbl)

	return {
		"cell": cell,
		"button": circle,
		"color": color,
	}


static func _make_detail_card(
	on_selected: Callable,
	apply_button_style: Callable,
	selected_state: Dictionary
) -> Dictionary:
	var panel = PanelContainer.new()
	panel.name = "ArtifactDetailPanel"
	panel.custom_minimum_size = Vector2(760, 178)
	panel.add_theme_stylebox_override("panel", _detail_style(Color.WHITE))

	var root = HBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	panel.add_child(root)

	var icon = TextureRect.new()
	icon.name = "ArtifactDetailIcon"
	icon.custom_minimum_size = Vector2(72, 72)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	root.add_child(icon)

	var text_box = VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 6)
	root.add_child(text_box)

	var title_lbl = Label.new()
	title_lbl.name = "ArtifactDetailTitle"
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	title_lbl.add_theme_constant_override("outline_size", 5)
	text_box.add_child(title_lbl)

	var summary_lbl = Label.new()
	summary_lbl.name = "ArtifactDetailSummary"
	summary_lbl.add_theme_font_size_override("font_size", 13)
	summary_lbl.add_theme_color_override("font_color", Color(0.72, 0.74, 0.78))
	text_box.add_child(summary_lbl)

	text_box.add_child(HSeparator.new())

	var line1_lbl = Label.new()
	line1_lbl.name = "ArtifactDetailLine1"
	line1_lbl.add_theme_font_size_override("font_size", 13)
	line1_lbl.add_theme_color_override("font_color", Color(0.86, 0.86, 0.86))
	line1_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_box.add_child(line1_lbl)

	var line2_lbl = Label.new()
	line2_lbl.name = "ArtifactDetailLine2"
	line2_lbl.add_theme_font_size_override("font_size", 13)
	line2_lbl.add_theme_color_override("font_color", Color(0.78, 0.80, 0.84))
	line2_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_box.add_child(line2_lbl)

	var action_box = VBoxContainer.new()
	action_box.custom_minimum_size = Vector2(132, 0)
	root.add_child(action_box)

	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_box.add_child(spacer)

	var pick_btn = Button.new()
	pick_btn.name = "ArtifactPickButton"
	pick_btn.text = "선택"
	pick_btn.add_theme_font_size_override("font_size", 14)
	pick_btn.custom_minimum_size = Vector2(128, 38)
	if on_selected.is_valid():
		pick_btn.pressed.connect(func():
			var artifact: Dictionary = selected_state.get("artifact", {})
			if not artifact.is_empty():
				on_selected.call(artifact.duplicate(true))
		)
	_call_if_valid(apply_button_style, pick_btn)
	action_box.add_child(pick_btn)

	return {
		"panel": panel,
		"refs": {
			"panel": panel,
			"icon": icon,
			"title": title_lbl,
			"summary": summary_lbl,
			"line1": line1_lbl,
			"line2": line2_lbl,
		},
	}


static func _update_detail_card(
	refs: Dictionary,
	artifact: Dictionary,
	asset_catalog,
	icon_resolver
) -> void:
	var color: Color = artifact.get("color", Color.WHITE)
	var panel = refs.get("panel") as PanelContainer
	if panel:
		panel.add_theme_stylebox_override("panel", _detail_style(color))
	var icon = refs.get("icon") as TextureRect
	if icon:
		icon.texture = icon_resolver.make_artifact_icon(artifact, asset_catalog, 72)
		icon.tooltip_text = String(artifact.get("label", ""))
	var title = refs.get("title") as Label
	if title:
		title.text = String(artifact.get("label", ""))
		title.add_theme_color_override("font_color", color)
	var summary = refs.get("summary") as Label
	if summary:
		summary.text = _summary_text(artifact)
	var line1 = refs.get("line1") as Label
	if line1:
		line1.text = String(artifact.get("line1", ""))
	var line2 = refs.get("line2") as Label
	if line2:
		line2.text = String(artifact.get("line2", ""))


static func _summary_text(artifact: Dictionary) -> String:
	var text = String(artifact.get("summary", ""))
	if text.strip_edges() != "":
		return text
	return String(artifact.get("line1", "")).replace("\n", " ")


static func _apply_option_button_style(button: Button, color: Color, selected: bool) -> void:
	button.add_theme_stylebox_override("normal", _circle_style(color, selected, false))
	button.add_theme_stylebox_override("hover", _circle_style(color, selected, true))
	button.add_theme_stylebox_override("pressed", _circle_style(color, true, true))
	button.add_theme_stylebox_override("focus", _circle_style(color, true, false))


static func _circle_style(color: Color, selected: bool, hover: bool) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	var border_alpha = 1.0 if selected else 0.55
	var bg_alpha = 0.96 if selected else 0.88
	var bg_color = color.darkened(0.66) if selected else Color(0.08, 0.10, 0.13)
	bg_color.a = bg_alpha
	style.bg_color = bg_color
	if hover and not selected:
		style.bg_color = Color(0.12, 0.14, 0.18, 0.92)
	style.border_color = Color(color.r, color.g, color.b, border_alpha)
	style.set_border_width_all(3 if selected else 2)
	style.set_corner_radius_all(44)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


static func _detail_style(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.15, 0.96)
	style.border_color = Color(color.r, color.g, color.b, 0.72)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style


static func _call_if_valid(callable: Callable, arg: Variant) -> void:
	if callable.is_valid():
		callable.call(arg)
