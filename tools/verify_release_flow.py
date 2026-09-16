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
            "report": {"passed": True, "user_dir": str(self.profile), "records": [{"score": 2450}], "restart_count": 1, "runtime_source": "e067", "menu_label": runner.LEGACY_MENU,
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
        self.result["report"]["checks"] += ["runtime_menu_label", "default_persistence_paths", "persistent_record_count"]
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

    def test_package_options_fail_closed(self):
        for args in [["--runtime-source", "package"], ["--package-dir", "ignored"],
                     ["--runtime-source", "workspace", "--package-dir", "ignored"]]:
            with self.subTest(args=args), patch.object(sys, "argv", ["run_release_flow.py", "--out-dir", str(self.profile), *args]), \
                    patch.object(runner.subprocess, "run") as launch, contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit):
                    runner.main()
                launch.assert_not_called()

    def test_manifest_identity_and_hashes(self):
        source = "a" * 40
        info = 'const PRODUCT_VERSION := "2.1.0"\nconst RELEASE_CHANNEL := "demo-dev"\nconst PLAYTEST_BUILD := "E-091"\n'
        manifest = (f"Build: E-091\nSource commit: {source}\n"
                    "Source: clean git archive; untracked working files excluded\n"
                    f"{'b' * 64}  BattleCapsule_E091_aaaaaaa.exe\n{'b' * 64}  BattleCapsule_E091_aaaaaaa.pck\n")
        with patch.object(Path, "read_text", return_value=manifest), patch.object(runner.subprocess, "check_output", return_value=info), \
                patch.object(runner, "digest", return_value="b" * 64):
            expected, actual_source, menu = runner.load_package(self.profile)
            self.assertEqual(len(expected), 2)
            self.assertEqual(actual_source, source)
            self.assertEqual(menu, "v2.1.0-demo-dev | E-091")
        for text, build_info, digest in [(manifest + "Build: E-091\n", info, "b" * 64),
                                         (manifest.replace(".pck", ".other"), info, "b" * 64),
                                         (manifest, info.replace("E-091", "E-067"), "b" * 64),
                                         (manifest, info, "c" * 64)]:
            with self.subTest(text=text, build_info=build_info, digest=digest), patch.object(Path, "read_text", return_value=text), \
                    patch.object(runner.subprocess, "check_output", return_value=build_info), patch.object(runner, "digest", return_value=digest):
                with self.assertRaises(ValueError):
                    runner.load_package(self.profile)

    def test_wrong_runtime_menu_rejected(self):
        self.result["phase"] = "relaunch"
        self.result["report"]["checks"] += ["runtime_menu_label", "default_persistence_paths", "persistent_record_count"]
        with self.assertRaises(RuntimeError):
            runner.validate_phase(self.result, self.profile, expected_menu="v2.1.0-demo-dev | E-091")

    def test_exe_boot_requires_clean_exit_and_menu_markers(self):
        text = "[MAIN] Starting initialization...\n[MAIN] MapSpec loaded successfully: Night\n[MAIN] Generating world via WorldBuilder...\n"
        runner.validate_exe_boot(0, text)
        for code, log in [(1, text), (0, ""), (0, text + "ERROR: failed\n"), (0, text + "WARNING: leak\n")]:
            with self.subTest(code=code, log=log), self.assertRaises(RuntimeError):
                runner.validate_exe_boot(code, log)

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
