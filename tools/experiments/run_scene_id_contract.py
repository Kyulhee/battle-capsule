"""Isolated Godot 4.6.2 scene-ID contract experiment, not a production exporter."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from run_release_flow import ROOT, USER_RELATIVE, digest, save, user_hashes

PROBE = Path(__file__).with_name("probe_scene_id_contract.gd")


def stable_id(identity):
    """Prototype initial ID only. Never recompute an existing node's identity."""
    return (int.from_bytes(hashlib.sha256(identity.encode("utf-8")).digest()[:4], "big")
            & 0x7fffffff) or 1


def fixtures(mode):
    keys = ["base/root", "base/Target", "base/Pulse", "derived/Child",
            "container/root", "container/First", "container/Second", "container/Marker"]
    ids = {key: stable_id(key) for key in keys}
    if len(set(ids.values())) != len(ids):
        raise ValueError("Fixture ID collision: do not fall back to random IDs")
    assigned = mode != "unassigned"
    renamed = mode.startswith("rename_")
    target = "RenamedTarget" if renamed else "Target"
    reference = target if mode == "rename_reconciled" else "Target"

    def uid(key, definition=False):
        if not assigned:
            return ""
        value = ids[key]
        if definition and mode == "rename_rehashed" and key == "base/Target":
            value = stable_id("base/RenamedTarget")
        return f" unique_id={value}"

    def id_path(field, *keys):
        return f' {field}=PackedInt32Array({", ".join(str(ids[k]) for k in keys)})' if assigned else ""

    header = '[gd_scene load_steps=2 format=3]\n\n[ext_resource type="PackedScene" path="res://base.tscn" id="1"]\n\n'
    base = f'''[gd_scene format=3]

[node name="Base" type="Node3D"{uid("base/root")}]

[node name="{target}" type="Node3D" parent="."{uid("base/Target", True)}]
position = Vector3(1, 2, 3)

[node name="Pulse" type="Timer" parent="."{uid("base/Pulse")}]

[connection signal="timeout" from="Pulse" to="{target}" method="set_position" binds=[Vector3(4, 5, 6)]]
'''
    derived = header + f'''[node name="Derived"{uid("base/root")} instance=ExtResource("1")]

[node name="{reference}" parent="."{uid("base/Target")}]
position = Vector3(7, 8, 9)

[node name="Child" type="Node3D" parent="{reference}"{id_path("parent_id_path", "base/Target")}{uid("derived/Child")}]
position = Vector3(10, 11, 12)
'''
    container = header + f'''[node name="Container" type="Node3D"{uid("container/root")}]

[node name="First" parent="."{uid("container/First")} instance=ExtResource("1")]

[node name="{reference}" parent="First"{id_path("parent_id_path", "container/First")}{uid("base/Target")}]
position = Vector3(7, 8, 9)

[node name="Second" parent="."{uid("container/Second")} instance=ExtResource("1")]

[node name="Marker" type="Node3D" parent="Second/{reference}"{id_path("parent_id_path", "container/Second", "base/Target")}{uid("container/Marker")}]
position = Vector3(10, 11, 12)

[connection signal="timeout" from="First/Pulse" to="Second/{reference}" method="set_position"{id_path("from_uid_path", "container/First", "base/Pulse")}{id_path("to_uid_path", "container/Second", "base/Target")} binds=[Vector3(13, 14, 15)]]

[editable path="First"]
[editable path="Second"]
'''
    return {"base.tscn": base, "derived.tscn": derived, "container.tscn": container}


def write_new(path, text):
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        stream.write(text)


