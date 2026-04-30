extends Node3D

@export var player_scene: PackedScene = preload("res://src/entities/player/Player.tscn")
@export var bot_scene: PackedScene = preload("res://src/entities/bot/Bot.tscn")
@export var bot_count: int = 11
var is_simulation: bool = false

enum GameState { MENU, PLAYING, RESULT }
var current_state: GameState = GameState.MENU

enum Difficulty { EASY, NORMAL, HARD, HELL }
var difficulty: Difficulty = Difficulty.NORMAL
const DIFFICULTY_PARAMS = {
	0: { "vision_mult": 0.75, "reaction_delay": 1.2, "aim_spread": 1.8,  "loot_break_mult": 0.0, "awareness_level": 0 },
	1: { "vision_mult": 1.0,  "reaction_delay": 0.5, "aim_spread": 1.0,  "loot_break_mult": 1.0, "awareness_level": 1 },
	2: { "vision_mult": 1.25, "reaction_delay": 0.0, "aim_spread": 0.65, "loot_break_mult": 1.5, "awareness_level": 2 },
	3: { "vision_mult": 1.5,  "reaction_delay": 0.0, "aim_spread": 0.5,  "loot_break_mult": 2.0, "awareness_level": 2 },
}
var _diff_btns: Array = []
var _pressure_opt_in_check: CheckButton = null
var _diff_tooltip: PanelContainer = null
var _diff_tooltip_label: Label = null
var _records_selected_diff: int = 1
const DIFF_DESCRIPTIONS = [
	"봇 시야 75%  ·  반응 느림  ·  조준 부정확\n배틀로얄 첫 입문에 추천.",
	"표준 봇 성능  ·  균형 잡힌 전투.",
	"봇 시야 125%  ·  즉각 반응  ·  정밀 조준\n극한의 도전.",
	"HP 1 시작  ·  힐 감소  ·  암전 + 폭격\n랜덤 모디파이어: 힐추가반감 / 탄막 / 전원적대",
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

var loot_hotspots: Array[Vector2] = []
var _spawn_positions: Array = []
var _zone_outside_time: Dictionary = {}

var current_zone_center: Vector2 = Vector2.ZERO
var current_zone_radius: float = 50.0
var current_zone_center_start: Vector2 = Vector2.ZERO
var current_zone_radius_start: float = 50.0
var next_zone_center: Vector2 = Vector2.ZERO
var next_zone_radius: float = 25.0

var zone_stage: int = 1
@export var zone_wait_time: float = 30.0
@export var zone_shrink_time: float = 20.0
@export var zone_damage: float = 2.0

var zone_timer: float = 0.0
var damage_tick_timer: float = 0.0
var is_shrinking: bool = false
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

const HEAL_ADVANCED_ITEM = preload("res://src/items/heal_advanced_pickup.tres")
const MissionTrackerScript = preload("res://src/core/MissionTracker.gd")

# MapSpec & Builder
const MapSpecScript = preload("res://src/core/MapSpec.gd")
var map_spec: Resource = null
@onready var world_builder = $WorldBuilder

# Navigation
var _nav_region: NavigationRegion3D = null

# Dynamic Supply
var supply_telegraphed: bool = false
var supply_spawned: bool = false
var _zone_warning_played: bool = false
var supply_pos: Vector3 = Vector3.ZERO
var supply_timer: float = 0.0
var supply_pillar: MeshInstance3D = null
var zone_ring: MeshInstance3D = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	# Check for autostart
	for arg in OS.get_cmdline_user_args():
		if "autostart=true" in arg:
			is_simulation = true
			Engine.time_scale = 5.0
			_load_map_spec()
			if map_spec:
				for poi in map_spec.pois:
					loot_hotspots.append(Vector2(poi.pos[0], poi.pos[1]))
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
		loot_hotspots.clear()
		for poi in map_spec.pois:
			loot_hotspots.append(Vector2(poi.pos[0], poi.pos[1]))
			
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
	diff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_lbl.add_theme_font_size_override("font_size", 13)
	diff_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	vbox.add_child(diff_lbl)
	vbox.move_child(diff_lbl, start_idx)

	var diff_hbox = HBoxContainer.new()
	diff_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	diff_hbox.add_theme_constant_override("separation", 6)
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

	$CanvasLayer/Control/ResultPanel/Content/RestartBtn.pressed.connect(restart_game)
	$CanvasLayer/Control/ResultPanel/Content/MenuBtn.pressed.connect(return_to_menu)
	_apply_btn_style($CanvasLayer/Control/ResultPanel/Content/RestartBtn)
	_apply_btn_style($CanvasLayer/Control/ResultPanel/Content/MenuBtn)
	var result_records_btn = Button.new()
	result_records_btn.text = "RECORDS"
	result_records_btn.add_theme_font_size_override("font_size", 24)
	result_records_btn.pressed.connect(_on_records_pressed)
	$CanvasLayer/Control/ResultPanel/Content.add_child(result_records_btn)
	_apply_btn_style(result_records_btn)
	
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
			start_game()

func _on_start_btn_pressed():
	start_game()

func start_game():
	current_state = GameState.PLAYING
	game_over = false
	match_timer = 0.0
	current_zone_center = Vector2.ZERO
	current_zone_radius = 50.0
	zone_stage = 1
	zone_timer = 15.0
	generate_next_zone()
	
	_show_panel("HUD")

	# 랜덤 보너스 미션 자동 배정
	mission_tracker = MissionTrackerScript.new()
	var pool = MissionTrackerScript.get_all_missions()
	mission_tracker.active_mission = pool[randi() % pool.size()]

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
		hell_modifier = randi() % 3 as HellModifier
		_hell_blackout_timer = randf_range(12.0, 20.0)
		_hell_bomb_timer = 20.0
		_create_hell_overlay()
		_show_hell_announcement()
	
	# Final Minimap Sync
	var minimap = get_node_or_null("CanvasLayer/Control/HUD/Minimap")
	if minimap and minimap.has_method("set_map_spec"):
		minimap.set_map_spec(map_spec)
	
	# Auto-screenshot for debug after 5 seconds (ONLY in simulation mode)
	pass

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
		get_node("/root/Telemetry").set_meta("_restart_difficulty", difficulty as int)
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

func _setup_navigation():
	var nav_mesh = NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.agent_height = 1.8
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_max_climb = 0.3
	nav_mesh.agent_max_slope = 45.0
	nav_mesh.cell_size = 0.3
	nav_mesh.cell_height = 0.2
	_nav_region = NavigationRegion3D.new()
	_nav_region.name = "NavRegion"
	_nav_region.navigation_mesh = nav_mesh
	add_child(_nav_region)
	_nav_region.bake_finished.connect(func(): print("[NAV] Bake complete"))
	_nav_region.bake_navigation_mesh()
	print("[NAV] Baking navigation mesh...")

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
		zone_ring.scale = Vector3(current_zone_radius, 1, current_zone_radius)
		zone_ring.position.x = current_zone_center.x
		zone_ring.position.z = current_zone_center.y
	
	if zone_stage == 2 and not supply_telegraphed:
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
	zone_timer -= delta
	if zone_timer <= 0:
		if not is_shrinking:
			is_shrinking = true
			zone_timer = zone_shrink_time
			current_zone_radius_start = current_zone_radius
			current_zone_center_start = current_zone_center
		else:
			current_zone_center = next_zone_center
			current_zone_radius = next_zone_radius
			zone_stage += 1
			if has_node("/root/Telemetry"): get_node("/root/Telemetry").set_stage(zone_stage)
			_print_bot_state_snapshot()
			spawn_loot(0.1 + (zone_stage * 0.1), 10)
			if heal_ban_until_stage > 0 and zone_stage > heal_ban_until_stage:
				heal_pickup_banned = false
				heal_ban_until_stage = -1
			if pressure_missions_enabled and not game_over:
				_trigger_pressure_mission()
			match zone_stage:
				2: zone_wait_time = 20.0; zone_shrink_time = 15.0; zone_damage = 5.0
				3: zone_wait_time = 15.0; zone_shrink_time = 12.0; zone_damage = 10.0
				4, _: zone_wait_time = 10.0; zone_shrink_time = 10.0; zone_damage = 15.0
			generate_next_zone()
			is_shrinking = false
			zone_timer = zone_wait_time
			_zone_warning_played = false
	if not is_shrinking and zone_timer <= 10.0 and not _zone_warning_played:
		_zone_warning_played = true
		if has_node("/root/Sfx"): get_node("/root/Sfx").play("zone_warning")
	if is_shrinking:
		var t = 1.0 - (zone_timer / zone_shrink_time)
		current_zone_radius = lerp(current_zone_radius_start, next_zone_radius, t)
		current_zone_center = current_zone_center_start.lerp(next_zone_center, t)

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

	# Spawn Bots
	var diff_params = DIFFICULTY_PARAMS[difficulty]
	for i in range(bot_count):
		var b = bot_scene.instantiate()
		$Entities.add_child(b)
		b.display_name = "Bot %d" % (i + 1)
		b.global_position = _get_safe_spawn_pos()
		b.died.connect(_on_bot_died.bind(b))
		b.apply_difficulty(diff_params)
		if difficulty == Difficulty.HELL and hell_modifier == HellModifier.ALL_AGGRESSIVE:
			b._apply_personality(b.Personality.AGGRESSIVE)

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

func _spawn_initial_loot():
	if loot_hotspots.is_empty(): return
	for hotspot in loot_hotspots:
		# 50% chance to spawn a weapon per hotspot
		if not weapon_templates.is_empty() and randf() < 0.5:
			var pickup = pickup_scene.instantiate()
			$Loot.add_child(pickup)
			var offset = Vector2(randf_range(-3, 3), randf_range(-3, 3))
			var sp = hotspot + offset
			pickup.global_position = Vector3(sp.x, 0.5, sp.y)
			pickup.init(weapon_templates[randi() % weapon_templates.size()].duplicate(true))
		for _i in range(randi_range(3, 5)):
			if consumable_templates.is_empty(): break
			var pickup = pickup_scene.instantiate()
			$Loot.add_child(pickup)
			var offset = Vector2(randf_range(-6, 6), randf_range(-6, 6))
			var sp = hotspot + offset
			pickup.global_position = Vector3(sp.x, 0.5, sp.y)
			pickup.init(consumable_templates[randi() % consumable_templates.size()])

func _is_clear_of_obstacles(pos: Vector2, margin: float = 2.0) -> bool:
	if not map_spec: return true
	for o in map_spec.obstacles:
		var type_str = o.get("type", "")
		if type_str == "bush_patch": continue  # bushes don't block movement
		var op = o.get("pos", [0, 0])
		var sc = o.get("scale", [1, 1, 1])
		var half_x = (sc[0] * 0.5) + margin
		var half_z = (sc[2] * 0.5) + margin
		if abs(pos.x - op[0]) < half_x and abs(pos.y - op[1]) < half_z:
			return false
	return true

func spawn_loot(prob: float, count_mult: int = 1):
	var total_to_spawn = int(loot_count * prob * count_mult)
	if total_to_spawn <= 0 or loot_hotspots.is_empty(): return
	for i in range(total_to_spawn):
		var hotspot = loot_hotspots[randi() % loot_hotspots.size()]
		var offset = Vector2(randf_range(-8, 8), randf_range(-8, 8))
		var spawn_pos = hotspot + offset
		
		var pickup = pickup_scene.instantiate()
		$Loot.add_child(pickup)
		pickup.global_position = Vector3(spawn_pos.x, 0.5, spawn_pos.y)
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

func generate_next_zone():
	next_zone_radius = current_zone_radius * 0.6
	var max_offset = current_zone_radius - next_zone_radius
	var angle = randf() * TAU
	var dist = randf() * max_offset
	next_zone_center = current_zone_center + Vector2(cos(angle), sin(angle)) * dist

func _on_bot_died(bot: Entity = null):
	# Capture final-duel context BEFORE decrementing alive_count
	if alive_count == 2 and bot and has_node("/root/Telemetry"):
		var pos_2d = Vector2(bot.global_position.x, bot.global_position.z)
		var zone_dist = pos_2d.distance_to(current_zone_center)
		var outside_extra = _zone_outside_time.get(bot.get_instance_id(), 0.0)
		get_node("/root/Telemetry").log_final_duel_death({
			"cause":            bot.last_damage_source,
			"state":            bot.State.keys()[bot.current_state],
			"zone_dist_ratio":  snappedf(zone_dist / max(current_zone_radius, 0.1), 0.01),
			"outside_sec":      outside_extra,
			"was_stuck":        bot._stuck_override_timer > 0.0,
			"stuck_sec":        snappedf(bot._stuck_timer, 0.01),
			"stage":            zone_stage,
			"bot_hp":           snappedf(bot.current_health, 0.1),
		})
	alive_count -= 1
	if bot:
		_zone_outside_time.erase(bot.get_instance_id())
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
		var p_outside = player_pos_2d.distance_to(current_zone_center) > current_zone_radius
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
		get_node("/root/Telemetry").end_match(final_rank, "Player" if is_victory else "Bot", zone_stage)
		
	# Hide Player HUD
	if is_instance_valid(player_ref):
		var p_canvas = player_ref.get_node_or_null("CanvasLayer")
		if p_canvas: p_canvas.visible = false

	# Show Result Panel
	_show_panel("Result")
	var stats_label = $CanvasLayer/Control/ResultPanel/Content/StatsLabel
	var header_label = $CanvasLayer/Control/ResultPanel/Content/HeaderLabel
	
	if header_label:
		header_label.text = "VICTORY!" if is_victory else "ELIMINATED"
		header_label.modulate = Color.GOLD if is_victory else Color.CRIMSON

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
			mission_result_text = "★ MISSION CLEAR: %s  (+%d)" % [mission_tracker.active_mission.title, mission_bonus_score]
		else:
			mission_result_text = "✗ MISSION FAILED: %s" % mission_tracker.active_mission.title
		if tel_node:
			tel_node.log_mission_result(mission_success)

	if stats_label:
		var tel = get_node("/root/Telemetry")
		var score = tel.calculate_score(
			final_rank, tel.metrics.session.kills,
			tel.metrics.session.assists, is_victory, difficulty as int
		) + mission_bonus_score
		stats_label.text = "RANK: #%d\nKILLS: %d\nASSISTS: %d\nDAMAGE: %.0f\nTIME: %d sec\nSCORE: %d" % [
			final_rank, tel.metrics.session.kills, tel.metrics.session.assists,
			tel.metrics.combat.total_damage_dealt, int(match_timer), score
		]

	# 미션 결과 — 별도 라벨로 분리 (클리핑 방지)
	var content = $CanvasLayer/Control/ResultPanel/Content
	if content:
		var mlabel = content.get_node_or_null("MissionResultLabel")
		if mission_result_text != "":
			if not mlabel:
				mlabel = Label.new()
				mlabel.name = "MissionResultLabel"
				mlabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				mlabel.add_theme_font_size_override("font_size", 14)
				mlabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				content.add_child(mlabel)
			mlabel.text = mission_result_text
			mlabel.modulate = Color.GOLD if mission_success else Color(0.9, 0.4, 0.4)
			mlabel.visible = true
		elif mlabel:
			mlabel.visible = false

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
		if b2d.distance_to(current_zone_center) > current_zone_radius:
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
		zone_stage, str(counts), outside_zone, avg_dist, positions.size()
	])

