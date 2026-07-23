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


def spawned_entities(run: dict) -> int:
    spawn = run.get("spawn", {})
    placed = int(spawn.get("placed_count", 0))
    if placed > 0:
        return placed
    requested = int(spawn.get("requested_count", 0))
    if requested > 0:
        return requested
    return 1


def per_spawned_entity_minute(run: dict, count_key: str) -> float:
    duration = float(run.get("core", {}).get("duration", 0.0))
    count = float(run.get("tactics", {}).get(count_key, 0.0))
    return count / max(1.0, spawned_entities(run)) / max(1.0, duration / 60.0)


def main() -> int:
    parser = argparse.ArgumentParser(description="Check repeated scale-test telemetry gates.")
    parser.add_argument("run_dir", nargs="?", default="tools/sim_runs_current")
    parser.add_argument("--min-runs", type=int, default=5)
    parser.add_argument("--min-avg-duration", type=float, default=70.0)
    parser.add_argument("--max-avg-duration", type=float, default=-1.0)
    parser.add_argument("--min-run-duration", type=float, default=-1.0)
    parser.add_argument("--max-run-duration", type=float, default=-1.0)
    parser.add_argument("--max-runs-under-60", type=int, default=0)
    parser.add_argument("--min-avg-first-upgrade", type=float, default=10.0)
    parser.add_argument("--max-avg-first-upgrade", type=float, default=300.0)
    parser.add_argument("--max-missing-first-upgrade", type=int, default=-1)
    parser.add_argument("--max-avg-stuck", type=float, default=60.0)
    parser.add_argument("--max-avg-disengage", type=float, default=130.0)
    parser.add_argument("--long-run-normalized-after", type=float, default=300.0)
    parser.add_argument("--max-stuck-per-entity-minute", type=float, default=0.15)
    parser.add_argument("--max-disengage-per-entity-minute", type=float, default=0.45)
    parser.add_argument("--max-recover-death-ratio", type=float, default=0.25)
    parser.add_argument("--max-ai-avg-usec", type=float, default=4500.0)
    parser.add_argument("--max-ai-max-usec", type=float, default=50000.0)
    parser.add_argument("--max-avg-spawn-fallbacks", type=float, default=0.0)
    parser.add_argument("--min-spawn-min-nearest", type=float, default=3.4)
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
    stuck_rate = [per_spawned_entity_minute(r, "stuck_triggered") for r in runs]
    disengage_rate = [per_spawned_entity_minute(r, "disengage_triggered") for r in runs]
    ai_samples = sum(int(r.get("ai", {}).get("update_samples", 0)) for r in runs)
    ai_total_usec = sum(int(r.get("ai", {}).get("update_total_usec", 0)) for r in runs)
    ai_max_usec = max((int(r.get("ai", {}).get("update_max_usec", 0)) for r in runs), default=0)
    spawn_runs = [
        r.get("spawn", {})
        for r in runs
        if int(r.get("spawn", {}).get("placed_count", 0)) > 0
    ]

    failures: list[str] = []
    if avg(durations) < args.min_avg_duration:
        failures.append(f"avg duration {avg(durations):.1f}s < {args.min_avg_duration:.1f}s")
    if args.max_avg_duration >= 0.0 and avg(durations) > args.max_avg_duration:
        failures.append(f"avg duration {avg(durations):.1f}s > {args.max_avg_duration:.1f}s")
    if args.min_run_duration >= 0.0:
        short_runs = [idx + 1 for idx, duration in enumerate(durations) if duration < args.min_run_duration]
        if short_runs:
            failures.append(f"duration below {args.min_run_duration:.1f}s in runs: {short_runs}")
    if args.max_run_duration >= 0.0:
        long_runs = [idx + 1 for idx, duration in enumerate(durations) if duration > args.max_run_duration]
        if long_runs:
            failures.append(f"duration above {args.max_run_duration:.1f}s in runs: {long_runs}")
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
    missing_first_upgrade = len(runs) - len(first_upgrade)
    if args.max_missing_first_upgrade >= 0 and missing_first_upgrade > args.max_missing_first_upgrade:
        failures.append(
            f"missing first upgrade runs {missing_first_upgrade} > {args.max_missing_first_upgrade}"
        )
    recover_total = sum(recover)
    recover_deaths = sum(died_in_recover)
    recover_death_ratio = recover_deaths / max(1, recover_total)
    if recover_death_ratio > args.max_recover_death_ratio:
        failures.append(
            f"recover death ratio {recover_death_ratio:.2f} > {args.max_recover_death_ratio:.2f}"
        )
    use_long_run_rates = avg(durations) >= args.long_run_normalized_after
    if use_long_run_rates:
        if avg(stuck_rate) > args.max_stuck_per_entity_minute:
            failures.append(
                f"stuck/entity/min {avg(stuck_rate):.2f} > {args.max_stuck_per_entity_minute:.2f}"
            )
        if avg(disengage_rate) > args.max_disengage_per_entity_minute:
            failures.append(
                f"disengage/entity/min {avg(disengage_rate):.2f} > {args.max_disengage_per_entity_minute:.2f}"
            )
    else:
        if avg(stuck) > args.max_avg_stuck:
            failures.append(f"avg stuck {avg(stuck):.1f} > {args.max_avg_stuck:.1f}")
        if avg(disengage) > args.max_avg_disengage:
            failures.append(f"avg disengage {avg(disengage):.1f} > {args.max_avg_disengage:.1f}")
    if ai_samples > 0:
        ai_avg_usec = ai_total_usec / ai_samples
        if ai_avg_usec > args.max_ai_avg_usec:
            failures.append(f"AI avg update {ai_avg_usec:.1f}us > {args.max_ai_avg_usec:.1f}us")
        if ai_max_usec > args.max_ai_max_usec:
            failures.append(f"AI max update {ai_max_usec}us > {args.max_ai_max_usec:.0f}us")
    if spawn_runs:
        spawn_fallback = [int(s.get("fallback_count", 0)) for s in spawn_runs]
        spawn_min_nearest = [float(s.get("min_nearest_distance", 0.0)) for s in spawn_runs]
        mismatched = [
            idx + 1
            for idx, run in enumerate(runs)
            if int(run.get("spawn", {}).get("placed_count", 0)) > 0
            and int(run.get("spawn", {}).get("placed_count", 0)) != int(run.get("spawn", {}).get("requested_count", 0))
        ]
        if mismatched:
            failures.append(f"spawn placed/requested mismatch runs: {mismatched}")
        if avg(spawn_fallback) > args.max_avg_spawn_fallbacks:
            failures.append(f"avg spawn fallbacks {avg(spawn_fallback):.1f} > {args.max_avg_spawn_fallbacks:.1f}")
        if min(spawn_min_nearest) < args.min_spawn_min_nearest:
            failures.append(f"spawn min nearest {min(spawn_min_nearest):.1f}m < {args.min_spawn_min_nearest:.1f}m")

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
    print(f"Min/Max duration: {min(durations):.1f}s / {max(durations):.1f}s")
    print(f"Runs under 60s: {runs_under_60}")
    print(f"Avg first upgrade: {avg(first_upgrade) if first_upgrade else -1.0:.1f}s")
    print(f"Missing first upgrade runs: {missing_first_upgrade}")
    print(f"Recover death ratio: {recover_death_ratio:.3f}")
    print(f"Avg stuck/disengage: {avg(stuck):.1f} / {avg(disengage):.1f}")
    print(
        "Per spawned entity/min: stuck={:.2f}, disengage={:.2f}{}".format(
            avg(stuck_rate),
            avg(disengage_rate),
            " (long-run gate)" if use_long_run_rates else "",
        )
    )
    if ai_samples > 0:
        print(f"AI update budget: samples={ai_samples}, avg={ai_total_usec / ai_samples:.1f}us, max={ai_max_usec}us")
    else:
        print("AI update budget: not recorded")
    if spawn_runs:
        spawn_fallback = [int(s.get("fallback_count", 0)) for s in spawn_runs]
        spawn_min_nearest = [float(s.get("min_nearest_distance", 0.0)) for s in spawn_runs]
        spawn_avg_nearest = [float(s.get("avg_nearest_distance", 0.0)) for s in spawn_runs]
        spawn_avg_attempts = [float(s.get("avg_attempts", 0.0)) for s in spawn_runs]
        spawn_max_attempts = [int(s.get("attempt_max", 0)) for s in spawn_runs]
        spawn_saturation = [float(s.get("annulus_saturation", 0.0)) for s in spawn_runs]
        print(
            "Spawn distribution: fallback={:.1f}/run, min_nearest={:.1f}m, avg_nearest={:.1f}m, attempts={:.1f}/{} max, saturation={:.2f}".format(
                avg(spawn_fallback),
                min(spawn_min_nearest),
                avg(spawn_avg_nearest),
                avg(spawn_avg_attempts),
                max(spawn_max_attempts),
                avg(spawn_saturation),
            )
        )
    else:
        print("Spawn distribution: not recorded")
    if failures:
        print("FAIL:")
        for failure in failures:
            print(f"  - {failure}")
        return 1
    print("PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
