class_name MenuVisualBuilder
extends RefCounted

const PANEL_TOP_COLOR := Color(0.04, 0.06, 0.10)
const PANEL_BOTTOM_COLOR := Color(0.05, 0.13, 0.08)
const MAIN_LOGO_SIZE := 80

static func make_main_logo(icon_factory_script) -> Texture2D:
	if icon_factory_script != null and icon_factory_script.has_method("make_capsule_logo"):
		return icon_factory_script.make_capsule_logo(MAIN_LOGO_SIZE)
	return null

static func setup_main_menu(panel: ColorRect, button_container: Node, logo_texture: Texture2D):
	if not panel:
		return
	panel.color = PANEL_TOP_COLOR
	_add_gradient_fill(panel)
	_add_noise_overlay(panel)
	_add_logo(panel, logo_texture)
	if button_container:
		for child in button_container.get_children():
			if child is Button:
				apply_button_style(child)

static func setup_secondary_panels(panels: Array, close_buttons: Array):
	for panel in panels:
		if panel is ColorRect:
			panel.color = PANEL_TOP_COLOR
			_add_gradient_fill(panel)
	for button in close_buttons:
		if button is Button:
			apply_button_style(button)

static func apply_button_style(btn: Button):
	if not btn:
		return
	var normal = _make_button_style(
		Color(0.08, 0.14, 0.10, 0.92),
		Color(0.25, 0.55, 0.35, 0.8),
		1
	)
	var hover = _make_button_style(
		Color(0.12, 0.22, 0.15, 0.98),
		Color(0.4, 0.85, 0.55, 1.0),
		2
	)
	var pressed = _make_button_style(
		Color(0.05, 0.10, 0.07, 1.0),
		Color(0.2, 0.5, 0.3, 1.0),
		1
	)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(0.88, 0.95, 0.9))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))

static func _add_gradient_fill(panel: Control):
	var grad_tex = GradientTexture2D.new()
	var grad = Gradient.new()
	grad.set_color(0, PANEL_TOP_COLOR)
	grad.set_color(1, PANEL_BOTTOM_COLOR)
	grad_tex.gradient = grad
	grad_tex.fill_from = Vector2(0.5, 0.0)
	grad_tex.fill_to = Vector2(0.5, 1.0)

	var grad_rect = TextureRect.new()
	grad_rect.texture = grad_tex
	grad_rect.layout_mode = 1
	grad_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grad_rect.stretch_mode = TextureRect.STRETCH_SCALE
	panel.add_child(grad_rect)
	panel.move_child(grad_rect, 0)

static func _add_noise_overlay(panel: Control):
	var noise_tex = NoiseTexture2D.new()
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.004
	noise_tex.noise = noise
	noise_tex.width = 512
	noise_tex.height = 512
	noise_tex.as_normal_map = false

	var overlay = TextureRect.new()
	overlay.texture = noise_tex
	overlay.layout_mode = 1
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.modulate = Color(0.12, 0.18, 0.12, 0.18)
	overlay.stretch_mode = TextureRect.STRETCH_TILE
	panel.add_child(overlay)
	panel.move_child(overlay, 1)

static func _add_logo(panel: Control, logo_texture: Texture2D):
	if not logo_texture:
		return
	var logo_rect = TextureRect.new()
	logo_rect.texture = logo_texture
	logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo_rect.layout_mode = 1
	logo_rect.anchor_left = 0.5
	logo_rect.anchor_right = 0.5
	logo_rect.offset_left = -40.0
	logo_rect.offset_right = 40.0
	logo_rect.offset_top = 26.0
	logo_rect.offset_bottom = 112.0
	panel.add_child(logo_rect)

static func _make_button_style(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(5)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style
