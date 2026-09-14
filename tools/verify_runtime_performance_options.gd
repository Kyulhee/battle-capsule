extends SceneTree

func _init(): _run.call_deferred()

func _run():
	var probe = load("res://tools/profile_runtime_performance.gd")
	var failures: Array[String] = []
	var defaults: Dictionary = probe._parse_options(PackedStringArray())
	if defaults.physics_clock_candidate or not defaults.error.is_empty() \
			or defaults.warmup_seconds != 5.0 or defaults.sample_seconds != 20.0:
		failures.append("Default performance contract changed")
	for enabled in ["true", "false"]:
		var options: Dictionary = probe._parse_options(PackedStringArray([
			"perf_physics_clock_candidate=" + enabled, "simulation_seed=41000"]))
		if options.physics_clock_candidate != (enabled == "true") or not options.error.is_empty():
			failures.append("Explicit clock option failed: " + enabled)
	for invalid in ["perf_physics_clock_candidate=typo", "autostart=true",
			"trace_progress=true", "first_collection_scale=5", "recovery_patrol_candidate=true",
			"loot_match_candidate=true", "loot_progress_candidate=true", "physics_clock_candidate=true"]:
		if probe._parse_options(PackedStringArray([invalid])).error.is_empty():
			failures.append("Invalid option accepted: " + invalid)
	if probe._parse_options(PackedStringArray([
		"perf_physics_clock_candidate=true", "perf_hide_minimap=true"])).error.is_empty():
		failures.append("Mixed clock/minimap comparison accepted")
	var protected := OS.get_user_data_dir()
	for invalid in ["", "relative.json", "user://new-profile.json", protected + "/new-profile.json",
			protected + "/nested/../new-profile.json", ProjectSettings.globalize_path("res://project.godot")]:
		if probe._output_error(invalid, protected).is_empty():
			failures.append("Unsafe output accepted: " + invalid)
	var safe := ProjectSettings.globalize_path("res://builds/verification/new-perf-%s.json" % Time.get_ticks_usec())
	if not probe._output_error(safe, protected).is_empty():
		failures.append("New workspace output rejected")
	if failures.is_empty():
		print("Performance options PASS: defaults, clock OFF/ON, mixtures, protected/existing paths")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
