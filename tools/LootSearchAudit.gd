extends RefCounted

const FILTERS := ["invalid", "out_of_radius", "not_sensed", "ammo_mismatch", "weapon_rejected", "armor_not_upgrade", "accepted"]
const OUTCOMES := ["cached_none", "cached_hit", "selected", "empty_pool", "invalid_pool", "out_of_radius", "not_sensed", "item_rules"]
const SCOPES := ["IDLE", "RECOVER/seek_loot", "RECOVER/patrol", "RECOVER/other"]
const PER_BUCKET := 2
const CAPACITY := 64
var report := {"schema_version": 1, "valid": true, "calls": 0, "scans": 0, "pool_candidates": 0,
	"outcomes": {}, "filters": {}, "by_scope": {}, "events": [], "omitted": 0,
	"capacity": CAPACITY, "per_bucket": PER_BUCKET}
var retained := {}

func record(sample: Dictionary, match_time: float) -> void:
	var counts: Dictionary = sample.get("counts", {})
	var total := 0
	for key in FILTERS:
		if not counts.has(key) or int(counts[key]) < 0:
			report["valid"] = false
			return
		total += int(counts[key])
	if total != int(counts.get("pool", -1)) or match_time < 0.0 or match_time > 260.0 \
			or not is_finite(match_time) or sample.get("state", "") not in ["IDLE", "RECOVER"] \
			or int(sample.get("loaded", 1)) > 0 or int(sample.get("reserve", 1)) > 0:
		report["valid"] = false
		return
	var mode := String(sample.get("mode", ""))
	var selected: bool = sample.get("selected_id") != null
	if mode not in ["scan", "cached_none", "cached_hit"] \
			or (mode != "scan" and (total != 0 or selected != (mode == "cached_hit"))) \
			or (mode == "scan" and selected != (int(counts["accepted"]) > 0)):
		report["valid"] = false
		return
	var outcome := mode
	if mode == "scan":
		if selected: outcome = "selected"
		elif total == 0: outcome = "empty_pool"
		elif total == int(counts["invalid"]): outcome = "invalid_pool"
		elif total == int(counts["invalid"]) + int(counts["out_of_radius"]): outcome = "out_of_radius"
		elif total == int(counts["invalid"]) + int(counts["out_of_radius"]) + int(counts["not_sensed"]): outcome = "not_sensed"
		else: outcome = "item_rules"
	var scope := "IDLE"
	if sample["state"] == "RECOVER":
		var substate := String(sample.get("recovery_substate", ""))
		scope = "RECOVER/" + (substate if substate in ["seek_loot", "patrol"] else "other")
	if not report["by_scope"].has(scope):
		report["by_scope"][scope] = {"calls": 0, "outcomes": {}, "filters": {}, "pool_candidates": 0}
	var bucket: Dictionary = report["by_scope"][scope]
	report["calls"] += 1
	report["scans"] += int(mode == "scan")
	_increment(report["outcomes"], outcome, 1)
	_increment(bucket["outcomes"], outcome, 1)
	bucket["calls"] += 1
	for key in FILTERS:
		_increment(report["filters"], key, int(counts[key]))
		_increment(bucket["filters"], key, int(counts[key]))
	report["pool_candidates"] += total
	bucket["pool_candidates"] += total
	var retention_key := scope + ":" + outcome
	if int(retained.get(retention_key, 0)) < PER_BUCKET:
		var event := sample.duplicate(true)
		event["match_time"] = match_time
		event["scope"] = scope
		event["outcome"] = outcome
		report["events"].append(event)
		_increment(retained, retention_key, 1)
	else:
		report["omitted"] += 1

func _increment(counts: Dictionary, key: String, amount: int) -> void:
	counts[key] = int(counts.get(key, 0)) + amount
