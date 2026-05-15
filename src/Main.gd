extends Node3D

@export var player_scene: PackedScene = preload("res://src/entities/player/Player.tscn")
@export var bot_scene: PackedScene = preload("res://src/entities/bot/Bot.tscn")
@export var bot_count: int = 11
var is_simulation: bool = false

enum GameState { MENU, PLAYING, RESULT }
var current_state: GameState = GameState.MENU

enum Difficulty { EASY, NORMAL, HARD, HELL }
var difficulty: Difficulty = Difficulty.NORMAL
var _difficulty_selector: Dictionary = {}
var _records_selected_diff: int = 1

# Hell events
enum HellModifier { SCARCITY, BARRAGE, ALL_AGGRESSIVE }
var hell_modifier: HellModifier = HellModifier.SCARCITY
var _hell_announce_active: bool = false
var _hell_announce_panel: Control = null
var _pause_panel: Control = null

@export var loot_count: int = 40
@export var spawn_radius: float = 45.0

var railgun_item: ItemData = null
var pickup_scene: PackedScene = null
var item_templates: Array[ItemData] = []
var extra_consumable_templates: Array[ItemData] = []
var weapon_templates: Array[ItemData] = []
var consumable_templates: Array[ItemData] = []

var loot_hotspots: Array[Dictionary] = []
var loot_spawner = null
var _spawn_positions: Array = []

var zone = null
@export var zone_wait_time: float = 30.0
@export var zone_shrink_time: float = 20.0
@export var zone_damage: float = 2.0
@export var zone_initial_timer: float = 15.0
var zone_stage_configs: Dictionary = {}
var alive_count: int = 0
var game_over: bool = false
var player_ref: Entity = null
var match_timer: float = 0.0
var mission_tracker = null  # MissionTracker instance
var pressure_missions_enabled: bool = false
var pressure_opt_in_hard: bool = false  # 어려움 난이도 압박 미션 opt-in
var heal_pickup_banned: bool = false    # 다음 존까지 힐 픽업 불가
var heal_ban_until_stage: int = -1
var railgun_unlimited_until_stage: int = -1  # 레일건 무제한 (v1.4.1에서 Player 연동)
var _artifact_panel: Control = null
var _pending_artifact: Dictionary = {}

var _result_panel_nodes: Dictionary = {}

const ArtifactCatalogScript = preload("res://src/core/ArtifactCatalog.gd")
const ArtifactSelectionPanelBuilderScript = preload("res://src/ui/panels/ArtifactSelectionPanelBuilder.gd")
const AssetCatalogScript = preload("res://src/core/AssetCatalog.gd")
const BotDoctrineScript = preload("res://src/entities/bot/BotDoctrine.gd")
const BotSpawnPlannerScript = preload("res://src/systems/match/BotSpawnPlanner.gd")
const DifficultySelectorBuilderScript = preload("res://src/ui/DifficultySelectorBuilder.gd")
const EventTextBuilderScript = preload("res://src/ui/overlays/EventTextBuilder.gd")
const GameConfigScript = preload("res://src/core/GameConfig.gd")
const DebugFlagsScript = preload("res://src/core/DebugFlags.gd")
const DebugOverlayScript = preload("res://src/ui/DebugOverlay.gd")
const HelpPanelBuilderScript = preload("res://src/ui/HelpPanelBuilder.gd")
const HellEventControllerScript = preload("res://src/core/HellEventController.gd")
const HellAnnouncementBuilderScript = preload("res://src/ui/panels/HellAnnouncementBuilder.gd")
const ItemResourceCatalogScript = preload("res://src/core/ItemResourceCatalog.gd")
const LootSpawnerScript = preload("res://src/core/LootSpawner.gd")
const LootSpawnDirectorScript = preload("res://src/systems/match/LootSpawnDirector.gd")
const MenuControllerScript = preload("res://src/ui/menu/MenuController.gd")
const MenuIconFactoryScript = preload("res://src/ui/MenuIconFactory.gd")
const MenuVisualBuilderScript = preload("res://src/ui/MenuVisualBuilder.gd")
const MatchBootstrapScript = preload("res://src/systems/match/MatchBootstrap.gd")
const MatchTuningScript = preload("res://src/systems/match/MatchTuning.gd")
const MissionTrackerScript = preload("res://src/core/MissionTracker.gd")
const PausePanelBuilderScript = preload("res://src/ui/panels/PausePanelBuilder.gd")
const PressureEffectApplierScript = preload("res://src/systems/match/PressureEffectApplier.gd")
const RecordsPanelBuilderScript = preload("res://src/ui/RecordsPanelBuilder.gd")
const ResultPanelBuilderScript = preload("res://src/ui/panels/ResultPanelBuilder.gd")
const SettingsPanelBuilderScript = preload("res://src/ui/SettingsPanelBuilder.gd")
const SupplyDropControllerScript = preload("res://src/core/SupplyDropController.gd")
const ZoneControllerScript = preload("res://src/core/ZoneController.gd")

# MapSpec & Builder
const MapSpecScript = preload("res://src/core/MapSpec.gd")
var map_spec = null
@onready var world_builder = $WorldBuilder

# Navigation
var _nav_region: NavigationRegion3D = null

# v1.8 expansion foundation
var asset_catalog = null
var game_config = null
var debug_flags = null
var debug_overlay = null
var supply_controller = null
var hell_events = null
var menu_controller = null

