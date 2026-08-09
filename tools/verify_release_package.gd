extends SceneTree


const REQUIRED_JSON_PATHS := [
	"res://data/asset_catalog.json",
	"res://data/game_config.json",
	"res://data/mapSpec_night_forest_expanded_candidate.json",
]
const REQUIRED_RESOURCE_PATHS := [
	"res://icon.svg",
	"res://src/Main.tscn",
	"res://src/core/SoundManager.gd",
	"res://src/core/Telemetry.gd",
	"res://src/core/VersionedJsonStore.gd",
	"res://src/entities/player/Player.tscn",
	"res://src/entities/bot/Bot.tscn",
	"res://src/entities/pickup/Pickup.tscn",
	"res://src/items/ammo_ar.tres",
	"res://src/items/ammo_railgun.tres",
	"res://src/items/ammo_shotgun.tres",
	"res://src/items/armor_ballistic_vest.tres",
	"res://src/items/armor_pickup.tres",
	"res://src/items/heal_advanced_pickup.tres",
	"res://src/items/heal_pickup.tres",
	"res://src/items/weapon_ar.tres",
	"res://src/items/weapon_ar_worn.tres",
	"res://src/items/weapon_railgun.tres",
	"res://src/items/weapon_shotgun.tres",
	"res://src/items/weapon_shotgun_worn.tres",
]
const EXPECTED_RUNTIME_PATHS := [
	"res://src/Main.gd",
	"res://src/Main.tscn",
	"res://src/core/ArtifactCatalog.gd",
	"res://src/core/AssetCatalog.gd",
	"res://src/core/BuildInfo.gd",
	"res://src/core/DebugFlags.gd",
	"res://src/core/DifficultyCatalog.gd",
	"res://src/core/DropDisplayCatalog.gd",
	"res://src/core/GameConfig.gd",
	"res://src/core/HelpCatalog.gd",
	"res://src/core/ItemData.gd",
	"res://src/core/ItemDisplayFormatter.gd",
	"res://src/core/ItemResourceCatalog.gd",
	"res://src/core/MapDefinition.gd",
	"res://src/core/MapSpec.gd",
	"res://src/core/MissionData.gd",
	"res://src/core/PressureEffectCatalog.gd",
	"res://src/core/SettingsManager.gd",
	"res://src/core/SoundManager.gd",
	"res://src/core/StatsData.gd",
	"res://src/core/Telemetry.gd",
	"res://src/core/VersionedJsonStore.gd",
	"res://src/core/WeaponSlotManager.gd",
	"res://src/core/WeaponSlotTuning.gd",
	"res://src/core/bot_stats.tres",
	"res://src/core/pistol_stats.tres",
	"res://src/core/player_stats.tres",
	"res://src/core/super_weapon_stats.tres",
	"res://src/entities/Entity.gd",
	"res://src/entities/bot/Bot.gd",
	"res://src/entities/bot/Bot.tscn",
	"res://src/entities/bot/BotDebugLabelBuilder.gd",
	"res://src/entities/bot/BotDecisionPolicy.gd",
	"res://src/entities/bot/BotDoctrine.gd",
	"res://src/entities/bot/BotMarkerFormatter.gd",
	"res://src/entities/bot/BotMovementPolicy.gd",
	"res://src/entities/bot/BotStrategicMovementPolicy.gd",
	"res://src/entities/bot/BotTuning.gd",
	"res://src/entities/bot/BotVisualKit.gd",
	"res://src/entities/bot/BotVisualSkinController.gd",
	"res://src/entities/pickup/Pickup.gd",
	"res://src/entities/pickup/Pickup.tscn",
	"res://src/entities/pickup/PickupIconResolver.gd",
	"res://src/entities/pickup/PickupPresentation.gd",
	"res://src/entities/player/Player.gd",
	"res://src/entities/player/Player.tscn",
	"res://src/entities/player/PlayerArtifactRuntime.gd",
	"res://src/entities/player/PlayerArtifactVisuals.gd",
	"res://src/entities/player/PlayerHealthPolicy.gd",
	"res://src/entities/player/PlayerMovementAudioPolicy.gd",
	"res://src/entities/player/PlayerNightReadability.gd",
	"res://src/entities/player/PlayerOccluderFader.gd",
	"res://src/entities/player/PlayerSurvivalPolicy.gd",
	"res://src/entities/player/PlayerTuning.gd",
	"res://src/environment/Bush.gd",
	"res://src/environment/Bush.tscn",
	"res://src/environment/NightWorldReadability.gd",
	"res://src/environment/Obstacle.tscn",
	"res://src/environment/WorldElement.gd",
	"res://src/fx/BulletTrail.gd",
	"res://src/fx/BulletTrail.tscn",
	"res://src/fx/DeathEffect.tscn",
	"res://src/fx/ImpactEffect.tscn",
	"res://src/fx/MuzzleFlash.tscn",
	"res://src/fx/ShotPing.gd",
	"res://src/fx/ShotPing.tscn",
	"res://src/items/ammo_ar.tres",
	"res://src/items/ammo_railgun.tres",
	"res://src/items/ammo_shotgun.tres",
	"res://src/items/armor_ballistic_vest.tres",
	"res://src/items/armor_pickup.tres",
	"res://src/items/heal_advanced_pickup.tres",
	"res://src/items/heal_pickup.tres",
	"res://src/items/weapon_ar.tres",
	"res://src/items/weapon_ar_worn.tres",
	"res://src/items/weapon_railgun.tres",
	"res://src/items/weapon_shotgun.tres",
	"res://src/items/weapon_shotgun_worn.tres",
	"res://src/maps/WorldBuilder.gd",
	"res://src/systems/hell/HellEventController.gd",
	"res://src/systems/hell/HellTuning.gd",
	"res://src/systems/loot/LootSpawnDirector.gd",
	"res://src/systems/loot/LootSpawner.gd",
	"res://src/systems/loot/SupplyDropController.gd",
	"res://src/systems/match/BotSpawnPlanner.gd",
	"res://src/systems/match/MatchBootstrap.gd",
	"res://src/systems/match/MatchRuntimeTuning.gd",
	"res://src/systems/match/MatchTuning.gd",
	"res://src/systems/match/PressureEffectApplier.gd",
	"res://src/systems/match/SimulationParticipants.gd",
	"res://src/systems/match/SpawnDistributionMetrics.gd",
	"res://src/systems/mission/MissionBadgeStore.gd",
	"res://src/systems/mission/MissionCatalog.gd",
	"res://src/systems/mission/MissionDescriptionFormatter.gd",
	"res://src/systems/mission/MissionEvaluator.gd",
	"res://src/systems/mission/MissionHudFormatter.gd",
	"res://src/systems/mission/MissionTracker.gd",
	"res://src/systems/mission/MissionTuning.gd",
	"res://src/systems/mission/PressureConditionEvaluator.gd",
	"res://src/systems/mission/PressureMissionDescriptionFormatter.gd",
	"res://src/systems/zone/ZoneController.gd",
	"res://src/ui/ArtifactIconResolver.gd",
	"res://src/ui/BuildVersionLabel.gd",
	"res://src/ui/DebugOverlay.gd",
	"res://src/ui/DifficultySelectorBuilder.gd",
	"res://src/ui/FullMapOverlay.gd",
	"res://src/ui/HelpPanelBuilder.gd",
	"res://src/ui/MenuIconFactory.gd",
	"res://src/ui/MenuVisualBuilder.gd",
	"res://src/ui/Minimap.gd",
	"res://src/ui/Minimap.tscn",
	"res://src/ui/MinimapStaticLayer.gd",
	"res://src/ui/RecordsPanelBuilder.gd",
	"res://src/ui/SettingsPanelBuilder.gd",
	"res://src/ui/WorldPresentationBuilder.gd",
	"res://src/ui/menu/MenuController.gd",
	"res://src/ui/overlays/EventTextBuilder.gd",
	"res://src/ui/panels/ArtifactSelectionPanelBuilder.gd",
	"res://src/ui/panels/HellAnnouncementBuilder.gd",
	"res://src/ui/panels/PausePanelBuilder.gd",
	"res://src/ui/panels/ResultPanelBuilder.gd",
	"res://src/ui/player/PlayerHudBuilder.gd",
	"res://src/ui/player/PlayerSlotHudRenderer.gd",
	"res://src/ui/player/PlayerWeaponIconResolver.gd",
]
const ALLOWED_GODOT_METADATA_PATHS := [
	"res://.godot/global_script_class_cache.cfg",
	"res://.godot/uid_cache.bin",
]
const FORBIDDEN_PACKAGE_PATHS := [
	"res://assets/sfx/README.txt",
	"res://data/mapSpec_ai_test_arena.json",
	"res://data/mapSpec_example.json",
	"res://data/mapSpec_mountain_forest_alpha_v3_backup_20260508.json",
	"res://data/mapSpec_night_forest_candidate.json",
	"res://data/mapSpec_poi_ammunition_pockets_probe.json",
	"res://data/mapSpec_poi_black_ridge_probe.json",
	"res://data/mapSpec_poi_broadcast_fence_probe.json",
	"res://data/mapSpec_poi_cabin_row_probe.json",
	"res://data/mapSpec_poi_false_clinic_probe.json",
	"res://data/mapSpec_poi_sluice_crossing_probe.json",
	"res://data/mapSpec_poi_supply_flats_probe.json",
	"res://data/mapSpec_poi_wire_maze_probe.json",
	"res://docs/CURRENT.md",
	"res://src/maps/TestMap.tscn",
	"res://src/tests/CombatTest.tscn",
	"res://tools/verify_release_identity.gd",
]
const EXPECTED_UNIQUE_ASSET_COUNT := 44
const EXPECTED_PNG_COUNT := 20
const EXPECTED_AUDIO_COUNT := 11
const EXPECTED_GLB_COUNT := 13


