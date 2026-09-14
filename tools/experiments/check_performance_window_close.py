"""E085: send WM_CLOSE only to the visible window owned by each process we launch."""
import argparse
import ctypes
from ctypes import wintypes
import subprocess
import time

from run_clock_performance import frozen_sources, user_hashes
from run_first_collection import ROOT, digest, read, save


def owned_windows(pid):
    user32 = ctypes.WinDLL("user32", use_last_error=True)
    callback_type = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    user32.EnumWindows.argtypes = [callback_type, wintypes.LPARAM]
    user32.EnumWindows.restype = wintypes.BOOL
    user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
    user32.GetWindowThreadProcessId.restype = wintypes.DWORD
    user32.IsWindowVisible.argtypes = [wintypes.HWND]
    user32.IsWindowVisible.restype = wintypes.BOOL
    windows = []

    @callback_type
    def visit(hwnd, _):
        owner = wintypes.DWORD()
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(owner))
        if owner.value == pid and user32.IsWindowVisible(hwnd):
            windows.append(int(hwnd))
        return True

    if not user32.EnumWindows(visit, 0):
        raise ctypes.WinError(ctypes.get_last_error())
    return windows


def close_owned_window(process):
    windows = owned_windows(process.pid)
    if process.poll() is not None or len(windows) != 1:
        raise RuntimeError(f"Expected exactly one live owned window; found {windows}.")
    user32 = ctypes.WinDLL("user32", use_last_error=True)
    user32.PostMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
    user32.PostMessageW.restype = wintypes.BOOL
    if not user32.PostMessageW(windows[0], 0x0010, 0, 0):  # WM_CLOSE, not process termination
        raise ctypes.WinError(ctypes.get_last_error())
    return windows[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--after-nav-seconds", type=float, default=7.0)
    parser.add_argument("--expected-exit", type=int, choices=(0, 2), default=2)
    parser.add_argument("--verbose", action="store_true", help="Print leaked object identities for a failed close.")
    parser.add_argument("--complete", action="store_true", help="One normal completion pair; no close or performance promotion.")
    args = parser.parse_args()
    if not 0 <= args.after_nav_seconds <= 10:
        parser.error("Close delay must be between 0 and 10 seconds after navigation readiness.")
    output = (ROOT / args.out_dir).resolve()
    if output.exists():
        parser.error("Output already exists; choose a new directory.")
    engine = ROOT / "Godot_v4.6.2-stable_win64.exe"  # Direct GUI PID; no console-wrapper child lookup.
    frozen, protected = frozen_sources(), user_hashes()
    if "sim_result_latest.json" not in protected:
        parser.error("Protected manual result missing.")
    output.mkdir(parents=True, exist_ok=False)
    save(output / "inputs.json", {"source_sha256": frozen, "user_sha256": protected,
         "runner_sha256": digest(ROOT / "tools/experiments/check_performance_window_close.py"),
         "engine_sha256": digest(engine), "after_nav_seconds": args.after_nav_seconds,
         "expected_exit": 0 if args.complete else args.expected_exit,
         "verbose": args.verbose,
         "complete": args.complete,
         "commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()})
    summary = {}
    initial = None
    for candidate in (False, True):
        name = "candidate" if candidate else "control"
        if frozen_sources() != frozen or user_hashes() != protected:
            raise RuntimeError("Source/user data changed before test.")
        case = output / name
        case.mkdir()
        result, runtime = case / "profile.json", case / "runtime.log"
        command = [str(engine), "--path", str(ROOT), "--rendering-method", "forward_plus",
                   "--rendering-driver", "vulkan", "--log-file", str(runtime),
                   "--script", "res://tools/profile_runtime_performance.gd", "--",
                   "map_spec_path=res://data/mapSpec_night_forest_expanded_candidate.json",
                   "scale_preset=night_br_m1_60", "simulation_seed=41000",
                   "perf_warmup_seconds=5", "perf_sample_seconds=20",
                   f"perf_physics_clock_candidate={str(candidate).lower()}", f"perf_output={result.as_posix()}"]
        if args.verbose:
            command.insert(1, "--verbose")
        save(case / "command.json", command)
        print(f"START {name}", flush=True)
        with (case / "stdout.log").open("x", encoding="utf-8") as stream:
            process = subprocess.Popen(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT,
                                       creationflags=subprocess.CREATE_NO_WINDOW)
            started, ready, close_sent = time.monotonic(), None, None
            try:
                while process.poll() is None:
                    now = time.monotonic()
                    log = runtime.read_text(encoding="utf-8", errors="replace") if runtime.exists() else ""
                    if ready is None and "[NAV] Bake complete" in log:
                        ready = now
                    if args.complete and ready is not None:
                        break
                    if ready is not None and now - ready >= args.after_nav_seconds:
                        hwnd = close_owned_window(process)
                        close_sent = time.monotonic()
                        save(case / "close_request.json", {"pid": process.pid, "hwnd": hwnd,
                             "message": "WM_CLOSE", "elapsed_seconds": now - started,
                             "after_nav_seconds": now - ready})
                        break
                    if now - started > 30:
                        raise TimeoutError("Navigation/window readiness timeout.")
                    time.sleep(0.05)
                process.wait(timeout=60 if args.complete else 15)
                finished = time.monotonic()
            finally:
                forced = process.poll() is None
                if forced:
                    process.kill()  # Only the direct process we own; never a name/global kill.
                    process.wait(timeout=10)
                save(case / "exit.json", {"returncode": process.returncode, "forced_stop": forced})
                save(case / "integrity.json", {"source_unchanged": frozen_sources() == frozen,
                                               "user_unchanged": user_hashes() == protected})
        if frozen_sources() != frozen or user_hashes() != protected:
            raise RuntimeError("Source/user data changed during test.")
        log = runtime.read_text(encoding="utf-8", errors="replace")
        summary[name] = {"returncode": process.returncode, "profile_exists": result.exists(),
                         "close_sent": close_sent is not None,
                         "close_to_exit_seconds": finished - close_sent if close_sent is not None else None,
                         "close_observed": "PERF_WINDOW_CLOSE_REQUESTED" in log,
                         "cancelled": "PERF_PROFILE_CANCELLED" in log,
                         "errors": [line for line in log.splitlines() if "ERROR:" in line or "WARNING:" in line]}
        if args.complete and result.exists():
            data = read(result)
            if initial is None:
                initial = data["initial"]
            summary[name]["normal_valid"] = (
                data["initial"] == initial and data["initial"]["bots"] == 60
                and len(data["initial"]["actors"]) == 61 and not data["match_ended"]
                and data["physics_clock_candidate"] == candidate
                and data["clock_physics_processing"] == candidate
                and data["clock_physics_priority"] == (-100 if candidate else 0)
                and data["time_scale"] == 1 and data["sample_count"] > 100
                and data["rendering_method"] == "forward_plus" and data["display_server"] != "headless"
                and 19.5 < data["match_time_end"] - data["match_time_start"] < 20.5)
        save(case / "summary.json", summary[name])
        print(f"DONE {name}: {summary[name]}", flush=True)
    save(output / "summary.json", summary)
    if args.complete:
        return 0 if all(s["returncode"] == 0 and s.get("normal_valid", False)
                        and not s["close_sent"] and not s["close_observed"] and not s["errors"]
                        for s in summary.values()) else 1
    return 0 if all(s["returncode"] == args.expected_exit and s["close_sent"] and s["close_observed"]
                    and (args.expected_exit != 2 or s["cancelled"]) and not s["errors"]
                    and s["close_to_exit_seconds"] < 2.0
                    and not s["profile_exists"] for s in summary.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
