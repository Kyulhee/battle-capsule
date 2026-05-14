class_name ResultPanelBuilder
extends RefCounted

static func build(
	result_panel: Control,
	on_restart: Callable,
	on_records: Callable,
	on_menu: Callable,
	apply_button_style: Callable
) -> Dictionary:
	if not result_panel:
		return {}

	var center = CenterContainer.new()
	center.layout_mode = 1
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_panel.add_child(center)

	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style())
	card.custom_minimum_size = Vector2(540, 0)
	center.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	var header_label = Label.new()
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_label.add_theme_font_size_override("font_size", 52)
	header_label.add_theme_color_override("font_outline_color", Color.BLACK)
	header_label.add_theme_constant_override("outline_size", 8)
	header_label.text = "VICTORY!"
	vbox.add_child(header_label)

	var rank_label = Label.new()
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.add_theme_font_size_override("font_size", 28)
	rank_label.add_theme_color_override("font_color", Color(0.80, 0.82, 0.90))
	rank_label.text = "RANK  #1"
	vbox.add_child(rank_label)

	vbox.add_child(HSeparator.new())

	var stats_label = Label.new()
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 17)
	stats_label.add_theme_color_override("font_color", Color(0.72, 0.74, 0.84))
	vbox.add_child(stats_label)

	var score_label = Label.new()
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 24)
	score_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	vbox.add_child(score_label)

	var mission_separator = HSeparator.new()
	mission_separator.visible = false
	vbox.add_child(mission_separator)

	var mission_label = Label.new()
	mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_label.add_theme_font_size_override("font_size", 16)
	mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_label.visible = false
	vbox.add_child(mission_label)

	vbox.add_child(HSeparator.new())

	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 14)
	vbox.add_child(btn_row)

	_add_button(btn_row, "RESTART", on_restart, apply_button_style)
	_add_button(btn_row, "RECORDS", on_records, apply_button_style)
	_add_button(btn_row, "MENU", on_menu, apply_button_style)

	return {
		"header": header_label,
		"rank": rank_label,
		"stats": stats_label,
		"score": score_label,
		"mission": mission_label,
		"mission_separator": mission_separator,
	}

static func populate(nodes: Dictionary, data: Dictionary) -> void:
	var final_rank = int(data.get("final_rank", 1))
	var is_victory = bool(data.get("is_victory", final_rank == 1))
	var result_color = Color.GOLD if is_victory else Color(1.0, 0.28, 0.28)

	var header_label = nodes.get("header", null)
	if is_instance_valid(header_label):
		header_label.text = "VICTORY!" if is_victory else "ELIMINATED"
		header_label.add_theme_color_override("font_color", result_color)

	var rank_label = nodes.get("rank", null)
	if is_instance_valid(rank_label):
		rank_label.text = "RANK  #%d" % final_rank

	var stats_label = nodes.get("stats", null)
	if is_instance_valid(stats_label):
		stats_label.text = data.get("stats_text", "")

	var score_label = nodes.get("score", null)
	if is_instance_valid(score_label):
		score_label.text = "SCORE  %d" % int(data.get("score", 0))

	_set_mission_result(
		nodes.get("mission", null),
		nodes.get("mission_separator", null),
		data.get("mission_text", ""),
		bool(data.get("mission_success", false))
	)

static func _set_mission_result(
	mission_label: Label,
	mission_separator: HSeparator,
	text: String,
	success: bool
) -> void:
	if not is_instance_valid(mission_label):
		return
	if text != "":
		mission_label.text = text
		mission_label.add_theme_color_override(
			"font_color",
			Color.GOLD if success else Color(0.92, 0.38, 0.38)
		)
		mission_label.visible = true
		if is_instance_valid(mission_separator):
			mission_separator.visible = true
	else:
		mission_label.visible = false
		if is_instance_valid(mission_separator):
			mission_separator.visible = false

static func _card_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.13)
	style.border_color = Color(0.28, 0.30, 0.44)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 52
	style.content_margin_right = 52
	style.content_margin_top = 40
	style.content_margin_bottom = 44
	return style

static func _add_button(
	parent: HBoxContainer,
	label: String,
	on_pressed: Callable,
	apply_button_style: Callable
) -> void:
	var btn = Button.new()
	btn.text = label
	btn.add_theme_font_size_override("font_size", 20)
	btn.custom_minimum_size = Vector2(130, 42)
	if on_pressed.is_valid():
		btn.pressed.connect(on_pressed)
	parent.add_child(btn)
	if apply_button_style.is_valid():
		apply_button_style.call(btn)
