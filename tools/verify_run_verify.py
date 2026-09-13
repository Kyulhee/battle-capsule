"""검증 선택·실행·승격 경계를 검사한다. Godot/매치는 실행하지 않는다."""
import contextlib
import io
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

import run_verify as runner


class VerifyRunnerTests(unittest.TestCase):
    def invoke(self, *args, codes=()):
        output = io.StringIO()
        with patch.object(sys, "argv", ["run_verify.py", *args]), \
                patch.object(runner, "run_step", side_effect=list(codes)) as run, \
                contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
            try:
                code = runner.main()
            except SystemExit as exc:
                code = exc.code
        return code, output.getvalue(), run

    def test_single_gd_preserves_command(self):
        steps = runner.focused_steps("custom godot.exe", ["verify_first_upgrade_clock.gd"])
        self.assertEqual(len(steps), 2)
        self.assertEqual(steps[0].argv, ["git", "diff", "--check"])
        self.assertEqual(steps[1], runner.godot_script("custom godot.exe", "verify_first_upgrade_clock.gd"))

    def test_variants_and_duplicate_requests(self):
        name = "verify_ai_arena_traffic_runtime.gd"
        steps = runner.focused_steps("godot", [name, name])
        self.assertEqual(len(steps), 3)
        self.assertIn("scale_preset=open_traffic_4", steps[1].argv)
        self.assertIn("scale_preset=wall_traffic_4", steps[2].argv)

    def test_tooling_only_verifier_available(self):
        steps = runner.focused_steps("godot", ["verify_ai_phase_analysis.py"])
        self.assertEqual(steps[1].argv, [sys.executable, runner.rel("tools/verify_ai_phase_analysis.py")])

    def test_python_deduplicated_between_profiles(self):
        self.assertEqual(len(runner.test_catalog("godot")["verify_loot_search_analysis.py"]), 1)

    def test_python_probe_keeps_engine_argument(self):
        steps = runner.focused_steps("custom.exe", ["verify_ai_phase_probe.py"])
        self.assertEqual(steps[1].argv[-2:], ["--godot", "custom.exe"])

    def test_invalid_selection_executes_nothing(self):
        for names in ([], ["typo.gd"], ["verify_run_verify.py", "typo.gd"], ["../verify_run_verify.py"]):
            with self.subTest(names=names):
                args = [arg for name in names for arg in ("--test", name)]
                code, _, run = self.invoke("--profile", "focused", *args)
                self.assertEqual(code, 2)
                run.assert_not_called()

    def test_no_filter_on_full_profiles(self):
        for profile in ("unit_smoke", "tooling", "pacing_candidate", "scale_99"):
            for option in (("--test", "verify_run_verify.py"), ("--list-tests",)):
                with self.subTest(profile=profile, option=option):
                    code, _, run = self.invoke("--profile", profile, *option)
                    self.assertEqual(code, 2)
                    run.assert_not_called()

    def test_list_is_read_only(self):
        code, output, run = self.invoke("--profile", "focused", "--list-tests")
        self.assertEqual(code, 0)
        self.assertIn("verify_ai_arena_traffic_runtime.gd (2 variant(s))", output)
        run.assert_not_called()

    def test_list_and_selection_rejected(self):
        code, _, run = self.invoke("--profile", "focused", "--list-tests", "--test", "verify_run_verify.py")
        self.assertEqual(code, 2)
        run.assert_not_called()

    def test_dry_run_does_not_claim_pass(self):
        code, output, run = self.invoke("--profile", "focused", "--test", "verify_run_verify.py", "--dry-run", codes=[0, 0])
        self.assertEqual(code, 0)
        self.assertIn("no checks executed", output)
        self.assertNotIn("passed", output)
        self.assertTrue(all(call.args[1] for call in run.call_args_list))

    def test_dry_run_never_launches_process(self):
        with patch.object(runner.subprocess, "run") as process, contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(runner.run_step(runner.Step("test", ["unused"]), True), 0)
        process.assert_not_called()

    def test_failure_propagates_and_stops(self):
        code, output, run = self.invoke("--profile", "focused", "--test", "verify_run_verify.py", codes=[7])
        self.assertEqual(code, 7)
        self.assertEqual(run.call_count, 1)
        self.assertNotIn("passed", output)

    def test_keep_going_still_fails(self):
        code, output, run = self.invoke("--profile", "focused", "--test", "verify_run_verify.py", "--keep-going", codes=[7, 0])
        self.assertEqual(code, 1)
        self.assertEqual(run.call_count, 2)
        self.assertIn("1 failure(s)", output)

    def test_focused_success_is_not_promotion(self):
        code, output, _ = self.invoke("--profile", "focused", "--test", "verify_run_verify.py", codes=[0, 0])
        self.assertEqual(code, 0)
        self.assertIn("not a full-profile or promotion result", output)

    def test_promotion_contract_preserved(self):
        with self.assertRaises(ValueError):
            runner.profile_steps("pacing_candidate", "godot", 1, Path("unused"), runner.M1_PRESET, runner.M1_MAP_SPEC)
        steps = runner.profile_steps("pacing_candidate", "godot", 5, Path("unused"), runner.M1_PRESET, runner.M1_MAP_SPEC)
        full = runner.profile_steps("unit_smoke", "godot", 5, Path("unused"))
        self.assertEqual(steps[:len(full)], full)
        gate = steps[-1].argv
        for flag, value in {"--min-runs": "5", "--min-avg-duration": "600.0", "--max-avg-duration": "900.0",
                            "--min-run-duration": "480.0", "--max-run-duration": "960.0",
                            "--min-avg-first-upgrade": "2.0", "--max-avg-first-upgrade": "30.0",
                            "--max-missing-first-upgrade": "0"}.items():
            self.assertEqual(gate[gate.index(flag) + 1], value)


if __name__ == "__main__":
    unittest.main()
