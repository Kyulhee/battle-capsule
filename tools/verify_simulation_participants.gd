extends SceneTree


func _init():
	var participants = load("res://src/systems/match/SimulationParticipants.gd")
	if participants.initial_alive_count(99, false) != 100:
		_fail("Playable match should count the player and 99 bots.")
		return
	if participants.initial_alive_count(99, true) != 99:
		_fail("Simulation should count only the 99 bot participants.")
		return
	if participants.bot_alive_count(99, true) != 99:
		_fail("Simulation bot-alive count should not subtract an observer.")
		return
	if participants.bot_alive_count(100, false) != 99:
		_fail("Playable bot-alive count should exclude the player.")
		return

	var observer := CharacterBody3D.new()
	observer.collision_layer = 2
	observer.collision_mask = 3
	observer.add_to_group("actors")
	root.add_child(observer)
	participants.configure_observer(observer)
	if observer.is_in_group("actors"):
		_fail("Simulation player should not remain targetable as an actor.")
		return
	if observer.process_mode != Node.PROCESS_MODE_DISABLED:
		_fail("Simulation player should be disabled.")
		return
	if observer.collision_layer != 0 or observer.collision_mask != 0:
		_fail("Simulation player collision should be disabled.")
		return
	if observer.position.y > -900.0:
		_fail("Simulation player should be parked outside the match space.")
		return

	observer.free()
	print("Simulation participants smoke passed: 99 bots, non-participant observer.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
