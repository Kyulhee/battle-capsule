extends Node3D

@export var player_scene: PackedScene = preload("res://src/entities/player/Player.tscn")
@export var bot_scene: PackedScene = preload("res://src/entities/bot/Bot.tscn")
@export var bot_count: int = 11
var is_simulation: bool = false

enum GameState { MENU, PLAYING, RESULT }
var current_state: GameState = GameState.MENU

@export_group("Loot")
@export var pickup_scene: PackedScene = preload("res://src/entities/pickup/Pickup.tscn")
@export var item_templates: Array[ItemData] = [
	preload("res://src/items/ammo_pickup.tres"),
	preload("res://src/items/heal_pickup.tres"),
	preload("res://src/items/weapon_ar.tres"),
	preload("res://src/items/weapon_shotgun.tres"),
	preload("res://src/items/armor_pickup.tres")
]
@export var loot_count: int = 40
@export var spawn_radius: float = 45.0

var loot_hotspots: Array[Vector2] = []

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

# MapSpec & Builder
const MapSpecScript = preload("res://src/core/MapSpec.gd")
var map_spec: Resource = null
@onready var world_builder = $WorldBuilder

# Dynamic Supply
var supply_telegraphed: bool = false
var supply_spawned: bool = false
var supply_pos: Vector3 = Vector3.ZERO
var supply_timer: float = 0.0
var supply_pillar: MeshInstance3D = null
var zone_ring: MeshInstance3D = null

func _ready():
	# Check for autostart
	for arg in OS.get_cmdline_user_args():
		if "autostart=true" in arg:
			is_simulation = true
			Engine.time_scale = 5.0
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
			
		loot_hotspots.clear()
		for poi in map_spec.pois:
			loot_hotspots.append(Vector2(poi.pos[0], poi.pos[1]))
			
	# Connect Buttons
	$CanvasLayer/Control/MainMenuPanel/VBoxContainer/StartBtn.pressed.connect(start_game)
	$CanvasLayer/Control/MainMenuPanel/VBoxContainer/RecordsBtn.pressed.connect(_on_records_pressed)
	$CanvasLayer/Control/MainMenuPanel/VBoxContainer/HelpBtn.pressed.connect(_on_help_pressed)
	$CanvasLayer/Control/MainMenuPanel/VBoxContainer/ExitBtn.pressed.connect(get_tree().quit)
	
	$CanvasLayer/Control/ResultPanel/Content/RestartBtn.pressed.connect(restart_game)
	$CanvasLayer/Control/ResultPanel/Content/MenuBtn.visible = false
	
	$CanvasLayer/Control/RecordsPanel/VBox/CloseRecordsBtn.pressed.connect(func(): _show_panel("MainMenu"))
	$CanvasLayer/Control/HelpPanel/VBox/CloseHelpBtn.pressed.connect(func(): _show_panel("MainMenu"))

	if is_simulation:
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
	
	if has_node("/root/Telemetry"):
		get_node("/root/Telemetry").start_match()
		get_node("/root/Telemetry").set_stage(1)
		
	alive_count = bot_count + 1
	spawn_entities()
	spawn_loot(0.05)
	
	# Final Minimap Sync
	var minimap = get_node_or_null("CanvasLayer/Control/HUD/Minimap")
	if minimap and minimap.has_method("set_map_spec"):
		minimap.set_map_spec(map_spec)
	
	# Auto-screenshot for debug after 5 seconds (ONLY in simulation mode)
	if is_simulation:
		await get_tree().create_timer(5.0).timeout
		_take_screenshot("debug_screenshot_auto.png")

func _show_panel(panel_name: String):
	var control = $CanvasLayer/Control
	for child in control.get_children():
		if child.name.ends_with("Panel"):
			child.visible = (child.name == panel_name + "Panel")
		elif child.name == "HUD":
			child.visible = (panel_name == "HUD")

func _on_records_pressed():
	_show_panel("Records")
	_populate_records_list()

func _on_help_pressed():
	_show_panel("Help")

func _populate_records_list():
	var list = $CanvasLayer/Control/RecordsPanel/VBox/Scroll/List
	for child in list.get_children(): child.queue_free()
	
	if has_node("/root/Telemetry"):
		var tel = get_node("/root/Telemetry")
		tel.load_history()
		for record in tel.match_history:
			var l = Label.new()
			l.text = "[%s] Rank: #%d | Kills: %d | Assists: %d | Time: %ds" % [
				record.date, record.rank, record.kills, record.assists, record.duration
			]
			if record.win: l.modulate = Color.GOLD
			list.add_child(l)

