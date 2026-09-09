"""E-070 읽기 전용 진행 표본 분석. 상태 전환 원인/실제 경로 길이는 추론하지 않는다."""
import argparse
import json
import math
from collections import Counter, defaultdict
from pathlib import Path


def empty(actor):
    return actor["loaded"] <= 0 and actor["reserve"] <= 0


def distance(a, b):
    return math.dist(a, b)


def analyze(report):
    if report.get("schema_version") != 3 or not report.get("complete"):
        raise ValueError("A completed schema v3 report is required.")
    if report.get("initial_only") or not report.get("progress_enabled"):
        raise ValueError("A progress-enabled match or 260-second window is required.")
    frames = report.get("progress", [])
    expected = list(range(261))
    if [f["requested_time"] for f in frames] != expected:
        raise ValueError("Expected every 1-second sample from 0 through 260.")
    if report.get("checkpoints_not_reached") != []:
        raise ValueError("Missing stock checkpoints.")
    if [s["requested_time"] for s in report["snapshots"]] != [0, 120, 260]:
        raise ValueError("Unexpected stock checkpoints.")
    for snapshot in report["snapshots"]:
        observed = snapshot["observed_time"]
        if not math.isfinite(observed) or not 0 <= observed - snapshot["requested_time"] <= 0.25:
            raise ValueError("Stock checkpoint observation lag exceeds 0.25 seconds.")
        if snapshot["alive"] != len(snapshot["actors"]):
            raise ValueError("Stock checkpoint population mismatch.")
    by_state, by_recovery = Counter(), Counter()
    recovered, disappeared, adjacent_empty_seconds = 0, 0, 0.0
    idle_strategy_samples, idle_strategy_progress = 0, 0.0
    previous, previous_time = {}, None
    segments, active = [], {}
    all_samples = 0
    for frame in frames:
        t = frame["observed_time"]
        if not math.isfinite(t) or not 0 <= t - frame["requested_time"] <= 0.25:
            raise ValueError("Sample observation lag exceeds 0.25 seconds.")
        if previous_time is not None and not 0 < t - previous_time <= 1.25:
            raise ValueError("Invalid sample time order or gap.")
        current = {a["id"]: a for a in frame["actors"]}
        if len(current) != len(frame["actors"]) or len(current) != frame["alive"]:
            raise ValueError("Duplicate actors or population mismatch.")
        all_samples += len(current)
        next_active = {}
        for actor_id, actor in current.items():
            no_ammo = empty(actor)
            if no_ammo:
                by_state[actor["state"]] += 1
                if actor["state"] == "RECOVER":
                    by_recovery[actor["recovery_substate"]] += 1
            prior = previous.get(actor_id)
            if prior and empty(prior):
                if no_ammo:
                    adjacent_empty_seconds += t - previous_time
                else:
                    recovered += 1
            # 동일 목표/상태 episode의 인접 표본만 비교한다. 도착/실패 원인은 기록하지 않는다.
            if (prior and no_ammo and empty(prior) and actor["state"] == prior["state"] == "IDLE"
                    and actor["episode"] == prior["episode"]
                    and actor["strategy_target"] is not None
                    and actor["strategy_target"] == prior["strategy_target"]):
                idle_strategy_samples += 1
                idle_strategy_progress += (distance(prior["position"], actor["strategy_target"])
                                           - distance(actor["position"], actor["strategy_target"]))
            if actor["state"] != "CHASE" or not actor["targeting_loot"] or actor["target_id"] is None:
                continue
            key = (actor_id, actor["episode"], actor["target_id"], actor["loot_source"])
            segment = active.get(key)
            target_distance = distance(actor["position"], actor["target_position"])
            if segment is None:
                segment = {"actor": actor_id, "episode": actor["episode"],
                           "target": actor["target_id"], "source": actor["loot_source"],
                           "kind": actor["loot_kind"], "first_time": t,
                           "first_state_timer": actor["state_timer"],
                           "first_distance": target_distance, "sample_displacement": 0.0,
                           "samples": 0, "empty_samples": 0}
                segments.append(segment)
            else:
                segment["sample_displacement"] += distance(prior["position"], actor["position"])
            segment.update(last_time=t, last_state_timer=actor["state_timer"], last_distance=target_distance)
            segment["samples"] += 1
            segment["empty_samples"] += int(no_ammo)
            next_active[key] = segment
        disappeared += sum(empty(a) for i, a in previous.items() if i not in current)
        previous, previous_time, active = current, t, next_active
    repeated = defaultdict(set)
    for s in segments:
        if s["empty_samples"]:
            repeated[(s["actor"], s["target"])].add(s["episode"])
    return {
        "seed": report["seed"], "time_scale": report.get("time_scale"),
        "progress_window_only": report.get("progress_window_only", False),
        "sample_count": len(frames), "actor_samples": all_samples,
        "max_observation_lag": max(f["observed_time"] - f["requested_time"] for f in frames),
        "empty_actor_samples": sum(by_state.values()), "empty_samples_by_state": dict(by_state),
        "empty_recovery_samples_by_substate": dict(by_recovery),
        "adjacent_empty_observed_seconds": adjacent_empty_seconds,
        "observed_empty_to_armed": recovered, "empty_then_absent": disappeared,
        "empty_idle_same_strategy_pairs": idle_strategy_samples,
        "empty_idle_strategy_net_approach": idle_strategy_progress,
        "empty_repeated_target_episode_counts": sorted([len(v) for v in repeated.values() if len(v) > 1], reverse=True),
        "segments": segments,
        "limits": "1-second sampled observations, not exact state durations, cause of exit, visibility or path lengths; absent does not identify cause of death; a real-time window is not a pacing run",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("flow", type=Path)
    args = parser.parse_args()
    result = analyze(json.loads(args.flow.read_text(encoding="utf-8")))
    segments = result.pop("segments")
    result["empty_long_chase_examples"] = sorted(
        [s for s in segments if s["empty_samples"] and s["samples"] >= 4],
        key=lambda s: s["last_distance"], reverse=True)[:10]
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
