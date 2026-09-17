extends SceneTree
## Standalone synthetic host only: never load a game scene or autoload.

var checks: Dictionary = {}
var rows: Array[Dictionary] = []
var mode := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var split := arg.find("=")
		if split > 0:
			args[arg.left(split)] = arg.substr(split + 1)
	mode = String(args.get("mode", ""))
	var expected := String(args.get("expected_user_dir", "")).replace("\\", "/").to_lower()
	if expected.is_empty() or expected != OS.get_user_data_dir().replace("\\", "/").to_lower() or root.get_child_count() != 0:
		push_error("Non-isolated synthetic host.")
		quit(1)
		return
	if FileAccess.file_exists("res://report.json") or DirAccess.dir_exists_absolute("res://packed"):
		push_error("Refusing to overwrite experiment.")
		quit(1)
		return
	DirAccess.make_dir_absolute("res://packed")
	for kind in ["base", "derived", "container"]:
		var source := load("res://%s.tscn" % kind) as PackedScene
		if source == null:
			quit(1)
			return
		var instance := source.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
		var packed := PackedScene.new()
		checks[kind + "/pack"] = packed.pack(instance) == OK
		var path := "res://packed/%s.scn" % kind
		checks[kind + "/save"] = ResourceSaver.save(packed, path) == OK
		var bundled: Dictionary = packed.get("_bundled")
		rows.append({"scene": kind, "sha256": FileAccess.get_sha256(path),
			"node_ids": Array(bundled.get("node_ids", [])),
			"node_paths": str(bundled.get("node_paths", [])),
			"id_paths": str(bundled.get("id_paths", [])),
			"connection_count": bundled.get("conn_count", 0),
			"has_base_scene": bundled.has("base_scene")})
		_check_scene(instance, kind, "source")
		instance.free()
		var reloaded := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		var roundtrip := reloaded.instantiate()
		_check_scene(roundtrip, kind, "binary")
		roundtrip.free()
	var file := FileAccess.open("res://report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"mode": mode, "isolation": true, "checks": checks, "scenes": rows}, "\t"))
	file.close()
	print("SCENE_ID_CONTRACT ", mode, " checks=", checks.size())
	quit(0)


func _check_scene(scene: Node, kind: String, phase: String) -> void:
	var prefix := kind + "/" + phase + "/"
	var target_name := "RenamedTarget" if mode.begins_with("rename_") else "Target"
	if kind == "container":
		var first := scene.get_node_or_null("First/" + target_name) as Node3D
		var second := scene.get_node_or_null("Second/" + target_name) as Node3D
		checks[prefix + "instances_distinct"] = first != null and second != null and first != second
		checks[prefix + "override"] = first != null and first.position == Vector3(7, 8, 9)
		checks[prefix + "second_default"] = second != null and second.position == Vector3(1, 2, 3)
		var marker := scene.get_node_or_null("Second/" + target_name + "/Marker") as Node3D
		checks[prefix + "nested_parent_id_path"] = marker != null and marker.position == Vector3(10, 11, 12) and marker.owner == scene
		scene.get_node("First/Pulse").emit_signal("timeout")
		checks[prefix + "base_signal"] = first != null and first.position == Vector3(4, 5, 6)
		checks[prefix + "cross_instance_signal"] = second != null and second.position == Vector3(13, 14, 15)
	else:
		var target := scene.get_node_or_null(target_name) as Node3D
		var position := Vector3(7, 8, 9) if kind == "derived" else Vector3(1, 2, 3)
		checks[prefix + "position"] = target != null and target.position == position
		if kind == "derived":
			var child := scene.get_node_or_null(target_name + "/Child") as Node3D
			checks[prefix + "inherited_parent_id_path"] = child != null and child.position == Vector3(10, 11, 12) and child.owner == scene
		scene.get_node("Pulse").emit_signal("timeout")
		checks[prefix + "signal"] = target != null and target.position == Vector3(4, 5, 6)
