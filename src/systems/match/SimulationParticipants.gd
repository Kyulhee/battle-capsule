extends RefCounted


static func initial_alive_count(bot_count: int, is_simulation: bool) -> int:
	return bot_count if is_simulation else bot_count + 1


static func bot_alive_count(alive_count: int, is_simulation: bool) -> int:
	return maxi(0, alive_count if is_simulation else alive_count - 1)


static func configure_observer(player: Node3D) -> void:
	player.remove_from_group("actors")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.visible = false
	player.position = Vector3(0, -1000, 0)
	if player is CollisionObject3D:
		player.collision_layer = 0
		player.collision_mask = 0
