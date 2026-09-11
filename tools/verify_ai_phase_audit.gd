extends SceneTree

const AUDIT = preload("res://tools/AiPhaseAudit.gd")

func _init():
	create_timer(5.0).timeout.connect(func(): quit(1))
	var audit = AUDIT.new()
	var sample := {"elapsed_usec": 5000, "marks": [100, 1100, 2100, 3100, 4100, 4500, 4900, 5100]}
	var original := sample.duplicate(true)
	audit.record(sample, 12.0)
	assert(sample == original)
	assert(audit.report["events"][0]["phases_usec"]["handler"] == 1000)
	assert(audit.report["events"][0]["match_time"] == 12.0)
	for i in range(40):
		var elapsed := 6000 + i * 2000
		audit.record({"elapsed_usec": elapsed, "marks": [0, elapsed, elapsed, elapsed, elapsed, elapsed, elapsed, elapsed]}, 20.0)
	assert(audit.report["valid"])
	assert(audit.report["slow_samples"] == 41 and audit.report["events"].size() == 32)
	assert(audit.report["omitted"] == 9 and audit.report["over_gate_samples"] == 17)
	assert(audit.report["max_usec"] == 84000 and audit.report["phase_max_usec"]["bookkeeping"] == 84000)
	assert(audit.report["events"][0]["elapsed_usec"] == 84000)
	var invalid = AUDIT.new()
	invalid.record({"elapsed_usec": 5000, "marks": []}, 0.0)
	assert(not invalid.report["valid"])
	invalid = AUDIT.new()
	invalid.record({"elapsed_usec": 5000, "marks": [0, 1, 0, 2, 3, 4, 5, 5000]}, 0.0)
	assert(not invalid.report["valid"])
	invalid = AUDIT.new()
	invalid.record({"elapsed_usec": 5001, "marks": [0, 1, 2, 3, 4, 5, 6, 5000]}, 0.0)
	assert(not invalid.report["valid"])
	print("AI phase audit passed: sum identity, monotonic marks, bounded largest32, overflow, threshold, immutable.")
	quit(0)
