extends SceneTree
## Read-only PCK scene inspection. Never instantiate the game or rewrite a pack.

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var split := arg.find("=")
		if split > 0:
			args[arg.left(split)] = arg.substr(split + 1)
	var expected := String(args.get("expected_user_dir", "")).replace("\\", "/").to_lower()
	if expected.is_empty() or OS.get_user_data_dir().replace("\\", "/").to_lower() != expected:
		_fail("User directory isolation mismatch.")
		return
	var output := String(args.get("output_dir", ""))
	if not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):
		_fail("A new absolute dump directory is required.")
		return
	var comparison = JSON.parse_string(FileAccess.get_file_as_string(String(args.get("comparison_path", ""))))
	if not comparison is Dictionary or not comparison.has("changed"):
		_fail("Missing comparison entries.")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("Cannot create dump directory.")
		return
	var rows: Array[Dictionary] = []
	for entry in comparison.changed:
		var path := String(entry.path)
		if not path.begins_with("res://.godot/") or not path.ends_with(".scn") or ".." in path:
			_fail("Only generated scene entries are supported.")
			return
		var packed = load(path)
		if not packed is PackedScene:
			_fail("Cannot load PackedScene: " + path)
			return
		var target := output.path_join(path.get_file().trim_suffix(".scn") + ".tscn")
		if FileAccess.file_exists(target) or ResourceSaver.save(packed, target) != OK:
			_fail("Cannot save new scene dump: " + target)
			return
		var bundled: Dictionary = packed.get("_bundled")
		rows.append({"path": path, "packed_sha256": FileAccess.get_sha256(path),
			"dump_sha256": FileAccess.get_sha256(target), "dump": target.get_file(),
			"node_count": bundled.get("node_count"), "node_ids": Array(bundled.get("node_ids", []))})
	var file := FileAccess.open(output.path_join("scenes.json"), FileAccess.WRITE)
	if file == null:
		_fail("Cannot save scene report.")
		return
	file.store_string(JSON.stringify(rows, "\t"))
	file.close()
	print("SCENE_DUMPS ", rows.size())
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
