extends SceneTree


func _init():
	var match_tuning_script = load("res://src/systems/match/MatchTuning.gd")
	var seed_arg: Dictionary = match_tuning_script.from_cmdline_arg("simulation_seed=41000")
	if int(seed_arg.get("simulation_seed", -1)) != 41000:
		_fail("simulation_seed CLI arg did not parse correctly.")
		return
	var clamped_seed_arg: Dictionary = match_tuning_script.from_cmdline_arg("simulation_seed=-1")
	if int(clamped_seed_arg.get("simulation_seed", -1)) != 0:
		_fail("simulation_seed CLI arg should clamp negative values to zero.")
		return

	print("Match tuning CLI smoke passed: simulation_seed=41000.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
