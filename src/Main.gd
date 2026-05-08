extends Node3D

@export var player_scene: PackedScene = preload("res://src/entities/player/Player.tscn")
@export var bot_scene: PackedScene = preload("res://src/entities/bot/Bot.tscn")
@export var bot_count: int = 11
var is_simulation: bool = false

enum GameState { MENU, PLAYING, RESULT }
var current_state: GameState = GameState.MENU

enum Difficulty { EASY, NORMAL, HARD, HELL }
var difficulty: Difficulty = Difficulty.NORMAL
var _diff_btns: Array = []
var _pressure_opt_in_check: CheckButton = null
var _diff_tooltip: PanelContainer = null
var _diff_tooltip_label: Label = null
var _records_selected_diff: int = 1
const DIFF_DESCRIPTIONS = [
	"봇 시야 75%  ·  반응 느림  ·  조준 부정확\n입문용 난이도.",
	"표준 난이도.",
	"봇 시야 125%  ·  즉각 반응  ·  정밀 조준\n극한의 도전.",
	"HP 1 시작  ·  힐 감소  ·  암전 + 폭격\n랜덤 이벤트: 힐추가반감 / 탄막 / 전원적대",
]

# Hell events
enum HellModifier { SCARCITY, BARRAGE, ALL_AGGRESSIVE }
var hell_modifier: HellModifier = HellModifier.SCARCITY
var _hell_blackout_timer: float = 0.0
var _hell_blackout_active: bool = false
var _hell_bomb_timer: float = 0.0
var _hell_overlay: ColorRect = null
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
const AssetCatalogScript = preload("res://src/core/AssetCatalog.gd")
const GameConfigScript = preload("res://src/core/GameConfig.gd")
const DebugFlagsScript = preload("res://src/core/DebugFlags.gd")
const DebugOverlayScript = preload("res://src/ui/DebugOverlay.gd")
const LootSpawnerScript = preload("res://src/core/LootSpawner.gd")
const MissionTrackerScript = preload("res://src/core/MissionTracker.gd")
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
	var start_idx = $CanvasLayer/Control/MainMenuPanel/VBoxContainer/StartBtn.get_index()

	var diff_lbl = Label.new()
	diff_lbl.text = "난이도"
	diff_lbl.custom_minimum_size = Vector2(0, 18)
	diff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_lbl.add_theme_font_size_override("font_size", 13)
	diff_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	vbox.add_child(diff_lbl)
	vbox.move_child(diff_lbl, start_idx)

	var diff_hbox = HBoxContainer.new()
	diff_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	diff_hbox.add_theme_constant_override("separation", 6)
	diff_hbox.custom_minimum_size = Vector2(0, 38)
	vbox.add_child(diff_hbox)
	vbox.move_child(diff_hbox, start_idx + 1)

	for i in range(4):
		var btn = Button.new()
		btn.text = ["쉬움", "보통", "어려움", "지옥"][i]
		btn.custom_minimum_size = Vector2(68, 0)
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(_on_difficulty_btn.bind(i))
		diff_hbox.add_child(btn)
		_diff_btns.append(btn)
		_apply_btn_style(btn)
	_update_diff_highlights()

	# 어려움 압박 미션 opt-in 체크버튼 (어려움 선택 시에만 표시)
	_pressure_opt_in_check = CheckButton.new()
	_pressure_opt_in_check.text = "압박 미션 활성화"
	_pressure_opt_in_check.custom_minimum_size = Vector2(310, 24)
	_pressure_opt_in_check.add_theme_font_size_override("font_size", 12)
	_pressure_opt_in_check.button_pressed = false
	_pressure_opt_in_check.visible = (difficulty == Difficulty.HARD)
	_pressure_opt_in_check.toggled.connect(func(v: bool): pressure_opt_in_hard = v)
	vbox.add_child(_pressure_opt_in_check)
	vbox.move_child(_pressure_opt_in_check, start_idx + 2)

	# Difficulty tooltip panel
	_diff_tooltip = PanelContainer.new()
	_diff_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ts = StyleBoxFlat.new()
	ts.bg_color = Color(0.06, 0.08, 0.10, 0.95)
	ts.border_color = Color(0.35, 0.60, 0.45, 0.8)
	ts.set_border_width_all(1); ts.set_corner_radius_all(4)
	ts.content_margin_left = 10; ts.content_margin_right = 10
	ts.content_margin_top = 6;   ts.content_margin_bottom = 6
	_diff_tooltip.add_theme_stylebox_override("panel", ts)
	_diff_tooltip_label = Label.new()
	_diff_tooltip_label.add_theme_font_size_override("font_size", 13)
	_diff_tooltip_label.add_theme_color_override("font_color", Color(0.82, 0.90, 0.84))
	_diff_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diff_tooltip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_diff_tooltip.add_child(_diff_tooltip_label)
	_diff_tooltip.custom_minimum_size = Vector2(240, 0)
	_diff_tooltip.visible = false
	$CanvasLayer/Control/MainMenuPanel.add_child(_diff_tooltip)
	for i in range(_diff_btns.size()):
		_diff_btns[i].mouse_entered.connect(_show_diff_tooltip.bind(i))
		_diff_btns[i].mouse_exited.connect(func(): if _diff_tooltip: _diff_tooltip.visible = false)

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

	var catalog = [
		{
			"id": "red_trigger", "label": "Red Trigger",
			"color": Color(1.0, 0.25, 0.25),
			"line1": "샷건 공격력 ×1.2  ·  근접 특화",
			"line2": "샷건 외 공격력 ×0.5\n샷건 외 탄퍼짐 극단적 (거의 난사)",
			"mods": {"red_trigger": true, "spread_all_shots": true},
		},
		{
			"id": "armor_sponge", "label": "Armor Sponge",
			"color": Color(0.35, 0.60, 1.0),
			"line1": "방어구 최대량 ×2.5  ·  힐→방어막",
			"line2": "이동 속도 -25%  ·  힐 사용 시 방어막 전환\n(붕대 +10 방어막 / 구급상자 +20 방어막)",
			"mods": {"max_shield_mult": 2.5, "heal_to_shield": true, "move_speed_mult": 0.75},
		},
		{
			"id": "silent_core", "label": "Silent Core",
			"color": Color(0.40, 0.95, 0.55),
			"line1": "달리기 소음 탐지 차단",
			"line2": "최대 HP / 방어막 -50%\n(들키면 즉시 위험)",
			"mods": {"footstep_radius_mult": 0.0, "max_health_mult": 0.5, "max_shield_mult": 0.5},
		},
		{
			"id": "zone_battery", "label": "Zone Battery",
			"color": Color(0.20, 0.85, 1.0),
			"line1": "자기장 내벽 8m 근방\n→ 방어막 +10/초 자동 충전",
			"line2": "힐·방어구 사용 불가",
			"mods": {
				"heal_mult": 0.0, "shield_recv_mult": 0.0,
				"zone_battery": true, "zone_battery_regen": 10.0, "zone_battery_range": 8.0,
			},
		},
	]

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
		_hell_blackout_timer = _hell_range("blackout_initial_min", "blackout_initial_max", 12.0, 20.0)
		_hell_bomb_timer = _hell_value("bomb_initial_timer", 20.0)
		_create_hell_overlay()
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
		var art = _pending_artifact
		if art.get("id", "") == "zone_battery":
			art = art.duplicate(true)
			var regen_by_diff = [10.0, 10.0, 5.0, 2.0]
			art.get("mods", {})["zone_battery_regen"] = regen_by_diff[clampi(difficulty as int, 0, 3)]
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
	_setup_records_controls()
	_populate_records_list()