func _init() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	var pck_path := String(args.get("pck_path", ""))
	if pck_path.is_empty():
		_fail(["Missing pck_path=<absolute path> argument."])
		return
	if not FileAccess.file_exists(pck_path):
		_fail(["PCK does not exist: %s." % pck_path])
		return
	if FileAccess.file_exists("res://src/Main.tscn") \
			or FileAccess.file_exists("res://data/asset_catalog.json"):
		_fail(["Package probe must run with --path pointing at an empty host directory."])
		return
	if not ProjectSettings.load_resource_pack(pck_path, true):
		_fail(["Could not mount release PCK: %s." % pck_path])
		return

	var failures: Array[String] = []
	for path in REQUIRED_RESOURCE_PATHS:
		var loader_exists := ResourceLoader.exists(path)
		if not loader_exists and not FileAccess.file_exists(path):
			failures.append("Required resource is missing: %s." % path)
	for path in REQUIRED_JSON_PATHS:
		if not FileAccess.file_exists(path):
			failures.append("Required JSON is missing: %s." % path)
	for path in FORBIDDEN_PACKAGE_PATHS:
		if FileAccess.file_exists(path) or ResourceLoader.exists(path):
			failures.append("Forbidden package path is present: %s." % path)
	var inventory: Array[String] = []
	_collect_files("res://", inventory, failures)
	if bool(args.get("print_inventory", false)):
		inventory.sort()
		for path in inventory:
			print("PACKAGE_FILE ", path)

	var catalog := _read_json(REQUIRED_JSON_PATHS[0], failures)
	var game_config := _read_json(REQUIRED_JSON_PATHS[1], failures)
	var map_spec := _read_json(REQUIRED_JSON_PATHS[2], failures)
	var catalog_asset_paths: Dictionary = {}
	if not catalog.is_empty():
		catalog_asset_paths = _verify_catalog_assets(catalog, failures)
	_verify_inventory(inventory, catalog_asset_paths, failures)
	if game_config.is_empty():
		failures.append("Game config must be a non-empty Dictionary.")
	if not map_spec.is_empty():
		var metadata = map_spec.get("metadata", {})
		if typeof(metadata) != TYPE_DICTIONARY:
			failures.append("Packaged map metadata must be a Dictionary.")
		elif String(metadata.get("id", "")) != "night_forest_m1_candidate" \
				or String(metadata.get("name", "")) != "Night Artificial Forest":
			failures.append("Packaged map identity does not match the reviewed M1 surface.")

	if not failures.is_empty():
		_fail(failures)
		return
	print((
		"Release package smoke passed: %d catalog assets, %d JSON files, "
		+ "%d exact runtime paths, %d load probes, generated payload closure exact."
	) % [
			EXPECTED_UNIQUE_ASSET_COUNT,
			REQUIRED_JSON_PATHS.size(),
			EXPECTED_RUNTIME_PATHS.size(),
			REQUIRED_RESOURCE_PATHS.size(),
		])
	quit(0)


