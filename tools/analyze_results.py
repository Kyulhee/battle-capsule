import json
import sys
from collections import Counter
from pathlib import Path


RUN_DIR = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("tools") / "sim_runs_current"


def load_runs(run_dir: Path) -> list[dict]:
    if (run_dir / "summary.json").exists():
        with (run_dir / "summary.json").open("r", encoding="utf-8") as f:
            return json.load(f)

    runs = []
    for path in sorted(run_dir.glob("run_*.json")):
        with path.open("r", encoding="utf-8") as f:
            runs.append(json.load(f))
    return runs


def avg(values: list[float]) -> float:
    return sum(values) / max(1, len(values))


if __name__ == "__main__":
    results = load_runs(RUN_DIR)
    if not results:
        print(f"No results found in {RUN_DIR}.")
        raise SystemExit(1)

    durations = [r.get("core", {}).get("duration", 0.0) for r in results]
    stages = [r.get("core", {}).get("zone_stage_reached", 0) for r in results]
    attack_bouts = [r.get("combat", {}).get("attack_max_continuous", 0.0) for r in results]
    recover = [r.get("tactics", {}).get("recover_bouts", 0) for r in results]
    recover_success = [r.get("tactics", {}).get("recover_success", 0) for r in results]
    died_in_recover = [r.get("tactics", {}).get("died_in_recover", 0) for r in results]
    disengage = [r.get("tactics", {}).get("disengage_triggered", 0) for r in results]
    stuck = [r.get("tactics", {}).get("stuck_triggered", 0) for r in results]
    cover_peek = [r.get("tactics", {}).get("cover_peek", 0) for r in results]
    reposition = [r.get("tactics", {}).get("combat_reposition", 0) for r in results]
    kite = [r.get("tactics", {}).get("combat_kite", 0) for r in results]
    survival_break = [r.get("tactics", {}).get("survival_break", 0) for r in results]
    zone_escape_fire = [r.get("tactics", {}).get("zone_escape_fire", 0) for r in results]
    retreat_counterfire = [r.get("tactics", {}).get("retreat_counterfire", 0) for r in results]
    retreat_melee_counter = [r.get("tactics", {}).get("retreat_melee_counter", 0) for r in results]
    stuck_while_threatened = [r.get("tactics", {}).get("stuck_while_threatened", 0) for r in results]
    zone_assisted_death = [r.get("tactics", {}).get("zone_assisted_death", 0) for r in results]
    zone_deaths = [r.get("zone", {}).get("zone_deaths", 0) for r in results]
    max_outside_time = [r.get("zone", {}).get("max_outside_time", 0.0) for r in results]
    first_upgrade = [
        r.get("economy", {}).get("first_upgrade_time", -1.0)
        for r in results
        if r.get("economy", {}).get("first_upgrade_time", -1.0) >= 0
    ]

    total_recover = sum(recover)
    total_recover_success = sum(recover_success)
    total_recover_deaths = sum(died_in_recover)
    weapon_pickups = Counter()
    first_upgrade_weapons = Counter()
    for r in results:
        economy = r.get("economy", {})
        weapon_pickups.update(economy.get("weapon_pickups", {}))
        first_weapon = economy.get("first_upgrade_weapon", "none")
        if first_weapon != "none":
            first_upgrade_weapons[first_weapon] += 1
    pressure = [r.get("pressure", {}) for r in results]
    pressure_triggered = sum(p.get("pressure_triggered", 0) for p in pressure)
    pressure_resolved = sum(p.get("pressure_cleared", 0) + p.get("pressure_failed", 0) for p in pressure)
    doctrine_profiles = Counter()
    doctrine_plans = Counter()
    doctrine_supply = Counter()
    for r in results:
        doctrine = r.get("doctrine", {})
        doctrine_profiles.update(doctrine.get("profile_counts", {}))
        doctrine_plans.update(doctrine.get("combat_plan_counts", {}))
        doctrine_supply.update(doctrine.get("supply_decisions", {}))

    print("--- Simulation Analysis ---")
    print(f"Runs: {len(results)}")
    print(f"Avg duration: {avg(durations):.1f}s")
    print(f"Min/Max duration: {min(durations):.1f}s / {max(durations):.1f}s")
    print(f"Avg zone stage: {avg(stages):.2f}")
    print(f"Runs under 60s: {sum(1 for d in durations if d < 60.0)}")
    print(f"Avg/Max longest attack bout: {avg(attack_bouts):.1f}s / {max(attack_bouts):.1f}s")
    print(f"Recover success: {total_recover_success}/{total_recover} ({100.0 * total_recover_success / max(1, total_recover):.1f}%)")
    print(
        f"Died in RECOVER: {total_recover_deaths} "
        f"({avg(died_in_recover):.1f}/run, {100.0 * total_recover_deaths / max(1, total_recover):.1f}% of bouts)"
    )
    print(f"Avg disengage triggers: {avg(disengage):.1f}")
    print(f"Avg stuck triggers: {avg(stuck):.1f}")
    print(
        "Avg combat plans: cover={:.1f}, reposition={:.1f}, kite={:.1f}, survival={:.1f}".format(
            avg(cover_peek),
            avg(reposition),
            avg(kite),
            avg(survival_break),
        )
    )
    print(
        "Avg retreat combat: zone_fire={:.1f}, counterfire={:.1f}, melee={:.1f}, stuck_threat={:.1f}, zone_assist={:.1f}".format(
            avg(zone_escape_fire),
            avg(retreat_counterfire),
            avg(retreat_melee_counter),
            avg(stuck_while_threatened),
            avg(zone_assisted_death),
        )
    )
    print(f"Zone deaths: {sum(zone_deaths)} ({avg(zone_deaths):.1f}/run), max outside time: {max(max_outside_time):.1f}s")
    if first_upgrade:
        print(f"Avg first upgrade: {avg(first_upgrade):.1f}s")
    if first_upgrade_weapons:
        first_parts = [f"{weapon}={count}" for weapon, count in sorted(first_upgrade_weapons.items())]
        print(f"First upgrade weapons: {', '.join(first_parts)}")
    if weapon_pickups:
        pickup_parts = [f"{weapon}={count}" for weapon, count in sorted(weapon_pickups.items())]
        print(f"Weapon pickups: {', '.join(pickup_parts)}")
    if doctrine_profiles:
        profile_parts = [f"{name}={count}" for name, count in sorted(doctrine_profiles.items())]
        print(f"Doctrine profiles: {', '.join(profile_parts)}")
    if doctrine_plans:
        plan_parts = [f"{plan}={count}" for plan, count in sorted(doctrine_plans.items()) if count]
        print(f"Doctrine plans: {', '.join(plan_parts) if plan_parts else 'none'}")
    if doctrine_supply:
        supply_parts = [f"{decision}={count}" for decision, count in sorted(doctrine_supply.items())]
        print(f"Doctrine supply: {', '.join(supply_parts)}")
    if pressure_triggered:
        print(f"Pressure resolved: {pressure_resolved}/{pressure_triggered}")
