extends SceneTree

const AUDIT = preload("res://tools/AiPhaseAudit.gd")
class SlowBot:
	extends "res://src/entities/bot/Bot.gd"
	func _ready():
		pass
	func handle_idle_state(_delta):
		# 진단 배선 검증용 합성 지연. 자연 매치/성능 결과에 포함하지 않는다.
		OS.delay_msec(6)

var samples: Array = []

func _init():
	_run.call_deferred()

func _run():
	create_timer(5.0).timeout.connect(func(): quit(1))
	var tel = root.get_node("Telemetry")
	tel.start_match()
	var bot := SlowBot.new()
	bot.stats = StatsData.new()
	bot.current_health = bot.stats.max_health
	var ray := RayCast3D.new()
	ray.name = "RayCast3D"
	bot.add_child(ray)
	root.add_child(bot)
	bot.set_process(false)
	bot.set_physics_process(false)
	assert(not bot._ai_phase_trace_sink.is_valid())
	bot._ai_update_telemetry_phase = 0
	bot._physics_process(1.0 / 60.0)
	assert(samples.is_empty())
	var before: int = tel.metrics["ai"]["update_total_usec"]
	bot._ai_phase_trace_sink = func(sample): samples.append(sample)
	bot._ai_update_telemetry_phase = 0
	bot._physics_process(1.0 / 60.0)
	assert(samples.size() == 1)
	assert(tel.metrics["ai"]["update_total_usec"] - before == samples[0]["elapsed_usec"])
	var audit = AUDIT.new()
	audit.record(samples[0], 0.0)
	assert(audit.report["valid"])
	assert(audit.report["events"][0]["phases_usec"]["handler"] >= 6000)
	assert(samples[0]["entry_state"] == "IDLE" and samples[0]["handler_state"] == "IDLE")
	bot._physics_process(1.0 / 60.0)
	assert(samples.size() == 1, "Trace should follow the existing sampled AI cadence")
	bot.free()
	print("AI phase runtime passed: default off, injected handler delay, shared telemetry total, sampling cadence.")
	quit(0)