func _collect_files(
	directory_path: String,
	inventory: Array[String],
	failures: Array[String]
) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		failures.append("Could not inspect mounted PCK directory: %s." % directory_path)
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var path := directory_path.path_join(entry)
			if directory.current_is_dir():
				_collect_files(path, inventory, failures)
			else:
				inventory.append(path)
		entry = directory.get_next()
	directory.list_dir_end()


func _verify_inventory(
	inventory: Array[String],
	catalog_asset_paths: Dictionary,
	failures: Array[String]
) -> void:
	var expected_visible: Dictionary = {
		"res://icon.svg": true,
		"res://project.binary": true,
	}
	for path in REQUIRED_JSON_PATHS:
		expected_visible[path] = true
	for path_variant in catalog_asset_paths.keys():
		expected_visible[String(path_variant) + ".import"] = true
	for logical_path_variant in EXPECTED_RUNTIME_PATHS:
		var logical_path := String(logical_path_variant)
		match logical_path.get_extension().to_lower():
			"gd":
				expected_visible[logical_path.trim_suffix(".gd") + ".gdc"] = true
				expected_visible[logical_path + ".remap"] = true
			"tscn", "tres":
				expected_visible[logical_path + ".remap"] = true
			_:
				failures.append("Runtime manifest uses an unsupported extension: %s." % logical_path)
	for path in ALLOWED_GODOT_METADATA_PATHS:
		expected_visible[path] = true

	var actual_visible: Dictionary = {}
	var actual_payloads: Dictionary = {}
	for path in inventory:
		if path.begins_with("res://.godot/imported/") \
				or path.begins_with("res://.godot/exported/"):
			actual_payloads[path] = true
		else:
			actual_visible[path] = true

	for path_variant in expected_visible.keys():
		var path := String(path_variant)
		if not actual_visible.has(path):
			failures.append("Expected package file is missing: %s." % path)
	for path_variant in actual_visible.keys():
		var path := String(path_variant)
		if not expected_visible.has(path):
			failures.append("Unexpected package file is present: %s." % path)

	var referenced_payloads: Dictionary = {}
	for path_variant in expected_visible.keys():
		var config_path := String(path_variant)
		if not actual_visible.has(config_path):
			continue
		if config_path.ends_with(".import") or config_path.ends_with(".remap"):
			_collect_config_targets(config_path, referenced_payloads, failures)
	for path_variant in referenced_payloads.keys():
		var path := String(path_variant)
		if not actual_payloads.has(path):
			failures.append("Referenced generated payload is missing: %s." % path)
	for path_variant in actual_payloads.keys():
		var path := String(path_variant)
		if not referenced_payloads.has(path):
			failures.append("Unreferenced generated payload is present: %s." % path)


