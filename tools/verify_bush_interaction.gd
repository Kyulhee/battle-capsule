extends SceneTree


func _init():
	call_deferred("_run")


func _run():
	var entity_script = load("res://src/entities/Entity.gd")
	var stats_script = load("res://src/core/StatsData.gd")
	var bush_scene = load("res://src/environment/Bush.tscn")

	var viewer = _make_entity(entity_script, stats_script, "Viewer", Vector3(0, 0, 0))
	var target = _make_entity(entity_script, stats_script, "Target", Vector3(0, 0, -10))
	root.add_child(viewer)
	root.add_child(target)

	var bush_a := Node.new()
	var bush_b := Node.new()
	root.add_child(bush_a)
	root.add_child(bush_b)

	target.enter_bush(bush_a)
	target.stealth_modifier = 0.2
	if viewer._can_i_see(target):
		_fail("Outside viewer saw an unrevealed target hidden in a bush beyond near range.")
		return

	viewer.enter_bush(bush_a)
	if not viewer._can_i_see(target):
		_fail("Viewer did not see target while both were inside the same bush.")
		return
	if absf(viewer._perception_dwell_for(target) - target.stats.dwell_time_open) > 0.001:
		_fail("Same-bush perception did not use open dwell time.")
		return

	viewer.exit_bush(bush_a)
	viewer.enter_bush(bush_b)
	if viewer._can_i_see(target):
		_fail("Viewer in a different bush saw an unrevealed target hidden in another bush.")
		return

	target.reveal(2.0)
	if not viewer._can_i_see(target):
		_fail("Revealed bush target was not visible from outside.")
		return

	var bush = bush_scene.instantiate()
	root.add_child(bush)
	var catalog_visual := Node3D.new()
	catalog_visual.name = "CatalogPropVisual"
	bush.add_child(catalog_visual)
	bush.set_catalog_visual_active(true)
	var feedback_mesh := bush.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if feedback_mesh == null:
		_fail("Bush has no feedback mesh.")
		return
	if feedback_mesh.visible:
		_fail("Catalog bush feedback mesh should start hidden until the player enters.")
		return

	var player = _make_entity(entity_script, stats_script, "Player", bush.global_position)
	player.add_to_group("players")
	root.add_child(player)
	bush._on_body_entered(player)
	var entered_state: Dictionary = bush.debug_state()
	if not player.is_in_bush:
		_fail("Bush enter did not set player is_in_bush.")
		return
	if not bool(entered_state.get("local_player_inside", false)):
		_fail("Bush did not track local player occupancy.")
		return
	if not bool(entered_state.get("feedback_visible", false)):
		_fail("Bush feedback mesh did not become visible for player occupancy.")
		return
	if float(entered_state.get("rustle_amount", 0.0)) <= 0.0:
		_fail("Bush enter did not kick rustle feedback.")
		return

	bush._on_body_exited(player)
	var exited_state: Dictionary = bush.debug_state()
	if player.is_in_bush:
		_fail("Bush exit did not clear player is_in_bush.")
		return
	if bool(exited_state.get("local_player_inside", false)):
		_fail("Bush kept local player occupancy after exit.")
		return
	if bool(exited_state.get("feedback_visible", false)):
		_fail("Bush feedback mesh stayed visible after player exit.")
		return

	print("Bush interaction smoke passed.")
	quit(0)


func _make_entity(entity_script: Script, stats_script: Script, entity_name: String, pos: Vector3):
	var entity = entity_script.new()
	entity.name = entity_name
	entity.stats = stats_script.new()
	entity.stats.vision_range = 25.0
	entity.stats.fov_near_range = 5.0
	entity.stats.fov_angle = 120.0
	entity.stats.dwell_time_open = 0.3
	entity.stats.dwell_time_bush = 0.8
	entity.position = pos
	return entity


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
