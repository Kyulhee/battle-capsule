extends SceneTree


func _init():
	var catalog_script = load("res://src/core/ArtifactCatalog.gd")
	var artifacts = catalog_script.starting_artifacts(1)
	var by_id := {}
	for artifact in artifacts:
		by_id[String(artifact.get("id", ""))] = artifact

	if not _verify_red_trigger(by_id.get("red_trigger", {})):
		quit(1)
		return
	if not _verify_armor_sponge(by_id.get("armor_sponge", {})):
		quit(1)
		return
	if not _verify_silent_core(by_id.get("silent_core", {})):
		quit(1)
		return
	if not _verify_ghost_grass(by_id.get("ghost_grass", {})):
		quit(1)
		return
	if not _verify_escape_capsule(by_id.get("emergency_shell", {})):
		quit(1)
		return

	print("Artifact balance catalog smoke passed.")
	quit(0)


func _verify_red_trigger(artifact: Dictionary) -> bool:
	var mods: Dictionary = artifact.get("mods", {})
	if float(mods.get("red_trigger_reveal_duration", 2.0)) <= 2.0:
		return _fail("Red Trigger reveal duration was not increased.")
	return true


func _verify_armor_sponge(artifact: Dictionary) -> bool:
	var mods: Dictionary = artifact.get("mods", {})
	if absf(float(mods.get("armor_sponge_move_speed_min", 1.0)) - 0.75) > 0.001:
		return _fail("Armor Sponge max-shield speed floor should remain at 0.75.")
	if absf(float(mods.get("heal_to_shield_ratio", 0.0)) - 0.5) > 0.001:
		return _fail("Armor Sponge heal-to-shield ratio should be 0.5.")
	if absf(float(mods.get("heal_to_shield_cap", 0.0)) - 50.0) > 0.001:
		return _fail("Armor Sponge heal-to-shield cap should be 50.")
	return true


func _verify_silent_core(artifact: Dictionary) -> bool:
	var mods: Dictionary = artifact.get("mods", {})
	if not bool(mods.get("silent_core_first_shot_miss", false)):
		return _fail("Silent Core should force the first unrevealed non-knife shot to miss.")
	if mods.has("max_health_mult") or mods.has("max_shield_mult"):
		return _fail("Silent Core should no longer reduce max HP or shield.")
	return true


func _verify_ghost_grass(artifact: Dictionary) -> bool:
	var mods: Dictionary = artifact.get("mods", {})
	if float(mods.get("ghost_grass_duration", 0.0)) > 1.5:
		return _fail("Ghost Grass duration should stay short enough to avoid chain invisibility.")
	if float(mods.get("ghost_grass_cooldown", 0.0)) < 4.0:
		return _fail("Ghost Grass cooldown should block repeated bush tapping.")
	if float(mods.get("ghost_grass_incoming_damage_mult", 1.0)) <= 1.0:
		return _fail("Ghost Grass should be risky when shot while active.")
	return true


func _verify_escape_capsule(artifact: Dictionary) -> bool:
	var mods: Dictionary = artifact.get("mods", {})
	if String(artifact.get("label", "")) != "Escape Capsule":
		return _fail("Emergency Shell artifact should present as Escape Capsule.")
	if not bool(mods.get("emergency_shell_ammo_purge", false)):
		return _fail("Escape Capsule should purge ammo after triggering.")
	return true


func _fail(message: String) -> bool:
	push_error(message)
	return false