func _collect_config_targets(
	config_path: String,
	referenced_payloads: Dictionary,
	failures: Array[String]
) -> void:
	var config := ConfigFile.new()
	var load_error := config.load(config_path)
	if load_error != OK:
		failures.append("Could not parse package remap metadata %s: %s." % [
			config_path,
			error_string(load_error),
		])
		return
	var remap_target := String(config.get_value("remap", "path", ""))
	if config_path.ends_with(".import"):
		_record_payload_target(
			remap_target,
			"res://.godot/imported/",
			config_path,
			referenced_payloads,
			failures
		)
		var destination_files = config.get_value("deps", "dest_files", PackedStringArray())
		if typeof(destination_files) not in [TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY]:
			failures.append("Import dest_files must be an Array: %s." % config_path)
			return
		for destination_variant in destination_files:
			_record_payload_target(
				String(destination_variant),
				"res://.godot/imported/",
				config_path,
				referenced_payloads,
				failures
			)
		return

	if config_path.ends_with(".gd.remap"):
		var expected_script_target := config_path.trim_suffix(".gd.remap") + ".gdc"
		if remap_target != expected_script_target:
			failures.append("Compiled script remap target mismatch in %s: %s." % [
				config_path,
				remap_target,
			])
		return
	_record_payload_target(
		remap_target,
		"res://.godot/exported/",
		config_path,
		referenced_payloads,
		failures
	)