func restart_game():
	get_tree().reload_current_scene()

func return_to_menu():
	get_tree().reload_current_scene() # Simply reload to menu state

func _input(event):
	if event is InputEventKey and event.keycode == KEY_F12 and event.pressed:
		_take_screenshot("debug_screenshot_manual.png")

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

func _load_map_spec():
	var file = FileAccess.open("res://data/mapSpec_example.json", FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		map_spec = MapSpecScript.from_json(json_text)
	else:
		push_error("Main: mapSpec_example.json not found!")

func _process(delta):
	if current_state != GameState.PLAYING: return
	if game_over: return
	
	match_timer += delta
	handle_zone_lifecycle(delta)
	handle_damage_tick(delta)
	_check_match_end()
	
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
			spawn_loot(0.1 + (zone_stage * 0.1), 10)
			match zone_stage:
				2: zone_wait_time = 20.0; zone_shrink_time = 15.0; zone_damage = 5.0
				3: zone_wait_time = 15.0; zone_shrink_time = 12.0; zone_damage = 10.0
				4, _: zone_wait_time = 10.0; zone_shrink_time = 10.0; zone_damage = 15.0
			generate_next_zone()
			is_shrinking = false
			zone_timer = zone_wait_time
	if is_shrinking:
		var t = 1.0 - (zone_timer / zone_shrink_time)
		current_zone_radius = lerp(current_zone_radius_start, next_zone_radius, t)
		current_zone_center = current_zone_center_start.lerp(next_zone_center, t)

func spawn_entities():
	# Spawn Player
	var p = player_scene.instantiate()
	$Entities.add_child(p)
	p.add_to_group("players") # Ensure player is in correct group for telemetry
	p.global_position = _get_safe_spawn_pos()
	player_ref = p
	p.died.connect(_on_player_died)
	
	# Spawn Bots
	for i in range(bot_count):
		var b = bot_scene.instantiate()
		$Entities.add_child(b)
		b.global_position = _get_safe_spawn_pos()
		b.died.connect(_on_bot_died)

func _get_safe_spawn_pos() -> Vector3:
	var angle = randf() * TAU
	var dist = randf() * spawn_radius
	return Vector3(cos(angle) * dist, 1.0, sin(angle) * dist)

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
	
	# Spawn Rare Loot cluster
	for i in range(5):
		var pickup = pickup_scene.instantiate()
		$Loot.add_child(pickup)
		var offset = Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
		pickup.global_position = supply_pos + offset
		pickup.init(item_templates[randi() % item_templates.size()]) # Could be rare items
		
	if has_node("/root/Telemetry"): get_node("/root/Telemetry").log_supply_event("contest")

func generate_next_zone():
	next_zone_radius = current_zone_radius * 0.6
	var max_offset = current_zone_radius - next_zone_radius
	var angle = randf() * TAU
	var dist = randf() * max_offset
	next_zone_center = current_zone_center + Vector2(cos(angle), sin(angle)) * dist

func _on_bot_died():
	alive_count -= 1
	_check_match_end()

func _on_player_died():
	# Capture rank BEFORE decrementing alive_count
	var death_rank = alive_count
	alive_count -= 1
	# Player death always ends the match immediately
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

	if stats_label:
		var tel = get_node("/root/Telemetry")
		stats_label.text = "RANK: #%d\nKILLS: %d\nASSISTS: %d\nTIME: %d sec" % [
			final_rank, tel.metrics.session.kills, tel.metrics.session.assists, int(match_timer)
		]
	
	if is_simulation:
		get_tree().quit()

func handle_damage_tick(delta):
	damage_tick_timer += delta
	if damage_tick_timer >= 1.0:
		damage_tick_timer = 0.0
		var actors = get_tree().get_nodes_in_group("actors")
		for a in actors:
			if a is Entity and not a.is_dead:
				var pos_2d = Vector2(a.global_position.x, a.global_position.z)
				if pos_2d.distance_to(current_zone_center) > current_zone_radius:
					a.take_damage(zone_damage, "zone")
