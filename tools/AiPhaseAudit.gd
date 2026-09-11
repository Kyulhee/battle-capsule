extends RefCounted

const PHASES := ["bookkeeping", "overrides_stuck", "perception_labels", "handler", "entity_movement", "visuals", "reporting"]
const CAPACITY := 32
var report := {"slow_samples": 0, "over_gate_samples": 0, "omitted": 0,
	"max_usec": 0, "events": [], "phase_max_usec": {}, "valid": true}

func record(sample: Dictionary, match_time: float) -> void:
	var marks: Array = sample.get("marks", [])
	if marks.size() != PHASES.size() + 1:
		report["valid"] = false
		return
	var phases := {}
	var total := 0
	for i in range(PHASES.size()):
		var elapsed := int(marks[i + 1]) - int(marks[i])
		if elapsed < 0:
			report["valid"] = false
			return
		phases[PHASES[i]] = elapsed
		total += elapsed
	if total != int(sample.get("elapsed_usec", -1)) or total < 5000:
		report["valid"] = false
		return
	report["slow_samples"] += 1
	report["over_gate_samples"] += int(total > 50000)
	report["max_usec"] = maxi(report["max_usec"], total)
	for phase in phases:
		report["phase_max_usec"][phase] = maxi(report["phase_max_usec"].get(phase, 0), phases[phase])
	var event := sample.duplicate(true)
	event.erase("marks")
	event["phases_usec"] = phases
	event["match_time"] = match_time
	# 가장 느린32개만 보존한다. 원본 sample은 바꾸지 않는다.
	report["events"].append(event)
	report["events"].sort_custom(func(a, b): return a["elapsed_usec"] > b["elapsed_usec"])
	if report["events"].size() > CAPACITY:
		report["events"].pop_back()
		report["omitted"] += 1
