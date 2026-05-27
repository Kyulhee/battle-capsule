extends SceneTree


const VIEWPORT_WIDTH := 1280.0


func _init():
	var catalog_script = load("res://src/core/ArtifactCatalog.gd")
	var builder_script = load("res://src/ui/panels/ArtifactSelectionPanelBuilder.gd")
	var catalog = catalog_script.starting_artifacts(1)

	var emergency_shell_found := false
	for artifact in catalog:
		if String(artifact.get("id", "")) == "emergency_shell":
			emergency_shell_found = true
		for key in ["label", "line1", "line2"]:
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
	var panel = builder_script.show(parent, catalog, Callable(), Callable(), Callable())
	if panel == null:
		push_error("Artifact selection panel did not build.")
		quit(1)
		return

	var cards = panel.find_children("*", "PanelContainer", true, false)
	if cards.size() != catalog.size():
		push_error("Artifact card count mismatch: expected %d, got %d." % [catalog.size(), cards.size()])
		quit(1)
		return

	var row = cards[0].get_parent()
	var separation = float(row.get_theme_constant("separation"))
	var total_width := 0.0
	for card in cards:
		total_width += float(card.custom_minimum_size.x)
	total_width += separation * max(0, cards.size() - 1)
	if total_width > VIEWPORT_WIDTH:
		push_error("Artifact cards exceed default viewport width: %.1f > %.1f." % [total_width, VIEWPORT_WIDTH])
		quit(1)
		return

	print("Artifact selection layout smoke passed: %d cards, %.1fpx row width." % [cards.size(), total_width])
	quit(0)
