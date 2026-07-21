extends SceneTree


func _init():
	var game_config_script = load("res://src/core/GameConfig.gd")
	var map_definition_script = load("res://src/core/MapDefinition.gd")
	var world_builder_script = load("res://src/maps/WorldBuilder.gd")
	var overlay_script = load("res://src/ui/FullMapOverlay.gd")
	var minimap_script = load("res://src/ui/Minimap.gd")

	var game_config = game_config_script.new()
	game_config.load_or_default()

	var file = FileAccess.open(
		"res://data/mapSpec_night_forest_expanded_candidate.json",
		FileAccess.READ
	)
	if not file:
		_fail("Expanded Night map not found.")
		return

	var definition = map_definition_script.new()
	if not definition.load_from_json(
		file.get_as_text(),
		"res://data/mapSpec_night_forest_expanded_candidate.json",
		game_config
	):
		_fail("MapDefinition failed to load.")
		return
	var spec = definition.map_spec
	if spec == null:
		_fail("MapDefinition did not expose a MapSpec.")
		return

	var world_builder = world_builder_script.new()
	world_builder.generate_world(spec, null)
	var features: Array[Dictionary] = world_builder.get_minimap_features()
	if features.is_empty():
		_fail("WorldBuilder produced no map features for FullMapOverlay.")
		return
	var path_feature_count := 0
	for feature in features:
		if String(feature.get("shape", "")) == "path":
			path_feature_count += 1
	if path_feature_count < 3:
		_fail("Expanded Night map must expose physical path surfaces to both maps.")
		return
	world_builder.free()

	var overlay = overlay_script.new()
	overlay.name = "FullMapOverlayTest"
	overlay.size = Vector2(1280.0, 720.0)
	overlay.set_map_data(definition, spec, features, "baseline")
	overlay.set_runtime_state(
		Vector2(4.0, -6.0),
		Vector2(0.0, -1.0),
		Vector2.ZERO,
		50.0,
		Vector2(10.0, 8.0),
		25.0,
		Vector2(-20.0, 14.0),
		"pending"
	)
	overlay.show_map()

	var map_rect: Rect2 = overlay._map_rect()
	if map_rect.size.x < 320.0 or map_rect.size.y < 320.0:
		_fail("Full map rect is too small: %s." % [map_rect])
		return
	if map_rect.position.x < 0.0 or map_rect.position.y < 0.0:
		_fail("Full map rect starts outside viewport: %s." % [map_rect])
		return
	if map_rect.position.x + map_rect.size.x > 1280.0 or map_rect.position.y + map_rect.size.y > 720.0:
		_fail("Full map rect exceeds viewport: %s." % [map_rect])
		return

	var center: Vector2 = overlay.world_to_full_map(Vector2.ZERO, map_rect)
	if center.distance_to(map_rect.get_center()) > 0.001:
		_fail("World origin does not map to full-map center.")
		return

	var half_size := float(spec.get_world_size()) * 0.5
	var top_left: Vector2 = overlay.world_to_full_map(Vector2(-half_size, -half_size), map_rect)
	var top_right: Vector2 = overlay.world_to_full_map(Vector2(half_size, -half_size), map_rect)
	var bottom_right: Vector2 = overlay.world_to_full_map(Vector2(half_size, half_size), map_rect)
	var bottom_left: Vector2 = overlay.world_to_full_map(Vector2(-half_size, half_size), map_rect)
	if top_left.distance_to(Vector2(map_rect.get_center().x, map_rect.position.y)) > 0.001:
		_fail("World top-left does not map to the full-map top vertex.")
		return
	if top_right.distance_to(Vector2(map_rect.end.x, map_rect.get_center().y)) > 0.001:
		_fail("World top-right does not map to the full-map right vertex.")
		return
	if bottom_right.distance_to(Vector2(map_rect.get_center().x, map_rect.end.y)) > 0.001:
		_fail("World bottom-right does not map to the full-map bottom vertex.")
		return
	if bottom_left.distance_to(Vector2(map_rect.position.x, map_rect.get_center().y)) > 0.001:
		_fail("World bottom-left does not map to the full-map left vertex.")
		return
	if not overlay.is_open():
		_fail("FullMapOverlay did not report open after show_map().")
		return
	var cabin_poi: Dictionary = definition.get_poi_descriptors().filter(
		func(poi: Dictionary) -> bool: return String(poi.get("name", "")) == "Cabin Row"
	).front()
	if String(overlay._poi_label(cabin_poi)) != "Cabin Row":
		_fail("Full map should label explicitly identified physical landmarks.")
		return
	if overlay._poi_label_world_pos(cabin_poi).distance_to(Vector2(0.0, 104.0)) > 0.001:
		_fail("Cabin Row label must use its physical compound anchor.")
		return
	if not String(overlay._poi_label({"name": "Central Meadow", "role": "loot_hub"})).is_empty():
		_fail("Full map should not infer labels from internal POI roles.")
		return
	if not String(overlay._poi_label({"name": "East Pine Lane", "role": "recovery_pocket"})).is_empty():
		_fail("Full map should not expose unlabeled analysis POIs.")
		return

	var projected_north: Vector2 = overlay.world_direction_to_full_map(Vector2(0.0, -1.0))
	if projected_north.distance_to(Vector2(1.0, -1.0).normalized()) > 0.001:
		_fail("Full-map north is not aligned to the upper-right gameplay direction.")
		return

	var minimap = minimap_script.new()
	minimap.minimap_size = Vector2(280.0, 280.0)
	minimap.local_view_size_m = 120.0
	root.add_child(minimap)
	minimap.set_map_spec(spec, features, definition)
	minimap._refresh_static_cache()
	var static_viewport = minimap.get("_static_viewport")
	var static_texture = minimap.get("_static_texture")
	var static_layer = minimap.get("_static_layer")
	if static_viewport == null or static_texture == null or static_layer == null:
		_fail("Minimap static cache is incomplete: viewport=%s texture=%s layer=%s." % [
			static_viewport,
			static_texture,
			static_layer,
		])
		return
	if static_viewport.render_target_update_mode != SubViewport.UPDATE_ONCE:
		_fail("Minimap static viewport must not update every frame.")
		return
	if static_viewport.size != Vector2i(768, 768):
		_fail("Minimap static cache must retain high-resolution terrain detail.")
		return
	if static_texture.size.x <= minimap.minimap_size.x or static_texture.size.y <= minimap.minimap_size.y:
		_fail("Local minimap texture must be larger than its clipped display.")
		return
	if int(static_layer.get("_features").size()) != features.size():
		_fail("Minimap static cache did not receive all generated map features.")
		return
	if absf(minimap.world_size_to_minimap(60.0) - 140.0) > 0.001:
		_fail("Local minimap must show 120m across its 280px display.")
		return
	var sample_world := Vector2(18.0, -12.0)
	var full_direction: Vector2 = (
		overlay.world_to_full_map(sample_world, map_rect) - map_rect.get_center()
	).normalized()
	var minimap_direction: Vector2 = (
		minimap.world_to_minimap(sample_world) - minimap.minimap_size * 0.5
	).normalized()
	if full_direction.distance_to(minimap_direction) > 0.001:
		_fail("Full map and minimap do not share the same rotated orientation.")
		return
	minimap.free()
	overlay.free()

	print("FullMapOverlay orientation smoke passed: features=%d rect=%s center=%s north=%s." % [
		features.size(),
		map_rect,
		center,
		projected_north,
	])
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
