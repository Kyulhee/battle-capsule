import copy
import unittest

from analyze_ai_phases import PHASES, analyze


def fixture():
    phases = dict.fromkeys(PHASES, 0)
    phases["handler"] = 60000
    event = {"elapsed_usec": 60000, "phases_usec": phases, "entry_state": "IDLE",
             "handler_state": "CHASE", "exit_state": "CHASE", "loot_candidate": True,
             "match_time": 12.0, "actor": 1, "physics_frame": 100}
    flow = {"complete": True, "ai_phase_trace_enabled": True, "loot_progress_candidate": True,
            "seed": 41000, "end_time": 600.0,
            "ai_phase_trace": {"valid": True, "telemetry_samples": 100,
                               "telemetry_max_usec": 60000, "max_usec": 60000,
                               "slow_samples": 1, "omitted": 0, "over_gate_samples": 1,
                               "events": [event]}}
    result = {"ai": {"update_samples": 100, "update_max_usec": 60000}, "core": {"duration": 600.0}}
    return flow, result


class PhaseTests(unittest.TestCase):
    def test_valid_failure_preserved_without_mutation(self):
        flow, result = fixture()
        original = copy.deepcopy(flow)
        self.assertFalse(analyze(flow, result)["max_gate_pass"])
        self.assertEqual(flow, original)

    def test_corruption_rejected(self):
        for mutate in [
            lambda f: f.update(complete=False),
            lambda f: f.update(end_time=700),
            lambda f: f.update(initial_only=True),
            lambda f: f["ai_phase_trace"].update(telemetry_samples=99),
            lambda f: f["ai_phase_trace"].update(omitted=1),
            lambda f: f["ai_phase_trace"].update(over_gate_samples=0),
            lambda f: f["ai_phase_trace"]["events"][0].update(loot_candidate=False),
            lambda f: f["ai_phase_trace"]["events"][0].update(match_time=float("nan")),
            lambda f: f["ai_phase_trace"]["events"][0]["phases_usec"].update(handler=59999),
        ]:
            flow, result = fixture()
            mutate(flow)
            with self.assertRaises(ValueError):
                analyze(flow, result)

    def test_quiet_match(self):
        flow, result = fixture()
        result["ai"]["update_max_usec"] = 4000
        flow["ai_phase_trace"].update(telemetry_max_usec=4000, max_usec=0, slow_samples=0,
                                       events=[], over_gate_samples=0)
        self.assertTrue(analyze(flow, result)["max_gate_pass"])

    def test_bounded_overflow(self):
        flow, result = fixture()
        trace = flow["ai_phase_trace"]
        template = trace["events"][0]
        trace.update(slow_samples=33, omitted=1, over_gate_samples=33,
                     events=[dict(copy.deepcopy(template), physics_frame=i) for i in range(32)])
        self.assertEqual(analyze(flow, result)["over_50ms"], 33)
        trace["events"].pop()
        with self.assertRaises(ValueError):
            analyze(flow, result)


if __name__ == "__main__":
    unittest.main()
