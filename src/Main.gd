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

@export_group("Loot")
@export var railgun_item: ItemData = preload("res://src/items/weapon_railgun.tres")
@export var pickup_scene: PackedScene = preload("res://src/entities/pickup/Pickup.tscn")
@export var item_templates: Array[ItemData] = [
	preload("res://src/items/ammo_ar.tres"),
	preload("res://src/items/ammo_shotgun.tres"),
	preload("res://src/items/ammo_railgun.tres"),
	preload("res://src/items/heal_pickup.tres"),
	preload("res://src/items/weapon_ar.tres"),
	preload("res://src/items/weapon_shotgun.tres"),
	preload("res://src/items/armor_pickup.tres")
]
@export var loot_count: int = 40
@export var spawn_radius: float = 45.0

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

# Result screen UI nodes (built in _setup_result_panel)
var _result_header_label: Label = null
var _result_rank_label: Label = null
var _result_stats_label: Label = null
var _result_score_label: Label = null
var _result_mission_label: Label = null
var _result_sep_mission: HSeparator = null

const HEAL_ADVANCED_ITEM = preload("res://src/items/heal_advanced_pickup.tres")
const ArtifactCatalogScript = preload("res://src/core/ArtifactCatalog.gd")
const AssetCatalogScript = preload("res://src/core/AssetCatalog.gd")
const DifficultySelectorBuilderScript = preload("res://src/ui/DifficultySelectorBuilder.gd")
const GameConfigScript = preload("res://src/core/GameConfig.gd")
const DebugFlagsScript = preload("res://src/core/DebugFlags.gd")
const DebugOverlayScript = preload("res://src/ui/DebugOverlay.gd")
const HelpPanelBuilderScript = preload("res://src/ui/HelpPanelBuilder.gd")
const HellEventControllerScript = preload("res://src/core/HellEventController.gd")
const LootSpawnerScript = preload("res://src/core/LootSpawner.gd")
const MenuIconFactoryScript = preload("res://src/ui/MenuIconFactory.gd")
const MissionTrackerScript = preload("res://src/core/MissionTracker.gd")
const RecordsPanelBuilderScript = preload("res://src/ui/RecordsPanelBuilder.gd")
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
			
	# Connect Buttons
	$CanvasLayer/Control/MainMenuPanel/VBoxContainer/StartBtn.pressed.connect(_on_start_btn_pressed)
	$CanvasLayer/Control/MainMenuPanel/VBoxContainer/RecordsBtn.pressed.connect(_on_records_pressed)
	$CanvasLayer/Control/MainMenuPanel/VBoxContainer/HelpBtn.pressed.connect(_on_help_pressed)
	$CanvasLayer/Control/MainMenuPanel/VBoxContainer/ExitBtn.pressed.connect(get_tree().quit)

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

	var exit_idx = $CanvasLayer/Control/MainMenuPanel/VBoxContainer/ExitBtn.get_index()
	var settings_btn = Button.new()
	settings_btn.text = "SETTINGS"
	settings_btn.add_theme_font_size_override("font_size", 24)
	settings_btn.pressed.connect(_on_settings_pressed)
	$CanvasLayer/Control/MainMenuPanel/VBoxContainer.add_child(settings_btn)
	$CanvasLayer/Control/MainMenuPanel/VBoxContainer.move_child(settings_btn, exit_idx)
	_apply_btn_style(settings_btn)

	_setup_result_panel()

	$CanvasLayer/Control/RecordsPanel/VBox/CloseRecordsBtn.pressed.connect(func(): _show_panel("MainMenu"))
	$CanvasLayer/Control/HelpPanel/VBox/CloseHelpBtn.pressed.connect(func(): _show_panel("MainMenu"))
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
	if _artifact_panel:
		_artifact_panel.queue_free()
		_artifact_panel = null

	var catalog = ArtifactCatalogScript.starting_artifacts(difficulty as int)

	# Dim overlay
	var overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	$CanvasLayer/Control.add_child(overlay)
	_artifact_panel = overlay

	var center = VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.add_theme_constant_override("separation", 18)
	overlay.add_child(center)

	var title = Label.new()
	title.text = "아티팩트 선택"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 6)
	center.add_child(title)

	var sub = Label.new()
	sub.text = "원하는 아티팩트를 골라 시작하세요"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.60, 0.60, 0.60))
	center.add_child(sub)

	var card_row = HBoxContainer.new()
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 14)
	center.add_child(card_row)

	for artifact in catalog:
		card_row.add_child(_make_artifact_card(artifact))

	var skip_btn = Button.new()
	skip_btn.text = "선택하지 않기"
	skip_btn.add_theme_font_size_override("font_size", 14)
	skip_btn.custom_minimum_size = Vector2(150, 36)
	_apply_btn_style(skip_btn)
	skip_btn.pressed.connect(func():
		_artifact_panel.queue_free(); _artifact_panel = null
		_pending_artifact = {}
		start_game()
	)
	center.add_child(skip_btn)

