"""Verify an existing E067 PCK's controlled normal-result/restart/relaunch flow.

Windows only. Every invocation requires a NEW output directory. Child APPDATA
is isolated and independently verified before any packaged autoload is started.
This is not EXE/manual/full-match or simulation-isolation certification.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "builds/playtest/E-067_78b5180"
EXPECTED = {
    "BattleCapsule_E067_78b5180.exe": "b241a13f6fb1e7fb297018d6d622601f9d68a5b4f8b0b389ed7f6cd5690e238d",
    "BattleCapsule_E067_78b5180.pck": "8fe8876ecae70904cf440c4a1419867f39dd838592443b84df04853842d4a271",
}
USER_RELATIVE = Path("Godot/app_userdata/BattleRoyalePrototype")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def user_hashes(directory):
    return {p.name: digest(p) for p in sorted(directory.iterdir())
            if p.is_file() and p.suffix in (".json", ".cfg", ".bak")}


def save(path, value):
    with path.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)


def validate_phase(result, expected_user):
    report = result["report"]
    if result["exit_code"] != 0 or report.get("passed") is not True or not result["log_clean"]:
        raise RuntimeError(f"{result['phase']} failed; inspect preserved logs/report")
    if Path(report.get("user_dir", "")).resolve() != expected_user.resolve():
        raise RuntimeError("Reported user directory does not match isolated profile")
    required = {"user_dir_isolated"}
    if result["phase"] == "isolation":
        required |= {"no_autoloads_in_preflight", "empty_host_in_preflight"}
    else:
        required |= {"packaged_E067_label", "default_persistence_paths", "two_persistent_records"}
    if not required.issubset(report.get("checks", [])):
        raise RuntimeError("Incomplete phase evidence")


def validate_relaunch(writer, reader):
    if writer["report"]["records"] != reader["report"]["records"]:
        raise RuntimeError("Relaunch changed full record payloads")
    if writer["profile_sha256"] != reader["profile_sha256"]:
        raise RuntimeError("Relaunch modified persisted profile files")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", required=True, type=Path)
    parser.add_argument("--godot", type=Path, default=ROOT / "Godot_v4.6.2-stable_win64_console.exe")
    args = parser.parse_args()
    if os.name != "nt":
        parser.error("Windows APPDATA isolation only")
    output = args.out_dir.resolve()
    allowed = (ROOT / "builds/verification").resolve()
    if not output.is_relative_to(allowed) or output == allowed:
        parser.error("--out-dir must be a new child of builds/verification")
    if output.exists():
        parser.error("Refusing to reuse an existing output/profile")
    artifacts = {name: digest(PACKAGE / name) for name in EXPECTED}
    if artifacts != EXPECTED:
        parser.error("E067 artifact SHA256 mismatch; no game started")
    protected = Path(os.environ["APPDATA"]) / USER_RELATIVE
    before = user_hashes(protected)
    godot = args.godot.resolve()
    engine_hash = digest(godot)
    scripts = [Path(__file__).resolve(), ROOT / "tools/probe_release_flow.gd"]
    source_hashes = {str(p): digest(p) for p in scripts}
    output.mkdir(parents=True)
    host = output / "host"
    host.mkdir()
    # No autoloads or game resources: prove the exact packaged user-dir settings
    # resolve beneath child APPDATA before allowing --main-pack in later phases.
    (host / "project.godot").write_text(
        'config_version=5\n[application]\nconfig/name="Battle Capsule"\n'
        'config/use_custom_user_dir=true\n'
        'config/custom_user_dir_name="Godot/app_userdata/BattleRoyalePrototype"\n',
        encoding="utf-8")
    env = os.environ.copy()
    for key in ("APPDATA", "LOCALAPPDATA"):
        target = output / key.lower()
        target.mkdir()
        env[key] = str(target)
    expected_user = Path(env["APPDATA"]) / USER_RELATIVE
    save(output / "inputs.json", {
        "source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "artifact_source_commit": "78b5180850e0656ed5fd316c75053ea7b50ea4a2",
        "artifacts_sha256": artifacts, "engine_sha256": engine_hash,
        "harness_sha256": source_hashes, "user_sha256": before,
        "expected_user_dir": str(expected_user),
        "scope": "E067 PCK; controlled deaths, real Main result/restart; not natural/manual play",
    })
    results = []
    success = False
    try:
        for phase in ("isolation", "write_restart", "relaunch"):
            command = [str(godot), "--headless", "--path", str(host),
                       "--log-file", str(output / f"{phase}.godot.log")]
            if phase != "isolation":
                command += ["--main-pack", str(PACKAGE / "BattleCapsule_E067_78b5180.pck")]
            command += ["--script", str(scripts[1]), "--", f"phase={phase}",
                        f"expected_user_dir={expected_user.as_posix()}",
                        f"report_path={(output / (phase + '.json')).as_posix()}"]
            save(output / f"{phase}.command.json", command)
            with (output / f"{phase}.stdout.log").open("x", encoding="utf-8") as log:
                process = subprocess.run(command, cwd=host, env=env, stdout=log,
                                         stderr=subprocess.STDOUT, timeout=180)
            text = (output / f"{phase}.stdout.log").read_text(encoding="utf-8")
            report_path = output / f"{phase}.json"
            report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.exists() else {}
            result = {"phase": phase, "exit_code": process.returncode,
                      "report": report, "profile_sha256": user_hashes(expected_user),
                      "log_clean": not bool(re.search(r"(?m)^(?:SCRIPT ERROR|ERROR|WARNING):", text))}
            results.append(result)
            if user_hashes(protected) != before:
                raise RuntimeError("Protected user files changed; stop without restoring/overwriting")
            validate_phase(result, expected_user)
            if phase == "relaunch":
                validate_relaunch(results[1], result)
            print(f"{phase}: PASS", flush=True)
        success = True
    finally:
        integrity = {
            "user_unchanged": user_hashes(protected) == before,
            "artifacts_unchanged": {n: digest(PACKAGE / n) for n in EXPECTED} == artifacts,
            "harness_unchanged": {str(p): digest(p) for p in scripts} == source_hashes,
            "engine_unchanged": digest(godot) == engine_hash,
        }
        save(output / "summary.json", {"passed": success and all(integrity.values()),
                                       "integrity": integrity, "phases": results})
        if not all(integrity.values()):
            raise RuntimeError(f"Integrity failure: {integrity}")
    print(f"Release flow PASS: {output}")


if __name__ == "__main__":
    main()
