"""E084: six sequential, visible Forward+ profiles; never promotes gameplay defaults."""
import argparse
import os
from pathlib import Path
import subprocess

from run_first_collection import ROOT, digest, read, save, sources


def frozen_sources():
    return {**sources(), **{path: digest(ROOT / path) for path in (
        "tools/profile_runtime_performance.gd", "tools/experiments/run_clock_performance.py")}}


def user_hashes():
    directory = Path(os.environ["APPDATA"]) / "Godot/app_userdata/BattleRoyalePrototype"
    return {path.name: digest(path) for path in sorted(directory.iterdir())
            if path.is_file() and path.suffix in (".json", ".cfg", ".bak")}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--seed", type=int, default=41000)
    args = parser.parse_args()
    output = args.out_dir.resolve()
    if output.exists():
        parser.error("Output already exists; choose a new directory.")
    engine = ROOT / "Godot_v4.6.2-stable_win64_console.exe"
    frozen, protected = frozen_sources(), user_hashes()
    if "sim_result_latest.json" not in protected:
        parser.error("Expected protected manual result is missing.")
    output.mkdir(parents=True, exist_ok=False)
    save(output / "inputs.json", {"source_sha256": frozen, "user_sha256": protected,
         "engine_sha256": digest(engine), "seed": args.seed,
         "commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
         "order": ["control_1", "candidate_1", "candidate_2", "control_2", "control_3", "candidate_3"]})
    initial = None
    environment = None
    summary = {}
    for name in read(output / "inputs.json")["order"]:
        if frozen_sources() != frozen or user_hashes() != protected:
            raise RuntimeError("Source/user data changed before profile.")
        candidate = name.startswith("candidate")
        case = output / name
        case.mkdir()
        result = case / "profile.json"
        command = [str(engine), "--path", str(ROOT), "--rendering-method", "forward_plus",
                   "--rendering-driver", "vulkan", "--log-file", str(case / "runtime.log"),
                   "--script", "res://tools/profile_runtime_performance.gd", "--",
                   "map_spec_path=res://data/mapSpec_night_forest_expanded_candidate.json",
                   "scale_preset=night_br_m1_60", f"simulation_seed={args.seed}",
                   "perf_warmup_seconds=5", "perf_sample_seconds=20",
                   f"perf_physics_clock_candidate={str(candidate).lower()}", f"perf_output={result.as_posix()}"]
        save(case / "command.json", command)
        print(f"START {name}", flush=True)
        with (case / "stdout.log").open("x", encoding="utf-8") as stream:
            try:
                completed = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT,
                                           timeout=120, creationflags=subprocess.CREATE_NO_WINDOW)
                save(case / "exit.json", {"returncode": completed.returncode})
                completed.check_returncode()
            except subprocess.TimeoutExpired:
                save(case / "exit.json", {"timeout_seconds": 120})
                raise
            finally:
                save(case / "integrity.json", {"source_unchanged": frozen_sources() == frozen,
                                               "user_unchanged": user_hashes() == protected})
        if frozen_sources() != frozen or user_hashes() != protected:
            raise RuntimeError("Source/user data changed during profile.")
        log = (case / "stdout.log").read_text(encoding="utf-8")
        if "SCRIPT ERROR:" in log or "ERROR:" in log:
            raise RuntimeError(f"{name}: runtime error; inspect preserved log.")
        data = read(result)
        if (data["physics_clock_candidate"] != candidate or data["clock_physics_processing"] != candidate
                or data["clock_physics_priority"] != (-100 if candidate else 0)
                or data["seed"] != args.seed or data["time_scale"] != 1 or data["match_ended"]
                or data["map_spec_path"] != "res://data/mapSpec_night_forest_expanded_candidate.json"
                or data["scale_preset"] != "night_br_m1_60"
                or data["rendering_method"] != "forward_plus" or data["display_server"] == "headless"
                or data["viewport_size"] != [1280, 720] or data["window_mode"] != 0
                or data["hide_minimap"] or data["warmup_seconds"] != 5 or data["sample_seconds"] != 20
                or data["sample_count"] < 100 or data["render"]["draw_calls"]["avg"] <= 0
                or data["initial"]["bots"] != 60 or len(data["initial"]["actors"]) != 61
                or data["match_time_end"] <= data["match_time_start"]):
            raise RuntimeError(f"{name}: profile conditions invalid.")
        if initial is None:
            initial = data["initial"]
        if data["initial"] != initial:
            raise RuntimeError(f"{name}: initial snapshot/IDs differ.")
        current_environment = {key: data[key] for key in (
            "video_adapter", "vsync_mode", "rendering_method", "display_server")}
        if environment is None:
            environment = current_environment
        if current_environment != environment:
            raise RuntimeError(f"{name}: renderer/GPU/vsync changed.")
        timing = data["timing"]["frame_interval"]
        summary[name] = {"p95_ms": timing["p95_ms"], "p99_ms": timing["p99_ms"],
                         "max_ms": timing["max_ms"], "over_33_3ms_ratio": timing["over_33_3ms_ratio"],
                         "p95_within_20ms": timing["p95_ms"] <= 20, "initial_exact": True}
        print(f"DONE {name}: {summary[name]}", flush=True)
    save(output / "summary.json", summary)
    print("COMPLETE: six profiles preserved; p95 failures are retained, not rerolled. No promotion.")
    return 0 if all(case["p95_within_20ms"] for case in summary.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
