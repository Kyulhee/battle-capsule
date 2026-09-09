"""진행 분석기의 표본 경계·누락·불변성 fixture."""
import copy
import unittest
from analyze_loot_progress import analyze


def fixture():
    actor = dict(id=1, loaded=0, reserve=0, state="CHASE", episode=1, targeting_loot=True,
                 target_id=7, target_position=[10, 0], position=[0, 0], state_timer=0,
                 loot_source="recover_seek_loot", loot_kind="pickup_ammo", strategy_target=None)
    frames = []
    for t in range(261):
        a = copy.deepcopy(actor)
        a.update(position=[min(t, 5), 0], state_timer=t)
        if t >= 5:
            a.update(state="IDLE", episode=2, targeting_loot=False, loaded=1)
        frames.append(dict(requested_time=t, observed_time=t, alive=1, actors=[a]))
    return dict(schema_version=3, complete=True, initial_only=False, progress_enabled=True,
                checkpoints_not_reached=[], seed=41000, progress=frames,
                snapshots=[dict(requested_time=t, observed_time=t, alive=0, actors=[]) for t in [0, 120, 260]])


class ProgressTests(unittest.TestCase):
    def test_progress_recovery_and_immutable(self):
        report = fixture()
        before = copy.deepcopy(report)
        result = analyze(report)
        self.assertEqual(report, before)
        self.assertEqual(result["empty_actor_samples"], 5)
        self.assertEqual(result["adjacent_empty_observed_seconds"], 4)
        self.assertEqual(result["observed_empty_to_armed"], 1)
        s = result["segments"][0]
        self.assertEqual((s["first_distance"], s["last_distance"], s["sample_displacement"]), (10, 6, 4))

    def test_episode_splits_repeated_target(self):
        report = fixture()
        for frame in report["progress"][3:5]:
            frame["actors"][0]["episode"] = 2
        result = analyze(report)
        self.assertEqual(len(result["segments"]), 2)
        self.assertEqual(result["empty_repeated_target_episode_counts"], [2])

    def test_absent_not_recovery(self):
        report = fixture()
        for frame in report["progress"][5:]:
            frame.update(alive=0, actors=[])
        result = analyze(report)
        self.assertEqual(result["empty_then_absent"], 1)
        self.assertEqual(result["observed_empty_to_armed"], 0)

    def test_idle_progress_ignores_changed_targets(self):
        report = fixture()
        for frame in report["progress"][:5]:
            frame["actors"][0].update(state="IDLE", targeting_loot=False, strategy_target=[10, 0])
        report["progress"][3]["actors"][0]["strategy_target"] = [20, 0]
        result = analyze(report)
        self.assertEqual(result["empty_idle_same_strategy_pairs"], 2)
        self.assertEqual(result["empty_idle_strategy_net_approach"], 2)

    def test_recovery_states_and_reserve_not_empty(self):
        report = fixture()
        for frame in report["progress"][:5]:
            frame["actors"][0].update(state="RECOVER", recovery_substate="patrol")
        report["progress"][4]["actors"][0]["reserve"] = 1
        result = analyze(report)
        self.assertEqual(result["empty_recovery_samples_by_substate"], {"patrol": 4})
        self.assertEqual(result["observed_empty_to_armed"], 1)

    def test_window_is_labelled_separately(self):
        report = fixture()
        report.update(progress_window_only=True, time_scale=1.0, loot_progress_candidate=True)
        result = analyze(report)
        self.assertTrue(result["progress_window_only"])
        self.assertEqual(result["time_scale"], 1.0)
        self.assertTrue(result["loot_progress_candidate"])
        self.assertFalse(result["ammo_pairing_candidate"])

    def test_invalid_inputs(self):
        for mode in ["incomplete", "missing", "duplicate", "lag", "checkpoint", "initial", "nan", "order", "stock"]:
            with self.subTest(mode=mode):
                report = fixture()
                if mode == "incomplete":
                    report["complete"] = False
                elif mode == "missing":
                    del report["progress"][9]
                elif mode == "duplicate":
                    report["progress"][9]["actors"] *= 2
                elif mode == "lag":
                    report["progress"][9]["observed_time"] += 0.5
                elif mode == "checkpoint":
                    report["checkpoints_not_reached"] = [260]
                elif mode == "nan":
                    report["progress"][9]["observed_time"] = float("nan")
                elif mode == "order":
                    report["progress"][9]["requested_time"] = 8
                elif mode == "stock":
                    report["snapshots"][1]["observed_time"] += 1.0
                else:
                    report["initial_only"] = True
                with self.assertRaises(ValueError):
                    analyze(report)


if __name__ == "__main__":
    unittest.main()
