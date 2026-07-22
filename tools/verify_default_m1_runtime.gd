extends SceneTree


const M1_MAP_PATH := "res://data/mapSpec_night_forest_expanded_candidate.json"
const M1_PRESET := "night_br_m1_60"


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

	if String(main.map_spec_path) != M1_MAP_PATH:
		await _cleanup(main)
		_fail("Default Main map must be the M1 Night candidate.")
		return
	if String(main.map_scale_preset) != M1_PRESET:
		await _cleanup(main)
		_fail("Default Main preset must be night_br_m1_60.")
		return
	if main.map_definition == null:
		await _cleanup(main)
		_fail("Default Main runtime did not load MapDefinition.")
		return

	var summary: Dictionary = main.map_definition.summary(main.game_config, main.map_scale_preset)
	var map_id := String(main.map_definition.id)
	var bot_count := int(summary.get("bot_count", 0))
	var loot_count := int(summary.get("loot_count", 0))
	var world_size := float(summary.get("world_size", 0.0))
	await _cleanup(main)
	if map_id != "night_forest_m1_candidate":
		_fail("Default Main runtime loaded unexpected map id: %s." % map_id)
		return
	if bot_count != 60 or loot_count != 200 or not is_equal_approx(world_size, 260.0):
		_fail("Default M1 runtime must resolve to 60 bots, 200 loot, and 260m world.")
		return
	print("Default M1 runtime smoke passed: %s %s bots=%d loot=%d world=%.0fm." % [
		M1_MAP_PATH,
		M1_PRESET,
		bot_count,
		loot_count,
		world_size,
	])
	quit(0)


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
