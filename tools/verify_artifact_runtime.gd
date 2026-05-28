extends SceneTree

var _runtime_script = null


func _init():
	_runtime_script = load("res://src/entities/player/PlayerArtifactRuntime.gd")
	if not _verify_emergency_shell():
		quit(1)
		return
	if not _verify_ghost_grass():
		quit(1)
		return

	print("Artifact runtime smoke passed.")
	quit(0)


func _verify_emergency_shell() -> bool:
	var runtime = _runtime_script.new()
	runtime.configure({
		"id": "emergency_shell",
		"label": "Escape Capsule",
		"mods": {
			"emergency_shell": true,
			"emergency_shell_hp_ratio": 0.3,
			"emergency_shell_shield": 35.0,
			"emergency_shell_ammo_purge": true,
		},
	})

	var high_hp = runtime.evaluate_after_damage(40.0, 100.0, 0.0, 50.0)
	if not high_hp.is_empty():
		return _fail("Emergency Shell triggered above threshold.")

	var triggered = runtime.evaluate_after_damage(30.0, 100.0, 0.0, 50.0)
	if int(roundf(float(triggered.get("shield", 0.0)))) != 35:
		return _fail("Escape Capsule did not return the configured shield amount.")
	if not bool(triggered.get("ammo_purge", false)):
		return _fail("Escape Capsule did not return the configured ammo purge flag.")

	var repeated = runtime.evaluate_after_damage(20.0, 100.0, 0.0, 50.0)
	if not repeated.is_empty():
		return _fail("Emergency Shell triggered more than once.")

	return true


func _verify_ghost_grass() -> bool:
	var runtime = _runtime_script.new()
	runtime.configure({
		"id": "ghost_grass",
		"label": "Ghost Grass",
		"mods": {
			"ghost_grass": true,
			"ghost_grass_duration": 1.25,
			"ghost_grass_cooldown": 5.0,
			"ghost_grass_stealth_mult": 0.45,
			"ghost_grass_footstep_mult": 0.6,
			"ghost_grass_incoming_damage_mult": 1.5,
		},
	})

	var entering = runtime.on_bush_changed(false, true)
	if not entering.is_empty():
		return _fail("Ghost Grass triggered while entering a bush.")

	var started = runtime.on_bush_changed(true, false)
	if String(started.get("event", "")) != "ghost_grass_started":
		return _fail("Ghost Grass did not trigger after leaving a bush.")
	if not runtime.is_ghost_grass_active():
		return _fail("Ghost Grass was not active after triggering.")
	if absf(runtime.get_ghost_grass_stealth_modifier() - 0.45) > 0.001:
		return _fail("Ghost Grass stealth modifier did not match catalog tuning.")
	if absf(runtime.get_footstep_radius_mult(1.0) - 0.6) > 0.001:
		return _fail("Ghost Grass footstep multiplier did not match catalog tuning.")
	if absf(runtime.get_ghost_grass_incoming_damage_mult() - 1.5) > 0.001:
		return _fail("Ghost Grass incoming damage multiplier did not match catalog tuning.")
	if runtime.get_ghost_grass_cooldown_remaining() <= 0.0:
		return _fail("Ghost Grass did not start cooldown after triggering.")

	runtime.tick(1.0)
	if not runtime.is_ghost_grass_active():
		return _fail("Ghost Grass expired too early.")
	runtime.tick(0.25)
	if runtime.is_ghost_grass_active():
		return _fail("Ghost Grass did not expire after its configured duration.")
	if absf(runtime.get_footstep_radius_mult(0.8) - 0.8) > 0.001:
		return _fail("Ghost Grass kept modifying footsteps after expiry.")
	if not runtime.on_bush_changed(true, false).is_empty():
		return _fail("Ghost Grass retriggered during cooldown.")
	runtime.tick(3.75)
	var restarted = runtime.on_bush_changed(true, false)
	if String(restarted.get("event", "")) != "ghost_grass_started":
		return _fail("Ghost Grass did not retrigger after cooldown.")
	runtime.cancel_ghost_grass()
	if runtime.is_ghost_grass_active():
		return _fail("Ghost Grass remained active after cancellation.")

	return true


func _fail(message: String) -> bool:
	push_error(message)
	return false
