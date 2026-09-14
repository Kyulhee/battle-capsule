"""E086: reuse verified E083 process controls and run five E078 patrol candidates."""
import argparse
from pathlib import Path
import subprocess

from run_first_collection import ROOT, digest, read, save, sources
from run_clock_performance import user_hashes

SEEDS = range(41000, 41005)
MAP = "res://data/mapSpec_night_forest_expanded_candidate.json"
OFF = ("physics_clock_candidate", "clock_physics_processing", "candidate",
       "loot_progress_candidate", "progress_enabled", "progress_window_only",
       "ai_phase_trace_enabled", "ai_phase_audit_created", "ai_phase_audit_loaded",
       "loot_phase_enabled", "phase_window_only", "loot_search_enabled",
       "search_window_only", "search_audit_created", "search_audit_loaded")


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def validate_flow(data, seed, candidate, initial_only=False):
    require(data["complete"] and data["seed"] == seed and data["map"] == MAP
            and data["preset"] == "night_br_m1_60" and data["time_scale"] == 5
            and data["recovery_patrol_candidate"] is candidate
            and data["initial_only"] is initial_only and data["clock_physics_priority"] == 0
            and all(data[key] is False for key in OFF) and "first_collection" not in data,
            f"{seed}: unexpected mode or incomplete flow")
    expected = [0] if initial_only else [0, 120, 260]
    require([snap["requested_time"] for snap in data["snapshots"]] == expected,
            f"{seed}: checkpoint set differs")
    for snap in data["snapshots"]:
        actors = snap["actors"]
        require(0 <= snap["observed_time"] - snap["requested_time"] <= 0.25
                and len(actors) == snap["alive"] == len({actor["id"] for actor in actors})
                and snap["needs"]["no_ammo"] == sum(
                    actor["loaded"] <= 0 and actor["reserve"] <= 0 for actor in actors),
                f"{seed}: checkpoint timing/population/ammo inconsistent")
    if not initial_only:
        require(not data["checkpoints_not_reached"], f"{seed}: missing checkpoints")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--baseline", type=Path, default=ROOT / "builds/verification/E083_clock_repeat")
    parser.add_argument("--check-only", action="store_true", help="Validate reuse inputs without writing or running Godot.")
    args = parser.parse_args()
    output, baseline = args.out_dir.resolve(), args.baseline.resolve()
    if output.exists() or not output.is_relative_to(ROOT / "builds/verification"):
        parser.error("Choose a new directory below builds/verification.")
    engine = ROOT / "Godot_v4.6.2-stable_win64_console.exe"
    frozen, protected, engine_hash = sources(), user_hashes(), digest(engine)
    require("sim_result_latest.json" in protected, "Protected manual result missing")
    inputs, initials, baseline_hashes = {}, {}, {}
    for index, seed in enumerate(SEEDS, 1):
        seed_dir = baseline / f"seed_{seed}"
        case = seed_dir / "control_match"
        old = read(seed_dir / "inputs.json")
        require(old["source_sha256"] == frozen and old["engine_sha256"] == engine_hash
                and old["seed"] == seed and old["full_match"]
                and old["injected_start_delay_ms"] == 0, f"{seed}: baseline sources/inputs differ")
        require(old["manual_sha256"] == protected["sim_result_latest.json"], "Manual baseline changed")
        command = read(case / "command.json")
        require(command[:5] == [str(engine), "--headless", "--path", str(ROOT), "--log-file"]
                and command[6:9] == ["--script", "res://tools/probe_loot_flow_runtime.gd", "--"]
                and command[9:] == [f"map_spec_path={MAP}", "scale_preset=night_br_m1_60",
                     f"simulation_seed={seed}", f"flow_output={(case / 'flow.json').as_posix()}",
                     f"result_output={(case / 'run_1.json').as_posix()}"], f"{seed}: control command differs")
        require(read(case / "exit.json") == {"returncode": 0}
                and read(case / "integrity.json") == {"source_unchanged": True, "manual_unchanged": True},
                f"{seed}: control failed integrity")
        flow, result = read(case / "flow.json"), read(case / "run_1.json")
        validate_flow(flow, seed, False)
        reference = baseline / "reference" / f"{seed}.json"
        require(digest(reference) == old["reference_sha256"]
                and flow["snapshots"][0] == read(reference)["snapshots"][0]
                and digest(case / "run_1.json") == digest(baseline / "control" / f"run_{index}.json")
                and abs(flow["end_time"] - result["core"]["duration"]) <= 0.25,
                f"{seed}: baseline reference/result mismatch")
        require(not any(token in (case / "stdout.log").read_text(encoding="utf-8")
                        for token in ("ERROR:", "WARNING:")), f"{seed}: baseline runtime issue")
        initials[seed] = flow["snapshots"][0]
        inputs[seed] = old
        for path in [seed_dir / "inputs.json", reference, baseline / "control" / f"run_{index}.json", *case.iterdir()]:
            if path.is_file():
                baseline_hashes[str(path)] = digest(path)
    if args.check_only:
        print("PASS: five E083 process controls eligible pending fresh initial-ID checks; no files written.")
        return 0
    output.mkdir(parents=True, exist_ok=False)
    runner_hashes = {str(path): digest(path) for path in (
        Path(__file__).resolve(), ROOT / "tools/experiments/run_clock_performance.py")}
    save(output / "inputs.json", {"baseline": str(baseline), "baseline_inputs": inputs,
         "baseline_sha256": baseline_hashes, "source_sha256": frozen, "runner_sha256": runner_hashes,
         "user_sha256": protected, "engine_sha256": engine_hash, "seeds": list(SEEDS),
         "commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
         "candidate": "recovery_patrol", "physics_clock_candidate": False, "extra_trace": False})
    (output / "candidate").mkdir()

    def integrity():
        return {"source_unchanged": sources() == frozen,
                "user_unchanged": user_hashes() == protected,
                "engine_unchanged": digest(engine) == engine_hash,
                "baseline_unchanged": all(digest(Path(p)) == h for p, h in baseline_hashes.items()),
                "runner_unchanged": all(digest(Path(p)) == h for p, h in runner_hashes.items())}

    summary = {}
    # Refuse reuse before any full match if even one fresh candidate initial ID differs.
    for initial_only in (True, False):
        for index, seed in enumerate(SEEDS, 1):
            name = f"initial_{seed}" if initial_only else f"candidate_{seed}"
            require(all(integrity().values()), f"{name}: inputs changed before run")
            case = output / name
            case.mkdir()
            flow_path = case / "flow.json"
            result_path = case / "unused-result.json" if initial_only else output / "candidate" / f"run_{index}.json"
            command = [str(engine), "--headless", "--path", str(ROOT), "--log-file", str(case / "runtime.log"),
                       "--script", "res://tools/probe_loot_flow_runtime.gd", "--", f"map_spec_path={MAP}",
                       "scale_preset=night_br_m1_60", f"simulation_seed={seed}",
                       f"flow_output={flow_path.as_posix()}", f"result_output={result_path.as_posix()}",
                       "recovery_patrol_candidate=true"]
            if initial_only:
                command.append("initial_only=true")
            save(case / "command.json", command)
            print(f"START {name}", flush=True)
            with (case / "stdout.log").open("x", encoding="utf-8") as stream:
                try:
                    completed = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT,
                                               timeout=600, creationflags=subprocess.CREATE_NO_WINDOW)
                    save(case / "exit.json", {"returncode": completed.returncode})
                    completed.check_returncode()
                except subprocess.TimeoutExpired:
                    save(case / "exit.json", {"timeout_seconds": 600})
                    raise
                finally:
                    save(case / "integrity.json", integrity())
            require(all(read(case / "integrity.json").values()), f"{name}: input integrity changed")
            data = read(flow_path)
            validate_flow(data, seed, True, initial_only)
            require(data["snapshots"][0] == initials[seed] and result_path.exists() is not initial_only,
                    f"{name}: initial raw IDs/layout or result presence differs; do not reuse controls")
            log = (case / "stdout.log").read_text(encoding="utf-8")
            warnings = [line for line in log.splitlines() if "WARNING:" in line]
            require("ERROR:" not in log and (not warnings or initial_only and all(
                    "WARNING: ObjectDB instances leaked at exit" in line for line in warnings)),
                    f"{name}: runtime error or unexpected warning")
            entry = {"initial_exact": True, "warnings": warnings}
            if not initial_only:
                metrics = read(result_path)
                require(metrics["core"]["duration"] > 0
                        and abs(data["end_time"] - metrics["core"]["duration"]) <= 0.25,
                        f"{name}: end clock mismatch")
                entry.update(duration=metrics["core"]["duration"], first_upgrade=metrics["economy"]["first_upgrade_time"],
                             checkpoints=[{key: snap[key] for key in ("requested_time", "alive", "needs", "zone_stage", "zone_shrinking")}
                                          for snap in data["snapshots"][1:]])
            summary[name] = entry
            save(case / "case_summary.json", entry)
            print(f"DONE {name}: {entry}", flush=True)
    save(output / "case_summary.json", summary)
    print("COMPLETE: five candidates and reused controls; run existing gate/survival analysis separately. No promotion.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