func _setup_records_controls():
	var vbox = $CanvasLayer/Control/RecordsPanel/VBox
	if vbox.get_node_or_null("DiffTabs"): return  # already built

	var scroll_idx = $CanvasLayer/Control/RecordsPanel/VBox/Scroll.get_index()

	# Difficulty tab row
	var tabs = HBoxContainer.new()
	tabs.name = "DiffTabs"
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 6)
	vbox.add_child(tabs)
	vbox.move_child(tabs, scroll_idx)

	const DIFF_LABELS = ["쉬움", "보통", "어려움", "지옥"]
	for i in range(4):
		var btn = Button.new()
		btn.text = DIFF_LABELS[i]
		btn.custom_minimum_size = Vector2(68, 0)
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(_on_records_diff_tab.bind(i))
		_apply_btn_style(btn)
		tabs.add_child(btn)

	# CLEAR ALL button (before close button)
	var close_idx = $CanvasLayer/Control/RecordsPanel/VBox/CloseRecordsBtn.get_index()
	var clear_btn = Button.new()
	clear_btn.name = "ClearBtn"
	clear_btn.text = "CLEAR ALL"
	clear_btn.add_theme_font_size_override("font_size", 14)
	clear_btn.pressed.connect(_on_records_clear)
	_apply_btn_style(clear_btn)
	vbox.add_child(clear_btn)
	vbox.move_child(clear_btn, close_idx)

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
	var list = $CanvasLayer/Control/RecordsPanel/VBox/Scroll/List
	for child in list.get_children(): child.queue_free()

	# Update tab highlights
	const DIFF_COLORS = [Color(0.3,1.0,0.45), Color(1.0,0.88,0.25), Color(1.0,0.35,0.35), Color(0.75,0.1,1.0)]
	var tabs = $CanvasLayer/Control/RecordsPanel/VBox.get_node_or_null("DiffTabs")
	if tabs:
		for i in range(tabs.get_child_count()):
			tabs.get_child(i).modulate = DIFF_COLORS[i] if i == _records_selected_diff else Color(0.55, 0.55, 0.55)

	if not has_node("/root/Telemetry"): return
	var tel = get_node("/root/Telemetry")
	var history = tel.get_history_for_difficulty(_records_selected_diff)

	if history.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "기록 없음"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		list.add_child(empty_lbl)
		return

	var skull_tex = _make_menu_icon("skull")
	var hand_tex  = _make_menu_icon("hand")
	for record in history:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		list.add_child(row)

		# WIN / --- badge
		var badge = Label.new()
		badge.text = "WIN" if record.win else "---"
		badge.add_theme_font_size_override("font_size", 12)
		badge.custom_minimum_size = Vector2(32, 0)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_theme_color_override("font_color", Color.GOLD if record.win else Color(0.5, 0.5, 0.5))
		row.add_child(badge)

		# Rank
		var rank_lbl = Label.new()
		rank_lbl.text = "#%d" % record.rank
		rank_lbl.add_theme_font_size_override("font_size", 14)
		rank_lbl.custom_minimum_size = Vector2(32, 0)
		rank_lbl.add_theme_color_override("font_color", Color.GOLD if record.win else Color(0.85, 0.85, 0.85))
		row.add_child(rank_lbl)

		# Score (prominent)
		var score_val = record.get("score", 0)
		var score_lbl = Label.new()
		score_lbl.text = "%d" % score_val
		score_lbl.add_theme_font_size_override("font_size", 14)
		score_lbl.custom_minimum_size = Vector2(54, 0)
		score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var score_col = Color.GOLD if record.win else Color(0.7, 0.85, 1.0)
		score_lbl.add_theme_color_override("font_color", score_col)
		row.add_child(score_lbl)

		# Kills + Assists icons
		_add_icon_val(row, skull_tex, str(record.kills), Color(1.0, 0.92, 0.15))
		_add_icon_val(row, hand_tex, str(record.assists), Color(1.0, 0.6, 0.2))

		# Duration
		var time_lbl = Label.new()
		time_lbl.text = "%ds" % record.duration
		time_lbl.add_theme_font_size_override("font_size", 12)
		time_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		row.add_child(time_lbl)

		# Date (right-aligned)
		var date_lbl = Label.new()
		date_lbl.text = record.date
		date_lbl.add_theme_font_size_override("font_size", 11)
		date_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		date_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		date_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(date_lbl)

