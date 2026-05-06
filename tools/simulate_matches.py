import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


GODOT_BIN = r".\Godot_v4.6.2-stable_win64_console.exe"
PROJECT_PATH = "."
NUM_MATCHES = int(sys.argv[1]) if len(sys.argv) > 1 else 20
TIMEOUT_PER_MATCH = 300

APPDATA = Path(os.environ.get("APPDATA", ""))
SIM_RESULT_PATH = APPDATA / "Godot" / "app_userdata" / "BattleRoyalePrototype" / "sim_result_latest.json"
OUT_DIR = Path("tools") / "sim_runs_current"


def run_match(match_id: int) -> dict:
    print(f"--- Running Match {match_id + 1}/{NUM_MATCHES} ---", flush=True)
    cmd = [GODOT_BIN, "--path", PROJECT_PATH, "--headless", "--", "autostart=true"]
    proc = subprocess.run(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=TIMEOUT_PER_MATCH,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"Godot exited with code {proc.returncode}\n{proc.stdout[-4000:]}")
    if not SIM_RESULT_PATH.exists():
        raise FileNotFoundError(f"Telemetry result not found: {SIM_RESULT_PATH}")

    with SIM_RESULT_PATH.open("r", encoding="utf-8") as f:
        data = json.load(f)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(SIM_RESULT_PATH, OUT_DIR / f"run_{match_id + 1}.json")

    core = data.get("core", {})
    tactics = data.get("tactics", {})
    archetype = data.get("archetype", {})
    print(
        "  duration={:.1f}s stage={} recover={} disengage={} plans(c/r/k)={}/{}/{} archetypes={}".format(
            core.get("duration", 0.0),
            core.get("zone_stage_reached", 0),
            tactics.get("recover_bouts", 0),
            tactics.get("disengage_triggered", 0),
            tactics.get("cover_peek", 0),
            tactics.get("combat_reposition", 0),
            tactics.get("combat_kite", 0),
            archetype.get("archetype_distribution", {}),
        ),
        flush=True,
    )
    return data


if __name__ == "__main__":
    results = []
    for i in range(NUM_MATCHES):
        results.append(run_match(i))

    with (OUT_DIR / "summary.json").open("w", encoding="utf-8") as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
    print(f"\nFinalized {len(results)} simulations in {OUT_DIR}.", flush=True)