# Dynamic Supply
var supply_telegraphed: bool = false
var supply_spawned: bool = false
var supply_pos: Vector3 = Vector3.ZERO
var supply_timer: float = 0.0
var supply_pillar: MeshInstance3D = null
var zone_ring: MeshInstance3D = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	loot_spawner = LootSpawnerScript.new()
	supply_controller = SupplyDropControllerScript.new()
	hell_events = HellEventControllerScript.new()
	hell_events.event_text_requested.connect(_show_event_text)
	_configure_item_resources()
	menu_controller = MenuControllerScript.new()
	menu_controller.configure($CanvasLayer/Control)
	asset_catalog = AssetCatalogScript.new()
	asset_catalog.load_or_default()
	_configure_asset_catalog()
	game_config = GameConfigScript.new()
	game_config.load_or_default()
	_apply_game_config()
	debug_flags = DebugFlagsScript.new()
	debug_flags.load_from_cmdline(OS.get_cmdline_user_args())
	if debug_flags.enabled:
		print("[DEBUG] Flags: %s" % debug_flags.describe())
	_load_settings()
	# Check for autostart
	var autostart_requested = false
	for arg in OS.get_cmdline_user_args():
		_apply_cmdline_arg(arg)
		if "autostart=true" in arg:
			autostart_requested = true
	if autostart_requested:
		is_simulation = true
		Engine.time_scale = 5.0
		_load_map_spec()
		if map_spec:
			if world_builder:
				world_builder.generate_world(map_spec)
			_register_loot_hotspots()
		_setup_navigation()
		start_game()
		return

	print("[MAIN] Starting initialization...")
	_load_map_spec()
	_show_panel("MainMenu")
	
	# Create World Zone Ring
	zone_ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.98
	torus.outer_radius = 1.0
	zone_ring.mesh = torus
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.6, 1.0, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.6, 1.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	zone_ring.mesh.surface_set_material(0, mat)
	add_child(zone_ring)
	zone_ring.position.y = 0.1
	
	if map_spec:
		print("[MAIN] MapSpec loaded successfully: ", map_spec.metadata.get("name", "Unknown"))
		if world_builder:
			print("[MAIN] Generating world via WorldBuilder...")
			world_builder.generate_world(map_spec)
		_setup_navigation()
		_register_loot_hotspots()
			
	var vbox = $CanvasLayer/Control/MainMenuPanel/VBoxContainer
	_setup_menu_visuals()

	# Difficulty selector (inserted before StartBtn)
	var start_btn = $CanvasLayer/Control/MainMenuPanel/VBoxContainer/StartBtn
	_difficulty_selector = DifficultySelectorBuilderScript.insert(
		vbox,
		$CanvasLayer/Control/MainMenuPanel,
		start_btn,
		difficulty as int,
		Callable(self, "_on_difficulty_btn"),
		Callable(self, "_on_pressure_opt_in_toggled"),
		Callable(self, "_apply_btn_style")
	)

	menu_controller.connect_main_buttons(
		Callable(self, "_on_start_btn_pressed"),
		Callable(self, "_on_records_pressed"),
		Callable(self, "_on_help_pressed"),
		Callable(self, "_on_settings_pressed"),
		Callable(get_tree(), "quit"),
		Callable(self, "_apply_btn_style")
	)

	_setup_result_panel()

	menu_controller.connect_secondary_close(Callable(self, "_show_panel").bind("MainMenu"))
	_setup_secondary_panels()

	if is_simulation:
		start_game()
		return

	if has_node("/root/Telemetry"):
		var tel = get_node("/root/Telemetry")
		if tel.has_meta("_restart_difficulty"):
			difficulty = tel.get_meta("_restart_difficulty") as Difficulty
			tel.remove_meta("_restart_difficulty")
			_update_diff_highlights()
			if tel.has_meta("_restart_artifact"):
				_pending_artifact = tel.get_meta("_restart_artifact")
				tel.remove_meta("_restart_artifact")
			start_game()

func _on_start_btn_pressed():
	_show_artifact_select()

func _show_artifact_select():
	_close_artifact_panel()
	var catalog = ArtifactCatalogScript.starting_artifacts(difficulty as int)
	_artifact_panel = ArtifactSelectionPanelBuilderScript.show(
		$CanvasLayer/Control,
		catalog,
		Callable(self, "_on_artifact_selected"),
		Callable(self, "_on_artifact_skipped"),
		Callable(self, "_apply_btn_style")
	)

func _on_artifact_selected(artifact: Dictionary):
	_close_artifact_panel()
	_pending_artifact = artifact
	start_game()

func _on_artifact_skipped():
	_close_artifact_panel()
	_pending_artifact = {}
	start_game()

func _close_artifact_panel():
	if is_instance_valid(_artifact_panel):
		_artifact_panel.queue_free()
	_artifact_panel = null