func handle_damage_tick(delta):
	damage_tick_timer += delta
	if damage_tick_timer >= 1.0:
		damage_tick_timer = 0.0
		var actors = get_tree().get_nodes_in_group("actors")
		for a in actors:
			if not is_instance_valid(a): continue
			if a is Entity and not a.is_dead:
				var pos_2d = Vector2(a.global_position.x, a.global_position.z)
				var uid = a.get_instance_id()
				var is_outside = pos_2d.distance_to(current_zone_center) > current_zone_radius
				if is_outside:
					_zone_outside_time[uid] = _zone_outside_time.get(uid, 0.0) + 1.0
					# Damage ramps up the longer you stay outside (caps at 2× after 10s)
					var time_mult = 1.0 + min(_zone_outside_time[uid], 10.0) * 0.1
					a.take_damage(zone_damage * time_mult, "zone")
				else:
					_zone_outside_time.erase(uid)
				if mission_tracker and a == player_ref:
					mission_tracker.on_player_zone_tick(is_outside)
					mission_tracker.on_pressure_zone_tick(is_outside, 1.0)

# ─── PRESSURE MISSION ────────────────────────────────────────────────────────

func _trigger_pressure_mission():
	if not mission_tracker: return
	var pool: Array
	if difficulty == Difficulty.HELL:
		pool = MissionTrackerScript.get_hell_pool()
	else:
		pool = MissionTrackerScript.get_hard_pool()
	if pool.is_empty(): return
	var descriptor = pool[randi() % pool.size()]
	mission_tracker.start_pressure(descriptor, zone_wait_time + zone_shrink_time)

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
	elif result == "fail":
		var _title = mission_tracker._active_pressure.get("title", "미션")
		_apply_pressure_effects(mission_tracker._active_pressure.get("penalty", []), false)
		if is_instance_valid(player_ref) and player_ref.has_method("show_pressure_flash"):
			player_ref.show_pressure_flash("✖ %s 실패" % _title, false)

