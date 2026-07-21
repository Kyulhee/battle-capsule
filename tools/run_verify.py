import argparse
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_GODOT = ROOT / "Godot_v4.6.2-stable_win64_console.exe"
DEFAULT_OUT_ROOT = Path(os.environ.get("GAME_DEV_VERIFY_OUT", r"C:\tmp"))
NIGHT_MAP_SPEC = "res://data/mapSpec_night_forest_candidate.json"
EXPANDED_MAP_SPEC = "res://data/mapSpec_night_forest_expanded_candidate.json"


@dataclass(frozen=True)
class Step:
    label: str
    argv: list[str]


def rel(path: str) -> str:
    return str(ROOT / path)


def godot_script(godot: str, script: str) -> Step:
    return Step(script, [godot, "--headless", "--path", str(ROOT), "--script", f"res://tools/{script}"])


def godot_script_args(godot: str, script: str, args: list[str]) -> Step:
    return Step(
        script,
        [
            godot,
            "--headless",
            "--path",
            str(ROOT),
            "--script",
            f"res://tools/{script}",
            "--",
            *args,
        ],
    )


def arena_traffic_step(godot: str, preset: str) -> Step:
    return godot_script_args(
        godot,
        "verify_ai_arena_traffic_runtime.gd",
        [
            "map_spec_path=res://data/mapSpec_ai_test_arena.json",
            f"scale_preset={preset}",
            "simulation_seed=41000",
        ],
    )


def py_compile(paths: list[str]) -> Step:
    return Step("python py_compile", [sys.executable, "-m", "py_compile", *[rel(path) for path in paths]])


def simulate_step(runs: int, preset: str, out_dir: Path, map_spec: str = NIGHT_MAP_SPEC) -> Step:
    return Step(
        f"simulate {preset} x{runs}",
        [
            sys.executable,
            rel("tools/simulate_matches.py"),
            str(runs),
            f"map_spec_path={map_spec}",
            f"scale_preset={preset}",
            f"out_dir={out_dir}",
        ],
    )


def pacing_steps(
    label: str,
    preset: str,
    godot: str,
    runs: int,
    out_root: Path,
    min_avg_duration: float | None = None,
    min_run_duration: float | None = None,
    max_run_duration: float | None = None,
    min_avg_first_upgrade: float = 10.0,
    max_missing_first_upgrade: int | None = None,
    map_spec: str = NIGHT_MAP_SPEC,
) -> list[Step]:
    out_dir = out_root / f"game_dev_verify_{preset}"
    scale_gate_args = [
        sys.executable,
        rel("tools/check_scale_telemetry.py"),
        str(out_dir),
        "--min-runs",
        str(runs),
        "--min-avg-first-upgrade",
        f"{min_avg_first_upgrade:.1f}",
    ]
    if min_avg_duration is not None:
        scale_gate_args.extend(["--min-avg-duration", f"{min_avg_duration:.1f}"])
    if min_run_duration is not None:
        scale_gate_args.extend(["--min-run-duration", f"{min_run_duration:.1f}"])
    if max_run_duration is not None:
        scale_gate_args.extend(["--max-run-duration", f"{max_run_duration:.1f}"])
    if max_missing_first_upgrade is not None:
        scale_gate_args.extend(["--max-missing-first-upgrade", str(max_missing_first_upgrade)])
    return [
        *profile_steps("unit_smoke", godot, runs, out_root),
        simulate_step(runs, preset, out_dir, map_spec),
        Step(f"analyze {label}", [sys.executable, rel("tools/analyze_results.py"), str(out_dir)]),
        Step(f"summarize {label}", [sys.executable, rel("tools/summarize_pacing_baseline.py"), str(out_dir)]),
        Step(f"scale gate {label}", scale_gate_args),
    ]


