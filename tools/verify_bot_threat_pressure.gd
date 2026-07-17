extends SceneTree

const BOT_SCRIPT := preload("res://src/entities/bot/Bot.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var subject = BOT_SCRIPT.new()
	var target = BOT_SCRIPT.new()
	var bystander = BOT_SCRIPT.new()

	target.add_to_group("players")
	subject.target_actor = target
	subject.perception_meters[target] = 1.0
	subject._disengage_threshold = 1
	_refresh_pressure(subject)
	if subject._should_disengage_outnumbered():
		_fail("A visible current target must not count as an additional threat.")
		return

	subject.perception_meters[bystander] = 1.0
	bystander.target_actor = target
	bystander.current_state = bystander.State.ATTACK
	_refresh_pressure(subject)
	if subject._should_disengage_outnumbered():
		_fail("A visible bystander attacking someone else must not force disengage.")
		return

	bystander.target_actor = subject
	bystander.current_state = bystander.State.CHASE
	_refresh_pressure(subject)
	if not subject._should_disengage_outnumbered():
		_fail("A visible bot pursuing the subject must count as an active threat.")
		return

	bystander.target_actor = target
	subject.damage_history[bystander] = Time.get_ticks_msec()
	_refresh_pressure(subject)
	if not subject._should_disengage_outnumbered():
		_fail("A recent attacker must remain an active threat.")
		return

	subject.damage_history[bystander] = Time.get_ticks_msec() - Entity.ASSIST_WINDOW_MS - 1
	_refresh_pressure(subject)
	if subject._should_disengage_outnumbered():
		_fail("An expired attacker that targets someone else must stop counting.")
		return

	target.remove_from_group("players")
	_refresh_pressure(subject)
	if not subject._should_disengage_outnumbered():
		_fail("Bot-only combat must preserve the existing visible-enemy threshold.")
		return

	subject.free()
	target.free()
	bystander.free()
	print("Bot threat pressure smoke passed.")
	quit(0)


func _refresh_pressure(bot) -> void:
	bot.set("_threat_pressure_timer", 0.0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
