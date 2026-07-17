extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var bot_scene: PackedScene = load("res://src/entities/bot/Bot.tscn")
	var bot = bot_scene.instantiate()
	root.add_child(bot)

	var expired_target := Node3D.new()
	root.add_child(expired_target)
	bot.target_actor = expired_target
	bot.is_targeting_loot = true
	expired_target.free()

	if is_instance_valid(bot.target_actor):
		_fail("Target fixture should be expired before chase context checks.")
		return
	if String(bot.call("_chase_context_name")) != "unknown":
		_fail("Expired chase target should use unknown context.")
		return
	if String(bot.call("_chase_target_kind")) != "none":
		_fail("Expired chase target should use none kind.")
		return
	var position_context: Dictionary = bot.call("_chase_target_position_context")
	if String(position_context.get("poi_role", "")) != "none":
		_fail("Expired chase target should use empty position context.")
		return
	if String(bot.call("_pickup_kind_for", bot.target_actor)) != "pickup_unknown":
		_fail("Expired pickup target should use pickup_unknown.")
		return

	print("Bot target lifetime smoke passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
