extends SceneTree


const BuildInfoScript = preload("res://src/core/BuildInfo.gd")
const BuildVersionLabelScript = preload("res://src/ui/BuildVersionLabel.gd")

const REQUIRED_EXPORT_SCENE := "res://src/Main.tscn"
const REQUIRED_EXPORT_INCLUDES := [
	"assets/**",
	"src/**",
	"data/asset_catalog.json",
	"data/game_config.json",
	"data/mapSpec_night_forest_expanded_candidate.json",
]
const REQUIRED_EXPORT_EXCLUDES := [
	"builds/**",
	"tools/**",
	"src/tests/**",
	"src/maps/TestMap.tscn",
	"docs/**",
	"asset_generator/**",
	"plan_report/**",
	".agents/**",
	".claude/**",
	".understand-anything/**",
	"assets/sfx/README.txt",
	"debug_screenshot*.png",
	"스크린샷*.png",
	"*.png.import",
	"*.gd.uid",
]


func _init() -> void:
	if not _verify_build_info():
		return
	if not _verify_project_identity():
		return
	if not _verify_export_preset():
		return
	if not _verify_menu_version():
		return

	print("Release identity smoke passed: %s %s (%s)." % [
		BuildInfoScript.PRODUCT_NAME,
		BuildInfoScript.DISPLAY_VERSION,
		BuildInfoScript.WINDOWS_VERSION,
	])
	quit(0)


func _verify_build_info() -> bool:
	if BuildInfoScript.PRODUCT_NAME != "Battle Capsule":
		return _fail_bool("Public product name must remain Battle Capsule.")
	if BuildInfoScript.EXECUTABLE_BASENAME != "BattleCapsule":
		return _fail_bool("Public executable basename must remain BattleCapsule.")
	var version_pattern := RegEx.new()
	if version_pattern.compile("^\\d+\\.\\d+\\.\\d+$") != OK \
			or version_pattern.search(BuildInfoScript.PRODUCT_VERSION) == null:
		return _fail_bool("Product version source must use a numeric major.minor.patch core.")
	if BuildInfoScript.WINDOWS_VERSION != BuildInfoScript.PRODUCT_VERSION + ".0":
		return _fail_bool("Windows version must derive from the product version.")
	if BuildInfoScript.DISPLAY_VERSION != "v%s-%s" % [
		BuildInfoScript.PRODUCT_VERSION,
		BuildInfoScript.RELEASE_CHANNEL,
	]:
		return _fail_bool("Display version must derive from product version and channel.")
	if BuildInfoScript.LEGACY_USER_DIR_NAME != "Godot/app_userdata/BattleRoyalePrototype":
		return _fail_bool("Legacy user directory changed without a save migration.")
	return true