func _make_artifact_card(artifact: Dictionary) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(148, 168)
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.10, 0.12, 0.16, 0.96)
	ps.border_color = artifact.get("color", Color.WHITE) * 0.75
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(6)
	ps.content_margin_left = 12; ps.content_margin_right = 12
	ps.content_margin_top = 14;  ps.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", ps)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	var name_lbl = Label.new()
	name_lbl.text = artifact.get("label", "")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", artifact.get("color", Color.WHITE))
	name_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	name_lbl.add_theme_constant_override("outline_size", 5)
	vb.add_child(name_lbl)

	var sep = HSeparator.new()
	vb.add_child(sep)

	for key in ["line1", "line2"]:
		if artifact.has(key):
			var lbl = Label.new()
			lbl.text = artifact[key]
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 13)
			lbl.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vb.add_child(lbl)

	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)

	var pick_btn = Button.new()
	pick_btn.text = "선택"
	pick_btn.add_theme_font_size_override("font_size", 14)
	_apply_btn_style(pick_btn)
	pick_btn.pressed.connect(func():
		_artifact_panel.queue_free(); _artifact_panel = null
		_pending_artifact = artifact
		start_game()
	)
	vb.add_child(pick_btn)

	return panel

func start_game():
	current_state = GameState.PLAYING
	game_over = false
	match_timer = 0.0
	zone = ZoneControllerScript.new()
	zone.wait_time = zone_wait_time
	zone.shrink_time = zone_shrink_time
	zone.damage_per_second = zone_damage
	zone.timer = _zone_initial_timer()
	zone.generate_next()
	zone.stage_advanced.connect(_on_zone_stage_changed)
	zone.zone_warning.connect(_on_zone_warning)
	
	_show_panel("HUD")
	_ensure_debug_overlay()

	# 랜덤 보너스 미션 자동 배정 (아티팩트와 불가능한 조합 제외)
	mission_tracker = MissionTrackerScript.new()
	var _bm_pool = MissionTrackerScript.get_all_missions()
	var _bm_art_mods = _pending_artifact.get("mods", {})
	_bm_pool = _bm_pool.filter(func(m): return _is_bonus_mission_feasible(m, _bm_art_mods))
	if _bm_pool.is_empty(): _bm_pool = MissionTrackerScript.get_all_missions()
	mission_tracker.active_mission = _bm_pool[randi() % _bm_pool.size()]

	# 압박 미션 활성화 여부
	heal_pickup_banned = false
	heal_ban_until_stage = -1
	railgun_unlimited_until_stage = -1
	pressure_missions_enabled = (difficulty == Difficulty.HELL) or \
		(difficulty == Difficulty.HARD and pressure_opt_in_hard)

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
		var _rng = RandomNumberGenerator.new()
		_rng.seed = Time.get_ticks_usec() ^ (Time.get_ticks_msec() << 16)
		hell_modifier = _rng.randi_range(0, 2) as HellModifier
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
	var control = $CanvasLayer/Control
	for child in control.get_children():
		if child.name.ends_with("Panel"):
			child.visible = (child.name == panel_name + "Panel")
		elif child.name == "HUD":
			child.visible = (panel_name == "HUD")

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
	var panel = ColorRect.new()
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.layout_mode = 1
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.color = Color(0.0, 0.0, 0.0, 0.55)
	panel.z_index = 15

	var box = VBoxContainer.new()
	box.process_mode = Node.PROCESS_MODE_ALWAYS
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -110.0; box.offset_right = 110.0
	box.offset_top  = -80.0;  box.offset_bottom = 80.0
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical   = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title = Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	box.add_child(title)

	for btn_data in [["RESUME", _toggle_pause], ["RESTART", restart_game], ["MAIN MENU", return_to_menu]]:
		var btn = Button.new()
		btn.process_mode = Node.PROCESS_MODE_ALWAYS
		btn.text = btn_data[0]
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(btn_data[1])
		_apply_btn_style(btn)
		box.add_child(btn)

	return panel

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