func _apply_pressure_effects(effects: Array, is_reward: bool):
	if not is_instance_valid(player_ref): return
	for eff in effects:
		match int(eff["type"]):
			MissionTrackerScript.PressureEffect.AMMO_REFILL:
				for i in range(1, 5):
					if player_ref.weapon_slots[i] != null:
						player_ref.slot_ammo[i] = player_ref.weapon_slots[i].max_ammo
						player_ref.slot_reserve[i] = player_ref.weapon_slots[i].max_reserve_ammo if player_ref.weapon_slots[i].has("max_reserve_ammo") else 30
				player_ref._refresh_slot_hud()
			MissionTrackerScript.PressureEffect.AMMO_CLEAR:
				for i in range(1, 5):
					player_ref.slot_ammo[i] = 0
					player_ref.slot_reserve[i] = 0
				player_ref._refresh_slot_hud()
			MissionTrackerScript.PressureEffect.AMMO_ACTIVE_CLEAR:
				var s = player_ref.active_slot
				if s >= 1:
					player_ref.slot_ammo[s] = 0
					player_ref.slot_reserve[s] = 0
				player_ref._refresh_slot_hud()
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
				heal_ban_until_stage = zone_stage + 1
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
					nearest.current_state = nearest.State.CHASE
					nearest.chase_target = player_ref
			MissionTrackerScript.PressureEffect.ZONE_EXTEND:
				zone_timer += zone_wait_time * (float(eff.get("mult", 1.0)) - 1.0)
			MissionTrackerScript.PressureEffect.RAILGUN_UNLIMITED:
				railgun_unlimited_until_stage = zone_stage + int(eff.get("stages", 1))

