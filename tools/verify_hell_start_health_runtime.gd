extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var main_scene: PackedScene = load("res://src/Main.tscn")
	if main_scene == null:
		_fail("Could not load Main.tscn.")
		return
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await _wait_for_navigation(main)
	main.difficulty = main.Difficulty.HELL
	main.start_game()
	var player = main.player_ref
	if not is_instance_valid(player):
		await _cleanup(main)
		_fail("Hell runtime did not spawn a player.")
		return
	if not is_equal_approx(player.current_health, 1.0) \
			or not is_equal_approx(player.stats.max_health, 100.0):
		var start_snapshot := "%.1f/%.1f" % [player.current_health, player.stats.max_health]
		await _cleanup(main)
		_fail("Hell runtime must start at recoverable 1/100 HP, got %s." % start_snapshot)
		return

	var catalog = load("res://src/core/ArtifactCatalog.gd")
	var zone_battery := _find_artifact(catalog.starting_artifacts(3), "zone_battery")
	player.apply_artifact(zone_battery)
	var locked_health: float = float(player.current_health)
	var locked_max_health: float = float(player.stats.max_health)
	await _cleanup(main)
	if not is_equal_approx(locked_health, 1.0) or not is_equal_approx(locked_max_health, 1.0):
		_fail("No-heal artifact must lock Hell runtime to 1/1 HP.")
		return
	print("Hell starting health runtime smoke passed: start=1/100 no-heal=1/1.")
	quit(0)


func _find_artifact(artifacts: Array, id: String) -> Dictionary:
	for artifact in artifacts:
		if String(artifact.get("id", "")) == id:
			return artifact
	return {}


func _wait_for_navigation(main: Node) -> void:
	var nav_region = main.get("_nav_region")
	if nav_region != null and nav_region.has_method("is_baking") and nav_region.is_baking():
		await nav_region.bake_finished


func _cleanup(main: Node) -> void:
	if is_instance_valid(main):
		main.queue_free()
	await process_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