func _apply_game_config():
	if not game_config:
		return
	bot_count = max(0, int(game_config.match_value("bot_count", bot_count)))
	loot_count = max(0, int(game_config.match_value("loot_count", loot_count)))
	spawn_radius = maxf(1.0, float(game_config.match_value("spawn_radius", spawn_radius)))
	if loot_spawner and loot_spawner.has_method("configure_count"):
		loot_spawner.configure_count(loot_count)
	zone_wait_time = maxf(1.0, float(game_config.zone_value("wait_time", zone_wait_time)))
	zone_shrink_time = maxf(1.0, float(game_config.zone_value("shrink_time", zone_shrink_time)))
	zone_damage = maxf(0.0, float(game_config.zone_value("damage_per_second", zone_damage)))
	zone_initial_timer = maxf(0.1, float(game_config.zone_value("initial_timer", zone_initial_timer)))

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
	var lower = arg.to_lower()
	if lower.begins_with("difficulty="):
		var value = lower.get_slice("=", 1)
		match value:
			"easy", "0":
				difficulty = Difficulty.EASY
			"normal", "1":
				difficulty = Difficulty.NORMAL
			"hard", "2":
				difficulty = Difficulty.HARD
			"hell", "3":
				difficulty = Difficulty.HELL
	elif lower.begins_with("bot_count="):
		bot_count = max(0, int(lower.get_slice("=", 1)))
	elif lower.begins_with("loot_count="):
		loot_count = max(0, int(lower.get_slice("=", 1)))
		if loot_spawner and loot_spawner.has_method("configure_count"):
			loot_spawner.configure_count(loot_count)
	elif lower.begins_with("spawn_radius="):
		spawn_radius = maxf(1.0, float(lower.get_slice("=", 1)))
	elif lower.begins_with("zone_wait_time=") or lower.begins_with("zone_wait="):
		zone_wait_time = maxf(1.0, float(lower.get_slice("=", 1)))
	elif lower.begins_with("zone_shrink_time=") or lower.begins_with("zone_shrink="):
		zone_shrink_time = maxf(1.0, float(lower.get_slice("=", 1)))
	elif lower.begins_with("zone_damage=") or lower.begins_with("zone_dps="):
		zone_damage = maxf(0.0, float(lower.get_slice("=", 1)))
	elif lower.begins_with("zone_initial_timer=") or lower.begins_with("zone_initial="):
		zone_initial_timer = maxf(0.1, float(lower.get_slice("=", 1)))

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
					var aname = b.BotArchetype.keys()[b.archetype]
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

	# Spawn Bots — 아키타입 배정 3:3:2:3 (AGGRESSIVE/DEFENSIVE/SNIPER/OPPORTUNIST)
	var diff_params = _get_difficulty_params()
	var _archetype_pool: Array = []
	for _ai in range(3): _archetype_pool.append(0)  # AGGRESSIVE
	for _ai in range(3): _archetype_pool.append(1)  # DEFENSIVE
	for _ai in range(2): _archetype_pool.append(2)  # SNIPER
	for _ai in range(3): _archetype_pool.append(3)  # OPPORTUNIST
	_archetype_pool.shuffle()
	for i in range(bot_count):
		var b = bot_scene.instantiate()
		$Entities.add_child(b)
		b.display_name = "Bot %d" % (i + 1)
		b.global_position = _get_safe_spawn_pos()
		b.died.connect(_on_bot_died.bind(b))
		var atype = _archetype_pool[i] if i < _archetype_pool.size() else 0
		if difficulty == Difficulty.HELL and hell_modifier == HellModifier.ALL_AGGRESSIVE:
			atype = b.BotArchetype.AGGRESSIVE
		b.configure_ai(atype, diff_params)
		if has_node("/root/Telemetry"):
			var aname = b.BotArchetype.keys()[b.archetype]
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
	for t in item_templates:
		if t.type == ItemData.Type.WEAPON:
			weapon_templates.append(t)
		else:
			consumable_templates.append(t)
	# Add advanced heal to pool at roughly 1:5 ratio vs other consumables (rare spawn)
	consumable_templates.append(HEAL_ADVANCED_ITEM)

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
	if not loot_spawner or not loot_spawner.has_hotspots(): return
	for hotspot in loot_hotspots:
		var weapon_chance = loot_spawner.initial_weapon_chance(hotspot)
		if not weapon_templates.is_empty() and randf() < weapon_chance:
			var pickup = pickup_scene.instantiate()
			$Loot.add_child(pickup)
			var sp = _random_loot_pos(hotspot)
			pickup.global_position = Vector3(sp.x, 0.5, sp.y)
			pickup.init(weapon_templates[randi() % weapon_templates.size()].duplicate(true))
		var consumable_count = loot_spawner.initial_consumable_count(hotspot)
		for _i in range(consumable_count):
			if consumable_templates.is_empty(): break
			var pickup = pickup_scene.instantiate()
			$Loot.add_child(pickup)
			var sp = _random_loot_pos(hotspot)
			pickup.global_position = Vector3(sp.x, 0.5, sp.y)
			pickup.init(consumable_templates[randi() % consumable_templates.size()])

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
	for i in range(total_to_spawn):
		var hotspot = _choose_loot_hotspot()
		var spawn_pos = _random_loot_pos(hotspot)
		
		var pickup = pickup_scene.instantiate()
		$Loot.add_child(pickup)
		pickup.global_position = Vector3(spawn_pos.x, 0.5, spawn_pos.y)
		if randf() < float(hotspot.get("rare_bias", 0.0)) and not weapon_templates.is_empty():
			pickup.init(weapon_templates[randi() % weapon_templates.size()].duplicate(true))
		else:
			pickup.init(item_templates[randi() % item_templates.size()])

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
	
	# Visual beacon
	supply_pillar = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.5; mesh.bottom_radius = 0.5; mesh.height = 100.0
	supply_pillar.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.2, 0.3)
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true; mat.emission = Color(1.0, 0.8, 0.2)
	supply_pillar.material_override = mat
	add_child(supply_pillar)
	supply_pillar.global_position = supply_pos + Vector3(0, 50, 0)
	
	if has_node("/root/Telemetry"): get_node("/root/Telemetry").log_supply_event("telegraph")

