extends SceneTree

const Items = preload("res://src/core/ItemResourceCatalog.gd")
var failed := false
var output_dir := "res://builds/verification/E066_visual"

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("capture_dir="):
			output_dir = arg.trim_prefix("capture_dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var main = load("res://src/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	if main._nav_region.is_baking():
		await main._nav_region.bake_finished
	main.start_game()
	main.set_process(false)
	main.set_physics_process(false)
	for bot in get_nodes_in_group("bots"):
		bot.set_process(false)
		bot.set_physics_process(false)
	var player = main.player_ref
	player.set_physics_process(false)
	player.set_process(false)
	player.global_position = Vector3(0.0, 0.5, 0.0)
	player.rotation.y = 0.0
	player.get_node("CameraPivot").global_position = player.global_position
	player.receive_weapon(Items.WEAPON_SHOTGUN_WORN.weapon_stats.duplicate())
	player.receive_weapon(Items.WEAPON_AR.weapon_stats.duplicate())
	player.receive_weapon(Items.WEAPON_RAILGUN.weapon_stats.duplicate())
	player.receive_armor_equipment(Items.BALLISTIC_VEST)
	player._process(0.0)
	var worn_pickup = Items.PICKUP_SCENE.instantiate()
	worn_pickup.item = Items.WEAPON_SHOTGUN_WORN
	main.add_child(worn_pickup)
	worn_pickup.global_position = player.global_position + Vector3(-2.5, 0.0, -1.5)
	var pickup = Items.PICKUP_SCENE.instantiate()
	pickup.item = Items.WEAPON_SHOTGUN
	main.add_child(pickup)
	pickup.global_position = player.global_position + Vector3(0.0, 0.0, -2.4)
	await create_timer(0.4).timeout
	pickup.set_focused(true)
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		DisplayServer.window_set_size(dimensions)
		root.size = dimensions
		player.slots.weapon_slots[2] = Items.WEAPON_SHOTGUN_WORN.weapon_stats.duplicate()
		player.slots.slot_ammo[2] = 3
		player.slots.slot_reserve[2] = 6
		player.slots.switch_to(2)
		pickup._refresh_label_for_player()
		if not pickup._label.visible or not pickup._label.text.contains("T1 → T2"):
			push_error("Night fixture pickup must be sensed and show the real comparison.")
			failed = true
		await _capture(player, "%d_worn" % dimensions.x)
		player.receive_weapon(Items.WEAPON_SHOTGUN.weapon_stats.duplicate())
		pickup._refresh_label_for_player()
		await _capture(player, "%d_upgraded" % dimensions.x)
		player.slots.slot_ammo[2] = 0
		player.slots.slot_reserve[2] = 8
		if not player.slots.start_reload():
			push_error("Reload fixture did not start.")
			failed = true
		player.slots.reload_timer = player.slots.reload_total_time * 0.5
		player._process(0.0)
		await _capture(player, "%d_reload" % dimensions.x, false)
		player.slots.switch_to(2)
		player.slots.slot_ammo[2] = 0
		player.slots.slot_reserve[2] = 0
		player.current_health = 20
		player._process(0.0)
		await _capture(player, "%d_empty_low_hp" % dimensions.x)
		player.current_health = player.stats.max_health
		player.slots.switch_to(0)
		await _capture(player, "%d_knife" % dimensions.x)
		player.slots.weapon_slots[4] = null
		await _capture(player, "%d_empty_slot" % dimensions.x)
		player.slots.weapon_slots[4] = Items.WEAPON_RAILGUN.weapon_stats.duplicate()
	main.queue_free()
	await process_frame
	await process_frame
	quit(1 if failed else 0)

func _capture(player, state: String, refresh := true) -> void:
	if refresh:
		player._refresh_slot_hud()
		player._update_hud()
	await process_frame
	await RenderingServer.frame_post_draw
	var slot_bar: Control = player.slot_panels[0].get_parent()
	# Canvas-items stretching keeps HUD coordinates logical (1280x720 at 1080p).
	var hud_bounds: Rect2 = slot_bar.get_parent().get_global_rect()
	for panel in player.slot_panels:
		var bounds: Rect2 = panel.get_global_rect()
		if not hud_bounds.encloses(bounds):
			push_error("HUD slot outside viewport: %s %s" % [state, bounds])
			failed = true
		for child in panel.get_node("Content").get_children():
			if child is Control and not bounds.grow(1.0).encloses(child.get_global_rect()):
				push_error("HUD child exceeds panel: %s %s" % [state, child.name])
				failed = true
	if absf(slot_bar.get_global_rect().get_center().x - hud_bounds.get_center().x) > 2.0:
		push_error("Slot bar is not centered: " + state)
		failed = true
	var screenshot := root.get_texture().get_image()
	if screenshot.get_size() != root.size:
		push_error("Capture resolution mismatch: " + state)
		failed = true
	var path := output_dir.path_join(state + ".png")
	if screenshot.save_png(path) != OK:
		push_error("Cannot save capture: " + path)
		failed = true
	print("TIER_CAPTURE ", path)
