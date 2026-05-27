extends SceneTree


func _init():
	var runtime_script = load("res://src/entities/player/PlayerArtifactRuntime.gd")
	var runtime = runtime_script.new()
	runtime.configure({
		"id": "emergency_shell",
		"label": "Emergency Shell",
		"mods": {
			"emergency_shell": true,
			"emergency_shell_hp_ratio": 0.3,
			"emergency_shell_shield": 35.0,
		},
	})

	var high_hp = runtime.evaluate_after_damage(40.0, 100.0, 0.0, 50.0)
	if not high_hp.is_empty():
		push_error("Emergency Shell triggered above threshold.")
		quit(1)
		return

	var triggered = runtime.evaluate_after_damage(30.0, 100.0, 0.0, 50.0)
	if int(roundf(float(triggered.get("shield", 0.0)))) != 35:
		push_error("Emergency Shell did not return the configured shield amount.")
		quit(1)
		return

	var repeated = runtime.evaluate_after_damage(20.0, 100.0, 0.0, 50.0)
	if not repeated.is_empty():
		push_error("Emergency Shell triggered more than once.")
		quit(1)
		return

	print("Artifact runtime smoke passed.")
	quit(0)