func activate_supply_zone():
	supply_spawned = true
	supply_telegraphed = false # Clear from minimap
	debug_log("loot", "supply activated at (%.1f, %.1f)" % [supply_pos.x, supply_pos.z])
	if supply_pillar:
		supply_pillar.queue_free()
		supply_pillar = null
	
	# Spawn Rare Loot cluster: 1 guaranteed railgun + 4 consumables
	if railgun_item:
		var rg = pickup_scene.instantiate()
		$Loot.add_child(rg)
		rg.global_position = supply_pos
		rg.init(railgun_item.duplicate(true))
	var consumable_count = supply_controller.consumable_count() if supply_controller else 4
	for i in range(consumable_count):
		var pickup = pickup_scene.instantiate()
		$Loot.add_child(pickup)
		var offset = supply_controller.random_cluster_offset() if supply_controller else Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5))
		pickup.global_position = supply_pos + offset
		if not consumable_templates.is_empty():
			pickup.init(consumable_templates[randi() % consumable_templates.size()])
		else:
			pickup.init(item_templates[randi() % item_templates.size()])
		
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
			var aname = bot.BotArchetype.keys()[bot.archetype]
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
	var result_color = Color.GOLD if is_victory else Color(1.0, 0.28, 0.28)
	if _result_header_label:
		_result_header_label.text = "VICTORY!" if is_victory else "ELIMINATED"
		_result_header_label.add_theme_color_override("font_color", result_color)
	if _result_rank_label:
		_result_rank_label.text = "RANK  #%d" % final_rank
	if has_node("/root/Telemetry"):
		var tel = get_node("/root/Telemetry")
		var score = tel.calculate_score(
			final_rank, tel.metrics.session.kills,
			tel.metrics.session.assists, is_victory, difficulty as int
		) + mission_bonus_score
		if _result_stats_label:
			_result_stats_label.text = "KILLS  %d    ASSISTS  %d    DAMAGE  %.0f    TIME  %ds" % [
				tel.metrics.session.kills, tel.metrics.session.assists,
				tel.metrics.combat.total_damage_dealt, int(match_timer)
			]
		if _result_score_label:
			_result_score_label.text = "SCORE  %d" % score
	if _result_mission_label:
		if mission_result_text != "":
			_result_mission_label.text = mission_result_text
			_result_mission_label.add_theme_color_override("font_color",
				Color.GOLD if mission_success else Color(0.92, 0.38, 0.38))
			_result_mission_label.visible = true
			if _result_sep_mission: _result_sep_mission.visible = true
		else:
			_result_mission_label.visible = false
			if _result_sep_mission: _result_sep_mission.visible = false

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

