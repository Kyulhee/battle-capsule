"""보관된 데이터를 수정하지 않고 E079 초기 배치 근거를 재확인한다."""
import argparse
import json
import math
from pathlib import Path


def inspect(input_dir: Path) -> dict:
    def read(path):
        return json.loads(path.read_text(encoding="utf-8"))

    flows = {mode: read(input_dir / mode / "flow.json") for mode in ("control", "candidate")}
    snapshot = flows["control"]["snapshots"][0]
    if snapshot != flows["candidate"]["snapshots"][0]:
        raise ValueError("Initial snapshots differ.")
    pairs = sorted((math.dist(a["position"], p["position"]), a["id"], p["family"], a["position"], p["position"])
                   for a in snapshot["actors"] for p in snapshot["records"]
                   if p["kind"] == "weapon" and p["family"] not in ("", "knife", "pistol"))
    if not pairs or pairs[0][0] <= 2.5:
        raise ValueError("Expected non-pistol weapons outside the initial collect radius.")
    events = {}
    for mode in flows:
        result = read(input_dir / mode / "results/run_1.json")
        economy = result["economy"]
        events[mode] = {key: economy[key] for key in ("first_upgrade_time", "first_upgrade_weapon", "first_upgrade_source")}
        if not economy["first_upgrade_time"] == result["pacing"]["first_non_pistol_upgrade_time"] == 0:
            raise ValueError("Expected consistent zero-time first upgrades.")
    return dict(initial_exact=True, actors=len(snapshot["actors"]), pairs=len(pairs),
                horizontal_pairs_within_collect_radius=sum(p[0] <= 2.5 for p in pairs), closest=pairs[:3], first_events=events,
                limits="XZ distance is a lower bound on3D distance. No initial non-pistol weapon is within2.5m. Actor name/first collector IDs and actual physics/process interleaving were not captured; closest pair is not attributed as first event.")


def main():
    parser = argparse.ArgumentParser(description="Read-only E079 initial-geometry check against preserved OFF/ON results.")
    parser.add_argument("--input-dir", type=Path, required=True, help="Directory containing control/ and candidate/.")
    args = parser.parse_args()
    try:
        result = inspect(args.input_dir)
    except (OSError, ValueError, KeyError, IndexError, TypeError) as exc:
        parser.error(str(exc))
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
