extends SceneTree


func _init():
	var runtime_tuning_script = load("res://src/systems/match/MatchRuntimeTuning.gd")
	var bot_script = load("res://src/entities/bot/Bot.gd")

	var default_combat: Dictionary = runtime_tuning_script.combat({})
	if not is_equal_approx(float(default_combat.get("bot_vs_bot_damage_mult", 0.0)), 1.0):
		_fail("Default bot-vs-bot damage should remain unchanged.")
		return

	var candidate_combat: Dictionary = runtime_tuning_script.combat({
		"combat": {"bot_vs_bot_damage_mult": 0.55},
	})
	var source = bot_script.new()
	source.configure_runtime_combat(candidate_combat)

	var bot_target = Node.new()
	root.add_child(bot_target)
	bot_target.add_to_group("bots")
	var player_target = Node.new()
	root.add_child(player_target)
	player_target.add_to_group("players")

	if not is_equal_approx(source._outgoing_damage_for(bot_target, 20.0), 11.0):
		_fail("Runtime combat multiplier should apply to bot targets.")
		return
	if not is_equal_approx(source._outgoing_damage_for(player_target, 20.0), 20.0):
		_fail("Runtime combat multiplier must not change damage to the player.")
		return

	source.free()
	bot_target.free()
	player_target.free()
	print("Bot runtime combat smoke passed: bot_vs_bot=0.55 player=1.00.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