func _apply_pressure_effects(effects: Array, is_reward: bool):
	if not is_instance_valid(player_ref): return
	for eff in effects:
		match int(eff["type"]):
			MissionTrackerScript.PressureEffect.AMMO_REFILL:
				player_ref.slots.fill_all_ammo()
			MissionTrackerScript.PressureEffect.AMMO_CLEAR:
				player_ref.slots.clear_all_ammo()
			MissionTrackerScript.PressureEffect.AMMO_ACTIVE_CLEAR:
				player_ref.slots.clear_active_ammo()
			MissionTrackerScript.PressureEffect.HP_RESTORE:
				if eff.get("full", false):
					player_ref.current_health = player_ref.stats.max_health
				else:
					player_ref.current_health = min(player_ref.stats.max_health, player_ref.current_health + float(eff.get("amount", 30.0)))
				player_ref.health_changed.emit(player_ref.current_health, player_ref.stats.max_health)
			MissionTrackerScript.PressureEffect.HP_DAMAGE:
				var frac = eff.get("fraction", 0.0)
				var amt = float(eff.get("amount", 20.0))
				if frac > 0.0:
					amt = player_ref.current_health * frac
				player_ref.current_health = max(1.0, player_ref.current_health - amt)
				player_ref.health_changed.emit(player_ref.current_health, player_ref.stats.max_health)
			MissionTrackerScript.PressureEffect.SHIELD_ADD:
				player_ref.current_shield = min(player_ref.stats.max_shield, player_ref.current_shield + float(eff.get("amount", 50.0)))
				player_ref.shield_changed.emit(player_ref.current_shield, player_ref.stats.max_shield)
			MissionTrackerScript.PressureEffect.HEAL_ADD:
				player_ref.stats.heal_items += int(eff.get("count", 1))
				player_ref._update_hud()
			MissionTrackerScript.PressureEffect.HEAL_CLEAR:
				player_ref.stats.heal_items = 0
				player_ref.stats.advanced_heals = 0
				player_ref._update_hud()
			MissionTrackerScript.PressureEffect.HEAL_PICKUP_BAN:
				heal_pickup_banned = true
				heal_ban_until_stage = zone.stage + 1
			MissionTrackerScript.PressureEffect.ALL_BOTS_DETECT:
				for b in get_tree().get_nodes_in_group("actors"):
					if is_instance_valid(b) and not b.is_in_group("players") and not b.is_dead:
						b.perception_meters[player_ref] = 1.0
			MissionTrackerScript.PressureEffect.BOT_AGGRO:
				var nearest = null
				var nearest_dist = INF
				for b in get_tree().get_nodes_in_group("actors"):
					if is_instance_valid(b) and not b.is_in_group("players") and not b.is_dead:
						var d = b.global_position.distance_to(player_ref.global_position)
						if d < nearest_dist:
							nearest_dist = d
							nearest = b
				if nearest and nearest.has_method("handle_idle_state"):
					nearest.target_actor = player_ref
					nearest.is_targeting_loot = false
					nearest.last_known_target_pos = player_ref.global_position
					nearest.current_state = nearest.State.CHASE
			MissionTrackerScript.PressureEffect.ZONE_EXTEND:
				zone.timer += zone.wait_time * (float(eff.get("mult", 1.0)) - 1.0)
			MissionTrackerScript.PressureEffect.RAILGUN_UNLIMITED:
				railgun_unlimited_until_stage = zone.stage + int(eff.get("stages", 1))