func _add_icon_val(parent: HBoxContainer, tex: ImageTexture, val: String, col: Color):
	var icon = TextureRect.new()
	icon.texture = tex
	icon.custom_minimum_size = Vector2(14, 14)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.modulate = col
	parent.add_child(icon)
	var lbl = Label.new()
	lbl.text = val
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", col)
	lbl.custom_minimum_size = Vector2(24, 0)
	parent.add_child(lbl)

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

func _hell_range(min_key: String, max_key: String, fallback_min: float, fallback_max: float) -> float:
	if not game_config:
		return randf_range(fallback_min, fallback_max)
	var a = float(game_config.hell_value(min_key, fallback_min))
	var b = float(game_config.hell_value(max_key, fallback_max))
	return randf_range(minf(a, b), maxf(a, b))

func _hell_value(key: String, fallback: float) -> float:
	return float(game_config.hell_value(key, fallback)) if game_config else fallback

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
	_process_hell_events(delta)
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
			var t = 1.0 - (supply_timer / 8.0) # 8.0 is the telegraph time
			supply_pillar.global_position.y = lerp(50.0, 0.0, t)
			
		if supply_timer <= 0:
			activate_supply_zone()

func handle_zone_lifecycle(delta):
	zone.tick_lifecycle(delta)

func _on_zone_stage_changed(new_stage: int):
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
	supply_telegraphed = true
	supply_spawned = false
	supply_timer = 8.0
	supply_pos = Vector3(randf_range(-25, 25), 1.0, randf_range(-25, 25))
	
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
	if supply_pillar:
		supply_pillar.queue_free()
		supply_pillar = null
	
	# Spawn Rare Loot cluster: 1 guaranteed railgun + 4 consumables
	if railgun_item:
		var rg = pickup_scene.instantiate()
		$Loot.add_child(rg)
		rg.global_position = supply_pos
		rg.init(railgun_item.duplicate(true))
	for i in range(4):
		var pickup = pickup_scene.instantiate()
		$Loot.add_child(pickup)
		var offset = Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5))
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

	# Pixel art capsule logo above title
	var logo_size = 80
	var img = Image.create(logo_size, logo_size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx = logo_size / 2
	var cy = logo_size / 2
	var rx = 18; var ry = 32
	for py in range(logo_size):
		for px in range(logo_size):
			var dx = float(px - cx) / rx
			var dy = float(py - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				var top_half = py < cy
				var border = (dx * dx + dy * dy) > 0.80
				if border:
					img.set_pixel(px, py, Color(0.15, 0.15, 0.22, 1.0))
				elif top_half:
					img.set_pixel(px, py, Color(0.25, 0.55, 1.0, 1.0))
				else:
					img.set_pixel(px, py, Color(0.9, 0.25, 0.25, 1.0))
	# Divider line
	for px in range(cx - rx + 2, cx + rx - 1):
		img.set_pixel(px, cy, Color(0.15, 0.15, 0.22, 1.0))
		img.set_pixel(px, cy - 1, Color(0.15, 0.15, 0.22, 1.0))
	var logo_tex = ImageTexture.create_from_image(img)
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
	_build_help_panel()

func _build_help_panel():
	var vbox = $CanvasLayer/Control/HelpPanel/VBox
	# Remove old text label, keep Title and CloseBtn
	for child in vbox.get_children():
		if child.name == "Text":
			child.queue_free()
	# Insert structured content between Title and CloseHelpBtn
	var close_idx = $CanvasLayer/Control/HelpPanel/VBox/CloseHelpBtn.get_index()

	# Scroll container for all content
	var scroll = ScrollContainer.new()
	scroll.layout_mode = 2
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 300)
	vbox.add_child(scroll)
	vbox.move_child(scroll, close_idx)

	var content = VBoxContainer.new()
	content.layout_mode = 2
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	scroll.add_child(content)

	# ── CONTROLS ──
	_help_section(content, "CONTROLS")
	_make_key_row(content, ["W","A","S","D"], "이동")
	_make_key_row(content, ["MOUSE"], "조준 (캐릭터가 커서 방향을 바라봄)")
	_make_key_row(content, ["LMB"], "사격 / 칼 공격")
	_make_key_row(content, ["F"], "근처 아이템 줍기")
	_make_key_row(content, ["Q"], "붕대/구급상자 사용 (HP 회복)")
	_make_key_row(content, ["R"], "재장전")
	_make_key_row(content, ["C"], "웅크리기 토글 (스텔스 증가)")
	_make_key_row(content, ["SPACE"], "점프")
	_make_key_row(content, ["`"], "근접 무기 (칼)")
	_make_key_row(content, ["1","2","3","4"], "총기 슬롯 전환")
	_make_key_row(content, ["ESC"], "일시정지 / 메뉴")

	# ── HUD GUIDE ──
	_help_section(content, "HUD 아이콘")
	_make_icon_row(content, "skull", Color(1.0,0.92,0.15), "Kill 수")
	_make_icon_row(content, "hand",  Color(1.0,0.6, 0.2 ), "Assist 수")
	_make_icon_row(content, "person",Color(0.72,0.72,0.72), "현재 생존자 수")
	_make_text_row(content, "♥", Color(0.95,0.25,0.25), "붕대 보유 수")
	_make_text_row(content, "◆", Color(1.0, 0.85,0.1 ), "구급상자 보유 수")

	# ── SYSTEMS ──
	_help_section(content, "SYSTEMS")
	_make_desc_row(content, "자기장", "파란 링 밖에 있으면 지속 피해. 타이머가 빨간색이 되기 전에 이동.")
	_make_desc_row(content, "보급 캡슐", "자기장 2단계에 맵 중앙 낙하. 레일건 포함 희귀 아이템.")
	_make_desc_row(content, "아티팩트", "매치 시작 전 1개 선택 가능. 강한 장점과 패널티가 함께 적용됨.")
	_make_desc_row(content, "압박 미션", "Hell은 자동 활성화. Hard는 메뉴에서 opt-in 가능.")
	_make_desc_row(content, "스텔스", "풀숲에서 웅크리면 봇 탐지가 크게 늦어짐.")
	_make_desc_row(content, "무기 획득", "주우면 탄창 1/3 장전. 탄약 아이템은 예비(+N)로 쌓이고 R로 보충.")
	_make_desc_row(content, "중복 제한", "같은 종류 무기는 두 번 주울 수 없음.")

func _help_section(parent: VBoxContainer, title: String):
	var spacer = Control.new(); spacer.custom_minimum_size = Vector2(0, 6); parent.add_child(spacer)
	var lbl = Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.9, 0.65))
	parent.add_child(lbl)
	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(0.3, 0.55, 0.35, 0.6)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sep)

