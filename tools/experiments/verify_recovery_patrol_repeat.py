"""Pure E086 report-contract regressions; no Godot or user-data writes."""
import copy
import subprocess
import sys
import unittest

from analyze_recovery_patrol_repeat import ammo_summary, snapshot_summary
from run_recovery_patrol_repeat import MAP, OFF, ROOT, validate_flow


class RecoveryRepeatTests(unittest.TestCase):
    def test_flow_contract(self):
        actors = [{"id": 1, "loaded": 0, "reserve": 0}, {"id": 2, "loaded": 0, "reserve": 2}]
        flow = {key: False for key in OFF}
        flow.update(complete=True, seed=41000, map=MAP, preset="night_br_m1_60", time_scale=5,
                    recovery_patrol_candidate=True, initial_only=False, clock_physics_priority=0,
                    checkpoints_not_reached=[], snapshots=[
                        {"requested_time": t, "observed_time": t, "alive": 2,
                         "actors": copy.deepcopy(actors), "needs": {"no_ammo": 1}} for t in (0, 120, 260)])
        validate_flow(flow, 41000, True)
        for key, value in [("physics_clock_candidate", True), ("ai_phase_audit_loaded", True),
                           ("recovery_patrol_candidate", False), ("complete", False), ("seed", 41001)]:
            with self.subTest(key=key), self.assertRaises(RuntimeError):
                validate_flow({**flow, key: value}, 41000, True)
        for key, value in [("observed_time", 120.251), ("observed_time", 119.999), ("alive", 1),
                           ("actors", [actors[0], actors[0]]), ("needs", {"no_ammo": 2})]:
            broken = copy.deepcopy(flow)
            broken["snapshots"][1][key] = value
            with self.subTest(key=key, value=value), self.assertRaises(RuntimeError):
                validate_flow(broken, 41000, True)

    def test_survivor_denominators(self):
        snapshots = [{"alive": 10, "needs": {"no_ammo": 1}}, {"alive": 2, "needs": {"no_ammo": 2}}]
        self.assertEqual(ammo_summary(snapshots), {"runs": 2, "empty": 3, "alive": 12,
                         "pooled_ratio": 0.25, "median_run_ratio": 0.55})
        self.assertIsNone(ammo_summary([])["pooled_ratio"])
        snap = dict(snapshots[0], observed_time=260.05, zone_stage=1, zone_shrinking=True, totals={"ammo_packs": 8})
        report = snapshot_summary(snap)
        self.assertEqual(report["phase"], [1, True])
        self.assertEqual(report["empty_ratio"], 0.1)
        self.assertEqual(report["stock"], {"ammo_packs": 8})

    def test_output_refused_before_io(self):
        for path in (ROOT / "builds/verification", ROOT / "e086_not_an_output"):
            result = subprocess.run([sys.executable, str(ROOT / "tools/experiments/run_recovery_patrol_repeat.py"),
                                     "--out-dir", str(path), "--check-only"], capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
            self.assertIn("Choose a new directory", result.stderr)
        self.assertFalse((ROOT / "e086_not_an_output").exists())


if __name__ == "__main__":
    unittest.main()