func _verify_project_identity() -> bool:
	if String(ProjectSettings.get_setting("application/config/name", "")) != BuildInfoScript.PRODUCT_NAME:
		return _fail_bool("project.godot product name does not match BuildInfo.")
	if String(ProjectSettings.get_setting("application/config/icon", "")) != BuildInfoScript.ICON_PATH:
		return _fail_bool("project.godot icon does not match BuildInfo.")
	if not bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false)):
		return _fail_bool("Visible rebrand must preserve an explicit user data directory.")
	if String(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")) \
			!= BuildInfoScript.LEGACY_USER_DIR_NAME:
		return _fail_bool("Visible rebrand would move the existing user:// directory.")
	var user_dir := ProjectSettings.globalize_path("user://").replace("\\", "/").trim_suffix("/")
	if not user_dir.ends_with("/" + BuildInfoScript.LEGACY_USER_DIR_NAME):
		return _fail_bool("Resolved user:// path no longer points at the existing save directory.")
	return true


func _verify_export_preset() -> bool:
	var presets := ConfigFile.new()
	var load_error := presets.load("res://export_presets.cfg")
	if load_error != OK:
		return _fail_bool("Could not load export_presets.cfg: %s." % error_string(load_error))

	if String(presets.get_value("preset.0", "name", "")) != "Windows Desktop":
		return _fail_bool("Windows release preset is missing.")
	if String(presets.get_value("preset.0", "platform", "")) != "Windows Desktop":
		return _fail_bool("Preset 0 must remain the Windows Desktop target.")
	if not _verify_export_boundary(presets, "preset.0", "Windows"):
		return false
	if String(presets.get_value("preset.0", "export_path", "")) \
			!= "./%s.exe" % BuildInfoScript.EXECUTABLE_BASENAME:
		return _fail_bool("Windows executable name does not match BuildInfo.")

	if int(presets.get_value("preset.0.options", "debug/export_console_wrapper", 1)) != 0:
		return _fail_bool("Public Windows export must not open a console wrapper.")
	if String(presets.get_value("preset.0.options", "binary_format/architecture", "")) != "x86_64":
		return _fail_bool("First public Windows target must remain x86_64.")
	if not bool(presets.get_value("preset.0.options", "application/modify_resources", false)):
		return _fail_bool("Windows metadata embedding must remain enabled.")
	if String(presets.get_value("preset.0.options", "application/icon", "")) \
			!= BuildInfoScript.ICON_PATH:
		return _fail_bool("Windows icon does not match BuildInfo.")
	if String(presets.get_value("preset.0.options", "application/file_version", "")) \
			!= BuildInfoScript.WINDOWS_VERSION:
		return _fail_bool("Windows file version does not match BuildInfo.")
	if String(presets.get_value("preset.0.options", "application/product_version", "")) \
			!= BuildInfoScript.WINDOWS_VERSION:
		return _fail_bool("Windows product version does not match BuildInfo.")
	if String(presets.get_value("preset.0.options", "application/product_name", "")) \
			!= BuildInfoScript.PRODUCT_NAME:
		return _fail_bool("Windows product name does not match BuildInfo.")
	if String(presets.get_value("preset.0.options", "application/file_description", "")) \
			!= BuildInfoScript.FILE_DESCRIPTION:
		return _fail_bool("Windows file description does not match BuildInfo.")

	if bool(presets.get_value("preset.1", "runnable", true)):
		return _fail_bool("macOS must remain outside the first public runnable target.")
	if not _verify_export_boundary(presets, "preset.1", "macOS"):
		return false
	if String(presets.get_value("preset.1.options", "application/name", "")) \
			!= BuildInfoScript.PRODUCT_NAME:
		return _fail_bool("Deferred macOS preset carries stale product branding.")
	return true


func _verify_export_boundary(presets: ConfigFile, section: String, target_name: String) -> bool:
	if String(presets.get_value(section, "export_filter", "")) != "scenes":
		return _fail_bool("%s export must use the selected-scene dependency boundary." % target_name)
	var export_scenes: PackedStringArray = presets.get_value(
		section,
		"export_files",
		PackedStringArray()
	)
	if export_scenes.size() != 1 or export_scenes[0] != REQUIRED_EXPORT_SCENE:
		return _fail_bool("%s export must select only src/Main.tscn." % target_name)
	if int(presets.get_value(section, "script_export_mode", -1)) != 2:
		return _fail_bool("%s export must keep compressed compiled scripts." % target_name)
	var include_entries := _csv_entries(String(presets.get_value(section, "include_filter", "")))
	if include_entries != REQUIRED_EXPORT_INCLUDES:
		return _fail_bool(
			"%s export must include only runtime source/assets and reviewed dynamic JSON files." \
					% target_name
		)
	var exclude_entries := _csv_entries(String(presets.get_value(section, "exclude_filter", "")))
	for required_path in REQUIRED_EXPORT_EXCLUDES:
		if not exclude_entries.has(required_path):
			return _fail_bool("%s export boundary is missing: %s." % [target_name, required_path])
	return true


func _verify_menu_version() -> bool:
	var label: Label = BuildVersionLabelScript.new()
	label._ready()
	var rendered_version := label.text
	label.free()
	if rendered_version != BuildInfoScript.DISPLAY_VERSION:
		return _fail_bool("Main menu version label does not use BuildInfo.")

	var scene_text := FileAccess.get_file_as_string("res://src/Main.tscn")
	if scene_text.is_empty():
		return _fail_bool("Could not read Main.tscn.")
	if not scene_text.contains("res://src/ui/BuildVersionLabel.gd"):
		return _fail_bool("Main menu version label script is not attached.")
	if scene_text.contains("v1.7.3.1"):
		return _fail_bool("Main menu still contains the legacy version string.")
	var label_start := scene_text.find("[node name=\"VersionLabel\"")
	var label_end := scene_text.find("[node name=\"ResultPanel\"", label_start + 1)
	if label_start < 0 or label_end < 0:
		return _fail_bool("Could not find the Main menu version-label scene block.")
	var label_block := scene_text.substr(label_start, label_end - label_start)
	if not label_block.contains("offset_left = -168.0") \
			or not label_block.contains("offset_right = -8.0"):
		return _fail_bool("Main menu version label is too narrow for the release channel.")
	return true


func _csv_entries(raw_value: String) -> Array[String]:
	var entries: Array[String] = []
	for raw_entry in raw_value.split(",", false):
		var entry := raw_entry.strip_edges()
		if not entry.is_empty():
			entries.append(entry)
	return entries


func _fail_bool(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
