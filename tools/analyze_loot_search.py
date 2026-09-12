"""Validate exact search/filter totals and bounded examples; do not infer path accessibility."""
import argparse
from collections import Counter
import json
import math
from pathlib import Path

FILTERS = ("invalid", "out_of_radius", "not_sensed", "ammo_mismatch", "weapon_rejected", "armor_not_upgrade", "accepted")
OUTCOMES = ("cached_none", "cached_hit", "selected", "empty_pool", "invalid_pool", "out_of_radius", "not_sensed", "item_rules")
SCOPES = ("IDLE", "RECOVER/seek_loot", "RECOVER/patrol", "RECOVER/other")
MAP = "res://data/mapSpec_night_forest_expanded_candidate.json"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def finite(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def count(value):
    require(type(value) is int and value >= 0, "Invalid nonnegative integer count")
    return value


def counters(values, keys):
    require(isinstance(values, dict) and set(values) <= set(keys), "Unknown counter keys")
    return Counter({key: count(value) for key, value in values.items()})


def event_outcome(event):
    c = event["counts"]
    require(set(c) == {"pool", *FILTERS}, "Event filter fields differ")
    require(count(c["pool"]) == sum(count(c[k]) for k in FILTERS), "Event filter sum differs")
    selected = event["selected_id"] is not None
    if selected:
        require(type(event["selected_id"]) is int and event["selected_id"] > 0, "Selected ID invalid")
    mode = event["mode"]
    require(mode in ("scan", "cached_none", "cached_hit"), "Unknown search mode")
    if mode != "scan":
        require(c["pool"] == 0 and selected == (mode == "cached_hit"), "Cache mode scanned or selection differs")
        return mode
    require(selected == (c["accepted"] > 0), "Scan selection/accepted count differs")
    if selected:
        return "selected"
    if c["pool"] == 0:
        return "empty_pool"
    if c["pool"] == c["invalid"]:
        return "invalid_pool"
    if c["pool"] == c["invalid"] + c["out_of_radius"]:
        return "out_of_radius"
    if c["pool"] == c["invalid"] + c["out_of_radius"] + c["not_sensed"]:
        return "not_sensed"
    return "item_rules"


def analyze(flow):
    require(flow["schema_version"] == 3 and flow["complete"] is True and not flow["initial_only"], "Incomplete flow")
    require(flow["loot_search_enabled"] is True and flow["search_audit_created"] is True
            and flow["search_audit_loaded"] is True and flow["search_until"] == 260, "Search capture not enabled")
    require(flow["map"] == MAP and flow["preset"] == "night_br_m1_60", "Unexpected map/preset")
    require(type(flow["seed"]) is int and flow["seed"] >= 0, "Missing tracked seed")
    require(not any(flow.get(k, False) for k in ("candidate", "ai_phase_trace_enabled", "loot_phase_enabled",
            "progress_enabled", "phase_window_only", "progress_window_only")), "Mixed diagnostics/candidates")
    require(flow["time_scale"] == (1 if flow["search_window_only"] else 5), "Wrong window time scale")
    require(flow["checkpoints_not_reached"] == [], "Missing checkpoints")
    snapshots = flow["snapshots"]
    require([s["requested_time"] for s in snapshots] == [0, 120, 260], "Checkpoint contract differs")
    require(snapshots[0]["alive"] == 60, "Initial population differs")
    for snapshot in snapshots:
        t, observed = snapshot["requested_time"], snapshot["observed_time"]
        require(finite(observed) and 0 <= observed - t <= 0.25, "Checkpoint timing invalid")
        actors = snapshot["actors"]
        require(len(actors) == snapshot["alive"] == len({a["id"] for a in actors}), "Checkpoint population/IDs")
    require(finite(flow["end_time"]) and flow["end_time"] >= snapshots[-1]["observed_time"], "End time invalid")
    if flow["search_window_only"]:
        require(flow["end_time"] <= 260.25, "Search window ended late")
    audit = flow["loot_search"]
    require(audit["schema_version"] == 1 and audit["valid"] is True, "Capture accounting invalid")
    require(audit["capacity"] == 64 and audit["per_bucket"] == 2, "Retention contract differs")
    calls, scans, pool = count(audit["calls"]), count(audit["scans"]), count(audit["pool_candidates"])
    outcomes, filters = counters(audit["outcomes"], OUTCOMES), counters(audit["filters"], FILTERS)
    require(sum(outcomes.values()) == calls and scans == calls - outcomes["cached_none"] - outcomes["cached_hit"], "Call/scan totals differ")
    require(sum(filters.values()) == pool, "Global filter sum differs")
    scopes = audit["by_scope"]
    require(set(scopes) <= set(SCOPES), "Unexpected search scope")
    sum_calls = sum_pool = 0
    sum_outcomes, sum_filters = Counter(), Counter()
    expected_retained = Counter()
    for scope, bucket in scopes.items():
        b_calls, b_pool = count(bucket["calls"]), count(bucket["pool_candidates"])
        b_outcomes, b_filters = counters(bucket["outcomes"], OUTCOMES), counters(bucket["filters"], FILTERS)
        require(sum(b_outcomes.values()) == b_calls and sum(b_filters.values()) == b_pool, "Scope sum differs")
        sum_calls += b_calls
        sum_pool += b_pool
        sum_outcomes.update(b_outcomes)
        sum_filters.update(b_filters)
        for outcome, population in b_outcomes.items():
            expected_retained[(scope, outcome)] = min(2, population)
    require((sum_calls, sum_pool, sum_outcomes, sum_filters) == (calls, pool, outcomes, filters), "Scope/global totals differ")
    events = audit["events"]
    require(len(events) <= 64 and len(events) + count(audit["omitted"]) == calls, "Retention/omitted totals differ")
    retained = Counter()
    previous_time = -1.0
    for event in events:
        t = event["match_time"]
        require(finite(t) and previous_time <= t <= 260, "Event clock invalid")
        previous_time = t
        require(type(event["actor_id"]) is int and event["actor_id"] > 0, "Actor ID invalid")
        require(event["state"] in ("IDLE", "RECOVER") and finite(event["loaded"]) and finite(event["reserve"])
                and event["loaded"] <= 0 and event["reserve"] <= 0, "Out-of-scope search")
        require(finite(event["radius"]) and event["radius"] > 0 and finite(event["search_timer"]), "Query context invalid")
        require(len(event["position"]) == 2 and all(finite(v) for v in event["position"]), "Position invalid")
        require(type(event["prefer_immediate"]) is bool, "Query preference invalid")
        scope = "IDLE"
        if event["state"] == "RECOVER":
            substate = event["recovery_substate"]
            scope = "RECOVER/" + (substate if substate in ("seek_loot", "patrol") else "other")
        outcome = event_outcome(event)
        require(event["scope"] == scope and event["outcome"] == outcome, "Event classification differs")
        require(scope in scopes and scopes[scope]["outcomes"].get(outcome, 0) > 0, "Event absent from aggregate")
        for key in FILTERS:
            require(event["counts"][key] <= scopes[scope]["filters"].get(key, 0), "Event exceeds scope filter population")
        retained[(scope, outcome)] += 1
    require(retained == expected_retained, "Per-bucket retention differs")
    return {"integrity": "PASS", "seed": flow["seed"], "loot_progress_candidate": flow["loot_progress_candidate"],
            "search_window_only": flow["search_window_only"], "calls": calls, "fresh_scans": scans,
            "outcomes": dict(outcomes), "filter_candidate_visits": dict(filters), "by_scope": scopes,
            "stored_examples": len(events), "omitted_examples": audit["omitted"],
            "limits": "Exact call/first-rejection counts, not unique items, scarcity duration, path reachability or causal proof. "
                      "Cache returns are not fresh scans; retained examples are the first two per scope/outcome, not random samples. "
                      "A large out-of-radius fraction of the global item pool alone does not establish a radius problem."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("flow", type=Path)
    args = parser.parse_args()
    try:
        result = analyze(json.loads(args.flow.read_text(encoding="utf-8")))
    except (KeyError, TypeError, ValueError) as exc:
        parser.exit(1, f"FAIL: {exc}\n")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
