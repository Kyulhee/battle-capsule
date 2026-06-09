extends SceneTree


func _init():
	if not _verify_controller_profile():
		quit(1)
		return
	if not _verify_player_scene_nodes():
		quit(1)
		return

	print("Player night readability smoke passed.")
	quit(0)


func _verify_controller_profile() -> bool:
	var script = load("res://src/entities/player/PlayerNightReadability.gd")
	var host := Node3D.new()
	var spot := SpotLight3D.new()
	var proximity := OmniLight3D.new()
	root.add_child(host)
	host.add_child(spot)
	host.add_child(proximity)

	spot.light_energy = 8.0
	spot.spot_range = 25.0
	spot.spot_angle = 70.0
	proximity.light_energy = 1.5
	proximity.omni_range = 5.0

	var readability = script.new()
	readability.attach(host, spot, proximity)
	readability.configure_for_metadata({
		"id": "night_artificial_forest_candidate",
		"theme": "night_artificial_forest",
		"layout": "diagonal_sluice_black_ridge_wire_broadcast_false_clinic_probe_integrated",
	})
	var night_state: Dictionary = readability.debug_state()
	if not bool(night_state.get("active", false)):
		return _fail("Night candidate did not activate player readability profile.")
	if not bool(night_state.get("spot_visible", false)):
		return _fail("Night readability spotlight was not visible.")
	if float(night_state.get("spot_range", 0.0)) < 30.0:
		return _fail("Night readability spotlight range is too short.")
	if float(night_state.get("spot_angle", 0.0)) >= 60.0:
		return _fail("Night readability spotlight is too wide for flashlight readability.")
	if float(night_state.get("proximity_energy", 0.0)) > 0.8:
		return _fail("Night proximity light should stay low-energy.")
	if spot.get_parent() != host:
		return _fail("Night spotlight should remain parented to the player host.")
	if float(night_state.get("forward_dot", 0.0)) < 0.98:
		return _fail("Night spotlight does not follow host aim direction.")

	readability.configure_for_metadata({
		"id": "example_map",
		"theme": "forest",
		"layout": "default",
	})
	var default_state: Dictionary = readability.debug_state()
	if bool(default_state.get("active", true)):
		return _fail("Default map should not use night readability profile.")
	if absf(float(default_state.get("spot_angle", 0.0)) - 70.0) > 0.01:
		return _fail("Default spotlight angle was not restored.")
	if absf(float(default_state.get("proximity_range", 0.0)) - 5.0) > 0.01:
		return _fail("Default proximity light range was not restored.")
	return true


func _verify_player_scene_nodes() -> bool:
	var scene_text := FileAccess.get_file_as_string("res://src/entities/player/Player.tscn")
	if scene_text.is_empty():
		return _fail("Player.tscn was empty or missing.")
	if not scene_text.contains("[node name=\"VisionSpot\" type=\"SpotLight3D\" parent=\".\"]"):
		return _fail("Player scene is missing VisionSpot.")
	if not scene_text.contains("[node name=\"ProximityLight\" type=\"OmniLight3D\" parent=\".\"]"):
		return _fail("Player scene is missing ProximityLight.")
	return true


func _fail(message: String) -> bool:
	push_error(message)
	return false
