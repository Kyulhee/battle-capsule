class_name RecordsPanelBuilder
extends RefCounted

const DifficultyCatalogScript = preload("res://src/core/DifficultyCatalog.gd")
const MenuIconFactoryScript = preload("res://src/ui/MenuIconFactory.gd")

static func setup_controls(
	vbox: VBoxContainer,
	on_diff_tab: Callable,
	on_clear: Callable,
	apply_button_style: Callable
) -> void:
	if vbox.get_node_or_null("DiffTabs"):
		return

	var scroll = vbox.get_node_or_null("Scroll")
	var scroll_idx = scroll.get_index() if scroll else vbox.get_child_count()

	var tabs = HBoxContainer.new()
	tabs.name = "DiffTabs"
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 6)
	vbox.add_child(tabs)
	vbox.move_child(tabs, scroll_idx)

	for i in range(4):
		var btn = Button.new()
		btn.text = DifficultyCatalogScript.label(i)
		btn.custom_minimum_size = Vector2(68, 0)
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(func(): on_diff_tab.call(i))
		_call_if_valid(apply_button_style, btn)
		tabs.add_child(btn)

	var close_btn = vbox.get_node_or_null("CloseRecordsBtn")
	var close_idx = close_btn.get_index() if close_btn else vbox.get_child_count()

	var clear_btn = Button.new()
	clear_btn.name = "ClearBtn"
	clear_btn.text = "CLEAR ALL"
	clear_btn.add_theme_font_size_override("font_size", 14)
	if on_clear.is_valid():
		clear_btn.pressed.connect(on_clear)
	_call_if_valid(apply_button_style, clear_btn)
	vbox.add_child(clear_btn)
	vbox.move_child(clear_btn, close_idx)

static func populate_list(vbox: VBoxContainer, selected_diff: int, telemetry: Node) -> void:
	var list = vbox.get_node_or_null("Scroll/List")
	if not list:
		return
	for child in list.get_children():
		child.queue_free()

	var tabs = vbox.get_node_or_null("DiffTabs")
	if tabs:
		for i in range(tabs.get_child_count()):
			tabs.get_child(i).modulate = DifficultyCatalogScript.color(i) if i == selected_diff else DifficultyCatalogScript.dim_color()

	if telemetry == null or not telemetry.has_method("get_history_for_difficulty"):
		return

	var history = telemetry.get_history_for_difficulty(selected_diff)
	if history.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "기록 없음"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		list.add_child(empty_lbl)
		return

	var skull_tex = MenuIconFactoryScript.make_icon("skull")
	var hand_tex = MenuIconFactoryScript.make_icon("hand")
	for record in history:
		_add_record_row(list, record, skull_tex, hand_tex)

static func _add_record_row(
	list: VBoxContainer,
	record: Dictionary,
	skull_tex: ImageTexture,
	hand_tex: ImageTexture
) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	list.add_child(row)

	var badge = Label.new()
	badge.text = "WIN" if record.win else "---"
	badge.add_theme_font_size_override("font_size", 12)
	badge.custom_minimum_size = Vector2(32, 0)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_color_override("font_color", Color.GOLD if record.win else Color(0.5, 0.5, 0.5))
	row.add_child(badge)

	var rank_lbl = Label.new()
	rank_lbl.text = "#%d" % record.rank
	rank_lbl.add_theme_font_size_override("font_size", 14)
	rank_lbl.custom_minimum_size = Vector2(32, 0)
	rank_lbl.add_theme_color_override("font_color", Color.GOLD if record.win else Color(0.85, 0.85, 0.85))
	row.add_child(rank_lbl)

	var score_val = record.get("score", 0)
	var score_lbl = Label.new()
	score_lbl.text = "%d" % score_val
	score_lbl.add_theme_font_size_override("font_size", 14)
	score_lbl.custom_minimum_size = Vector2(54, 0)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var score_col = Color.GOLD if record.win else Color(0.7, 0.85, 1.0)
	score_lbl.add_theme_color_override("font_color", score_col)
	row.add_child(score_lbl)

	_add_icon_val(row, skull_tex, str(record.kills), Color(1.0, 0.92, 0.15))
	_add_icon_val(row, hand_tex, str(record.assists), Color(1.0, 0.6, 0.2))

	var time_lbl = Label.new()
	time_lbl.text = "%ds" % record.duration
	time_lbl.add_theme_font_size_override("font_size", 12)
	time_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	row.add_child(time_lbl)

	var date_lbl = Label.new()
	date_lbl.text = record.date
	date_lbl.add_theme_font_size_override("font_size", 11)
	date_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	date_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	date_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(date_lbl)

static func _add_icon_val(parent: HBoxContainer, tex: ImageTexture, val: String, col: Color) -> void:
	var icon = TextureRect.new()
	icon.texture = tex
	icon.custom_minimum_size = Vector2(14, 14)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.modulate = col
	parent.add_child(icon)

	var lbl = Label.new()
	lbl.text = val
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", col)
	lbl.custom_minimum_size = Vector2(24, 0)
	parent.add_child(lbl)

static func _call_if_valid(callable: Callable, arg: Variant) -> void:
	if callable.is_valid():
		callable.call(arg)
