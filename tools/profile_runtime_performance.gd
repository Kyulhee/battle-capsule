extends SceneTree


const DEFAULT_OUTPUT_PATH := "C:/tmp/runtime_performance.json"
const DEFAULT_WARMUP_SECONDS := 5.0
const DEFAULT_SAMPLE_SECONDS := 20.0
const TARGET_FRAME_SECONDS := 1.0 / 60.0
const HITCH_FRAME_SECONDS := 1.0 / 30.0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var options := _parse_options()
	root.size = Vector2i(1280, 720)
	var main_scene: PackedScene = load("res://src/Main.tscn")
	if main_scene == null:
		_fail("Could not load Main.tscn for runtime performance profiling.")
		return

	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await _wait_for_navigation(main)
	main.start_game()
	_keep_player_alive(main)

	await create_timer(float(options["warmup_seconds"])).timeout
	var pipeline_start := _pipeline_compilation_counts()
	var samples := {
		"frame_interval_seconds": [],
		"process_seconds": [],
		"physics_seconds": [],
		"navigation_seconds": [],
		"fps": [],
		"render_objects": [],
		"render_primitives": [],
		"draw_calls": [],
		"physics_pairs": [],
	}
	var sample_start_usec := Time.get_ticks_usec()
	var previous_frame_usec := sample_start_usec
	var sample_duration_usec := int(float(options["sample_seconds"]) * 1000000.0)
	while Time.get_ticks_usec() - sample_start_usec < sample_duration_usec:
		await process_frame
		var now_usec := Time.get_ticks_usec()
		samples.frame_interval_seconds.append(float(now_usec - previous_frame_usec) / 1000000.0)
		previous_frame_usec = now_usec
		samples.process_seconds.append(Performance.get_monitor(Performance.TIME_PROCESS))
		samples.physics_seconds.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
		samples.navigation_seconds.append(Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS))
		samples.fps.append(Performance.get_monitor(Performance.TIME_FPS))
		samples.render_objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		samples.render_primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		samples.draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		samples.physics_pairs.append(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS))

	var pipeline_end := _pipeline_compilation_counts()
	var result := {
		"map_spec_path": options["map_spec_path"],
		"scale_preset": options["scale_preset"],
		"warmup_seconds": options["warmup_seconds"],
		"sample_seconds": options["sample_seconds"],
		"sample_count": samples.frame_interval_seconds.size(),
		"population": {
			"bots": get_nodes_in_group("bots").size(),
			"actors": get_nodes_in_group("actors").size(),
			"pickups": get_nodes_in_group("pickups").size(),
		},
		"timing": {
			"frame_interval": _timing_summary(samples.frame_interval_seconds),
			"process": _timing_summary(samples.process_seconds),
			"physics": _timing_summary(samples.physics_seconds),
			"navigation": _timing_summary(samples.navigation_seconds),
		},
		"fps": _value_summary(samples.fps),
		"render": {
			"objects": _value_summary(samples.render_objects),
			"primitives": _value_summary(samples.render_primitives),
			"draw_calls": _value_summary(samples.draw_calls),
		},
		"physics_pairs": _value_summary(samples.physics_pairs),
		"ai_update": _ai_update_summary(),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"pipeline_compilations": _dictionary_delta(pipeline_start, pipeline_end),
	}
	if not _write_result(String(options["output_path"]), result):
		await _cleanup(main)
		_fail("Could not write runtime performance result: %s." % options["output_path"])
		return

	print("Runtime performance profile: %s" % JSON.stringify(result))
	await _cleanup(main)
	quit(0)


func _parse_options() -> Dictionary:
	var result := {
		"output_path": DEFAULT_OUTPUT_PATH,
		"warmup_seconds": DEFAULT_WARMUP_SECONDS,
		"sample_seconds": DEFAULT_SAMPLE_SECONDS,
		"map_spec_path": "",
		"scale_preset": "",
	}
	for raw_arg in OS.get_cmdline_user_args():
		var arg := String(raw_arg)
		if arg.begins_with("perf_output="):
			result.output_path = arg.trim_prefix("perf_output=")
		elif arg.begins_with("perf_warmup_seconds="):
			result.warmup_seconds = maxf(0.0, float(arg.trim_prefix("perf_warmup_seconds=")))
		elif arg.begins_with("perf_sample_seconds="):
			result.sample_seconds = maxf(1.0, float(arg.trim_prefix("perf_sample_seconds=")))
		elif arg.begins_with("map_spec_path="):
			result.map_spec_path = arg.trim_prefix("map_spec_path=")
		elif arg.begins_with("scale_preset="):
			result.scale_preset = arg.trim_prefix("scale_preset=")
	return result


