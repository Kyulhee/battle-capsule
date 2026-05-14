class_name MenuController
extends RefCounted

var _control: Control = null

func configure(control: Control) -> void:
	_control = control

func show_panel(panel_name: String) -> void:
	if not _control:
		return
	for child in _control.get_children():
		if child.name.ends_with("Panel"):
			child.visible = (child.name == panel_name + "Panel")
		elif child.name == "HUD":
			child.visible = (panel_name == "HUD")

func connect_main_buttons(
	on_start: Callable,
	on_records: Callable,
	on_help: Callable,
	on_settings: Callable,
	on_exit: Callable,
	apply_button_style: Callable
) -> void:
	var vbox = _main_menu_vbox()
	if not vbox:
		return
	_connect_named_button(vbox, "StartBtn", on_start)
	_connect_named_button(vbox, "RecordsBtn", on_records)
	_connect_named_button(vbox, "HelpBtn", on_help)
	_connect_named_button(vbox, "ExitBtn", on_exit)
	_ensure_settings_button(vbox, on_settings, apply_button_style)

func connect_secondary_close(on_main_menu: Callable) -> void:
	if not _control:
		return
	_connect_button(_control.get_node_or_null("RecordsPanel/VBox/CloseRecordsBtn"), on_main_menu)
	_connect_button(_control.get_node_or_null("HelpPanel/VBox/CloseHelpBtn"), on_main_menu)

func _main_menu_vbox() -> VBoxContainer:
	if not _control:
		return null
	return _control.get_node_or_null("MainMenuPanel/VBoxContainer") as VBoxContainer

func _connect_named_button(vbox: VBoxContainer, button_name: String, callable: Callable) -> void:
	_connect_button(vbox.get_node_or_null(button_name), callable)

func _connect_button(button: Button, callable: Callable) -> void:
	if not is_instance_valid(button) or not callable.is_valid():
		return
	if not button.pressed.is_connected(callable):
		button.pressed.connect(callable)

func _ensure_settings_button(
	vbox: VBoxContainer,
	on_settings: Callable,
	apply_button_style: Callable
) -> void:
	var settings_btn = vbox.get_node_or_null("SettingsBtn") as Button
	if not settings_btn:
		settings_btn = Button.new()
		settings_btn.name = "SettingsBtn"
		settings_btn.text = "SETTINGS"
		settings_btn.add_theme_font_size_override("font_size", 24)
		vbox.add_child(settings_btn)
		var exit_btn = vbox.get_node_or_null("ExitBtn")
		if exit_btn:
			vbox.move_child(settings_btn, exit_btn.get_index())
		if apply_button_style.is_valid():
			apply_button_style.call(settings_btn)
	_connect_button(settings_btn, on_settings)
