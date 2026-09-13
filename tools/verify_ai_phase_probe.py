"""Exercise the real probe startup: diagnostics must preserve initial actor IDs."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    args = parser.parse_args()
    output_root = ROOT / "builds" / "verification"
    output_root.mkdir(parents=True, exist_ok=True)
    output = Path(tempfile.mkdtemp(prefix="ai_phase_identity_", dir=output_root))
    reference = None
    for name, flags in (
        ("off", []), ("phase_on", ["trace_ai_phases=true"]),
        ("loot_on", ["loot_progress_candidate=true"]),
        ("stock_phase_on", ["trace_loot_phase=true"]),
        ("search_on", ["trace_loot_search=true"]),
        ("patrol_on", ["recovery_patrol_candidate=true"]),
    ):
        flow_path = output / f"{name}.json"
        result_path = output / f"{name}-unused.json"
        command = [args.godot, "--headless", "--path", str(ROOT), "--log-file",
                   str(output / f"{name}.log"), "--script", "res://tools/probe_loot_flow_runtime.gd",
                   "--", "map_spec_path=res://data/mapSpec_night_forest_expanded_candidate.json",
                   "scale_preset=night_br_m1_60", "simulation_seed=41000", "initial_only=true",
                   f"flow_output={flow_path.as_posix()}", f"result_output={result_path.as_posix()}", *flags]
        completed = subprocess.run(command, capture_output=True, text=True, encoding="utf-8",
                                   errors="replace", timeout=30)
        if completed.returncode:
            raise RuntimeError(f"Probe {name} failed: {completed.stdout}\n{completed.stderr}")
        flow = json.loads(flow_path.read_text(encoding="utf-8"))
        assert flow["complete"] and flow["initial_only"] and not result_path.exists()
        assert flow["ai_phase_trace_enabled"] == (name == "phase_on")
        assert flow["ai_phase_audit_created"] == flow["ai_phase_audit_loaded"] == (name == "phase_on")
        assert flow["loot_progress_candidate"] == (name == "loot_on")
        assert flow["recovery_patrol_candidate"] == (name == "patrol_on")
        if name == "patrol_on":
            assert flow["recovery_patrol_observations"][0]["survivor_selections"] == 0
        assert flow["loot_phase_enabled"] == (name == "stock_phase_on")
        if name == "stock_phase_on":
            assert flow["phase_snapshots"] == []
        assert flow["loot_search_enabled"] == (name == "search_on")
        assert flow["search_audit_created"] == flow["search_audit_loaded"] == (name == "search_on")
        if name == "search_on":
            assert flow["loot_search"]["calls"] == 0
            assert flow["loot_search"]["schema_version"] == 2 and flow["loot_search"]["sensing"] == {}
        snapshot = flow["snapshots"][0]
        assert snapshot["alive"] == len(snapshot["actors"]) == 60
        if reference is None:
            reference = snapshot
        assert snapshot == reference, f"Initial snapshot/actor IDs changed in {name}"
    for conflict in ("loot_match_candidate", "loot_progress_candidate", "trace_progress", "trace_ai_phases", "trace_loot_phase", "trace_loot_search"):
        flow_path = output / f"rejected-{conflict}.json"
        result_path = output / f"rejected-{conflict}-unused.json"
        command = [args.godot, "--headless", "--path", str(ROOT), "--script", "res://tools/probe_loot_flow_runtime.gd",
                   "--", "recovery_patrol_candidate=true", f"{conflict}=true",
                   f"flow_output={flow_path.as_posix()}", f"result_output={result_path.as_posix()}"]
        completed = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=30)
        assert completed.returncode != 0 and "Keep E-078 patrol candidate separate" in completed.stdout + completed.stderr
        assert not flow_path.exists() and not result_path.exists(), "Rejected mixture wrote experiment output"
    print(f"AI phase probe identity passed: six modes, OFF unloaded, ON deferred, raw actor IDs unchanged; six E078 mixtures rejected. Logs: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
