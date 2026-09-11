"""Validate E-072 phase capture against canonical telemetry; no gate waivers."""
import argparse
import json
import math
from pathlib import Path

PHASES = {"bookkeeping", "overrides_stuck", "perception_labels", "handler",
          "entity_movement", "visuals", "reporting"}
STATES = {"IDLE", "CHASE", "ATTACK", "ZONE_ESCAPE", "RECOVER", "DISENGAGE"}


def analyze(flow: dict, result: dict) -> dict:
    def require(condition, message):
        if not condition:
            raise ValueError(message)

    require(flow.get("complete") is True and flow.get("ai_phase_trace_enabled") is True,
            "Incomplete or uninstrumented flow")
    require(not flow.get("initial_only") and not flow.get("progress_window_only"),
            "A full match is required")
    trace = flow["ai_phase_trace"]
    ai = result["ai"]
    require(trace.get("valid") is True, "Runtime timing identity failed")
    require(trace["telemetry_samples"] == ai["update_samples"] > 0,
            "Sample coverage differs from telemetry")
    require(trace["telemetry_max_usec"] == ai["update_max_usec"], "Telemetry max differs")
    events = trace["events"]
    slow = trace["slow_samples"]
    require(isinstance(slow, int) and 0 <= slow <= ai["update_samples"], "Invalid slow count")
    require(len(events) == min(slow, 32) and trace["omitted"] == slow - len(events),
            "Bounded capture count differs")
    require(trace["max_usec"] == (ai["update_max_usec"] if slow else 0),
            "Maximum sample was not retained")
    require(slow > 0 or ai["update_max_usec"] < 5000, "Slow samples missing")
    duration = result["core"]["duration"]
    require(math.isfinite(duration) and abs(flow["end_time"] - duration) < 0.25,
            "Match duration differs")
    previous = math.inf
    seen = set()
    visible_over = 0
    for event in events:
        elapsed = event["elapsed_usec"]
        require(isinstance(elapsed, int) and 5000 <= elapsed <= previous, "Invalid event ordering")
        previous = elapsed
        phases = event["phases_usec"]
        require(set(phases) == PHASES and all(isinstance(v, int) and v >= 0 for v in phases.values()),
                "Invalid phases")
        require(sum(phases.values()) == elapsed, "Phase sum differs from AI total")
        require(all(event[key] in STATES for key in ("entry_state", "handler_state", "exit_state")),
                "Invalid state context")
        require(event["loot_candidate"] is flow["loot_progress_candidate"], "Candidate context differs")
        require(math.isfinite(event["match_time"]) and 0 <= event["match_time"] <= duration + 0.25,
                "Invalid event clock")
        key = (event["actor"], event["physics_frame"])
        require(key not in seen, "Duplicate event")
        seen.add(key)
        visible_over += elapsed > 50000
    if events:
        require(events[0]["elapsed_usec"] == trace["max_usec"], "Largest event missing")
    require(min(trace["over_gate_samples"], 32) == visible_over
            and visible_over <= trace["over_gate_samples"] <= slow, "Gate exceedance count differs")
    return {"seed": flow["seed"], "loot_progress_candidate": flow["loot_progress_candidate"],
            "duration": duration, "samples": ai["update_samples"], "slow_samples": slow,
            "over_50ms": trace["over_gate_samples"], "max_usec": ai["update_max_usec"],
            "max_gate_pass": ai["update_max_usec"] <= 50000,
            "worst_event": events[0] if events else None,
            "scope": "Instrumented diagnostic, not uninstrumented pacing promotion; CPU vs OS stall unresolved."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("flow", type=Path)
    parser.add_argument("result", type=Path)
    args = parser.parse_args()
    try:
        summary = analyze(json.loads(args.flow.read_text(encoding="utf-8-sig")),
                          json.loads(args.result.read_text(encoding="utf-8-sig")))
    except (KeyError, ValueError, TypeError, OSError) as error:
        parser.exit(1, f"Invalid AI phase capture: {error}\n")
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