func start_game():
	current_state = GameState.PLAYING
	game_over = false
	match_timer = 0.0
	zone = MatchBootstrapScript.create_zone(
		ZoneControllerScript,
		zone_wait_time,
		zone_shrink_time,
		zone_damage,
		_zone_initial_timer(),
		zone_stage_configs,
		Callable(self, "_on_zone_stage_changed"),
		Callable(self, "_on_zone_warning")
	)
	
	_show_panel("HUD")
	_ensure_debug_overlay()

	# 랜덤 보너스 미션 자동 배정 (아티팩트와 불가능한 조합 제외)
	mission_tracker = MatchBootstrapScript.create_mission_tracker(
		MissionTrackerScript,
		_pending_artifact,
		Callable(self, "_is_bonus_mission_feasible")
	)

	# 압박 미션 활성화 여부
	var pressure_state = MatchBootstrapScript.initial_pressure_state(
		difficulty as int,
		pressure_opt_in_hard,
		Difficulty.HARD,
		Difficulty.HELL
	)
	heal_pickup_banned = pressure_state.get("heal_pickup_banned", false)
	heal_ban_until_stage = pressure_state.get("heal_ban_until_stage", -1)
	railgun_unlimited_until_stage = pressure_state.get("railgun_unlimited_until_stage", -1)
	pressure_missions_enabled = pressure_state.get("pressure_missions_enabled", false)

	if has_node("/root/Telemetry"):
		var tel = get_node("/root/Telemetry")
		tel.current_difficulty = difficulty as int
		tel.start_match()
		tel.set_stage(1)
		tel.log_mission_start(mission_tracker.active_mission.id)  # start_match 이후에 호출
		
	alive_count = bot_count + 1
	_categorize_templates()
	spawn_entities()
	_spawn_initial_loot()
	if difficulty == Difficulty.HELL and not is_simulation:
		hell_modifier = MatchBootstrapScript.pick_hell_modifier(0, 2) as HellModifier
		hell_events.configure(game_config)
		hell_events.start_match(
			self,
			hell_modifier as int,
			$CanvasLayer/Control,
			get_node_or_null("/root/Telemetry")
		)
		_show_hell_announcement()
	
	# Final Minimap Sync
	var minimap = get_node_or_null("CanvasLayer/Control/HUD/Minimap")
	if minimap and minimap.has_method("set_map_spec"):
		var minimap_features: Array[Dictionary] = []
		if world_builder and world_builder.has_method("get_minimap_features"):
			minimap_features = world_builder.get_minimap_features()
		minimap.set_map_spec(map_spec, minimap_features)

	# Apply artifact to player (skipped in simulation)
	if player_ref and player_ref.has_method("apply_artifact") and not is_simulation:
		var art = ArtifactCatalogScript.prepare_for_difficulty(_pending_artifact, difficulty as int)
		player_ref.apply_artifact(art)
		_pending_artifact = {}

func _show_panel(panel_name: String):
	if menu_controller:
		menu_controller.show_panel(panel_name)

func _on_records_pressed():
	_show_panel("Records")
	RecordsPanelBuilderScript.setup_controls(
		$CanvasLayer/Control/RecordsPanel/VBox,
		Callable(self, "_on_records_diff_tab"),
		Callable(self, "_on_records_clear"),
		Callable(self, "_apply_btn_style")
	)
	_populate_records_list()

func _on_records_diff_tab(diff: int):
	_records_selected_diff = diff
	_populate_records_list()

func _on_records_clear():
	if has_node("/root/Telemetry"):
		get_node("/root/Telemetry").clear_history()
	_populate_records_list()

func _on_help_pressed():
	_show_panel("Help")

func _populate_records_list():
	var tel = get_node_or_null("/root/Telemetry")
	RecordsPanelBuilderScript.populate_list($CanvasLayer/Control/RecordsPanel/VBox, _records_selected_diff, tel)

func restart_game():
	if has_node("/root/Telemetry"):
		var tel = get_node("/root/Telemetry")
		tel.set_meta("_restart_difficulty", difficulty as int)
		var art = _pending_artifact
		if art.is_empty() and player_ref != null and is_instance_valid(player_ref):
			art = player_ref.get("active_artifact") if player_ref.get("active_artifact") != null else {}
		tel.set_meta("_restart_artifact", art)
	get_tree().paused = false
	get_tree().reload_current_scene()

func return_to_menu():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _toggle_pause():
	if is_instance_valid(_pause_panel):
		_pause_panel.queue_free()
		_pause_panel = null
		get_tree().paused = false
	else:
		get_tree().paused = true
		_pause_panel = _create_pause_panel()
		$CanvasLayer/Control.add_child(_pause_panel)

func _create_pause_panel() -> Control:
	return PausePanelBuilderScript.build(
		Callable(self, "_toggle_pause"),
		Callable(self, "restart_game"),
		Callable(self, "return_to_menu"),
		Callable(self, "_apply_btn_style")
	)

func _input(event):
	if not (event is InputEventKey) or not event.pressed: return
	match event.keycode:
		KEY_F12:
			_take_screenshot("debug_screenshot_manual.png")
		KEY_ESCAPE:
			if _hell_announce_active:
				_dismiss_hell_announcement()
			elif current_state == GameState.PLAYING:
				_toggle_pause()
		KEY_SPACE:
			if _hell_announce_active:
				_dismiss_hell_announcement()

func _take_screenshot(file_name: String):
	var viewport = get_viewport()
	if not viewport: return
	
	var tex = viewport.get_texture()
	if not tex: return
	
	var img = tex.get_image()
	if img:
		var err = img.save_png("res://" + file_name)
		if err == OK:
			print("[MAIN] Screenshot saved to res://", file_name)
		else:
			# If res:// is read-only, try user://
			img.save_png("user://" + file_name)
			print("[MAIN] res:// write failed, saved to user://", file_name)

func _configure_asset_catalog():
	var sfx = get_node_or_null("/root/Sfx")
	if sfx and sfx.has_method("set_asset_catalog"):
		sfx.set_asset_catalog(asset_catalog)

func _configure_item_resources():
	pickup_scene = ItemResourceCatalogScript.pickup_scene()
	railgun_item = ItemResourceCatalogScript.supply_railgun_item()
	item_templates = ItemResourceCatalogScript.default_item_templates()
	extra_consumable_templates = ItemResourceCatalogScript.extra_consumable_templates()

func _apply_game_config():
	_apply_match_tuning(MatchTuningScript.from_game_config(game_config, _current_match_tuning()))

