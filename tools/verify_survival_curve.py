from survival_curve import (
    alive_threshold_summary,
    alive_at,
    checkpoint_summaries,
    format_survival_curve_lines,
    normalized_alive_timeline,
    threshold_summary,
)


def _sample_run(duration: float, samples: list[tuple[float, int]]) -> dict:
    return {
        "core": {"duration": duration},
        "pacing": {
            "alive_timeline": [
                {"time": time, "alive": alive}
                for time, alive in samples
            ]
        },
    }


def main() -> int:
    first = _sample_run(120.0, [(0.0, 10), (20.0, 8), (60.0, 5), (100.0, 1)])
    second = _sample_run(95.0, [(0.0, 20), (30.0, 15), (90.0, 10)])
    legacy = {"core": {"duration": 300.0}, "pacing": {}}
    runs = [first, second, legacy]

    equal_time = normalized_alive_timeline(
        _sample_run(10.0, [(0.0, 4), (5.0, 3), (5.0, 2)])
    )
    assert alive_at(equal_time, 4.9) == 4
    assert alive_at(equal_time, 5.0) == 2

    checkpoints = checkpoint_summaries(runs)
    by_time = {int(item["seconds"]): item for item in checkpoints}
    assert by_time[30]["eligible"] == 2
    assert abs(float(by_time[30]["avg_alive"]) - 11.5) < 1e-6
    assert abs(float(by_time[30]["avg_ratio"]) - 0.775) < 1e-6
    assert by_time[60]["eligible"] == 2
    assert abs(float(by_time[60]["avg_alive"]) - 10.0) < 1e-6
    assert abs(float(by_time[60]["avg_ratio"]) - 0.625) < 1e-6
    assert by_time[90]["eligible"] == 2
    assert abs(float(by_time[90]["avg_ratio"]) - 0.5) < 1e-6
    assert by_time[120]["eligible"] == 1
    assert by_time[180]["eligible"] == 1
    assert by_time[180]["completed_carry"] == 1
    assert by_time[180]["median_alive"] == 1
    assert by_time[260]["eligible"] == 1

    t50 = threshold_summary(runs, 0.5)
    assert t50["reached"] == 2
    assert abs(float(t50["avg_seconds"]) - 75.0) < 1e-6
    t10 = threshold_summary(runs, 0.1)
    assert t10["reached"] == 1
    assert abs(float(t10["avg_seconds"]) - 100.0) < 1e-6

    alive_10 = alive_threshold_summary(runs, 10)
    assert alive_10["applicable_runs"] == 1
    assert alive_10["reached"] == 1
    assert abs(float(alive_10["avg_seconds"]) - 90.0) < 1e-6
    alive_1 = alive_threshold_summary(runs, 1)
    assert alive_1["reached"] == 1
    assert abs(float(alive_1["avg_seconds"]) - 100.0) < 1e-6

    median_runs = [
        _sample_run(120.0, [(0.0, 20), (10.0, 10), (120.0, 1)]),
        _sample_run(120.0, [(0.0, 20), (20.0, 10), (120.0, 1)]),
        _sample_run(120.0, [(0.0, 20), (100.0, 10), (120.0, 1)]),
    ]
    median_half = threshold_summary(median_runs, 0.5)
    assert abs(float(median_half["median_seconds"]) - 20.0) < 1e-6
    assert abs(float(median_half["avg_seconds"]) - (130.0 / 3.0)) < 1e-6

    lines = format_survival_curve_lines(runs)
    assert any("30s: median alive=11.5" in line for line in lines)
    assert any("Half-life: median 75.0s" in line for line in lines)
    legacy_lines = format_survival_curve_lines([legacy])
    assert len(legacy_lines) == 1 and "legacy run schema accepted" in legacy_lines[0]
    print("Survival curve analysis smoke passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