def validate_result(mode, result):
    report, messages = result["report"], result["messages"]
    if result["exit_code"] != 0 or report.get("mode") != mode or report.get("isolation") is not True:
        raise ValueError("Execution/isolation failure")
    required = {f"{kind}/{action}" for kind in ("base", "derived", "container") for action in ("pack", "save")}
    for phase in ("source", "binary"):
        required |= {f"base/{phase}/{name}" for name in ("position", "signal")}
        required |= {f"derived/{phase}/{name}" for name in ("position", "signal", "inherited_parent_id_path")}
        required |= {f"container/{phase}/{name}" for name in ("instances_distinct", "override", "second_default",
                    "nested_parent_id_path", "base_signal", "cross_instance_signal")}
    checks = report.get("checks", {})
    if checks.keys() != required or any(type(v) is not bool for v in checks.values()):
        raise ValueError("Incomplete/non-boolean checks")
    expected_failed = set()
    allowed_warnings = []
    if mode in ("rename_preserved", "rename_rehashed"):
        expected_failed |= {f"derived/{phase}/inherited_parent_id_path" for phase in ("source", "binary")}
        allowed_warnings = [
            r"WARNING: res://(?:derived|container)\.tscn: A node in the scene this one inherits from .*recovery process.*",
            r"WARNING: Parent path '\./Target' for node 'Child' has vanished when instantiating: 'res://derived\.tscn'\.",
        ]
    if mode == "rename_rehashed":
        expected_failed |= {f"derived/{phase}/position" for phase in ("source", "binary")}
        expected_failed |= {f"container/{phase}/{name}" for phase in ("source", "binary")
                            for name in ("override", "nested_parent_id_path", "cross_instance_signal")}
        allowed_warnings += [
            r"WARNING: Node '(?:\./Target|First/Target)' was modified from inside an instance, but it has vanished\.",
            r"WARNING: Parent path '\./Second/Target' for node 'Marker' has vanished when instantiating: 'res://container\.tscn'\.",
        ]
    elif mode not in ("unassigned", "assigned", "rename_preserved", "rename_reconciled"):
        raise ValueError("Unknown fixture mode")
    if any(not any(re.fullmatch(pattern, message) for pattern in allowed_warnings) for message in messages):
        raise ValueError("Unexpected engine diagnostic")
    if {key for key, value in checks.items() if not value} != expected_failed:
        raise ValueError("Different semantic outcome; never promote expected negative cases")
    scenes = report.get("scenes", [])
    if len(scenes) != 3 or {row["scene"] for row in scenes} != {"base", "derived", "container"}:
        raise ValueError("Missing/duplicate scene evidence")
    if any(row["has_base_scene"] != (row["scene"] == "derived") for row in scenes):
        raise ValueError("Inheritance was flattened/changed")
    return not expected_failed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", required=True, type=Path)
    args = parser.parse_args()
    output = args.out_dir.resolve()
    allowed = (ROOT / "builds/verification").resolve()
    if output == allowed or not output.is_relative_to(allowed) or output.exists():
        parser.error("A NEW directory below builds/verification is required")
    engine = ROOT / "Godot_v4.6.2-stable_win64_console.exe"
    protected = Path(os.environ["APPDATA"]) / USER_RELATIVE
    before = user_hashes(protected)
    engine_hash, probe_hash = digest(engine), digest(PROBE)
    output.mkdir(parents=True)
    source = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    save(output / "inputs.json", {"source_commit": source, "engine_sha256": engine_hash,
                                  "probe_sha256": probe_hash, "runner_sha256": digest(Path(__file__)),
                                  "protected_user_sha256": before,
                                  "scope": "Synthetic scenes only; no game/PCK promotion"})
    results = {}
    passed = False
    try:
        for mode, repetitions in [("unassigned", 2), ("assigned", 2),
                                  ("rename_preserved", 1), ("rename_reconciled", 1), ("rename_rehashed", 1)]:
            for index in range(repetitions):
                key = f"{mode}_{index + 1}"
                run = output / key
                host = run / "host"
                host.mkdir(parents=True)
                write_new(host / "project.godot", '[application]\nconfig/name="SceneIdContract"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
                for name, text in fixtures(mode).items():
                    write_new(host / name, text)
                shutil.copyfile(PROBE, host / "probe.gd")
                env = os.environ.copy()
                env["APPDATA"] = str(run / "profile")
                env["LOCALAPPDATA"] = str(run / "local")
                Path(env["APPDATA"]).mkdir()
                Path(env["LOCALAPPDATA"]).mkdir()
                expected_user = Path(env["APPDATA"]) / "Godot/app_userdata/SceneIdContract"
                command = [str(engine), "--headless", "--path", str(host), "--log-file", str(run / "godot.log"),
                           "--script", "res://probe.gd", "--", f"mode={mode}",
                           f"expected_user_dir={expected_user.as_posix()}"]
                save(run / "command.json", command)
                with (run / "stdout.log").open("x", encoding="utf-8") as stream:
                    process = subprocess.run(command, cwd=host, env=env, stdout=stream,
                                             stderr=subprocess.STDOUT, timeout=60)
                report = json.loads((host / "report.json").read_text(encoding="utf-8"))
                log = (run / "stdout.log").read_text(encoding="utf-8")
                messages = re.findall(r"(?m)^(?:SCRIPT ERROR|ERROR|WARNING):.*$", log)
                result = {"exit_code": process.returncode, "report": report, "messages": messages,
                          "input_sha256": {n: digest(host / n) for n in fixtures(mode)},
                          "packed_sha256": {p.name: digest(p) for p in sorted((host / "packed").glob("*.scn"))}}
                results[key] = result
                save(run / "result.json", result)
                semantic = validate_result(mode, result)
                if user_hashes(protected) != before:
                    raise RuntimeError("Protected saves changed; stop without restoring")
                print(f"{key}: {'expected semantic rejection' if not semantic else 'semantic PASS'}", flush=True)
        comparisons = {}
        for mode in ("unassigned", "assigned"):
            left, right = results[f"{mode}_1"], results[f"{mode}_2"]
            if left["input_sha256"] != right["input_sha256"]:
                raise RuntimeError("Cold inputs differ")
            same = left["packed_sha256"] == right["packed_sha256"]
            comparisons[mode] = {"byte_identical": same, "left": left["packed_sha256"], "right": right["packed_sha256"]}
            if same != (mode == "assigned") or len(left["packed_sha256"]) != 3:
                raise RuntimeError(f"{mode}: unexpected raw-byte outcome")
        save(output / "comparison.json", comparisons)
        passed = True
    finally:
        integrity = {"user_unchanged": user_hashes(protected) == before,
                     "engine_unchanged": digest(engine) == engine_hash, "probe_unchanged": digest(PROBE) == probe_hash}
        save(output / "summary.json", {"passed": passed and all(integrity.values()),
                                       "integrity": integrity, "runs": results})
        if not all(integrity.values()):
            raise RuntimeError(f"Integrity failure: {integrity}")
    print(f"Scene ID synthetic contract PASS: {output}")


if __name__ == "__main__":
    main()