func _make_key_row(parent: VBoxContainer, keys: Array, desc: String):
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	for k in keys:
		var kp = PanelContainer.new()
		var ks = StyleBoxFlat.new()
		ks.bg_color = Color(0.18, 0.20, 0.25)
		ks.border_color = Color(0.62, 0.65, 0.72)
		ks.set_border_width_all(1); ks.set_corner_radius_all(3)
		ks.content_margin_left = 6; ks.content_margin_right = 6
		ks.content_margin_top = 2; ks.content_margin_bottom = 2
		kp.add_theme_stylebox_override("panel", ks)
		var kl = Label.new()
		kl.text = k
		kl.add_theme_font_size_override("font_size", 12)
		kl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
		kp.add_child(kl)
		row.add_child(kp)
	var dl = Label.new()
	dl.text = "  " + desc
	dl.add_theme_font_size_override("font_size", 13)
	dl.add_theme_color_override("font_color", Color(0.78, 0.82, 0.78))
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(dl)

func _make_icon_row(parent: VBoxContainer, shape: String, col: Color, desc: String):
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var icon = TextureRect.new()
	icon.texture = _make_menu_icon(shape)
	icon.custom_minimum_size = Vector2(16, 16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.modulate = col
	row.add_child(icon)
	var dl = Label.new()
	dl.text = desc
	dl.add_theme_font_size_override("font_size", 13)
	dl.add_theme_color_override("font_color", Color(0.78, 0.82, 0.78))
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(dl)

func _make_text_row(parent: VBoxContainer, symbol: String, col: Color, desc: String):
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var sym = Label.new()
	sym.text = symbol
	sym.add_theme_font_size_override("font_size", 15)
	sym.add_theme_color_override("font_color", col)
	sym.custom_minimum_size = Vector2(16, 0)
	sym.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(sym)
	var dl = Label.new()
	dl.text = desc
	dl.add_theme_font_size_override("font_size", 13)
	dl.add_theme_color_override("font_color", Color(0.78, 0.82, 0.78))
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(dl)

func _make_desc_row(parent: VBoxContainer, label: String, desc: String):
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var ll = Label.new()
	ll.text = label
	ll.add_theme_font_size_override("font_size", 13)
	ll.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	ll.custom_minimum_size = Vector2(72, 0)
	row.add_child(ll)
	var dl = Label.new()
	dl.text = desc
	dl.add_theme_font_size_override("font_size", 12)
	dl.add_theme_color_override("font_color", Color(0.72, 0.75, 0.72))
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(dl)

static func _make_menu_icon(shape: String) -> ImageTexture:
	const S = 12
	var img = Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var px: Array
	match shape:
		"skull":
			px = [
				[0,0,1,1,1,1,1,1,0,0,0,0],
				[0,1,1,1,1,1,1,1,1,0,0,0],
				[1,1,1,1,1,1,1,1,1,1,0,0],
				[1,1,0,0,1,1,0,0,1,1,0,0],
				[1,1,0,0,1,1,0,0,1,1,0,0],
				[1,1,1,1,1,1,1,1,1,1,0,0],
				[1,1,1,1,1,1,1,1,1,1,0,0],
				[0,1,0,1,1,0,1,1,0,1,0,0],
				[0,1,0,1,1,0,1,1,0,1,0,0],
				[0,0,0,0,0,0,0,0,0,0,0,0],
				[0,0,0,0,0,0,0,0,0,0,0,0],
				[0,0,0,0,0,0,0,0,0,0,0,0],
			]
		"hand":
			px = [
				[0,0,1,1,0,0,0,0,0,0,0,0],
				[0,1,1,1,0,0,0,0,0,0,0,0],
				[0,1,1,1,0,1,1,0,0,0,0,0],
				[0,1,1,1,1,1,1,0,1,1,0,0],
				[0,1,1,1,1,1,1,1,1,1,0,0],
				[1,1,1,1,1,1,1,1,1,1,0,0],
				[1,1,1,1,1,1,1,1,1,1,0,0],
				[0,1,1,1,1,1,1,1,1,0,0,0],
				[0,0,1,1,1,1,1,1,0,0,0,0],
				[0,0,0,1,1,1,1,0,0,0,0,0],
				[0,0,0,0,0,0,0,0,0,0,0,0],
				[0,0,0,0,0,0,0,0,0,0,0,0],
			]
		"person":
			px = [
				[0,0,0,1,1,1,0,0,0,0,0,0],
				[0,0,0,1,1,1,0,0,0,0,0,0],
				[0,0,0,1,1,1,0,0,0,0,0,0],
				[0,0,1,1,1,1,1,0,0,0,0,0],
				[0,0,0,1,1,1,0,0,0,0,0,0],
				[0,0,0,1,1,1,0,0,0,0,0,0],
				[0,0,1,1,1,1,1,0,0,0,0,0],
				[0,0,1,1,1,1,1,0,0,0,0,0],
				[0,1,1,1,0,1,1,1,0,0,0,0],
				[0,1,1,0,0,0,1,1,0,0,0,0],
				[0,1,0,0,0,0,0,1,0,0,0,0],
				[0,0,0,0,0,0,0,0,0,0,0,0],
			]
		_:
			px = []
	for y in range(S):
		for x in range(S):
			if y < px.size() and x < px[y].size() and px[y][x]:
				img.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(img)

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

func _show_diff_tooltip(idx: int):
	if not _diff_tooltip or idx >= _diff_btns.size(): return
	_diff_tooltip_label.text = DIFF_DESCRIPTIONS[idx]
	var gr = _diff_btns[idx].get_global_rect()
	_diff_tooltip.global_position = Vector2(gr.position.x - 10, gr.end.y + 6)
	_diff_tooltip.visible = true

func _on_difficulty_btn(idx: int):
	difficulty = idx as Difficulty
	_update_diff_highlights()
	if _pressure_opt_in_check:
		_pressure_opt_in_check.visible = (difficulty == Difficulty.HARD)

func _update_diff_highlights():
	const DIFF_COLORS = [
		Color(0.3, 1.0, 0.45),   # 쉬움 — 초록
		Color(1.0, 0.88, 0.25),  # 보통 — 노랑
		Color(1.0, 0.35, 0.35),  # 어려움 — 빨강
		Color(0.75, 0.1,  1.0),  # 지옥 — 보라
	]
	for i in range(_diff_btns.size()):
		_diff_btns[i].modulate = DIFF_COLORS[i] if i == difficulty else Color(0.55, 0.55, 0.55)

# ─── HELL EVENTS ─────────────────────────────────────────────────────────────

func _create_hell_overlay():
	_hell_overlay = ColorRect.new()
	_hell_overlay.layout_mode = 1
	_hell_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hell_overlay.color = Color(0, 0, 0, 0.0)
	_hell_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hell_overlay.z_index = 10
	$CanvasLayer/Control.add_child(_hell_overlay)

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
	const MOD_DESC = {
		0: ["아이템 희귀화", "힐·장비 드롭 확률이 크게 낮아집니다"],
		1: ["포격 강화",     "포격 범위와 폭탄 수가 크게 늘어납니다"],
		2: ["전원 경계",     "모든 봇이 처음부터 당신을 추적합니다"],
	}
	var md = MOD_DESC[hell_modifier as int]
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

func _process_hell_events(delta):
	if difficulty != Difficulty.HELL or game_over: return
	if not _hell_blackout_active:
		_hell_blackout_timer -= delta
		if _hell_blackout_timer <= 0:
			_trigger_blackout()
	if match_timer > 10.0:
		_hell_bomb_timer -= delta
		if _hell_bomb_timer <= 0:
			_hell_bomb_timer = _hell_range("bomb_repeat_min", "bomb_repeat_max", 18.0, 28.0)
			_start_bombardment()

func _trigger_blackout():
	if _hell_blackout_active or not is_instance_valid(_hell_overlay): return
	_hell_blackout_active = true
	var hold = randf_range(2.0, 4.0)
	var tw = create_tween()
	tw.tween_property(_hell_overlay, "color:a", 0.88, 0.3)
	tw.tween_interval(hold)
	tw.tween_property(_hell_overlay, "color:a", 0.0, 0.5)
	tw.tween_callback(func():
		_hell_blackout_active = false
		_hell_blackout_timer = _hell_range("blackout_repeat_min", "blackout_repeat_max", 15.0, 28.0)
	)
	if has_node("/root/Telemetry"):
		get_node("/root/Telemetry").log_hell_event("blackout")

func _make_bomb_disc(radius: float, col: Color) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = radius; cyl.bottom_radius = radius; cyl.height = 0.12
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(col.r, col.g * 0.4, 0.0)
	mat.emission_energy_multiplier = 1.2
	cyl.surface_set_material(0, mat)
	m.mesh = cyl
	return m

func _start_bombardment():
	_show_event_text("BOMBARDMENT INCOMING", Color(1.0, 0.35, 0.0))
	if has_node("/root/Telemetry"):
		get_node("/root/Telemetry").log_hell_event("bombardment_warned")

	var angle = randf() * TAU
	var dist  = randf() * zone.current_radius * 0.85
	var center = Vector3(
		zone.current_center.x + cos(angle) * dist,
		0.05,
		zone.current_center.y + sin(angle) * dist
	)

	if hell_modifier == HellModifier.BARRAGE:
		const OUTER_R       = 14.0
		const PELLET_R      = 2.5
		const PELLET_DAMAGE = 22.0
		const PELLET_COUNT  = 10
		const BASE_DELAY    = 0.7

		var outer = _make_bomb_disc(OUTER_R, Color(1.0, 0.1, 0.1, 0.3))
		add_child(outer)
		outer.global_position = center

		for i in range(PELLET_COUNT):
			var pa   = randf() * TAU
			var pr   = randf() * OUTER_R
			var pos  = Vector3(center.x + cos(pa) * pr, 0.05, center.z + sin(pa) * pr)
			var disc = _make_bomb_disc(PELLET_R, Color(1.0, 0.45, 0.0, 0.75))
			add_child(disc)
			disc.global_position = pos
			var delay = BASE_DELAY + i * 0.06
			get_tree().create_timer(delay).timeout.connect(func():
				if is_instance_valid(disc): disc.queue_free()
				for actor in get_tree().get_nodes_in_group("actors"):
					if not is_instance_valid(actor): continue
					if actor is Entity and actor.is_dead: continue
					if actor.global_position.distance_to(pos) <= PELLET_R:
						actor.take_damage(PELLET_DAMAGE, "zone")
			)

		get_tree().create_timer(BASE_DELAY + PELLET_COUNT * 0.06).timeout.connect(func():
			if is_instance_valid(outer): outer.queue_free()
			if is_instance_valid(_hell_overlay):
				_hell_overlay.color = Color(0.9, 0.3, 0.0, 0.5)
				create_tween().tween_property(_hell_overlay, "color:a", 0.0, 0.3)
			if has_node("/root/Telemetry"):
				get_node("/root/Telemetry").log_hell_event("bombardment_hit")
		)
	else:
		# ── 비-BARRAGE 포격 튜닝 파라미터 ────────────────────────────────────────
		# 봇에게 회피 로직이 없으므로 데미지를 낮게 유지.
		# 봇 회피 AI 추가 시 BOMB_DAMAGE를 30~45 수준으로 상향 고려.
		const ZONE_RADIUS  = 15.0  # 폭탄이 퍼지는 전체 반경 (m) — 넓힐수록 긴장감↑
		const BOMB_RADIUS  = 3.0   # 개별 폭탄 폭발 반경 (m)
		const BOMB_DAMAGE  = 18.0  # 개별 폭탄 데미지 — 봇 회피 추가 시 상향
		const WARN_DELAY   = 1.5   # 첫 폭탄까지 경고 시간 (s) — 너무 짧으면 불공평
		const PELLET_COUNT = 10    # 투하 개수 — 늘릴수록 화면이 정신없어짐
		const PELLET_GAP   = 0.18  # 폭탄 간 간격 (s) — 줄일수록 밀집·혼란스러움
		# ─────────────────────────────────────────────────────────────────────────

		for i in PELLET_COUNT:
			var spread_a = randf() * TAU
			var spread_r = randf_range(0.0, ZONE_RADIUS)
			var pos = Vector3(
				center.x + cos(spread_a) * spread_r,
				0.05,
				center.z + sin(spread_a) * spread_r
			)
			var disc = _make_bomb_disc(BOMB_RADIUS, Color(1.0, 0.1, 0.1, 0.55))
			add_child(disc)
			disc.global_position = pos
			var fire_at = WARN_DELAY + i * PELLET_GAP
			get_tree().create_timer(fire_at).timeout.connect(func():
				if is_instance_valid(disc): disc.queue_free()
				for actor in get_tree().get_nodes_in_group("actors"):
					if not is_instance_valid(actor): continue
					if actor is Entity and actor.is_dead: continue
					if actor.global_position.distance_to(pos) <= BOMB_RADIUS:
						actor.take_damage(BOMB_DAMAGE, "zone")
				if is_instance_valid(_hell_overlay):
					_hell_overlay.color = Color(0.9, 0.3, 0.0, 0.4)
					create_tween().tween_property(_hell_overlay, "color:a", 0.0, 0.25)
			)
		# 마지막 폭탄 착탄 후 텔레메트리 기록
		get_tree().create_timer(WARN_DELAY + (PELLET_COUNT - 1) * PELLET_GAP + 0.05).timeout.connect(func():
			if has_node("/root/Telemetry"):
				get_node("/root/Telemetry").log_hell_event("bombardment_hit")
		)

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
	if get_node_or_null("CanvasLayer/Control/SettingsPanel"): return
	var ctrl = $CanvasLayer/Control
	var panel = PanelContainer.new()
	panel.name = "SettingsPanel"
	panel.layout_mode = 1
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -200.0; panel.offset_right = 200.0
	panel.offset_top  = -160.0; panel.offset_bottom = 160.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.04, 0.06, 0.10, 0.97)
	ps.border_color = Color(0.25, 0.55, 0.35, 0.8)
	ps.set_border_width_all(1); ps.set_corner_radius_all(6)
	ps.content_margin_left = 20; ps.content_margin_right = 20
	ps.content_margin_top = 16;  ps.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", ps)
	ctrl.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.88, 0.95, 0.9))
	vbox.add_child(title)

	# Volume row
	var vol_lbl = Label.new()
	vol_lbl.text = "VOLUME"
	vol_lbl.add_theme_font_size_override("font_size", 15)
	vol_lbl.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	vbox.add_child(vol_lbl)
	var slider = HSlider.new()
	slider.min_value = 0.0; slider.max_value = 1.0; slider.step = 0.01
	var cur_vol = db_to_linear(AudioServer.get_bus_volume_db(0))
	slider.value = cur_vol
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(slider)
	var vol_val_lbl = Label.new()
	vol_val_lbl.text = "%d%%" % int(cur_vol * 100)
	vol_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vol_val_lbl.add_theme_font_size_override("font_size", 13)
	vol_val_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	vbox.add_child(vol_val_lbl)
	slider.value_changed.connect(func(v: float):
		AudioServer.set_bus_volume_db(0, linear_to_db(v))
		vol_val_lbl.text = "%d%%" % int(v * 100)
	)

	# Fullscreen toggle
	var fs_btn = Button.new()
	var is_fs = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fs_btn.text = "FULLSCREEN: ON" if is_fs else "FULLSCREEN: OFF"
	fs_btn.add_theme_font_size_override("font_size", 18)
	fs_btn.pressed.connect(func():
		var new_fs = not (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
		if new_fs:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		fs_btn.text = "FULLSCREEN: ON" if new_fs else "FULLSCREEN: OFF"
	)
	_apply_btn_style(fs_btn)
	vbox.add_child(fs_btn)

	# Close + save
	var close_btn = Button.new()
	close_btn.text = "CLOSE"
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(func():
		_save_settings(slider.value, DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
		panel.queue_free()
	)
	_apply_btn_style(close_btn)
	vbox.add_child(close_btn)

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
