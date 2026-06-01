import argparse
import json
from pathlib import Path


def load_runs(run_dir: Path) -> list[dict]:
    summary = run_dir / "summary.json"
    if summary.exists():
        with summary.open("r", encoding="utf-8") as f:
            return json.load(f)
    runs = []
    for path in sorted(run_dir.glob("run_*.json")):
        with path.open("r", encoding="utf-8") as f:
            runs.append(json.load(f))
    return runs


def avg(values: list[float]) -> float:
    return sum(values) / max(1, len(values))


def combat_plan_total(run: dict) -> int:
    tactics = run.get("tactics", {})
    doctrine = run.get("doctrine", {})
    doctrine_total = sum(int(v) for v in doctrine.get("combat_plan_counts", {}).values())
    tactics_total = (
        int(tactics.get("cover_peek", 0))
        + int(tactics.get("combat_reposition", 0))
        + int(tactics.get("combat_kite", 0))
    )
    return max(tactics_total, doctrine_total)


def run_numbers(runs: list[dict], predicate) -> list[int]:
    return [idx + 1 for idx, run in enumerate(runs) if predicate(run)]


def main() -> int:
    parser = argparse.ArgumentParser(description="Check repeated scale-test telemetry gates.")
    parser.add_argument("run_dir", nargs="?", default="tools/sim_runs_current")
    parser.add_argument("--min-runs", type=int, default=5)
    parser.add_argument("--min-avg-duration", type=float, default=70.0)
    parser.add_argument("--max-runs-under-60", type=int, default=0)
    parser.add_argument("--min-avg-first-upgrade", type=float, default=10.0)
    parser.add_argument("--max-avg-first-upgrade", type=float, default=60.0)
    parser.add_argument("--max-avg-stuck", type=float, default=60.0)
    parser.add_argument("--max-avg-disengage", type=float, default=130.0)
    parser.add_argument("--max-recover-death-ratio", type=float, default=0.25)
    args = parser.parse_args()

    runs = load_runs(Path(args.run_dir))
    if len(runs) < args.min_runs:
        print(f"FAIL: expected at least {args.min_runs} runs, found {len(runs)}.")
        return 1

    durations = [float(r.get("core", {}).get("duration", 0.0)) for r in runs]
    first_upgrade = [
        float(r.get("economy", {}).get("first_upgrade_time", -1.0))
        for r in runs
        if float(r.get("economy", {}).get("first_upgrade_time", -1.0)) >= 0.0
    ]
    recover = [int(r.get("tactics", {}).get("recover_bouts", 0)) for r in runs]
    died_in_recover = [int(r.get("tactics", {}).get("died_in_recover", 0)) for r in runs]
    disengage = [int(r.get("tactics", {}).get("disengage_triggered", 0)) for r in runs]
    stuck = [int(r.get("tactics", {}).get("stuck_triggered", 0)) for r in runs]

    failures: list[str] = []
    if avg(durations) < args.min_avg_duration:
        failures.append(f"avg duration {avg(durations):.1f}s < {args.min_avg_duration:.1f}s")
    runs_under_60 = sum(1 for d in durations if d < 60.0)
    if runs_under_60 > args.max_runs_under_60:
        failures.append(f"runs under 60s {runs_under_60} > {args.max_runs_under_60}")
    if not first_upgrade:
        failures.append("no first upgrade was recorded")
    else:
        avg_first = avg(first_upgrade)
        if avg_first < args.min_avg_first_upgrade:
            failures.append(f"avg first upgrade {avg_first:.1f}s < {args.min_avg_first_upgrade:.1f}s")
        if avg_first > args.max_avg_first_upgrade:
            failures.append(f"avg first upgrade {avg_first:.1f}s > {args.max_avg_first_upgrade:.1f}s")
    recover_total = sum(recover)
    recover_deaths = sum(died_in_recover)
    recover_death_ratio = recover_deaths / max(1, recover_total)
    if recover_death_ratio > args.max_recover_death_ratio:
        failures.append(
            f"recover death ratio {recover_death_ratio:.2f} > {args.max_recover_death_ratio:.2f}"
        )
    if avg(stuck) > args.max_avg_stuck:
        failures.append(f"avg stuck {avg(stuck):.1f} > {args.max_avg_stuck:.1f}")
    if avg(disengage) > args.max_avg_disengage:
        failures.append(f"avg disengage {avg(disengage):.1f} > {args.max_avg_disengage:.1f}")

    zero_damage = run_numbers(
        runs,
        lambda r: float(r.get("combat", {}).get("total_damage_dealt", 0.0)) <= 0.0,
    )
    zero_weapon_damage = run_numbers(
        runs,
        lambda r: sum(float(v) for v in r.get("combat", {}).get("damage_by_weapon", {}).values()) <= 0.0,
    )
    zero_shot = run_numbers(runs, lambda r: int(r.get("combat", {}).get("shots_fired", 0)) <= 0)
    zero_plan = run_numbers(runs, lambda r: combat_plan_total(r) <= 0)
    if zero_damage:
        failures.append(f"zero total damage runs: {zero_damage}")
    if zero_weapon_damage:
        failures.append(f"zero weapon damage runs: {zero_weapon_damage}")
    if zero_shot:
        failures.append(f"zero shot runs: {zero_shot}")
    if zero_plan:
        failures.append(f"zero combat plan runs: {zero_plan}")

    print("--- Scale Telemetry Gate ---")
    print(f"Runs: {len(runs)}")
    print(f"Avg duration: {avg(durations):.1f}s")
    print(f"Runs under 60s: {runs_under_60}")
    print(f"Avg first upgrade: {avg(first_upgrade) if first_upgrade else -1.0:.1f}s")
    print(f"Recover death ratio: {recover_death_ratio:.3f}")
    print(f"Avg stuck/disengage: {avg(stuck):.1f} / {avg(disengage):.1f}")
    if failures:
        print("FAIL:")
        for failure in failures:
            print(f"  - {failure}")
        return 1
    print("PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
