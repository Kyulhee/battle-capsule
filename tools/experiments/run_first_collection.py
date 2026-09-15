"""E080 수집 관측과 E081/E088 선택적 전체 매치 pair. 후보를 혼합하거나 승격하지 않는다."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def save(path, data):
    with path.open("x", encoding="utf-8") as stream:
        json.dump(data, stream, indent=2, ensure_ascii=False)


def sources():
    paths = ["src/Main.gd", "src/entities/pickup/Pickup.gd", "src/entities/Entity.gd",
             "src/entities/bot/Bot.gd", "src/core/Telemetry.gd", "tools/probe_loot_flow_runtime.gd",
             "tools/experiments/run_first_collection.py", "project.godot",
             "data/mapSpec_night_forest_expanded_candidate.json"]
    return {path: digest(ROOT / path) for path in paths}


def protected_user_hashes():
    directory = Path(os.environ["APPDATA"]) / "Godot/app_userdata/BattleRoyalePrototype"
    return {path.name: digest(path) for path in sorted(directory.iterdir())
            if path.is_file() and path.suffix in (".json", ".cfg", ".bak")}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", type=Path, required=True, help="New directory; existing directories are refused.")
    parser.add_argument("--reference-flow", type=Path, required=True, help="Preserved flow with exact initial actor IDs.")
    parser.add_argument("--godot", default=str(ROOT / "Godot_v4.6.2-stable_win64_console.exe"))
    parser.add_argument("--seed", type=int, default=41001)
    parser.add_argument("--start-delay-ms", type=int, choices=[0, 100], default=0,
                        help="Explicit startup delay injection; separate from natural scheduling observations.")
    candidates = parser.add_mutually_exclusive_group()
    candidates.add_argument("--clock-candidate", action="store_true", help="Compare E081 physics clock instead of E078 patrol.")
    candidates.add_argument("--cover-pressure-candidate", action="store_true", help="E088 process-clock pair only; requires --full-match.")
    parser.add_argument("--full-match", action="store_true", help="One OFF/ON E081 or E088 integration pair; no promotion claim.")
    parser.add_argument("--manual-result", type=Path, default=Path(os.environ.get("APPDATA", "")) / "Godot/app_userdata/BattleRoyalePrototype/sim_result_latest.json")
    args = parser.parse_args()
    if args.full_match and (not (args.clock_candidate or args.cover_pressure_candidate) or args.start_delay_ms):
        parser.error("--full-match requires a clock/cover-pressure candidate and excludes delay injection.")
    if args.cover_pressure_candidate and not args.full_match:
        parser.error("--cover-pressure-candidate requires --full-match.")
    reference = read(args.reference_flow)
    if reference["seed"] != args.seed:
        parser.error("Reference seed differs.")
    initial = reference["snapshots"][0]
    manual_hash = digest(args.manual_result)
    frozen = sources()
    protected = protected_user_hashes()
    def integrity():
        return {"manual_unchanged": digest(args.manual_result) == manual_hash,
                "source_unchanged": sources() == frozen, "user_unchanged": protected_user_hashes() == protected}
    output = args.out_dir.resolve()
    output.mkdir(parents=True, exist_ok=False)
    save(output / "inputs.json", dict(reference=str(args.reference_flow.resolve()), reference_sha256=digest(args.reference_flow),
         source_sha256=frozen, manual_sha256=manual_hash, seed=args.seed, injected_start_delay_ms=args.start_delay_ms,
         candidate="cover_pressure" if args.cover_pressure_candidate else "physics_clock" if args.clock_candidate else "recovery_patrol",
         user_sha256=protected,
         full_match=args.full_match,
         commit=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
         engine_sha256=digest(Path(args.godot))))
    summary = {}
    candidate_flag = "physics_clock_candidate=true" if args.clock_candidate else "recovery_patrol_candidate=true"
    if args.cover_pressure_candidate:
        candidate_flag = "survival_cover_pressure_candidate=true"
    cases = [("off_initial", ["initial_only=true"]),
                        ("control_1x", ["first_collection_scale=1"]),
                        ("control_5x", ["first_collection_scale=5"]),
                        ("candidate_1x", ["first_collection_scale=1", candidate_flag]),
             ("candidate_5x", ["first_collection_scale=5", candidate_flag])]
    if args.full_match:
        cases = [("control_match", []), ("candidate_match", [candidate_flag])]
        if args.cover_pressure_candidate:
            cases = [("off_initial", ["initial_only=true"]),
                     ("on_initial", ["initial_only=true", candidate_flag]), *cases]
    timeout = 600 if args.full_match else 90
    for name, flags in cases:
        if not all(integrity().values()):
            raise RuntimeError("Source/manual data changed during experiment.")
        case = output / name
        case.mkdir()
        full_case = args.full_match and name.endswith("_match")
        flow, result = case / "flow.json", case / ("run_1.json" if args.full_match else "unused-result.json")
        command = [args.godot, "--headless", "--path", str(ROOT), "--log-file", str(case / "runtime.log"),
                   "--script", "res://tools/probe_loot_flow_runtime.gd", "--",
                   "map_spec_path=res://data/mapSpec_night_forest_expanded_candidate.json",
                   "scale_preset=night_br_m1_60", f"simulation_seed={args.seed}",
                   f"flow_output={flow.as_posix()}", f"result_output={result.as_posix()}", *flags]
        if name != "off_initial" and not args.full_match:
            command.append(f"first_collection_start_delay_ms={args.start_delay_ms}")
        save(case / "command.json", command)
        print(f"START {name}", flush=True)
        with (case / "stdout.log").open("x", encoding="utf-8") as stream:
            try:
                completed = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=timeout,
                                           creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
                save(case / "exit.json", {"returncode": completed.returncode})
                completed.check_returncode()
            except subprocess.TimeoutExpired:
                save(case / "exit.json", {"timeout_seconds": timeout})
                raise
            finally:
                save(case / "integrity.json", integrity())
        if not all(integrity().values()):
            raise RuntimeError("Source/manual data changed during experiment.")
        data = read(flow)
        if data["physics_clock_candidate"] != (args.clock_candidate and name.startswith("candidate_")):
            raise RuntimeError("Physics clock candidate metadata differs.")
        if data.get("survival_cover_pressure_candidate", False) != (args.cover_pressure_candidate and name in ("on_initial", "candidate_match")):
            raise RuntimeError("Cover pressure candidate metadata differs.")
        if not data["complete"] or result.exists() != full_case or data["snapshots"][0] != initial:
            raise RuntimeError(f"{name}: incomplete, full-match output, or initial snapshot/IDs changed.")
        if full_case:
            log = (case / "stdout.log").read_text(encoding="utf-8")
            if any(token in log for token in ("ERROR:", "WARNING:")):
                raise RuntimeError("Full match runtime error/warning; inspect preserved log.")
            metrics = read(result)
            duration = metrics["core"]["duration"]
            if data["checkpoints_not_reached"] or abs(data["end_time"] - duration) > 0.25 or duration <= 0:
                raise RuntimeError("Incomplete checkpoints or flow/telemetry end clock mismatch.")
            summary[name] = {"initial_exact": True, "duration": duration,
                             "first_upgrade": metrics["economy"]["first_upgrade_time"],
                             "ai_max_usec": metrics["ai"]["update_max_usec"], "promotion_eligible": False}
        elif name in ("off_initial", "on_initial"):
            if "first_collection" in data:
                raise RuntimeError("OFF observation unexpectedly enabled.")
            summary[name] = {"initial_exact": True}
        else:
            trace = data["first_collection"]
            if trace["injected_start_delay_ms"] != args.start_delay_ms:
                raise RuntimeError("Injected delay metadata differs.")
            if not trace["events"] or len(trace["events"]) > 8 or len(trace["process_boundaries"]) > 16:
                raise RuntimeError(f"{name}: no successful collection or sample bound exceeded.")
            first = trace["events"][0]
            if args.clock_candidate and name.startswith("candidate_") and first["canonical_time"] <= 0:
                raise RuntimeError("Physics clock candidate collected before the clock advanced.")
            if first["weapon"] != first["equipped_weapon"] or first["collect_distance"] > 2.5001:
                raise RuntimeError(f"{name}: equip/collect contract differs.")
            if first["canonical_time"] != first["telemetry_first_upgrade"]:
                raise RuntimeError(f"{name}: first success does not explain the first telemetry record.")
            summary[name] = {"initial_exact": True, "time_scale": data["time_scale"], "first": first,
                             "injected_start_delay_ms": args.start_delay_ms,
                             "start": trace["start"], "end": trace["end"], "event_count": len(trace["events"]),
                             "dropped_events": trace["dropped_events"]}
        save(case / "case_summary.json", summary[name])
        print(f"DONE {name}: {json.dumps(summary[name])}", flush=True)
    save(output / "summary.json", summary)
    print("COMPLETE: initial IDs/manual preserved. Integration pair only, not promotion evidence." if args.full_match
          else "COMPLETE: initial IDs/manual preserved. Short diagnostic windows, not promotion evidence.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
