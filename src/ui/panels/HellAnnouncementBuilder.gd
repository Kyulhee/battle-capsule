class_name HellAnnouncementBuilder
extends RefCounted

static func show(
	parent: Control,
	modifier_description: Array,
	on_dismiss: Callable,
	apply_button_style: Callable
) -> Control:
	if not parent:
		return null

	var root = Control.new()
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.layout_mode = 1
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.z_index = 20

	var overlay = ColorRect.new()
	overlay.layout_mode = 1
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)

	var center = CenterContainer.new()
	center.layout_mode = 1
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(center)

	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style())
	card.custom_minimum_size = Vector2(640, 0)
	center.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	var title_lbl = Label.new()
	title_lbl.text = "지옥 모드"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 42)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.20, 0.20))
	title_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	title_lbl.add_theme_constant_override("outline_size", 6)
	vbox.add_child(title_lbl)

	vbox.add_child(_separator())
	vbox.add_child(_section("기본 패널티"))
	_add_row(vbox, "시작 체력 1", "아이템 없이 한 번 맞으면 즉사합니다")
	_add_row(vbox, "치료 효율 50%", "힐 아이템 회복량이 절반입니다")
	_add_row(vbox, "압박 미션", "존 전환마다 제한 시간 미션이 발동됩니다")

	vbox.add_child(_separator())
	vbox.add_child(_section("이번 매치 이벤트"))
	_add_row(
		vbox,
		str(modifier_description[0]) if modifier_description.size() > 0 else "",
		str(modifier_description[1]) if modifier_description.size() > 1 else ""
	)
	_add_row(vbox, "정전", "주기적으로 화면이 어두워지며 미니맵이 차단됩니다")
	_add_row(vbox, "포격", "경고 후 지정 범위에 폭탄이 쏟아집니다")

	vbox.add_child(_separator())
	var btn = Button.new()
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.text = "시작하기  [SPACE / ESC]"
	btn.add_theme_font_size_override("font_size", 18)
	if on_dismiss.is_valid():
		btn.pressed.connect(on_dismiss)
	if apply_button_style.is_valid():
		apply_button_style.call(btn)
	vbox.add_child(btn)

	parent.add_child(root)
	return root

static func _card_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.03, 0.07)
	style.border_color = Color(0.50, 0.08, 0.12)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 44
	style.content_margin_right = 44
	style.content_margin_top = 36
	style.content_margin_bottom = 38
	return style

static func _separator() -> HSeparator:
	var separator = HSeparator.new()
	separator.add_theme_constant_override("separation", 4)
	return separator

static func _section(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.28))
	return label

static func _add_row(parent: Control, key: String, desc: String) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	parent.add_child(hbox)

	var key_lbl = Label.new()
	key_lbl.text = key
	key_lbl.add_theme_font_size_override("font_size", 14)
	key_lbl.add_theme_color_override("font_color", Color(0.92, 0.90, 0.92))
	key_lbl.custom_minimum_size = Vector2(108, 0)
	hbox.add_child(key_lbl)

	var dash = Label.new()
	dash.text = "—"
	dash.add_theme_font_size_override("font_size", 14)
	dash.add_theme_color_override("font_color", Color(0.42, 0.40, 0.44))
	hbox.add_child(dash)

	var desc_lbl = Label.new()
	desc_lbl.text = desc
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.add_theme_color_override("font_color", Color(0.66, 0.64, 0.70))
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hbox.add_child(desc_lbl)