# ─── MENU VISUALS ────────────────────────────────────────────────────────────

func _setup_result_panel():
	var result_panel = $CanvasLayer/Control/ResultPanel

	var center = CenterContainer.new()
	center.layout_mode = 1
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_panel.add_child(center)

	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.07, 0.08, 0.13)
	card_style.border_color = Color(0.28, 0.30, 0.44)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(10)
	card_style.content_margin_left = 52
	card_style.content_margin_right = 52
	card_style.content_margin_top = 40
	card_style.content_margin_bottom = 44
	card.add_theme_stylebox_override("panel", card_style)
	card.custom_minimum_size = Vector2(540, 0)
	center.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	_result_header_label = Label.new()
	_result_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_header_label.add_theme_font_size_override("font_size", 52)
	_result_header_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_result_header_label.add_theme_constant_override("outline_size", 8)
	_result_header_label.text = "VICTORY!"
	vbox.add_child(_result_header_label)

	_result_rank_label = Label.new()
	_result_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_rank_label.add_theme_font_size_override("font_size", 28)
	_result_rank_label.add_theme_color_override("font_color", Color(0.80, 0.82, 0.90))
	_result_rank_label.text = "RANK  #1"
	vbox.add_child(_result_rank_label)

	var sep1 = HSeparator.new()
	vbox.add_child(sep1)

	_result_stats_label = Label.new()
	_result_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_stats_label.add_theme_font_size_override("font_size", 17)
	_result_stats_label.add_theme_color_override("font_color", Color(0.72, 0.74, 0.84))
	vbox.add_child(_result_stats_label)

	_result_score_label = Label.new()
	_result_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_score_label.add_theme_font_size_override("font_size", 24)
	_result_score_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	vbox.add_child(_result_score_label)

	_result_sep_mission = HSeparator.new()
	_result_sep_mission.visible = false
	vbox.add_child(_result_sep_mission)

	_result_mission_label = Label.new()
	_result_mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_mission_label.add_theme_font_size_override("font_size", 16)
	_result_mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_mission_label.visible = false
	vbox.add_child(_result_mission_label)

	var sep_btns = HSeparator.new()
	vbox.add_child(sep_btns)

	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 14)
	vbox.add_child(btn_row)

	var restart_btn = Button.new()
	restart_btn.text = "RESTART"
	restart_btn.add_theme_font_size_override("font_size", 20)
	restart_btn.custom_minimum_size = Vector2(130, 42)
	restart_btn.pressed.connect(restart_game)
	btn_row.add_child(restart_btn)
	_apply_btn_style(restart_btn)

	var records_btn = Button.new()
	records_btn.text = "RECORDS"
	records_btn.add_theme_font_size_override("font_size", 20)
	records_btn.custom_minimum_size = Vector2(130, 42)
	records_btn.pressed.connect(_on_records_pressed)
	btn_row.add_child(records_btn)
	_apply_btn_style(records_btn)

	var menu_btn = Button.new()
	menu_btn.text = "MENU"
	menu_btn.add_theme_font_size_override("font_size", 20)
	menu_btn.custom_minimum_size = Vector2(130, 42)
	menu_btn.pressed.connect(return_to_menu)
	btn_row.add_child(menu_btn)
	_apply_btn_style(menu_btn)

