class_name EventTextBuilder
extends RefCounted

static func show(parent: Control, message: String, color: Color) -> Label:
	if not parent:
		return null
	var label = Label.new()
	label.process_mode = Node.PROCESS_MODE_ALWAYS
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.layout_mode = 1
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.offset_top = 80.0
	label.offset_bottom = 120.0
	label.offset_left = -200.0
	label.offset_right = 200.0
	label.z_index = 8
	parent.add_child(label)

	var tween = label.create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(label.queue_free)
	return label