def profile_steps(
    profile: str,
    godot: str,
    runs: int,
    out_root: Path,
    pacing_preset: str = "",
    map_spec_path: str = "",
) -> list[Step]:
    docs_only = [Step("git diff --check", ["git", "diff", "--check"])]
    report_scripts = [
        "tools/analyze_results.py",
        "tools/summarize_pacing_baseline.py",
        "tools/check_scale_telemetry.py",
        "tools/analyze_map_structure.py",
        "tools/simulate_matches.py",
        "tools/run_verify.py",
    ]

    if profile == "docs_only":
        return docs_only

    if profile == "tooling":
        return [*docs_only, py_compile(report_scripts)]

    if profile == "unit_smoke":
        return [
            *docs_only,
            py_compile(report_scripts),
            godot_script(godot, "verify_pacing_telemetry.gd"),
            godot_script(godot, "verify_playable_pacing_preset.gd"),
            godot_script(godot, "verify_zone_initial_radius_tuning.gd"),
            godot_script(godot, "verify_spawn_distribution_metrics.gd"),
            godot_script(godot, "verify_bot_opening_loot_rules.gd"),
            godot_script(godot, "verify_bot_runtime_combat.gd"),
            godot_script(godot, "verify_bot_target_lifetime.gd"),
            godot_script(godot, "verify_bot_decision_policy.gd"),
            godot_script(godot, "verify_bot_engagement_saturation_runtime.gd"),
            godot_script(godot, "verify_bot_movement_policy.gd"),
            godot_script(godot, "verify_bot_strategic_movement_policy.gd"),
            godot_script(godot, "verify_bot_threat_pressure.gd"),
            godot_script(godot, "verify_bot_zone_escape_runtime.gd"),
            godot_script(godot, "verify_match_tuning_cli.gd"),
            godot_script(godot, "verify_night_world_readability.gd"),
            godot_script(godot, "verify_audio_catalog_assets.gd"),
            godot_script(godot, "verify_cover_classes.gd"),
            godot_script(godot, "verify_world_prop_assets.gd"),
            godot_script(godot, "verify_full_map_overlay.gd"),
            godot_script(godot, "verify_simulation_participants.gd"),
            godot_script(godot, "verify_night_expanded_candidate.gd"),
            godot_script_args(
                godot,
                "verify_night_nav_hotspot_runtime.gd",
                [
                    "map_spec_path=res://data/mapSpec_night_forest_expanded_candidate.json",
                    "scale_preset=nav_hotspot_1",
                    "simulation_seed=41000",
                ],
            ),
            godot_script_args(
                godot,
                "verify_night_cabin_compound_nav.gd",
                [
                    "map_spec_path=res://data/mapSpec_night_forest_expanded_candidate.json",
                    "scale_preset=nav_hotspot_1",
                    "simulation_seed=41000",
                ],
            ),
            godot_script_args(
                godot,
                "verify_night_west_ridge_nav.gd",
                [
                    "map_spec_path=res://data/mapSpec_night_forest_expanded_candidate.json",
                    "scale_preset=nav_hotspot_1",
                    "simulation_seed=41000",
                ],
            ),
            godot_script(godot, "verify_strategic_flow_map.gd"),
            godot_script(godot, "verify_map_runtime_path.gd"),
            godot_script(godot, "verify_ai_test_arena.gd"),
            godot_script_args(
                godot,
                "verify_ai_arena_runtime.gd",
                [
                    "map_spec_path=res://data/mapSpec_ai_test_arena.json",
                    "scale_preset=duel_1",
                    "simulation_seed=41000",
                ],
            ),
            godot_script_args(
                godot,
                "verify_ai_arena_rock_nav_runtime.gd",
                [
                    "map_spec_path=res://data/mapSpec_ai_test_arena.json",
                    "scale_preset=rock_nav_1",
                    "simulation_seed=41000",
                ],
            ),
            arena_traffic_step(godot, "open_traffic_4"),
            arena_traffic_step(godot, "wall_traffic_4"),
            godot_script_args(
                godot,
                "verify_ai_arena_squad_runtime.gd",
                [
                    "map_spec_path=res://data/mapSpec_ai_test_arena.json",
                    "scale_preset=squad_4",
                    "simulation_seed=41000",
                ],
            ),
        ]

    if profile == "ai_test_arena":
        return [
            *docs_only,
            godot_script(godot, "verify_bot_decision_policy.gd"),
            godot_script(godot, "verify_bot_engagement_saturation_runtime.gd"),
            godot_script(godot, "verify_bot_movement_policy.gd"),
            godot_script(godot, "verify_ai_test_arena.gd"),
            godot_script_args(
                godot,
                "verify_ai_arena_runtime.gd",
                [
                    "map_spec_path=res://data/mapSpec_ai_test_arena.json",
                    "scale_preset=duel_1",
                    "simulation_seed=41000",
                ],
            ),
            godot_script_args(
                godot,
                "verify_ai_arena_rock_nav_runtime.gd",
                [
                    "map_spec_path=res://data/mapSpec_ai_test_arena.json",
                    "scale_preset=rock_nav_1",
                    "simulation_seed=41000",
                ],
            ),
            arena_traffic_step(godot, "open_traffic_4"),
            arena_traffic_step(godot, "wall_traffic_4"),
            godot_script_args(
                godot,
                "verify_ai_arena_squad_runtime.gd",
                [
                    "map_spec_path=res://data/mapSpec_ai_test_arena.json",
                    "scale_preset=squad_4",
                    "simulation_seed=41000",
                ],
            ),
        ]

    if profile == "pacing_v2":
        return pacing_steps("pacing_v2", "playable_pacing_v2", godot, runs, out_root)

    if profile == "pacing_v3":
        return pacing_steps("pacing_v3", "playable_pacing_v3", godot, runs, out_root)

    if profile == "pacing_candidate":
        if not pacing_preset:
            raise ValueError("--pacing-preset is required for pacing_candidate.")
        if not map_spec_path:
            raise ValueError("--map-spec-path is required for pacing_candidate.")
        if runs < 5:
            raise ValueError("pacing_candidate requires at least 5 runs because fixed RNG seeds are not physics-deterministic.")
        return pacing_steps(
            "pacing_candidate",
            pacing_preset,
            godot,
            runs,
            out_root,
            540.0,
            None,
            None,
            120.0,
            0,
            map_spec_path,
        )

    if profile == "scale_99":
        out_dir = out_root / "game_dev_verify_scale_99"
        return [
            *docs_only,
            godot_script(godot, "verify_candidate_99_probe.gd"),
            simulate_step(runs, "target_99_probe", out_dir, EXPANDED_MAP_SPEC),
            Step("analyze scale_99", [sys.executable, rel("tools/analyze_results.py"), str(out_dir)]),
            Step(
                "scale gate scale_99",
                [sys.executable, rel("tools/check_scale_telemetry.py"), str(out_dir), "--min-runs", str(runs)],
            ),
        ]

    if profile == "visual_review":
        out_dir = out_root / "game_dev_verify_visual_review"
        return [
            *docs_only,
            godot_script(godot, "verify_player_night_readability.gd"),
            Step(
                "capture player night readability",
                [godot, "--path", str(ROOT), "--script", "res://tools/capture_player_night_readability.gd"],
            ),
            Step(
                "capture map orientation",
                [godot, "--path", str(ROOT), "--script", "res://tools/capture_map_orientation.gd"],
            ),
            simulate_step(1, "visual_review", out_dir),
            Step("analyze visual_review", [sys.executable, rel("tools/analyze_results.py"), str(out_dir)]),
        ]

    raise ValueError(f"Unknown profile: {profile}")