# ─── MENU VISUALS ────────────────────────────────────────────────────────────

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
	_make_key_row(content, ["LMB"], "사격 / 근접 공격 (슬롯 0)")
	_make_key_row(content, ["E"], "근처 아이템 줍기")
	_make_key_row(content, ["Q"], "치료 아이템 사용 (+50 HP)")
	_make_key_row(content, ["R"], "재장전")
	_make_key_row(content, ["C"], "웅크리기 토글 (스텔스 증가)")
	_make_key_row(content, ["SPACE"], "점프")
	_make_key_row(content, ["0"], "근접 무기 (칼)")
	_make_key_row(content, ["1","2","3","4"], "총기 슬롯 전환")

	# ── HUD GUIDE ──
	_help_section(content, "HUD 아이콘")
	_make_icon_row(content, "skull", Color(1.0,0.92,0.15), "Kill 수")
	_make_icon_row(content, "hand",  Color(1.0,0.6, 0.2 ), "Assist 수")
	_make_icon_row(content, "person",Color(0.72,0.72,0.72), "현재 생존자 수")
	_make_text_row(content, "♥", Color(0.95,0.25,0.25), "치료 아이템 보유 수")
	_make_text_row(content, "◆", Color(1.0, 0.85,0.1 ), "고급 치료제 보유 수")

	# ── SYSTEMS ──
	_help_section(content, "SYSTEMS")
	_make_desc_row(content, "자기장", "파란 링 밖에 있으면 지속 피해. 타이머가 빨간색이 되기 전에 이동.")
	_make_desc_row(content, "보급 캡슐", "자기장 2단계에 맵 중앙 낙하. 레일건 포함 희귀 아이템.")
	_make_desc_row(content, "스텔스", "풀숲에서 웅크리면 봇 시야 차단.")
	_make_desc_row(content, "무기 획득", "주우면 탄창 1/3 장전. 탄약 아이템은 예비(+N)로 쌓임, R로 보충.")
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

	var panel = ColorRect.new()
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.layout_mode = 1
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -240.0; panel.offset_right = 240.0
	panel.offset_top  = -155.0; panel.offset_bottom = 155.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
	panel.color = Color(0.04, 0.0, 0.08, 0.95)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 20
	_hell_announce_panel = panel

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	const MOD_INFO = {
		0: ["★ SCARCITY — HEALS ×0.5",  Color(0.4, 0.8, 1.0)],
		1: ["★ BARRAGE MODE",            Color(1.0, 0.5, 0.0)],
		2: ["★ ALL BOTS HOSTILE",        Color(1.0, 0.2, 0.2)],
	}
	var mod = MOD_INFO[hell_modifier as int]
	for line_data in [
		["HELL MODE",              38, Color(0.85, 0.05, 1.0)],
		["HP 1 · HEALING REDUCED", 18, Color(1.0,  0.3,  0.3)],
		[mod[0],                   22, mod[1]],
		["BLACKOUTS & BOMBARDMENTS", 16, Color(0.9, 0.5, 0.1)],
		["SURVIVE IF YOU CAN",     15, Color(0.55, 0.55, 0.55)],
	]:
		var lbl = Label.new()
		lbl.text = line_data[0]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", line_data[1])
		lbl.add_theme_color_override("font_color", line_data[2])
		vbox.add_child(lbl)

	var start_btn = Button.new()
	start_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	start_btn.text = "START  [SPACE / ESC]"
	start_btn.add_theme_font_size_override("font_size", 18)
	start_btn.pressed.connect(_dismiss_hell_announcement)
	_apply_btn_style(start_btn)
	vbox.add_child(start_btn)

	$CanvasLayer/Control.add_child(panel)

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
			_hell_bomb_timer = randf_range(18.0, 28.0)
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
		_hell_blackout_timer = randf_range(15.0, 28.0)
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
	var dist  = randf() * current_zone_radius * 0.85
	var center = Vector3(
		current_zone_center.x + cos(angle) * dist,
		0.05,
		current_zone_center.y + sin(angle) * dist
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
		const BOMB_RADIUS = 5.0
		const BOMB_DAMAGE = 45.0
		const BOMB_DELAY  = 1.5
		var mesh_inst = _make_bomb_disc(BOMB_RADIUS, Color(1.0, 0.1, 0.1, 0.55))
		add_child(mesh_inst)
		mesh_inst.global_position = center
		get_tree().create_timer(BOMB_DELAY).timeout.connect(func():
			if is_instance_valid(mesh_inst): mesh_inst.queue_free()
			for actor in get_tree().get_nodes_in_group("actors"):
				if not is_instance_valid(actor): continue
				if actor is Entity and actor.is_dead: continue
				if actor.global_position.distance_to(center) <= BOMB_RADIUS:
					actor.take_damage(BOMB_DAMAGE, "zone")
			if is_instance_valid(_hell_overlay):
				_hell_overlay.color = Color(0.9, 0.3, 0.0, 0.4)
				create_tween().tween_property(_hell_overlay, "color:a", 0.0, 0.25)
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