func _setup_menu_visuals():
	var panel = $CanvasLayer/Control/MainMenuPanel

	# Gradient background (replace flat ColorRect color)
	panel.color = Color(0.04, 0.06, 0.10)
	var grad_tex = GradientTexture2D.new()
	var grad = Gradient.new()
	grad.set_color(0, Color(0.04, 0.06, 0.10))
	grad.set_color(1, Color(0.05, 0.13, 0.08))
	grad_tex.gradient = grad
	grad_tex.fill_from = Vector2(0.5, 0.0)
	grad_tex.fill_to = Vector2(0.5, 1.0)
	var grad_rect = TextureRect.new()
	grad_rect.texture = grad_tex
	grad_rect.layout_mode = 1
	grad_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grad_rect.stretch_mode = TextureRect.STRETCH_SCALE
	panel.add_child(grad_rect)
	panel.move_child(grad_rect, 0)

	# Subtle noise overlay for texture
	var noise_tex = NoiseTexture2D.new()
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.004
	noise_tex.noise = noise
	noise_tex.width = 512
	noise_tex.height = 512
	noise_tex.as_normal_map = false
	var overlay = TextureRect.new()
	overlay.texture = noise_tex
	overlay.layout_mode = 1
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.modulate = Color(0.12, 0.18, 0.12, 0.18)
	overlay.stretch_mode = TextureRect.STRETCH_TILE
	panel.add_child(overlay)
	panel.move_child(overlay, 1)

	var logo_tex = MenuIconFactoryScript.make_capsule_logo(80)
	var logo_rect = TextureRect.new()
	logo_rect.texture = logo_tex
	logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo_rect.layout_mode = 1
	logo_rect.anchor_left = 0.5; logo_rect.anchor_right = 0.5
	logo_rect.offset_left = -40.0; logo_rect.offset_right = 40.0
	logo_rect.offset_top = 26.0; logo_rect.offset_bottom = 112.0
	panel.add_child(logo_rect)

	# StyleBoxFlat for all buttons in main menu VBox
	for child in $CanvasLayer/Control/MainMenuPanel/VBoxContainer.get_children():
		if child is Button:
			_apply_btn_style(child)

func _setup_secondary_panels():
	# Apply gradient overlay to Records and Help panels
	for panel_path in [
		"CanvasLayer/Control/RecordsPanel",
		"CanvasLayer/Control/HelpPanel"
	]:
		var panel = get_node(panel_path)
		panel.color = Color(0.04, 0.06, 0.10)
		var gr = GradientTexture2D.new()
		var g = Gradient.new(); g.set_color(0, Color(0.04, 0.06, 0.10)); g.set_color(1, Color(0.05, 0.13, 0.08))
		gr.gradient = g; gr.fill_from = Vector2(0.5, 0.0); gr.fill_to = Vector2(0.5, 1.0)
		var gr_rect = TextureRect.new()
		gr_rect.texture = gr; gr_rect.layout_mode = 1
		gr_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		gr_rect.stretch_mode = TextureRect.STRETCH_SCALE
		panel.add_child(gr_rect); panel.move_child(gr_rect, 0)
	# Style close buttons
	_apply_btn_style($CanvasLayer/Control/RecordsPanel/VBox/CloseRecordsBtn)
	_apply_btn_style($CanvasLayer/Control/HelpPanel/VBox/CloseHelpBtn)
	# Build How to Play content
	HelpPanelBuilderScript.build($CanvasLayer/Control/HelpPanel/VBox)