def run_step(step: Step, dry_run: bool) -> int:
    print(f"\n== {step.label} ==", flush=True)
    print(" ".join(step.argv), flush=True)
    if dry_run:
        return 0
    proc = subprocess.run(step.argv, cwd=ROOT)
    return int(proc.returncode)


def main() -> int:
    parser = argparse.ArgumentParser(description="Run Battle Capsule verification profiles.")
    parser.add_argument(
        "--profile",
        choices=["docs_only", "tooling", "unit_smoke", "ai_test_arena", "pacing_v2", "pacing_v3", "pacing_candidate", "scale_99", "visual_review"],
        required=True,
    )
    parser.add_argument("--pacing-preset", default="", help="Scale preset for --profile pacing_candidate.")
    parser.add_argument("--map-spec-path", default="", help="Explicit res:// map path for --profile pacing_candidate.")
    parser.add_argument("--runs", type=int, default=5, help="Run count for simulation profiles.")
    parser.add_argument("--out-root", default=str(DEFAULT_OUT_ROOT))
    parser.add_argument("--godot", default=str(DEFAULT_GODOT))
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--keep-going", action="store_true")
    args = parser.parse_args()

    try:
        steps = profile_steps(
            args.profile,
            args.godot,
            max(1, args.runs),
            Path(args.out_root),
            args.pacing_preset,
            args.map_spec_path,
        )
    except ValueError as exc:
        parser.error(str(exc))
    failures = 0
    for step in steps:
        code = run_step(step, args.dry_run)
        if code != 0:
            failures += 1
            print(f"FAIL: {step.label} exited with {code}.", flush=True)
            if not args.keep_going:
                return code
    if failures:
        print(f"\nProfile {args.profile} finished with {failures} failure(s).", flush=True)
        return 1
    print(f"\nProfile {args.profile} passed.", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