func _current_match_tuning() -> Dictionary:
	return {
		"bot_count": bot_count,
		"loot_count": loot_count,
		"spawn_radius": spawn_radius,
		"zone_wait_time": zone_wait_time,
		"zone_shrink_time": zone_shrink_time,
		"zone_damage": zone_damage,
		"zone_initial_timer": zone_initial_timer,
		"zone_stage_configs": zone_stage_configs,
	}

func _apply_match_tuning(tuning: Dictionary):
	if tuning.is_empty():
		return
	if tuning.has("bot_count"):
		bot_count = int(tuning["bot_count"])
	if tuning.has("loot_count"):
		loot_count = int(tuning["loot_count"])
	if tuning.has("spawn_radius"):
		spawn_radius = float(tuning["spawn_radius"])
	if tuning.has("zone_wait_time"):
		zone_wait_time = float(tuning["zone_wait_time"])
	if tuning.has("zone_shrink_time"):
		zone_shrink_time = float(tuning["zone_shrink_time"])
	if tuning.has("zone_damage"):
		zone_damage = float(tuning["zone_damage"])
	if tuning.has("zone_initial_timer"):
		zone_initial_timer = float(tuning["zone_initial_timer"])
	if tuning.has("zone_stage_configs"):
		zone_stage_configs = tuning["zone_stage_configs"].duplicate(true)
	if loot_spawner and loot_spawner.has_method("configure_count"):
		loot_spawner.configure_count(loot_count)

func _get_difficulty_params() -> Dictionary:
	if game_config:
		var params = game_config.get_difficulty_params(difficulty as int)
		if not params.is_empty():
			return params
	return {}

func _zone_initial_timer() -> float:
	return zone_initial_timer

func _ensure_debug_overlay():
	if not debug_flags or not debug_flags.enabled or not debug_flags.overlay_enabled:
		return
	if is_instance_valid(debug_overlay):
		return
	var parent = get_node_or_null("CanvasLayer/Control/HUD")
	if not parent:
		parent = get_node_or_null("CanvasLayer/Control")
	if not parent:
		return
	debug_overlay = DebugOverlayScript.new()
	parent.add_child(debug_overlay)
	debug_overlay.configure(self, debug_flags)

func debug_enabled(flag: String) -> bool:
	return debug_flags != null and debug_flags.has_method("is_enabled") and debug_flags.is_enabled(flag)

func debug_log(flag: String, message: String) -> void:
	if debug_enabled(flag):
		print("[DEBUG:%s] %s" % [flag, message])

func _setup_navigation():
	var nav_mesh = NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.agent_height = 1.8
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_max_climb = 0.3
	nav_mesh.agent_max_slope = 45.0
	nav_mesh.cell_size = 0.3
	nav_mesh.cell_height = 0.25
	_nav_region = NavigationRegion3D.new()
	_nav_region.name = "NavRegion"
	_nav_region.navigation_mesh = nav_mesh
	add_child(_nav_region)
	_nav_region.bake_finished.connect(func(): print("[NAV] Bake complete"))
	_nav_region.bake_navigation_mesh()
	print("[NAV] Baking navigation mesh...")

func _apply_cmdline_arg(arg: String):
	var parsed = MatchTuningScript.from_cmdline_arg(arg)
	if parsed.is_empty():
		return
	if parsed.has("difficulty"):
		difficulty = int(parsed["difficulty"]) as Difficulty
	_apply_match_tuning(parsed.get("tuning", {}))