func _apply_btn_style(btn: Button):
	var sn = StyleBoxFlat.new()
	sn.bg_color = Color(0.08, 0.14, 0.10, 0.92)
	sn.border_color = Color(0.25, 0.55, 0.35, 0.8)
	sn.set_border_width_all(1); sn.set_corner_radius_all(5)
	sn.content_margin_left = 12; sn.content_margin_right = 12
	sn.content_margin_top = 6; sn.content_margin_bottom = 6
	var sh = StyleBoxFlat.new()
	sh.bg_color = Color(0.12, 0.22, 0.15, 0.98)
	sh.border_color = Color(0.4, 0.85, 0.55, 1.0)
	sh.set_border_width_all(2); sh.set_corner_radius_all(5)
	sh.content_margin_left = 12; sh.content_margin_right = 12
	sh.content_margin_top = 6; sh.content_margin_bottom = 6
	var sp = StyleBoxFlat.new()
	sp.bg_color = Color(0.05, 0.10, 0.07, 1.0)
	sp.border_color = Color(0.2, 0.5, 0.3, 1.0)
	sp.set_border_width_all(1); sp.set_corner_radius_all(5)
	sp.content_margin_left = 12; sp.content_margin_right = 12
	sp.content_margin_top = 6; sp.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", sn)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("pressed", sp)
	btn.add_theme_color_override("font_color", Color(0.88, 0.95, 0.9))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))

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

	# Root node — dismiss frees everything at once
	var root = Control.new()
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.layout_mode = 1
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.z_index = 20
	_hell_announce_panel = root

	# Semi-transparent overlay
	var overlay = ColorRect.new()
	overlay.layout_mode = 1
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)

	# Centered card
	var center = CenterContainer.new()
	center.layout_mode = 1
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(center)

	var card = PanelContainer.new()
	var cs = StyleBoxFlat.new()
	cs.bg_color = Color(0.05, 0.03, 0.07)
	cs.border_color = Color(0.50, 0.08, 0.12)
	cs.set_border_width_all(2)
	cs.set_corner_radius_all(8)
	cs.content_margin_left = 44; cs.content_margin_right = 44
	cs.content_margin_top = 36;  cs.content_margin_bottom = 38
	card.add_theme_stylebox_override("panel", cs)
	card.custom_minimum_size = Vector2(640, 0)
	center.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	# ── 제목 ──
	var title_lbl = Label.new()
	title_lbl.text = "지옥 모드"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 42)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.20, 0.20))
	title_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	title_lbl.add_theme_constant_override("outline_size", 6)
	vbox.add_child(title_lbl)

	vbox.add_child(_hell_sep())

	# ── 기본 패널티 ──
	vbox.add_child(_hell_section("기본 패널티"))
	_hell_row(vbox, "시작 체력 1",   "아이템 없이 한 번 맞으면 즉사합니다")
	_hell_row(vbox, "치료 효율 50%", "힐 아이템 회복량이 절반입니다")
	_hell_row(vbox, "압박 미션",     "존 전환마다 제한 시간 미션이 발동됩니다")

	vbox.add_child(_hell_sep())

	# ── 이번 매치 이벤트 ──
	vbox.add_child(_hell_section("이번 매치 이벤트"))
	var md = HellEventControllerScript.modifier_description(hell_modifier as int)
	_hell_row(vbox, md[0], md[1])
	_hell_row(vbox, "정전", "주기적으로 화면이 어두워지며 미니맵이 차단됩니다")
	_hell_row(vbox, "포격", "경고 후 지정 범위에 폭탄이 쏟아집니다")

	vbox.add_child(_hell_sep())

	# ── 버튼 ──
	var btn = Button.new()
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.text = "시작하기  [SPACE / ESC]"
	btn.add_theme_font_size_override("font_size", 18)
	btn.pressed.connect(_dismiss_hell_announcement)
	_apply_btn_style(btn)
	vbox.add_child(btn)

	$CanvasLayer/Control.add_child(root)

func _hell_sep() -> HSeparator:
	var s = HSeparator.new()
	s.add_theme_constant_override("separation", 4)
	return s

func _hell_section(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.28))
	return lbl

func _hell_row(parent: Control, key: String, desc: String):
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	parent.add_child(hbox)
	var key_lbl = Label.new()
	key_lbl.text = key
	key_lbl.add_theme_font_size_override("font_size", 14)
	key_lbl.add_theme_color_override("font_color", Color(0.92, 0.90, 0.92))
	key_lbl.custom_minimum_size = Vector2(108, 0)
	hbox.add_child(key_lbl)
	var dash = Label.new()
	dash.text = "—"
	dash.add_theme_font_size_override("font_size", 14)
	dash.add_theme_color_override("font_color", Color(0.42, 0.40, 0.44))
	hbox.add_child(dash)
	var desc_lbl = Label.new()
	desc_lbl.text = desc
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.add_theme_color_override("font_color", Color(0.66, 0.64, 0.70))
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hbox.add_child(desc_lbl)

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
	var lbl = Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.layout_mode = 1
	lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lbl.offset_top = 80.0; lbl.offset_bottom = 120.0
	lbl.offset_left = -200.0; lbl.offset_right = 200.0
	lbl.z_index = 8
	$CanvasLayer/Control.add_child(lbl)
	var tw = create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.4)
	tw.tween_callback(lbl.queue_free)
