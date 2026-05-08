class_name DebugOverlay
extends PanelContainer

var main_ref: Node = null
var debug_flags = null
var _label: Label = null

func configure(main_node: Node, flags) -> void:
	main_ref = main_node
	debug_flags = flags
	_update_text()

func _ready() -> void:
	name = "DebugOverlay"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 90
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -320.0
	offset_right = -12.0
	offset_top = 12.0
	offset_bottom = 132.0

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.04, 0.78)
	style.border_color = Color(0.3, 0.8, 0.55, 0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_color", Color(0.72, 1.0, 0.82))
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_label)
	_update_text()

func _process(_delta: float) -> void:
	_update_text()

func _update_text() -> void:
	if not _label:
		return
	visible = debug_flags != null and debug_flags.enabled and debug_flags.overlay_enabled
	if not visible:
		return

	var lines: Array[String] = []
	lines.append("DEBUG %s" % debug_flags.describe())
	if main_ref:
		lines.append("state=%s diff=%s alive=%d" % [
			str(main_ref.current_state),
			str(main_ref.difficulty),
			int(main_ref.alive_count)
		])
		lines.append("bots=%d loot=%d spawn=%.1f" % [
			int(main_ref.bot_count),
			int(main_ref.loot_count),
			float(main_ref.spawn_radius)
		])
		if main_ref.loot_spawner != null:
			lines.append("loot_hotspots=%d" % int(main_ref.loot_spawner.hotspots.size()))
		if main_ref.asset_catalog != null and main_ref.asset_catalog.has_method("summary"):
			var assets: Dictionary = main_ref.asset_catalog.summary()
			lines.append("assets a=%d i=%d p=%d c=%d" % [
				int(assets.get("audio", 0)),
				int(assets.get("icons", 0)),
				int(assets.get("props", 0)),
				int(assets.get("cosmetics", 0))
			])
		if main_ref.zone != null:
			lines.append("zone=%d r=%.1f t=%.1f shrink=%s" % [
				int(main_ref.zone.stage),
				float(main_ref.zone.current_radius),
				float(main_ref.zone.timer),
				str(main_ref.zone.shrinking)
			])

	_label.text = "\n".join(PackedStringArray(lines))