func _load_map_spec():
	var file = FileAccess.open("res://data/mapSpec_example.json", FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		map_spec = MapSpecScript.from_json(json_text)
	else:
		push_error("Main: mapSpec_example.json not found!")

func _process(delta):
	if get_tree().paused: return
	if current_state != GameState.PLAYING: return
	if game_over: return
	
	match_timer += delta
	handle_zone_lifecycle(delta)
	handle_damage_tick(delta)
	_check_match_end()
	if difficulty == Difficulty.HELL and hell_events:
		hell_events.tick(delta, match_timer, zone)
	_process_pressure_mission(delta)
	
	# Update Zone Visuals
	if zone_ring:
		zone_ring.scale = Vector3(zone.current_radius, 1, zone.current_radius)
		zone_ring.position.x = zone.current_center.x
		zone_ring.position.z = zone.current_center.y

	if zone.stage == 2 and not supply_telegraphed:
		telegraph_supply_zone()
		
	if supply_telegraphed and not supply_spawned:
		supply_timer -= delta
		# Move pillar down over time
		if supply_pillar:
			var t = supply_controller.pillar_progress(supply_timer) if supply_controller else 1.0
			supply_pillar.global_position.y = lerp(50.0, 0.0, t)
			
		if supply_timer <= 0:
			activate_supply_zone()

func handle_zone_lifecycle(delta):
	zone.tick_lifecycle(delta)

func _on_zone_stage_changed(new_stage: int):
	debug_log("zone", "stage advanced to %d radius=%.1f next=%.1f" % [
		new_stage,
		float(zone.current_radius),
		float(zone.next_radius),
	])
	if has_node("/root/Telemetry"):
		get_node("/root/Telemetry").set_stage(new_stage)
		if new_stage == 2:
			var dist: Dictionary = {}
			for b in get_tree().get_nodes_in_group("actors"):
				if is_instance_valid(b) and not b.is_in_group("players") and not b.is_dead:
					var aname = BotDoctrineScript.archetype_name(int(b.archetype))
					dist[aname] = dist.get(aname, 0) + 1
			get_node("/root/Telemetry").log_archetype_alive_at_zone2(dist)
	_print_bot_state_snapshot()
	spawn_loot(0.1 + (new_stage * 0.1), 10)
	if heal_ban_until_stage > 0 and new_stage > heal_ban_until_stage:
		heal_pickup_banned = false
		heal_ban_until_stage = -1
	if pressure_missions_enabled and not game_over:
		_trigger_pressure_mission()

func _on_zone_warning():
	if has_node("/root/Sfx"): get_node("/root/Sfx").play("zone_warning")

func spawn_entities():
	_spawn_positions = []
	# Spawn Player
	var p = player_scene.instantiate()
	$Entities.add_child(p)
	p.display_name = "YOU"
	p.add_to_group("players") # Ensure player is in correct group for telemetry
	p.global_position = _get_safe_spawn_pos()
	player_ref = p
	p.died.connect(_on_player_died)
	if difficulty == Difficulty.HELL and not is_simulation:
		p.current_health = 1.0
		p.health_changed.emit(1.0, p.stats.max_health)

	var diff_params = _get_difficulty_params()
	var archetype_plan = BotSpawnPlannerScript.archetype_plan(bot_count)
	if difficulty == Difficulty.HELL and hell_modifier == HellModifier.ALL_AGGRESSIVE:
		archetype_plan = BotSpawnPlannerScript.force_archetype(archetype_plan, "AGGRESSIVE")
	for i in range(bot_count):
		var b = bot_scene.instantiate()
		$Entities.add_child(b)
		b.display_name = "Bot %d" % (i + 1)
		b.global_position = _get_safe_spawn_pos()
		b.died.connect(_on_bot_died.bind(b))
		var archetype_name = archetype_plan[i] if i < archetype_plan.size() else BotSpawnPlannerScript.DEFAULT_ARCHETYPE
		var atype = BotDoctrineScript.archetype_id(archetype_name)
		b.configure_ai(atype, diff_params)
		if has_node("/root/Telemetry"):
			var aname = BotDoctrineScript.archetype_name(int(b.archetype))
			get_node("/root/Telemetry").log_archetype_spawn(aname)

func _get_safe_spawn_pos() -> Vector3:
	for _attempt in range(50):
		var angle = randf() * TAU
		var dist = randf_range(5.0, spawn_radius)
		var candidate = Vector2(cos(angle) * dist, sin(angle) * dist)
		if _is_clear_of_obstacles(candidate) and _is_clear_of_entities(candidate):
			var pos = Vector3(candidate.x, 1.0, candidate.y)
			_spawn_positions.append(pos)
			return pos
	return Vector3(randf_range(-10, 10), 1.0, randf_range(-10, 10))

func _is_clear_of_entities(pos: Vector2, min_dist: float = 3.5) -> bool:
	for sp in _spawn_positions:
		if Vector2(sp.x, sp.z).distance_to(pos) < min_dist:
			return false
	return true

func _categorize_templates():
	weapon_templates.clear()
	consumable_templates.clear()
	var categorized = LootSpawnDirectorScript.categorize_templates(item_templates, extra_consumable_templates)
	for template in categorized.get("weapons", []):
		weapon_templates.append(template)
	for template in categorized.get("consumables", []):
		consumable_templates.append(template)

func _register_loot_hotspots():
	loot_hotspots.clear()
	if not loot_spawner or not map_spec:
		return
	loot_spawner.register_from_map_spec(map_spec)
	loot_hotspots = loot_spawner.hotspots.duplicate(true)

func _choose_loot_hotspot() -> Dictionary:
	return loot_spawner.choose_hotspot() if loot_spawner else {}

func _random_loot_pos(hotspot: Dictionary) -> Vector2:
	if not loot_spawner:
		return hotspot.get("pos", Vector2.ZERO)
	return loot_spawner.random_position(hotspot, Callable(self, "_is_clear_of_obstacles"))

func _spawn_initial_loot():
	if not loot_spawner or not loot_spawner.has_hotspots():
		return
	LootSpawnDirectorScript.spawn_initial_loot(
		pickup_scene,
		$Loot,
		loot_hotspots,
		loot_spawner,
		weapon_templates,
		consumable_templates,
		Callable(self, "_random_loot_pos")
	)

func _is_clear_of_obstacles(pos: Vector2, margin: float = 2.0) -> bool:
	if not map_spec: return true
	for o in map_spec.obstacles:
		var type_str = o.get("type", "")
		if type_str == "bush_patch": continue  # bushes don't block movement
		var op = o.get("pos", [0, 0])
		var sc = o.get("scale", [1, 1, 1])
		var half_x = float(sc[0]) + margin
		var half_z = float(sc[2]) + margin
		if abs(pos.x - op[0]) < half_x and abs(pos.y - op[1]) < half_z:
			return false
	return true

func spawn_loot(prob: float, count_mult: int = 1):
	var total_to_spawn = loot_spawner.spawn_count(prob, count_mult) if loot_spawner else int(loot_count * prob * count_mult)
	if total_to_spawn <= 0 or loot_hotspots.is_empty(): return
	LootSpawnDirectorScript.spawn_loot_wave(
		pickup_scene,
		$Loot,
		total_to_spawn,
		Callable(self, "_choose_loot_hotspot"),
		Callable(self, "_random_loot_pos"),
		weapon_templates,
		item_templates
	)

func telegraph_supply_zone():
	var drop = supply_controller.start_telegraph() if supply_controller else {
		"pos": Vector3(randf_range(-25, 25), 1.0, randf_range(-25, 25)),
		"timer": 8.0,
	}
	supply_telegraphed = true
	supply_spawned = false
	supply_timer = float(drop.get("timer", 8.0))
	supply_pos = drop.get("pos", Vector3.ZERO)
	debug_log("loot", "supply telegraphed at (%.1f, %.1f)" % [supply_pos.x, supply_pos.z])
	
	supply_pillar = LootSpawnDirectorScript.create_supply_pillar(self, supply_pos)
	
	if has_node("/root/Telemetry"): get_node("/root/Telemetry").log_supply_event("telegraph")

func activate_supply_zone():
	supply_spawned = true
	supply_telegraphed = false # Clear from minimap
	debug_log("loot", "supply activated at (%.1f, %.1f)" % [supply_pos.x, supply_pos.z])
	if supply_pillar:
		supply_pillar.queue_free()
		supply_pillar = null
	
	var consumable_count = supply_controller.consumable_count() if supply_controller else 4
	var cluster_offset = Callable()
	if supply_controller:
		cluster_offset = Callable(supply_controller, "random_cluster_offset")
	LootSpawnDirectorScript.spawn_supply_cluster(
		pickup_scene,
		$Loot,
		supply_pos,
		railgun_item,
		consumable_count,
		cluster_offset,
		consumable_templates,
		item_templates
	)
		
	if has_node("/root/Telemetry"): get_node("/root/Telemetry").log_supply_event("contest")

func _on_bot_died(bot: Entity = null):
	# Capture final-duel context BEFORE decrementing alive_count
	if alive_count == 2 and bot and has_node("/root/Telemetry"):
		var pos_2d = Vector2(bot.global_position.x, bot.global_position.z)
		var zone_dist = pos_2d.distance_to(zone.current_center)
		var outside_extra = zone.get_outside_time(bot.get_instance_id())
		get_node("/root/Telemetry").log_final_duel_death({
			"cause":            bot.last_damage_source,
			"state":            bot.State.keys()[bot.current_state],
			"zone_dist_ratio":  snappedf(zone_dist / max(zone.current_radius, 0.1), 0.01),
			"outside_sec":      outside_extra,
			"was_stuck":        bot._stuck_override_timer > 0.0,
			"stuck_sec":        snappedf(bot._stuck_timer, 0.01),
			"stage":            zone.stage,
			"bot_hp":           snappedf(bot.current_health, 0.1),
		})
	alive_count -= 1
	if bot:
		zone.on_entity_died(bot.get_instance_id())
		if has_node("/root/Telemetry"):
			var aname = BotDoctrineScript.archetype_name(int(bot.archetype))
			get_node("/root/Telemetry").log_archetype_death(aname)
	# Mission tracker kill hook
	if mission_tracker and bot and bot.last_killer == player_ref:
		var num_detecting = 0
		for b2 in get_tree().get_nodes_in_group("actors"):
			if is_instance_valid(b2) and not b2.is_in_group("players") and not b2.is_dead:
				if b2.perception_meters.get(player_ref, 0.0) >= 1.0:
					num_detecting += 1
		mission_tracker.on_player_kill({
			"weapon_type":   bot.last_damage_weapon,
			"in_bush":       player_ref.is_in_bush,
			"near_supply":   supply_spawned and player_ref.global_position.distance_to(supply_pos) <= 12.0,
			"undetected":    bot.perception_meters.get(player_ref, 0.0) < 1.0,
			"num_detecting": num_detecting,
		})
		var player_hp_ratio = player_ref.current_health / player_ref.stats.max_health if is_instance_valid(player_ref) else 1.0
		var player_pos_2d = Vector2(player_ref.global_position.x, player_ref.global_position.z) if is_instance_valid(player_ref) else Vector2.ZERO
		var p_outside = zone.is_outside(player_pos_2d)
		mission_tracker.on_pressure_kill(
			bot.last_damage_weapon,
			bot.perception_meters.get(player_ref, 0.0) < 1.0,
			p_outside,
			player_hp_ratio,
			num_detecting
		)

	if is_instance_valid(player_ref) and not player_ref.is_dead and player_ref.has_method("add_kill_feed_entry"):
		var killer_is_player = bot and (bot.last_killer == player_ref)
		var _now_ms = Time.get_ticks_msec()
		var player_assisted = bot and not killer_is_player and \
			(player_ref in bot.damage_history) and \
			(_now_ms - bot.damage_history[player_ref] <= bot.ASSIST_WINDOW_MS)
		var victim_name = bot.display_name if bot else "Bot"
		var killer_node = bot.last_killer if bot else null
		var killer_name: String
		if not is_instance_valid(killer_node):
			killer_name = "Zone"
		elif killer_node == player_ref:
			killer_name = "YOU"
		else:
			killer_name = killer_node.display_name if killer_node.display_name != "" else "Bot"
		var weapon_type = (bot.last_damage_weapon if bot else "")
		var killer_streak = (killer_node.kill_streak if (is_instance_valid(killer_node) and killer_node is Entity) else 0)
		player_ref.add_kill_feed_entry(killer_is_player, player_assisted, killer_name, victim_name, weapon_type, killer_streak)
	_check_match_end()

func _on_player_died():
	# Capture rank BEFORE decrementing alive_count
	var death_rank = alive_count
	alive_count -= 1
	if is_simulation:
		return  # In headless sim, let bots fight to the end — don't cut match short
	if not game_over:
		game_over = true
		_end_match(death_rank)

func _check_match_end():
	if alive_count <= 1 and not game_over:
		game_over = true
		_end_match(1)

func _end_match(final_rank: int = 1):
	current_state = GameState.RESULT
	var is_victory = (final_rank == 1)
	if is_instance_valid(player_ref) and not player_ref.is_dead:
		is_victory = true
		final_rank = 1
	
	if has_node("/root/Telemetry"):
		get_node("/root/Telemetry").end_match(final_rank, "Player" if is_victory else "Bot", zone.stage)
		
	# Hide Player HUD
	if is_instance_valid(player_ref):
		var p_canvas = player_ref.get_node_or_null("CanvasLayer")
		if p_canvas: p_canvas.visible = false

	# Evaluate bonus mission
	var mission_success: bool = false
	var mission_result_text: String = ""
	var mission_bonus_score: int = 0
	if mission_tracker and mission_tracker.active_mission:
		var tel_node = get_node_or_null("/root/Telemetry")
		var player_hp = player_ref.current_health if is_instance_valid(player_ref) else 0.0
		mission_success = mission_tracker.evaluate(tel_node, final_rank, player_hp, difficulty as int)
		var mid = mission_tracker.active_mission.id
		if mission_success:
			mission_tracker.save_badge(mid)
			mission_bonus_score = mission_tracker.active_mission.score_bonus
			mission_result_text = "★ MISSION CLEAR  %s  (+%d pt)" % [mission_tracker.active_mission.title, mission_bonus_score]
		else:
			mission_result_text = "✗ MISSION FAILED  %s" % mission_tracker.active_mission.title
		if tel_node:
			tel_node.log_mission_result(mission_success)

	# Show Result Panel and populate UI
	_show_panel("Result")
	var result_score = 0
	var result_stats_text = ""
	if has_node("/root/Telemetry"):
		var tel = get_node("/root/Telemetry")
		result_score = tel.calculate_score(
			final_rank, tel.metrics.session.kills,
			tel.metrics.session.assists, is_victory, difficulty as int
		) + mission_bonus_score
		result_stats_text = "KILLS  %d    ASSISTS  %d    DAMAGE  %.0f    TIME  %ds" % [
			tel.metrics.session.kills, tel.metrics.session.assists,
			tel.metrics.combat.total_damage_dealt, int(match_timer)
		]
	ResultPanelBuilderScript.populate(_result_panel_nodes, {
		"final_rank": final_rank,
		"is_victory": is_victory,
		"score": result_score,
		"stats_text": result_stats_text,
		"mission_text": mission_result_text,
		"mission_success": mission_success,
	})

	if is_simulation:
		get_tree().quit()

func _print_bot_state_snapshot():
	# 0=IDLE 1=CHASE 2=ATTACK 3=ZONE_ESCAPE 4=RECOVER 5=DISENGAGE
	var names = ["IDLE", "CHASE", "ATTACK", "ZONE_ESCAPE", "RECOVER", "DISENGAGE"]
	var counts = {}
	var positions: Array = []
	var outside_zone = 0
	for b in get_tree().get_nodes_in_group("actors"):
		if not is_instance_valid(b): continue
		if b.is_in_group("players") or not b.has_method("handle_idle_state"): continue
		if b.is_dead: continue
		var s = names[b.current_state] if b.current_state < names.size() else str(b.current_state)
		counts[s] = counts.get(s, 0) + 1
		positions.append(Vector2(b.global_position.x, b.global_position.z))
		var b2d = Vector2(b.global_position.x, b.global_position.z)
		if zone.is_outside(b2d):
			outside_zone += 1
	# Compute pairwise distance average to measure clustering
	var avg_dist = 0.0
	var pairs = 0
	for i in range(positions.size()):
		for j in range(i + 1, positions.size()):
			avg_dist += positions[i].distance_to(positions[j])
			pairs += 1
	if pairs > 0: avg_dist /= pairs
	print("[BOT_SNAPSHOT] zone_stage=%d  states=%s  outside_zone=%d  avg_pairwise_dist=%.1fm  alive=%d" % [
		zone.stage, str(counts), outside_zone, avg_dist, positions.size()
	])

func handle_damage_tick(delta):
	zone.tick_damage(delta, get_tree().get_nodes_in_group("actors"), mission_tracker, player_ref)

# ─── PRESSURE MISSION ────────────────────────────────────────────────────────

func _trigger_pressure_mission():
	if not mission_tracker: return
	var pool: Array
	if difficulty == Difficulty.HELL:
		pool = MissionTrackerScript.get_hell_pool()
	else:
		pool = MissionTrackerScript.get_hard_pool()
	# Filter out missions that are impossible given current game state
	var bot_alive = max(0, alive_count - 1)
	pool = MissionTrackerScript.filter_feasible(pool, zone.stage, bot_alive)
	if pool.is_empty(): return
	var descriptor = pool[randi() % pool.size()]
	mission_tracker.start_pressure(descriptor, zone.wait_time + zone.shrink_time)
	if has_node("/root/Telemetry"):
		get_node("/root/Telemetry").log_pressure_event("triggered", descriptor.get("id", ""))

func _is_bonus_mission_feasible(m, art_mods: Dictionary) -> bool:
	# zone_battery (heal_mult=0): 힐 완전 봉인 → 구급상자 사용 미션 불가
	if art_mods.get("heal_mult", 1.0) == 0.0 and m.id == "medic_run":
		return false
	# armor_sponge (heal_to_shield): 힐→방어막 전환이지만 on_player_medkit_used()는 정상 호출되므로 호환
	# silent_core (max_health_mult 0.5): WIN_HIGH_HP(50) 목표값이 최대HP와 동일해 어렵지만 가능
	return true

func _process_pressure_mission(delta: float):
	if not mission_tracker or not mission_tracker.pressure_active: return
	# 봇 감지 수 계산
	var num_detecting: int = 0
	if is_instance_valid(player_ref):
		for b in get_tree().get_nodes_in_group("actors"):
			if is_instance_valid(b) and not b.is_in_group("players") and not b.is_dead:
				if b.perception_meters.get(player_ref, 0.0) >= 1.0:
					num_detecting += 1
	var result = mission_tracker.tick_pressure(delta, num_detecting)
	if result == "success":
		var _title = mission_tracker._active_pressure.get("title", "미션")
		_apply_pressure_effects(mission_tracker._active_pressure.get("reward", []), true)
		if is_instance_valid(player_ref) and player_ref.has_method("show_pressure_flash"):
			player_ref.show_pressure_flash("⚡ %s 성공!" % _title, true)
		if has_node("/root/Telemetry"):
			get_node("/root/Telemetry").log_pressure_event("cleared")
	elif result == "fail":
		var _title = mission_tracker._active_pressure.get("title", "미션")
		_apply_pressure_effects(mission_tracker._active_pressure.get("penalty", []), false)
		if is_instance_valid(player_ref) and player_ref.has_method("show_pressure_flash"):
			player_ref.show_pressure_flash("✖ %s 실패" % _title, false)
		if has_node("/root/Telemetry"):
			get_node("/root/Telemetry").log_pressure_event("failed")

func _apply_pressure_effects(effects: Array, _is_reward: bool):
	var updates = PressureEffectApplierScript.apply(effects, {
		"player": player_ref,
		"actors": get_tree().get_nodes_in_group("actors"),
		"zone": zone,
	})
	if updates.has("heal_pickup_banned"):
		heal_pickup_banned = bool(updates["heal_pickup_banned"])
	if updates.has("heal_ban_until_stage"):
		heal_ban_until_stage = int(updates["heal_ban_until_stage"])
	if updates.has("railgun_unlimited_until_stage"):
		railgun_unlimited_until_stage = int(updates["railgun_unlimited_until_stage"])

# ─── MENU VISUALS ────────────────────────────────────────────────────────────

func _setup_result_panel():
	_result_panel_nodes = ResultPanelBuilderScript.build(
		$CanvasLayer/Control/ResultPanel,
		Callable(self, "restart_game"),
		Callable(self, "_on_records_pressed"),
		Callable(self, "return_to_menu"),
		Callable(self, "_apply_btn_style")
	)

func _setup_menu_visuals():
	MenuVisualBuilderScript.setup_main_menu(
		$CanvasLayer/Control/MainMenuPanel,
		$CanvasLayer/Control/MainMenuPanel/VBoxContainer,
		MenuIconFactoryScript.make_capsule_logo(80)
	)

func _setup_secondary_panels():
	MenuVisualBuilderScript.setup_secondary_panels(
		[
			$CanvasLayer/Control/RecordsPanel,
			$CanvasLayer/Control/HelpPanel,
		],
		[
			$CanvasLayer/Control/RecordsPanel/VBox/CloseRecordsBtn,
			$CanvasLayer/Control/HelpPanel/VBox/CloseHelpBtn,
		]
	)
	HelpPanelBuilderScript.build($CanvasLayer/Control/HelpPanel/VBox)

func _apply_btn_style(btn: Button):
	MenuVisualBuilderScript.apply_button_style(btn)

# ─── DIFFICULTY ──────────────────────────────────────────────────────────────

func _on_difficulty_btn(idx: int):
	difficulty = idx as Difficulty
	_update_diff_highlights()
	DifficultySelectorBuilderScript.set_pressure_visible(_difficulty_selector, difficulty == Difficulty.HARD)

func _on_pressure_opt_in_toggled(enabled: bool):
	pressure_opt_in_hard = enabled

func _update_diff_highlights():
	DifficultySelectorBuilderScript.update_highlights(_difficulty_selector, difficulty as int)

# ─── HELL EVENTS ─────────────────────────────────────────────────────────────

func _show_hell_announcement():
	_hell_announce_active = true
	get_tree().paused = true
	var md = HellEventControllerScript.modifier_description(hell_modifier as int)
	_hell_announce_panel = HellAnnouncementBuilderScript.show(
		$CanvasLayer/Control,
		md,
		Callable(self, "_dismiss_hell_announcement"),
		Callable(self, "_apply_btn_style")
	)

func _dismiss_hell_announcement():
	if not _hell_announce_active: return
	_hell_announce_active = false
	if is_instance_valid(_hell_announce_panel):
		var tw = _hell_announce_panel.create_tween()
		tw.tween_property(_hell_announce_panel, "modulate:a", 0.0, 0.3)
		tw.tween_callback(_hell_announce_panel.queue_free)
		_hell_announce_panel = null
	get_tree().paused = false

# ─── SETTINGS ────────────────────────────────────────────────────────────────

func _load_settings():
	var cfg = ConfigFile.new()
	if cfg.load("user://settings.cfg") != OK: return
	var vol: float = cfg.get_value("audio", "master_volume", 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(vol))
	if cfg.get_value("display", "fullscreen", false):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _save_settings(vol_linear: float, fullscreen: bool):
	var cfg = ConfigFile.new()
	cfg.set_value("audio", "master_volume", vol_linear)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.save("user://settings.cfg")

func _on_settings_pressed():
	SettingsPanelBuilderScript.show(
		$CanvasLayer/Control,
		db_to_linear(AudioServer.get_bus_volume_db(0)),
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN,
		Callable(self, "_on_settings_volume_changed"),
		Callable(self, "_toggle_fullscreen_setting"),
		Callable(self, "_on_settings_closed"),
		Callable(self, "_apply_btn_style")
	)

func _on_settings_volume_changed(vol_linear: float):
	AudioServer.set_bus_volume_db(0, linear_to_db(vol_linear))

func _toggle_fullscreen_setting() -> bool:
	var new_fullscreen = not (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	if new_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	return new_fullscreen

func _on_settings_closed(vol_linear: float):
	_save_settings(vol_linear, DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)

func _show_event_text(msg: String, col: Color):
	EventTextBuilderScript.show($CanvasLayer/Control, msg, col)
