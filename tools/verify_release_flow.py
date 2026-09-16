"""Release-flow evidence/CLI safety fixtures; no game or user saves are touched."""
import contextlib
import copy
import io
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

import run_release_flow as runner


class ReleaseFlowTests(unittest.TestCase):
    def setUp(self):
        self.profile = runner.ROOT / "builds/verification/fixture/appdata"
        self.result = {
            "phase": "isolation", "exit_code": 0, "log_clean": True,
            "profile_sha256": {"match_history.json": "sha"},
            "report": {"passed": True, "user_dir": str(self.profile), "records": [{"score": 2450}], "restart_count": 1, "runtime_source": "e067",
                       "checks": ["user_dir_isolated", "no_autoloads_in_preflight", "empty_host_in_preflight"]},
        }

    def test_valid_isolation(self):
        runner.validate_phase(self.result, self.profile)

    def test_exit_warning_missing_or_false_report_rejected(self):
        for key, value in [("exit_code", 1), ("log_clean", False), ("report", {}),
                           ("report", {"passed": False}), ("report", {"passed": 1})]:
            with self.subTest(key=key, value=value):
                result = copy.deepcopy(self.result)
                result[key] = value
                with self.assertRaises(RuntimeError):
                    runner.validate_phase(result, self.profile)

    def test_wrong_profile_or_incomplete_preflight_rejected(self):
        for key, value in [("user_dir", str(runner.ROOT)), ("checks", ["user_dir_isolated"])]:
            result = copy.deepcopy(self.result)
            result["report"][key] = value
            with self.assertRaises(RuntimeError):
                runner.validate_phase(result, self.profile)

    def test_package_evidence_required(self):
        self.result["phase"] = "write_restart"
        with self.assertRaises(RuntimeError):
            runner.validate_phase(self.result, self.profile)
        self.result["report"]["checks"] += ["E067_menu_label", "default_persistence_paths", "persistent_record_count"]
        self.result["report"]["cycles"] = self.cycles(1)
        runner.validate_phase(self.result, self.profile)

    @staticmethod
    def cycles(restarts):
        return [{"cycle": i, "scene_id": 100 + i, "record_count": i + 1,
                 "actors": 61, "bots": 60, "players": 1, "previous_nodes_freed": True,
                 "previous_node_count": 100 if i else 0, "won": i % 2 == 0}
                for i in range(restarts + 1)]

    def test_five_restart_evidence(self):
        runner.validate_cycles({"cycles": self.cycles(5)}, 5)
        with self.assertRaises(RuntimeError):
            runner.validate_cycles({"cycles": self.cycles(1)}, 5)
        with self.assertRaises(RuntimeError):
            runner.validate_phase(self.result, self.profile, 5)

    def test_runtime_sources_cannot_be_mixed(self):
        with self.assertRaises(RuntimeError):
            runner.validate_phase(self.result, self.profile, runtime_source="workspace")
        self.result["report"]["runtime_source"] = "workspace"
        runner.validate_phase(self.result, self.profile, runtime_source="workspace")

    def test_cycle_count_lifetime_groups_and_duplicate_records_rejected(self):
        for key, bad in [("cycle", 0), ("scene_id", 100), ("record_count", 3),
                         ("actors", 122), ("bots", 61), ("players", 2),
                         ("previous_nodes_freed", False), ("previous_node_count", 0), ("won", True)]:
            with self.subTest(key=key):
                cycles = self.cycles(5)
                cycles[1][key] = bad
                with self.assertRaises(RuntimeError):
                    runner.validate_cycles({"cycles": cycles}, 5)

    def test_unbounded_restart_cli_rejected_before_launch(self):
        for value in ["0", "2", "6", "-1", "100", "bad"]:
            with self.subTest(value=value), \
                    patch.object(sys, "argv", ["run_release_flow.py", "--out-dir", str(self.profile), "--restart-count", value]), \
                    patch.object(runner.subprocess, "run") as launch, contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit):
                    runner.main()
                launch.assert_not_called()

    def test_relaunch_payload_and_bytes_unchanged(self):
        reader = copy.deepcopy(self.result)
        runner.validate_relaunch(self.result, reader)
        reader["report"]["records"][0]["duration"] = 99
        with self.assertRaises(RuntimeError):
            runner.validate_relaunch(self.result, reader)
        reader = copy.deepcopy(self.result)
        reader["profile_sha256"]["settings.cfg"] = "unexpected"
        with self.assertRaises(RuntimeError):
            runner.validate_relaunch(self.result, reader)

    def test_cli_refuses_existing_or_broad_targets_before_launch(self):
        for path in [runner.ROOT, runner.ROOT.parent, runner.ROOT / "builds/verification",
                     runner.ROOT / "builds/verification/../escape", Path(__file__).resolve()]:
            with self.subTest(path=path), patch.object(sys, "argv", ["run_release_flow.py", "--out-dir", str(path)]), \
                    patch.object(runner.subprocess, "run") as launch, contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit):
                    runner.main()
                launch.assert_not_called()
        with patch.object(sys, "argv", ["run_release_flow.py", "--out-dir", str(self.profile)]), \
                patch.object(Path, "exists", return_value=True), patch.object(runner.subprocess, "run") as launch, \
                contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit):
                runner.main()
            launch.assert_not_called()

    def test_artifact_mismatch_prevents_launch(self):
        with patch.object(sys, "argv", ["run_release_flow.py", "--out-dir", str(self.profile)]), \
                patch.object(Path, "exists", return_value=False), patch.object(runner, "digest", return_value="wrong"), \
                patch.object(runner.subprocess, "run") as launch, contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit):
                runner.main()
            launch.assert_not_called()


if __name__ == "__main__":
    unittest.main()
