extends SceneTree


func _init():
	var game_config_script = load("res://src/core/GameConfig.gd")
	var map_definition_script = load("res://src/core/MapDefinition.gd")
	var world_builder_script = load("res://src/maps/WorldBuilder.gd")
	var overlay_script = load("res://src/ui/FullMapOverlay.gd")
	var minimap_script = load("res://src/ui/Minimap.gd")
	var route_presentation_script = load("res://src/ui/MapRoutePresentation.gd")

	var game_config = game_config_script.new()
	game_config.load_or_default()

	var file = FileAccess.open("res://data/mapSpec_night_forest_candidate.json", FileAccess.READ)
	if not file:
		_fail("mapSpec_night_forest_candidate.json not found.")
		return

	var definition = map_definition_script.new()
	if not definition.load_from_json(file.get_as_text(), "res://data/mapSpec_night_forest_candidate.json", game_config):
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
	var bottom_right: Vector2 = overlay.world_to_full_map(Vector2(half_size, half_size), map_rect)
	if top_left.distance_to(map_rect.position) > 0.001:
		_fail("World top-left does not map to full-map top-left.")
		return
	if bottom_right.distance_to(map_rect.position + map_rect.size) > 0.001:
		_fail("World bottom-right does not map to full-map bottom-right.")
		return
	if not overlay.is_open():
		_fail("FullMapOverlay did not report open after show_map().")
		return

	var routes: Array[Dictionary] = route_presentation_script.sorted_routes(definition, spec)
	if routes.size() != 6:
		_fail("Night full map needs 6 strategic routes; got %d." % routes.size())
		return
	var role_counts := {}
	for route in routes:
		var role := String(route.get("role", ""))
		role_counts[role] = int(role_counts.get(role, 0)) + 1
		var points: Array[Vector2] = route_presentation_script.route_points(route)
		if points.size() < 2:
			_fail("Route %s has fewer than 2 drawable points." % String(route.get("id", "")))
			return
		for point in points:
			if not map_rect.has_point(overlay.world_to_full_map(point, map_rect)):
				_fail("Route %s projects outside the full map." % String(route.get("id", "")))
				return

	var primary_style: Dictionary = route_presentation_script.style_for("primary_choke")
	var flank_style: Dictionary = route_presentation_script.style_for("flank")
	if float(primary_style.get("dash", -1.0)) != 0.0:
		_fail("Primary route must use a continuous line.")
		return
	if float(flank_style.get("dash", 0.0)) <= 0.0:
		_fail("Flank route must use a dashed line.")
		return

	var minimap = minimap_script.new()
	minimap.minimap_size = Vector2(240.0, 240.0)
	minimap.set_map_spec(spec, features, definition)
	var minimap_bounds := Rect2(Vector2.ZERO, minimap.minimap_size)
	for route in routes:
		for point in route_presentation_script.route_points(route):
			if not minimap_bounds.has_point(minimap.world_to_minimap(point)):
				_fail("Route %s projects outside the minimap." % String(route.get("id", "")))
				return
	minimap.free()
	overlay.free()

	print("FullMapOverlay route smoke passed: features=%d routes=%d roles=%s rect=%s center=%s." % [
		features.size(),
		routes.size(),
		str(role_counts),
		map_rect,
		center,
	])
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
