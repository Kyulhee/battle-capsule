"""Read-only E086 effect report; fixed-time survival and phase-matched stock are separate."""
import argparse
import json
from pathlib import Path
from statistics import mean, median
import sys

from run_recovery_patrol_repeat import ROOT, SEEDS, digest, read, require, validate_flow

sys.path.insert(0, str(ROOT / "tools"))
from survival_curve import alive_at, alive_threshold_summary, checkpoint_summaries, normalized_alive_timeline


def snapshot_summary(snap):
    return {"observed_time": snap["observed_time"], "alive": snap["alive"],
            "empty": snap["needs"]["no_ammo"], "empty_ratio": snap["needs"]["no_ammo"] / snap["alive"],
            "phase": [snap["zone_stage"], snap["zone_shrinking"]], "stock": snap["totals"]}


def ammo_summary(snapshots):
    empty = sum(snap["needs"]["no_ammo"] for snap in snapshots)
    alive = sum(snap["alive"] for snap in snapshots)
    return {"runs": len(snapshots), "empty": empty, "alive": alive,
            "pooled_ratio": empty / alive if alive else None,
            "median_run_ratio": median(snap["needs"]["no_ammo"] / snap["alive"] for snap in snapshots) if snapshots else None}


def analyze(directory):
    inputs = read(directory / "inputs.json")
    require(len(read(directory / "case_summary.json")) == 10, "Cohort incomplete")
    require(all(digest(Path(p)) == h for p, h in inputs["baseline_sha256"].items()), "Reused baseline changed")
    baseline = Path(inputs["baseline"])
    runs = {"control": [], "candidate": []}
    snapshots = {"control": [], "candidate": []}
    matched = {"control": [], "candidate": []}
    pairs, hashes, delays = [], {}, []
    for index, seed in enumerate(SEEDS, 1):
        pair = {"seed": seed}
        initial = None
        for group in runs:
            case = baseline / f"seed_{seed}" / "control_match" if group == "control" else directory / f"candidate_{seed}"
            result_path = case / "run_1.json" if group == "control" else directory / "candidate" / f"run_{index}.json"
            require(read(case / "exit.json") == {"returncode": 0}
                    and all(read(case / "integrity.json").values()), f"{case}: failed run")
            flow, result = read(case / "flow.json"), read(result_path)
            validate_flow(flow, seed, group == "candidate")
            if initial is None:
                initial = flow["snapshots"][0]
            require(flow["snapshots"][0] == initial, f"{seed}: raw initial mismatch")
            raw = result["pacing"]["alive_timeline"]
            require(raw[0]["alive"] == 60 and raw[-1]["alive"] == 1
                    and all(a["time"] <= b["time"] and a["alive"] >= b["alive"] for a, b in zip(raw, raw[1:])),
                    f"{seed}: invalid alive timeline")
            timeline = normalized_alive_timeline(result)
            require(abs(result["core"]["duration"] - flow["end_time"]) <= 0.25, "End clock mismatch")
            for snap in flow["snapshots"]:
                require(alive_at(timeline, snap["observed_time"]) == snap["alive"], "Snapshot/timeline population differs")
                delays.append(snap["observed_time"] - snap["requested_time"])
            snapshots[group].append(flow["snapshots"])
            runs[group].append(result)
            pair[group] = {"duration": result["core"]["duration"], "first_upgrade": result["economy"]["first_upgrade_time"],
                           "at120": snapshot_summary(flow["snapshots"][1]), "at260": snapshot_summary(flow["snapshots"][2]),
                           "t10": alive_threshold_summary([result], 10)["median_seconds"]}
            for path in (case / "flow.json", result_path):
                hashes[str(path)] = digest(path)
        pair["same_phase260"] = pair["control"]["at260"]["phase"] == pair["candidate"]["at260"]["phase"]
        pair["same_phase120"] = pair["control"]["at120"]["phase"] == pair["candidate"]["at120"]["phase"]
        pair["empty_ratio120_delta"] = pair["candidate"]["at120"]["empty_ratio"] - pair["control"]["at120"]["empty_ratio"]
        if pair["same_phase260"]:
            for group in runs:
                matched[group].append(snapshots[group][-1][2])
        pairs.append(pair)
    groups = {}
    for group, values in runs.items():
        durations = [run["core"]["duration"] for run in values]
        first = [run["economy"]["first_upgrade_time"] for run in values]
        groups[group] = {"mean_duration": mean(durations), "duration_range": [min(durations), max(durations)],
                         "mean_first_upgrade": mean(x for x in first if x >= 0), "missing_first_upgrade": sum(x < 0 for x in first),
                         "survival": checkpoint_summaries(values), "t50": alive_threshold_summary(values, 50),
                         "t10": alive_threshold_summary(values, 10),
                         "ammo120": ammo_summary([snaps[1] for snaps in snapshots[group]]),
                         "ammo260_same_phase_pairs": ammo_summary(matched[group])}
    return {"groups": groups, "pairs": pairs, "max_snapshot_delay": max(delays),
            "input_sha256": hashes, "limitations": [
                "Five reused process controls versus five later candidates; scheduling is not deterministic.",
                "Empty ammo is loaded <= 0 AND reserve <= 0 among survivors, not shortage duration or rearm success.",
                "Fixed-time event survival differs from delayed flow snapshots; never mix their denominators.",
                "260 stock comparisons use only within-seed matching stage/shrinking, not exact post-wave age.",
                "Patrol survivor selections are not successful supply collections. No automatic promotion."]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-dir", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(analyze(args.input_dir.resolve()), indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