func _record_payload_target(
	target_path: String,
	required_prefix: String,
	config_path: String,
	referenced_payloads: Dictionary,
	failures: Array[String]
) -> void:
	if target_path.is_empty():
		failures.append("Package remap target is empty: %s." % config_path)
		return
	if not target_path.begins_with(required_prefix):
		failures.append("Package remap target escapes %s in %s: %s." % [
			required_prefix,
			config_path,
			target_path,
		])
		return
	referenced_payloads[target_path] = true


func _verify_catalog_assets(catalog: Dictionary, failures: Array[String]) -> Dictionary:
	var unique_paths: Dictionary = {}
	for section_name in ["audio", "icons", "materials", "props", "cosmetics"]:
		var section = catalog.get(section_name, {})
		if typeof(section) != TYPE_DICTIONARY:
			failures.append("Asset catalog section is not a Dictionary: %s." % section_name)
			continue
		for asset_id in section.keys():
			var entry = section[asset_id]
			if typeof(entry) != TYPE_DICTIONARY:
				failures.append("Asset catalog entry is not a Dictionary: %s/%s." % [
					section_name,
					asset_id,
				])
				continue
			var path := String(entry.get("path", ""))
			if not path.is_empty():
				unique_paths[path] = true

	var png_count := 0
	var audio_count := 0
	var glb_count := 0
	for path_variant in unique_paths.keys():
		var path := String(path_variant)
		if not path.begins_with("res://assets/"):
			failures.append("Catalog asset escapes the reviewed assets/** boundary: %s." % path)
			continue
		if not ResourceLoader.exists(path):
			failures.append("Catalog resource is missing from PCK: %s." % path)
			continue
		var resource := ResourceLoader.load(path)
		if resource == null:
			failures.append("Catalog resource could not be loaded from PCK: %s." % path)
			continue
		match path.get_extension().to_lower():
			"png":
				png_count += 1
				if not resource is Texture2D:
					failures.append("Catalog PNG did not load as Texture2D: %s." % path)
			"wav", "ogg":
				audio_count += 1
				if not resource is AudioStream:
					failures.append("Catalog audio did not load as AudioStream: %s." % path)
			"glb":
				glb_count += 1
				if not resource is PackedScene:
					failures.append("Catalog GLB did not load as PackedScene: %s." % path)
			_:
				failures.append("Catalog asset uses an unreviewed extension: %s." % path)

	if unique_paths.size() != EXPECTED_UNIQUE_ASSET_COUNT:
		failures.append("Expected %d unique catalog assets, found %d." % [
			EXPECTED_UNIQUE_ASSET_COUNT,
			unique_paths.size(),
		])
	if png_count != EXPECTED_PNG_COUNT:
		failures.append("Expected %d packaged PNG assets, found %d." % [
			EXPECTED_PNG_COUNT,
			png_count,
		])
	if audio_count != EXPECTED_AUDIO_COUNT:
		failures.append("Expected %d packaged audio assets, found %d." % [
			EXPECTED_AUDIO_COUNT,
			audio_count,
		])
	if glb_count != EXPECTED_GLB_COUNT:
		failures.append("Expected %d packaged GLB assets, found %d." % [
			EXPECTED_GLB_COUNT,
			glb_count,
		])
	return unique_paths


func _read_json(path: String, failures: Array[String]) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		failures.append("Could not open packaged JSON: %s." % path)
		return {}
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	if parse_error != OK:
		failures.append("Could not parse packaged JSON %s at line %d: %s." % [
			path,
			json.get_error_line(),
			json.get_error_message(),
		])
		return {}
	var parsed = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		failures.append("Packaged JSON root must be a Dictionary: %s." % path)
		return {}
	return parsed


func _parse_args(raw_args: PackedStringArray) -> Dictionary:
	var parsed := {}
	for arg in raw_args:
		var separator := arg.find("=")
		if separator > 0:
			var value := arg.substr(separator + 1)
			parsed[arg.left(separator)] = value if value not in ["true", "false"] else value == "true"
	return parsed


func _fail(failures: Array[String]) -> void:
	for failure in failures:
		push_error(failure)
	quit(1)
