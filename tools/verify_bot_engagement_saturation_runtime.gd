extends SceneTree


const BOT_SCENE := preload("res://src/entities/bot/Bot.tscn")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var subject = BOT_SCENE.instantiate()
	var target = BOT_SCENE.instantiate()
	var existing_attacker = BOT_SCENE.instantiate()
	root.add_child(subject)
	root.add_child(target)
	root.add_child(existing_attacker)
	for bot in [subject, target, existing_attacker]:
		bot.set_physics_process(false)
	await create_timer(0.25).timeout

	subject.configure_ai(1)
	subject.global_position = Vector3.ZERO
	target.global_position = Vector3(0.0, 0.0, 16.0)
	existing_attacker.global_position = Vector3(3.0, 0.0, 14.0)
	existing_attacker.target_actor = target
	existing_attacker.current_state = existing_attacker.State.CHASE

	if subject.acquire_enemy_target(target, "idle_reaction"):
		_fail("A distant defensive bot joined a target that already reached its capacity.")
		return
	if subject.target_actor != null:
		_fail("A deferred bot must keep its current strategic objective.")
		return

	target.target_actor = subject
	target.current_state = target.State.CHASE
	if not subject.acquire_enemy_target(target, "idle_reaction"):
		_fail("A target directly pressuring the subject must bypass saturation.")
		return
	if subject.target_actor != target:
		_fail("Direct threat bypass did not retain the attacker as target.")
		return

	for bot in [subject, target, existing_attacker]:
		bot.free()
	await process_frame
	print("Bot engagement saturation runtime smoke passed: defer and direct response.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
