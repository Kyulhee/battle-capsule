extends SceneTree

const OUTPUT_PATH := "C:/tmp/artifact_selection_ui.png"


func _init():
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)

	var catalog_script = load("res://src/core/ArtifactCatalog.gd")
	var asset_catalog_script = load("res://src/core/AssetCatalog.gd")
	var builder_script = load("res://src/ui/panels/ArtifactSelectionPanelBuilder.gd")
	var catalog = catalog_script.starting_artifacts(1)
	var asset_catalog = asset_catalog_script.new()
	asset_catalog.load_or_default()

	var parent = Control.new()
	parent.size = Vector2(1280, 720)
	parent.custom_minimum_size = Vector2(1280, 720)
	root.add_child(parent)
	builder_script.show(parent, catalog, Callable(), Callable(), Callable(self, "_apply_capture_button_style"), asset_catalog)

	await process_frame
	await process_frame
	await process_frame

	var image = root.get_texture().get_image()
	if image == null:
		push_error("Could not capture artifact selection UI.")
		quit(1)
		return
	var err = image.save_png(OUTPUT_PATH)
	if err != OK:
		var fallback = ProjectSettings.globalize_path("user://artifact_selection_ui.png")
		err = image.save_png(fallback)
		if err == OK:
			print("Artifact selection UI saved: %s" % fallback)
			quit(0)
			return
		push_error("Could not save artifact selection UI.")
		quit(1)
		return
	print("Artifact selection UI saved: %s" % OUTPUT_PATH)
	quit(0)


func _apply_capture_button_style(btn: Button) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.18, 0.23, 0.95)
	style.border_color = Color(0.40, 0.46, 0.58, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", style)
