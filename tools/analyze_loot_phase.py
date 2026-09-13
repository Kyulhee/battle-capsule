"""Compare matched post-wave stock observations; reject phase/identity/timing mismatches."""
import argparse
from collections import Counter
import json
import math
from pathlib import Path

MAP = "res://data/mapSpec_night_forest_expanded_candidate.json"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def number(value):
    return isinstance(value, (float, int)) and not isinstance(value, bool) and math.isfinite(value)


def validate_snapshot(snapshot):
    requested, observed = snapshot["requested_time"], snapshot["observed_time"]
    require(number(requested) and number(observed) and 0 <= observed - requested <= 0.25,
            "Snapshot timing missing, nonfinite, early or delayed")
    actors = snapshot["actors"]
    require(len(actors) == snapshot["alive"] == len({a["id"] for a in actors}), "Actor population/IDs")
    empty = sum(a["loaded"] <= 0 and a["reserve"] <= 0 for a in actors)
    require(empty == snapshot["needs"]["no_ammo"], "Empty-ammo count differs from actors")
    records, totals = snapshot["records"], snapshot["totals"]
    require(totals["items"] == len(records), "Stock count differs from records")
    for key, kind in (("ammo_packs", "ammo"), ("weapons", "weapon")):
        require(totals[key] == sum(r["kind"] == kind for r in records), "Stock kind count differs")


def analyze(report):
    require(report["schema_version"] == 3 and report["complete"] and not report["initial_only"], "Incomplete flow")
    require(report.get("loot_phase_enabled") is True, "Phase observation disabled")
    require(report["map"] == MAP and report["preset"] == "night_br_m1_60", "Wrong map/preset")
    expected_scale = 1 if report.get("phase_window_only") else 5
    require(report["time_scale"] == expected_scale, "Phase-only windows require real-time; full runs use 5x")
    require(not any(report.get(k, False) for k in ("candidate", "ai_phase_trace_enabled",
        "ai_phase_audit_loaded", "ai_phase_audit_created", "progress_enabled", "progress_window_only", "recovery_patrol_candidate")), "Mixed diagnostics/candidates")
    require(report["checkpoints_not_reached"] == [], "Missing legacy checkpoint")
    snapshots = report["snapshots"]
    require([s["requested_time"] for s in snapshots] == [0, 120, 260], "Legacy checkpoints changed")
    require(snapshots[0]["alive"] == 60, "Initial population differs")
    for snapshot in snapshots:
        validate_snapshot(snapshot)
    phases = report["phase_snapshots"]
    require(len(phases) == 1, "Missing or duplicate phase snapshot")
    phase = phases[0]
    validate_snapshot(phase)
    require(phase["phase_key"] == "stage2_post_wave_1s" and phase["zone_stage"] == 2
            and phase["zone_shrinking"] is False, "Wrong zone phase")
    anchor = phase["phase_anchor_time"]
    require(number(anchor) and anchor > 0 and phase["phase_offset_seconds"] == 1.0, "Invalid phase anchor/offset")
    require(report["phase_stage_times"]["2"] == anchor, "Anchor differs from telemetry stage clock")
    require(abs(phase["requested_time"] - anchor - 1.0) < 1e-6, "Wrong relative phase time")
    require(phase["observed_time"] >= snapshots[-1]["observed_time"], "Phase precedes checkpoint")
    require(number(report["end_time"]) and report["end_time"] >= phase["observed_time"], "Invalid end time")
    if report.get("phase_window_only"):
        require(report["end_time"] == phase["observed_time"], "Window did not stop at observation")
    empty = [a for a in phase["actors"] if a["loaded"] <= 0 and a["reserve"] <= 0]
    states = Counter(a["state_name"] for a in empty)
    recovery = Counter(a["recovery_substate"] for a in empty if a["state_name"] == "RECOVER")
    return {"seed": report["seed"], "loot_progress_candidate": report["loot_progress_candidate"],
            "phase_window_only": report.get("phase_window_only", False),
            "phase_key": phase["phase_key"], "phase_anchor_time": anchor,
            "observed_time": phase["observed_time"], "lag": phase["observed_time"] - phase["requested_time"],
            "alive": phase["alive"], "no_ammo": len(empty),
            "empty_states": dict(states), "empty_recovery_substates": dict(recovery),
            "items": phase["totals"]["items"], "ammo_packs": phase["totals"]["ammo_packs"],
            "weapons": phase["totals"]["weapons"],
            "stage_wave_items": sum(r["source"] == "stage_wave" for r in phase["records"])}


def compare(control, candidate):
    left, right = analyze(control), analyze(candidate)
    require(not left["loot_progress_candidate"] and right["loot_progress_candidate"], "Expected control then loot candidate")
    require(left["seed"] == right["seed"] and left["phase_window_only"] == right["phase_window_only"], "Input/window mismatch")
    require(control["snapshots"][0] == candidate["snapshots"][0], "Raw initial snapshot/actor IDs differ")
    return {"integrity": "PASS", "control": left, "candidate": right,
            "limits": "Single matched-phase diagnostic pair, not causal proof, pacing gate or manual validation. "
                      "Recovery state is an observation, not a failed-search or path-accessibility verdict."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("control", type=Path)
    parser.add_argument("candidate", type=Path)
    args = parser.parse_args()
    try:
        result = compare(*(json.loads(p.read_text(encoding="utf-8")) for p in (args.control, args.candidate)))
    except (KeyError, TypeError, ValueError) as exc:
        parser.exit(1, f"FAIL: {exc}\n")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
