extends SceneTree

var _visuals_script = null


func _init():
	_visuals_script = load("res://src/entities/player/PlayerArtifactVisuals.gd")
	var host = Node3D.new()
	root.add_child(host)
	var visuals = _visuals_script.new()
	visuals.attach(host)

	if not _verify_catalog_visual_ids():
		quit(1)
		return
	if not _verify_red_trigger(visuals):
		quit(1)
		return
	if not _verify_armor_sponge(visuals):
		quit(1)
		return
	if not _verify_silent_core(visuals):
		quit(1)
		return
	if not _verify_zone_battery(visuals):
		quit(1)
		return
	if not _verify_emergency_shell(visuals):
		quit(1)
		return
	if not _verify_ghost_grass(visuals):
		quit(1)
		return

	print("Artifact visuals smoke passed.")
	quit(0)


func _verify_catalog_visual_ids() -> bool:
	var catalog_script = load("res://src/core/ArtifactCatalog.gd")
	var catalog = catalog_script.starting_artifacts(1)
	for artifact in catalog:
		if String(artifact.get("visual_id", "")).strip_edges() == "":
			return _fail("Artifact %s is missing visual_id." % artifact.get("id", ""))
	return true


func _verify_red_trigger(visuals) -> bool:
	visuals.configure({
		"id": "red_trigger",
		"label": "Red Trigger",
		"color": Color(1.0, 0.25, 0.25),
		"visual_id": "red_trigger",
	})
	visuals.tick(0.1, {"weapon_type": "shotgun", "is_dead": false})
	if not bool(visuals.debug_state().get("red_trigger_visible", false)):
		return _fail("Red Trigger glow was not visible while holding a shotgun.")
	visuals.tick(0.1, {"weapon_type": "pistol", "is_dead": false})
	if bool(visuals.debug_state().get("red_trigger_visible", false)):
		return _fail("Red Trigger glow stayed visible without a shotgun.")
	return true


func _verify_armor_sponge(visuals) -> bool:
	visuals.configure({
		"id": "armor_sponge",
		"label": "Armor Sponge",
		"color": Color(0.35, 0.60, 1.0),
		"visual_id": "armor_sponge",
	})
	visuals.tick(0.1, {"shield_ratio": 0.65, "is_dead": false})
	if int(visuals.debug_state().get("armor_visible_count", 0)) < 3:
		return _fail("Armor Sponge did not reveal armor plates from shield ratio.")
	visuals.tick(0.1, {"shield_ratio": 0.0, "is_dead": false})
	if int(visuals.debug_state().get("armor_visible_count", 0)) != 0:
		return _fail("Armor Sponge plates stayed visible at zero shield.")
	return true


func _verify_silent_core(visuals) -> bool:
	visuals.configure({
		"id": "silent_core",
		"label": "Silent Core",
		"color": Color(0.40, 0.95, 0.55),
		"visual_id": "silent_core",
	})
	visuals.tick(0.1, {"move_speed": 5.0, "is_crouching": false, "is_dead": false})
	if int(visuals.debug_state().get("silent_visible_count", 0)) == 0:
		return _fail("Silent Core afterimages were not visible while running.")
	visuals.tick(0.1, {"move_speed": 0.0, "is_crouching": false, "is_dead": false})
	if int(visuals.debug_state().get("silent_visible_count", 0)) != 0:
		return _fail("Silent Core afterimages stayed visible while stopped.")
	return true


func _verify_zone_battery(visuals) -> bool:
	visuals.configure({
		"id": "zone_battery",
		"label": "Zone Battery",
		"color": Color(0.20, 0.85, 1.0),
		"visual_id": "zone_battery",
	})
	visuals.tick(0.1, {"zone_battery_near": true, "zone_battery_charging": true, "is_dead": false})
	if not bool(visuals.debug_state().get("zone_battery_visible", false)):
		return _fail("Zone Battery plasma was not visible near the zone edge.")
	visuals.tick(0.1, {"zone_battery_near": false, "zone_battery_charging": false, "is_dead": false})
	if bool(visuals.debug_state().get("zone_battery_visible", false)):
		return _fail("Zone Battery plasma stayed visible away from the zone edge.")
	return true


func _verify_emergency_shell(visuals) -> bool:
	visuals.configure({
		"id": "emergency_shell",
		"label": "Emergency Shell",
		"color": Color(1.0, 0.72, 0.28),
		"visual_id": "emergency_shell",
	})
	visuals.tick(0.1, {"is_dead": false})
	if not bool(visuals.debug_state().get("emergency_pack_visible", false)):
		return _fail("Emergency Shell pack was not visible before triggering.")
	visuals.on_artifact_event("emergency_shell_triggered")
	visuals.tick(0.1, {"is_dead": false})
	var state = visuals.debug_state()
	if bool(state.get("emergency_pack_visible", false)):
		return _fail("Emergency Shell pack stayed visible after triggering.")
	if int(state.get("rupture_count", 0)) == 0:
		return _fail("Emergency Shell did not spawn rupture shards.")
	return true


func _verify_ghost_grass(visuals) -> bool:
	visuals.configure({
		"id": "ghost_grass",
		"label": "Ghost Grass",
		"color": Color(0.55, 1.0, 0.65),
		"visual_id": "ghost_grass",
	})
	visuals.tick(0.1, {"ghost_grass_active": true, "is_dead": false})
	if not bool(visuals.debug_state().get("ghost_grass_visible", false)):
		return _fail("Ghost Grass visual was not visible while active.")
	visuals.tick(0.1, {"ghost_grass_active": false, "is_dead": false})
	if bool(visuals.debug_state().get("ghost_grass_visible", false)):
		return _fail("Ghost Grass visual stayed visible while inactive.")
	return true


func _fail(message: String) -> bool:
	push_error(message)
	return false
