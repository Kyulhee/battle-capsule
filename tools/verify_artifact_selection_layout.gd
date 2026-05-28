extends SceneTree


const VIEWPORT_WIDTH := 1280.0


func _init():
	var catalog_script = load("res://src/core/ArtifactCatalog.gd")
	var asset_catalog_script = load("res://src/core/AssetCatalog.gd")
	var builder_script = load("res://src/ui/panels/ArtifactSelectionPanelBuilder.gd")
	var catalog = catalog_script.starting_artifacts(1)
	var asset_catalog = asset_catalog_script.new()
	asset_catalog.load_or_default()

	var emergency_shell_found := false
	for artifact in catalog:
		if String(artifact.get("id", "")) == "emergency_shell":
			emergency_shell_found = true
		for key in ["label", "summary", "line1", "line2"]:
			if String(artifact.get(key, "")).strip_edges() == "":
				push_error("Artifact %s is missing %s text." % [artifact.get("id", ""), key])
				quit(1)
				return
	if not emergency_shell_found:
		push_error("Emergency Shell is missing from the starting artifact catalog.")
		quit(1)
		return

	var parent = Control.new()
	parent.custom_minimum_size = Vector2(VIEWPORT_WIDTH, 720.0)
	root.add_child(parent)
	var panel = builder_script.show(parent, catalog, Callable(), Callable(), Callable(), asset_catalog)
	if panel == null:
		push_error("Artifact selection panel did not build.")
		quit(1)
		return

	var option_cells = panel.find_children("ArtifactOptionCell_*", "VBoxContainer", true, false)
	if option_cells.size() != catalog.size():
		push_error("Artifact option count mismatch: expected %d, got %d." % [catalog.size(), option_cells.size()])
		quit(1)
		return

	var option_buttons = panel.find_children("ArtifactOption_*", "Button", true, false)
	if option_buttons.size() != catalog.size():
		push_error("Artifact option button count mismatch: expected %d, got %d." % [catalog.size(), option_buttons.size()])
		quit(1)
		return
	for button in option_buttons:
		if button.icon == null:
			push_error("Artifact option button has no icon texture.")
			quit(1)
			return

	var detail_cards = panel.find_children("ArtifactDetailPanel", "PanelContainer", true, false)
	if detail_cards.size() != 1:
		push_error("Artifact detail panel count mismatch: expected 1, got %d." % detail_cards.size())
		quit(1)
		return
	var detail_icon = panel.find_child("ArtifactDetailIcon", true, false) as TextureRect
	if detail_icon == null or detail_icon.texture == null:
		push_error("Artifact detail icon is missing.")
		quit(1)
		return
	var detail_title = panel.find_child("ArtifactDetailTitle", true, false) as Label
	if detail_title == null or detail_title.text != String(catalog[0].get("label", "")):
		push_error("Artifact detail panel did not default to the first artifact.")
		quit(1)
		return
	option_buttons[1].emit_signal("pressed")
	if detail_title.text != String(catalog[1].get("label", "")):
		push_error("Artifact detail panel did not update after pressing an option.")
		quit(1)
		return

	var row = option_cells[0].get_parent()
	var separation = float(row.get_theme_constant("separation"))
	var total_width := 0.0
	for option in option_cells:
		total_width += float(option.custom_minimum_size.x)
	total_width += separation * max(0, option_cells.size() - 1)
	if total_width > VIEWPORT_WIDTH:
		push_error("Artifact options exceed default viewport width: %.1f > %.1f." % [total_width, VIEWPORT_WIDTH])
		quit(1)
		return

	print("Artifact selection layout smoke passed: %d options, %.1fpx row width." % [option_cells.size(), total_width])
	quit(0)