func _wait_for_navigation(main: Node) -> void:
	var nav_region = main.get("_nav_region")
	if nav_region != null and nav_region.has_method("is_baking") and nav_region.is_baking():
		await nav_region.bake_finished


func _keep_player_alive(main: Node) -> void:
	var player = main.get("player_ref")
	if not is_instance_valid(player):
		return
	if player.get("stats") != null:
		player.stats.max_health = 1000000.0
	player.current_health = 1000000.0


func _timing_summary(values: Array) -> Dictionary:
	var summary := _value_summary(values)
	summary["avg_ms"] = float(summary["avg"]) * 1000.0
	summary["p50_ms"] = float(summary["p50"]) * 1000.0
	summary["p95_ms"] = float(summary["p95"]) * 1000.0
	summary["p99_ms"] = float(summary["p99"]) * 1000.0
	summary["max_ms"] = float(summary["max"]) * 1000.0
	summary["over_16_7ms_ratio"] = _ratio_above(values, TARGET_FRAME_SECONDS)
	summary["over_33_3ms_ratio"] = _ratio_above(values, HITCH_FRAME_SECONDS)
	return summary


func _value_summary(values: Array) -> Dictionary:
	if values.is_empty():
		return {"avg": 0.0, "min": 0.0, "p50": 0.0, "p95": 0.0, "p99": 0.0, "max": 0.0}
	var sorted_values := values.duplicate()
	sorted_values.sort()
	var total := 0.0
	for value in values:
		total += float(value)
	return {
		"avg": total / float(values.size()),
		"min": float(sorted_values[0]),
		"p50": _percentile(sorted_values, 0.50),
		"p95": _percentile(sorted_values, 0.95),
		"p99": _percentile(sorted_values, 0.99),
		"max": float(sorted_values[-1]),
	}


func _percentile(sorted_values: Array, fraction: float) -> float:
	var index := clampi(int(ceil(fraction * float(sorted_values.size()))) - 1, 0, sorted_values.size() - 1)
	return float(sorted_values[index])


func _ratio_above(values: Array, threshold: float) -> float:
	if values.is_empty():
		return 0.0
	var count := 0
	for value in values:
		if float(value) > threshold:
			count += 1
	return float(count) / float(values.size())


func _pipeline_compilation_counts() -> Dictionary:
	return {
		"canvas": int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS)),
		"mesh": int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH)),
		"surface": int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)),
		"draw": int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)),
		"specialization": int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)),
	}


func _ai_update_summary() -> Dictionary:
	var telemetry = root.get_node_or_null("Telemetry")
	if telemetry == null:
		return {"samples": 0, "avg_usec": 0.0, "max_usec": 0, "by_state": {}}
	var metrics = telemetry.get("metrics")
	if typeof(metrics) != TYPE_DICTIONARY:
		return {"samples": 0, "avg_usec": 0.0, "max_usec": 0, "by_state": {}}
	var ai: Dictionary = metrics.get("ai", {})
	var samples := int(ai.get("update_samples", 0))
	return {
		"samples": samples,
		"avg_usec": float(ai.get("update_total_usec", 0)) / maxf(1.0, float(samples)),
		"max_usec": int(ai.get("update_max_usec", 0)),
		"by_state": _ai_update_bucket_summary(ai.get("update_by_state", {})),
	}


func _ai_update_bucket_summary(buckets: Dictionary) -> Dictionary:
	var result := {}
	for bucket_name in buckets:
		var bucket: Dictionary = buckets[bucket_name]
		var samples := int(bucket.get("samples", 0))
		result[bucket_name] = {
			"samples": samples,
			"avg_usec": float(bucket.get("total_usec", 0)) / maxf(1.0, float(samples)),
			"max_usec": int(bucket.get("max_usec", 0)),
		}
	return result


func _dictionary_delta(before: Dictionary, after: Dictionary) -> Dictionary:
	var result := {}
	for key in after:
		result[key] = int(after[key]) - int(before.get(key, 0))
	return result


func _write_result(output_path: String, result: Dictionary) -> bool:
	var error := DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	if error != OK:
		return false
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(result, "\t"))
	return true


func _cleanup(main: Node) -> void:
	if is_instance_valid(main):
		main.queue_free()
	await process_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
