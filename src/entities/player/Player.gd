extends Entity

@onready var camera_pivot = $CameraPivot
@onready var ray_cast = $RayCast3D
@onready var hud_label = $CanvasLayer/Control/HPLabel

var fire_cooldown: float = 0.0
var is_crouching: bool = false
var footstep_timer: float = 0.0
const FOOTSTEP_INTERVAL: float = 0.38
var _mesh_origin_y: float = 0.0

@onready var interaction_area = $InteractionArea
var zone_timer_label: Label = null
var mission_hud_label: Label = null
var pressure_hud_label: Label = null
var _flash_panel: PanelContainer = null
var _flash_label: Label = null
var _flash_tween: Tween = null
var kill_feed_container: VBoxContainer = null
var kill_feed_entries: Array = []

var camera_shake_amount: float = 0.0
var camera_shake_decay: float = 5.0

var _zone_warning_style: StyleBoxFlat = null
var _zone_warning_pulse: float = 0.0

var _occluder_fade_states: Dictionary = {}
const OCCLUDER_FADE_ALPHA: float = 0.35
const OCCLUDER_FADE_LINGER: float = 0.22
const OCCLUDER_FADE_IN_SPEED: float = 18.0
const OCCLUDER_FADE_OUT_SPEED: float = 8.0
const OCCLUDER_RAY_STEP: float = 0.16
const OCCLUDER_MAX_RAY_HITS: int = 8
var _heal_regen: float = 0.0
const HEAL_REGEN_RATE: float = 10.0

# ── Artifact System ──────────────────────────────────────────────────────────
var active_artifact: Dictionary = {}
var _artifact_mods: Dictionary = {
	"damage_mult": 1.0, "spread_mult": 1.0, "spread_all_shots": false, "red_trigger": false,
	"move_speed_mult": 1.0,
	"heal_mult": 1.0, "heal_to_shield": false,
	"shield_recv_mult": 1.0, "zone_dmg_mult": 1.0,
	"footstep_radius_mult": 1.0,
	"zone_battery": false, "zone_battery_regen": 0.0, "zone_battery_range": 0.0,
}
var _artifact_label: Label = null

# ── Shot Heat (AR / Pistol spread heat-up) ──────────────────────────────────
var _shot_heat: float = 0.0
const HEAT_MAX: float = 1.0
const HEAT_PER_SHOT_AR: float = 0.30
const HEAT_PER_SHOT_PISTOL: float = 0.20
const HEAT_DECAY: float = 0.55
const BASE_SPREAD_AR: float = 0.5
const BASE_SPREAD_PISTOL: float = 0.25

const MUZZLE_FLASH_SCN = preload("res://src/fx/MuzzleFlash.tscn")
const IMPACT_EFFECT_SCN = preload("res://src/fx/ImpactEffect.tscn")
const BULLET_TRAIL_SCN = preload("res://src/fx/BulletTrail.tscn")
const SHOT_PING_SCN = preload("res://src/fx/ShotPing.tscn")
const PISTOL_STATS = preload("res://src/core/pistol_stats.tres")
const PICKUP_SCN = preload("res://src/entities/pickup/Pickup.tscn")
const WeaponSlotManagerScript = preload("res://src/core/WeaponSlotManager.gd")

# ── Weapon Slot Inventory ────────────────────────────────────────────────
# slot 0 = knife (melee, always available), slots 1-4 = ranged weapons
const MELEE_RANGE: float = 1.8
const MELEE_DAMAGE: float = 14.0
const MELEE_RATE: float = 0.55

var _hp_bar:        ProgressBar  = null
var _sh_bar:        ProgressBar  = null
var _hp_fill:       StyleBoxFlat = null
var _hp_val:        Label        = null
var _sh_val:        Label        = null
var _stat_heal_val: Label        = null
var _stat_mk_val:   Label        = null
var _stat_kill_val: Label        = null
var _stat_asst_val: Label        = null
var _stat_alive_val: Label       = null

var slots = WeaponSlotManagerScript.new()

var slot_panels: Array = []
var slot_icon_rects: Array = []
var slot_ammo_labels: Array = []
var _catalog_icon_cache: Dictionary = {}

func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if stats:
		stats = stats.duplicate()
	super._ready()
	_apply_cosmetic_tint()

	# Zone timer (B구역 — top-center)
	zone_timer_label = Label.new()
	zone_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_timer_label.add_theme_font_size_override("font_size", 26)
	zone_timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
	zone_timer_label.add_theme_constant_override("outline_size", 8)
	var zone_panel = PanelContainer.new()
	$CanvasLayer/Control.add_child(zone_panel)
	zone_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	zone_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	zone_panel.position.y += 6
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	ps.set_corner_radius_all(6)
	ps.content_margin_left = 14; ps.content_margin_right = 14
	ps.content_margin_top = 4;   ps.content_margin_bottom = 4
	zone_panel.add_theme_stylebox_override("panel", ps)
	zone_panel.add_child(zone_timer_label)

	# Mission HUD (below zone timer)
	mission_hud_label = Label.new()
	mission_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_hud_label.add_theme_font_size_override("font_size", 15)
	mission_hud_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	mission_hud_label.add_theme_color_override("font_outline_color", Color.BLACK)
	mission_hud_label.add_theme_constant_override("outline_size", 6)
	mission_hud_label.visible = false
	$CanvasLayer/Control.add_child(mission_hud_label)
	mission_hud_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	mission_hud_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mission_hud_label.position.y += 46

	# Pressure Mission HUD (center-top, urgent style)
	pressure_hud_label = Label.new()
	pressure_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pressure_hud_label.add_theme_font_size_override("font_size", 15)
	pressure_hud_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.1))
	pressure_hud_label.add_theme_color_override("font_outline_color", Color.BLACK)
	pressure_hud_label.add_theme_constant_override("outline_size", 8)
	pressure_hud_label.visible = false
	$CanvasLayer/Control.add_child(pressure_hud_label)
	pressure_hud_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	pressure_hud_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pressure_hud_label.position.y += 96

	# Pressure / mission flash message (center screen)
	_flash_panel = PanelContainer.new()
	_flash_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_flash_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_flash_panel.grow_vertical = Control.GROW_DIRECTION_END
	_flash_panel.position.y += 110
	var flash_style = StyleBoxFlat.new()
	flash_style.bg_color = Color(0.05, 0.05, 0.05, 0.78)
	flash_style.set_corner_radius_all(6)
	flash_style.content_margin_left = 18; flash_style.content_margin_right = 18
	flash_style.content_margin_top = 7;   flash_style.content_margin_bottom = 7
	_flash_panel.add_theme_stylebox_override("panel", flash_style)
	_flash_label = Label.new()
	_flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash_label.add_theme_font_size_override("font_size", 16)
	_flash_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_flash_label.add_theme_constant_override("outline_size", 6)
	_flash_panel.add_child(_flash_label)
	_flash_panel.modulate.a = 0.0
	$CanvasLayer/Control.add_child(_flash_panel)

	# Kill feed (top-right)
	kill_feed_container = VBoxContainer.new()
	$CanvasLayer/Control.add_child(kill_feed_container)
	kill_feed_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	kill_feed_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	kill_feed_container.position.x -= 220
	kill_feed_container.position.y += 280
	kill_feed_container.custom_minimum_size = Vector2(200, 0)

	if hud_label: hud_label.visible = false
	var hud_a = VBoxContainer.new()
	$CanvasLayer/Control.add_child(hud_a)
	hud_a.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	hud_a.position = Vector2(12, 12)
	hud_a.add_theme_constant_override("separation", 3)

	# HP row
	var hp_row = HBoxContainer.new()
	hud_a.add_child(hp_row)
	hp_row.add_theme_constant_override("separation", 6)

	var hp_lbl = Label.new()
	hp_lbl.text = "HP"
	hp_lbl.add_theme_font_size_override("font_size", 14)
	hp_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	hp_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	hp_lbl.add_theme_constant_override("outline_size", 5)
	hp_row.add_child(hp_lbl)

	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(140, 14)
	_hp_bar.show_percentage = false
	var hp_bg = StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.12, 0.12, 0.12, 0.85)
	hp_bg.set_corner_radius_all(3)
	hp_bg.border_color = Color(0.4, 0.4, 0.4, 0.7)
	hp_bg.set_border_width_all(1)
	_hp_bar.add_theme_stylebox_override("background", hp_bg)
	_hp_fill = StyleBoxFlat.new()
	_hp_fill.bg_color = Color(0.2, 1.0, 0.35)
	_hp_fill.set_corner_radius_all(3)
	_hp_bar.add_theme_stylebox_override("fill", _hp_fill)
	hp_row.add_child(_hp_bar)

	_hp_val = Label.new()
	_hp_val.add_theme_font_size_override("font_size", 14)
	_hp_val.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_hp_val.add_theme_color_override("font_outline_color", Color.BLACK)
	_hp_val.add_theme_constant_override("outline_size", 5)
	hp_row.add_child(_hp_val)

	# SH row
	var sh_row = HBoxContainer.new()
	hud_a.add_child(sh_row)
	sh_row.add_theme_constant_override("separation", 6)

	var sh_lbl = Label.new()
	sh_lbl.text = "SH"
	sh_lbl.add_theme_font_size_override("font_size", 14)
	sh_lbl.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	sh_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	sh_lbl.add_theme_constant_override("outline_size", 5)
	sh_row.add_child(sh_lbl)

	_sh_bar = ProgressBar.new()
	_sh_bar.custom_minimum_size = Vector2(140, 14)
	_sh_bar.show_percentage = false
	var sh_bg = StyleBoxFlat.new()
	sh_bg.bg_color = Color(0.06, 0.08, 0.18, 0.85)
	sh_bg.set_corner_radius_all(3)
	sh_bg.border_color = Color(0.3, 0.4, 0.7, 0.7)
	sh_bg.set_border_width_all(1)
	_sh_bar.add_theme_stylebox_override("background", sh_bg)
	var sh_fill = StyleBoxFlat.new()
	sh_fill.bg_color = Color(0.3, 0.6, 1.0)
	sh_fill.set_corner_radius_all(3)
	_sh_bar.add_theme_stylebox_override("fill", sh_fill)
	sh_row.add_child(_sh_bar)

	_sh_val = Label.new()
	_sh_val.add_theme_font_size_override("font_size", 14)
	_sh_val.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	_sh_val.add_theme_color_override("font_outline_color", Color.BLACK)
	_sh_val.add_theme_constant_override("outline_size", 5)
	sh_row.add_child(_sh_val)

	var stat_row = HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", 4)
	hud_a.add_child(stat_row)

	_artifact_label = Label.new()
	_artifact_label.add_theme_font_size_override("font_size", 12)
	_artifact_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_artifact_label.add_theme_constant_override("outline_size", 5)
	_artifact_label.visible = false
	hud_a.add_child(_artifact_label)

	_stat_heal_val  = _stat_pair(stat_row, "♥", Color(0.95, 0.25, 0.25))
	_stat_mk_val    = _stat_pair(stat_row, "◆", Color(1.0,  0.85, 0.1 ))
	var sp1 = Label.new(); sp1.text = "  "; stat_row.add_child(sp1)
	_stat_kill_val  = _stat_pair_icon(stat_row, _make_hud_icon("skull"), Color(1.0,  0.92, 0.15))
	_stat_asst_val  = _stat_pair_icon(stat_row, _make_hud_icon("hand"),  Color(1.0,  0.6,  0.2 ))
	var sp2 = Label.new(); sp2.text = "  "; stat_row.add_child(sp2)
	_stat_alive_val = _stat_pair_icon(stat_row, _make_hud_icon("person"), Color(0.72, 0.72, 0.72))

	# Slot bar (bottom-center): 5 boxes — 0=knife, 1-4=weapons
	var slot_bar = HBoxContainer.new()
	$CanvasLayer/Control.add_child(slot_bar)
	slot_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	slot_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	slot_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	slot_bar.position.y -= 18
	slot_bar.position.x -= 201
	slot_bar.add_theme_constant_override("separation", 8)

	var slot_labels = ["`", "1", "2", "3", "4"]
	for i in range(5):
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(74, 84)
		slot_bar.add_child(panel)
		slot_panels.append(panel)

		var vbox = VBoxContainer.new()
		panel.add_child(vbox)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 1)

		var key_lbl = Label.new()
		key_lbl.text = slot_labels[i]
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_lbl.add_theme_font_size_override("font_size", 12)
		key_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		vbox.add_child(key_lbl)

		var icon_rect = TextureRect.new()
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(48, 48)
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		vbox.add_child(icon_rect)
		slot_icon_rects.append(icon_rect)

		var ammo_lbl = Label.new()
		ammo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ammo_lbl.add_theme_font_size_override("font_size", 12)
		vbox.add_child(ammo_lbl)
		slot_ammo_labels.append(ammo_lbl)

	if has_node("MeshInstance3D"):
		_mesh_origin_y = $MeshInstance3D.position.y

	health_changed.connect(_on_health_changed)
	shield_changed.connect(_on_shield_changed)
	if ray_cast:
		ray_cast.enabled = true
		ray_cast.add_exception(self)
		ray_cast.collision_mask = 2 | 8
	_on_health_changed(current_health, stats.max_health)
	slots.slot_switched.connect(_on_slot_switched)
	slots.reload_started.connect(func(): if Sfx: Sfx.play("reload"))
	slots.reload_done.connect(_on_reload_done)
	slots.inventory_changed.connect(_refresh_slot_hud)
	slots.gun_count_changed.connect(_on_gun_count_changed)
	slots.switch_to(0)
	slots.receive_weapon(PISTOL_STATS.duplicate())

	# Zone warning — pulsing red border when outside zone
	var zone_warn_panel = Panel.new()
	zone_warn_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	zone_warn_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zone_warning_style = StyleBoxFlat.new()
	_zone_warning_style.draw_center = false
	_zone_warning_style.bg_color = Color.TRANSPARENT
	_zone_warning_style.border_color = Color(1.0, 0.08, 0.05, 0.0)
	_zone_warning_style.set_border_width_all(28)
	zone_warn_panel.add_theme_stylebox_override("panel", _zone_warning_style)
	$CanvasLayer/Control.add_child(zone_warn_panel)

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_C: is_crouching = not is_crouching
			KEY_QUOTELEFT: slots.switch_to(0)
			KEY_1: slots.switch_to(1)
			KEY_2: slots.switch_to(2)
			KEY_3: slots.switch_to(3)
			KEY_4: slots.switch_to(4)
			KEY_R: slots.start_reload()

func reveal(duration: float = 2.0):
	super.reveal(duration)
	if has_node("/root/Telemetry"):
		get_node("/root/Telemetry").log_stealth("reveal_pings")

func set_in_bush(value: bool):
	if value and not is_in_bush:
		if has_node("/root/Telemetry"):
			get_node("/root/Telemetry").log_stealth("bush_entries")
	super.set_in_bush(value)

func take_damage(amount: float, source: String = "gun", weapon_type: String = "", source_node: Node3D = null):
	if source == "zone":
		amount *= _artifact_mods.get("zone_dmg_mult", 1.0)
	super.take_damage(amount, source, weapon_type, source_node)
	if Sfx: Sfx.play("hurt")
	var main = get_tree().root.get_node_or_null("Main")
	if main and main.mission_tracker:
		main.mission_tracker.on_pressure_damage(amount)
	var overlay = $CanvasLayer/Control/DamageOverlay
	if overlay:
		var tween = create_tween()
		tween.tween_property(overlay, "modulate:a", 0.3, 0.05)
		tween.tween_property(overlay, "modulate:a", 0.0, 0.2)

func _physics_process(delta):
	if is_dead: return
	if fire_cooldown > 0: fire_cooldown -= delta
	if _shot_heat > 0.0: _shot_heat = maxf(0.0, _shot_heat - HEAT_DECAY * delta)
	if _heal_regen > 0:
		var tick = min(HEAL_REGEN_RATE * delta, min(_heal_regen, stats.max_health - current_health))
		if tick > 0:
			current_health += tick
			_heal_regen -= tick
			health_changed.emit(current_health, stats.max_health)
		else:
			_heal_regen = 0.0
	slots.tick(delta)
	handle_aiming(delta)
	var effective_speed = stats.move_speed * (0.45 if is_crouching else 1.0) * _artifact_mods.get("move_speed_mult", 1.0)

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_dir == Vector2.ZERO:
		var manual_dir = Vector2.ZERO
		if Input.is_key_pressed(KEY_W): manual_dir.y -= 1
		if Input.is_key_pressed(KEY_S): manual_dir.y += 1
		if Input.is_key_pressed(KEY_A): manual_dir.x -= 1
		if Input.is_key_pressed(KEY_D): manual_dir.x += 1
		input_dir = manual_dir.normalized()
	var camera = camera_pivot.get_node("Camera3D")
	var cam_basis = camera.global_transform.basis
	var forward = cam_basis.z; forward.y = 0; forward = forward.normalized()
	var right = cam_basis.x; right.y = 0; right = right.normalized()
	var direction = (right * input_dir.x + forward * input_dir.y).normalized()
	if direction:
		velocity.x = lerp(velocity.x, direction.x * effective_speed, stats.acceleration * delta)
		velocity.z = lerp(velocity.z, direction.z * effective_speed, stats.acceleration * delta)
	else:
		velocity.x = lerp(velocity.x, 0.0, stats.friction * delta)
		velocity.z = lerp(velocity.z, 0.0, stats.friction * delta)

	# Footstep
	if is_on_floor() and Vector2(velocity.x, velocity.z).length() > 1.0:
		footstep_timer -= delta
		if footstep_timer <= 0:
			footstep_timer = FOOTSTEP_INTERVAL
			if Sfx and Sfx.has_method("play_footstep"):
				Sfx.play_footstep(_current_surface_id(), global_position)
			elif Sfx:
				Sfx.play("footstep", global_position)
	else:
		footstep_timer = 0.0

	# Fire / melee
	if Input.is_action_pressed("click") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if fire_cooldown <= 0 and slots.reload_timer <= 0:
			if slots.active_slot == 0:
				_melee_attack()
			else:
				var wdata = slots.weapon_slots[slots.active_slot]
				if wdata and slots.slot_ammo[slots.active_slot] > 0:
					if wdata.weapon_type == "shotgun":
						slots.consume_ammo()
						_sync_stats_ammo()
						for i in range(wdata.pellet_count): shoot_pellet(i)
						fire_cooldown = wdata.fire_rate
						_play_weapon_shot_sfx("shotgun")
						_refresh_slot_hud()
						_notify_mission_tracker_fire("shotgun")
					else:
						_shoot_with_slot(slots.active_slot)
				else:
					if Sfx: Sfx.play("dry_fire")
					fire_cooldown = 0.5
					slots.try_auto_switch()

	if Input.is_key_pressed(KEY_SPACE) and is_on_floor() and not is_crouching:
		velocity.y = 7.0
		footstep_timer = 0.0
	if Input.is_action_just_pressed("interact"): handle_interaction()
	if Input.is_key_pressed(KEY_Q): handle_healing()
	super._physics_process(delta)
	# Crouch stealth
	if is_crouching and reveal_timer <= 0:
		stealth_modifier = min(stealth_modifier, 0.35)
	# Crouch visual
	if has_node("MeshInstance3D"):
		$MeshInstance3D.scale.y = 0.55 if is_crouching else 1.0
		$MeshInstance3D.position.y = _mesh_origin_y - 0.225 if is_crouching else _mesh_origin_y
	camera_pivot.global_position = global_position

func _apply_cosmetic_tint() -> void:
	if not has_node("MeshInstance3D"):
		return
	var main = get_tree().root.get_node_or_null("Main")
	if not main:
		return
	var catalog = main.get("asset_catalog")
	if not catalog or not catalog.has_method("get_cosmetic_tint"):
		return
	var body_tint = catalog.get_cosmetic_tint("player.default", "body_tint", Color(0.2, 1.0, 0.2, 1.0))
	var mat = StandardMaterial3D.new()
	mat.albedo_color = body_tint
	mat.roughness = 0.5
	$MeshInstance3D.set_surface_override_material(0, mat)

func _process(delta):
	_handle_wall_transparency(delta)
	if camera_shake_amount > 0:
		var camera = camera_pivot.get_node("Camera3D")
		if camera:
			camera.h_offset = randf_range(-camera_shake_amount, camera_shake_amount)
			camera.v_offset = randf_range(-camera_shake_amount, camera_shake_amount)
			camera_shake_amount = lerp(camera_shake_amount, 0.0, camera_shake_decay * delta)
	var actors = get_tree().get_nodes_in_group("actors")
	for a in actors:
		if not a is Entity or a == self: continue
		var actor_visible = a.is_revealed_to(self)
		if a.has_node("MeshInstance3D"):
			a.get_node("MeshInstance3D").visible = actor_visible
		if a.has_node("ArchetypeSkin"):
			a.get_node("ArchetypeSkin").visible = actor_visible

	# Zone timer label + alive count HUD sync
	var main = get_tree().root.get_node_or_null("Main")
	if main and zone_timer_label:
		if main.zone.shrinking:
			zone_timer_label.text = "ZONE CLOSING"
			zone_timer_label.modulate = Color(1.0, 0.3, 0.3)
		else:
			var t = main.zone.timer
			zone_timer_label.text = "ZONE  %ds" % int(max(0, t))
			zone_timer_label.modulate = Color.CYAN if t > 10.0 else Color.YELLOW
	if main and mission_hud_label and main.mission_tracker and main.mission_tracker.active_mission:
		var tel = get_node_or_null("/root/Telemetry")
		mission_hud_label.text = main.mission_tracker.get_hud_text(tel)
		mission_hud_label.visible = true
		var failed = main.mission_tracker.get_early_fail_status(tel)
		mission_hud_label.modulate = Color(1.0, 0.32, 0.32) if failed else Color(1.0, 0.88, 0.3)
	elif mission_hud_label:
		mission_hud_label.visible = false
	if main and pressure_hud_label and main.mission_tracker and main.mission_tracker.pressure_active:
		pressure_hud_label.text = main.mission_tracker.get_pressure_hud_text()
		var deadline = main.mission_tracker.pressure_deadline
		pressure_hud_label.modulate = Color(1.0, 0.3, 0.1) if deadline <= 5.0 else Color(1.0, 0.65, 0.1)
		pressure_hud_label.visible = true
	elif pressure_hud_label:
		pressure_hud_label.visible = false
	_update_hud()

	# Reload HUD progress (per-frame count-up animation)
	if slots.reload_timer > 0 and not slot_ammo_labels.is_empty() and slots.active_slot > 0 and slots.reload_total_time > 0:
		var progress = 1.0 - slots.reload_timer / slots.reload_total_time
		var disp_ammo = int(lerp(float(slots.reload_ammo_start), float(slots.reload_ammo_target), progress))
		var wdata_r = slots.weapon_slots[slots.active_slot]
		var max_a_r = wdata_r.max_ammo if wdata_r else 0
		var transferred = disp_ammo - slots.reload_ammo_start
		var disp_res = max(0, slots.slot_reserve[slots.active_slot] - transferred)
		slot_ammo_labels[slots.active_slot].text = "%d/%d+%d" % [disp_ammo, max_a_r, disp_res]
		slot_ammo_labels[slots.active_slot].modulate = Color.YELLOW

	# Zone Battery: 자기장 경계 내측 근방에서 쉴드 자동 충전
	# shield_recv_mult를 우회해 직접 더함 (존 배터리 고유 충전 경로)
	if _artifact_mods.get("zone_battery", false) and not is_dead and current_shield < stats.max_shield:
		var _zbmain = get_tree().root.get_node_or_null("Main")
		if _zbmain:
			var pos2d = Vector2(global_position.x, global_position.z)
			var dist_from_center = pos2d.distance_to(_zbmain.zone.current_center)
			var dist_inside_edge = _zbmain.zone.current_radius - dist_from_center
			var rng = _artifact_mods.get("zone_battery_range", 0.0)
			if dist_inside_edge >= 0.0 and dist_inside_edge <= rng:
				current_shield = min(stats.max_shield, current_shield + _artifact_mods.get("zone_battery_regen", 0.0) * delta)
				shield_changed.emit(current_shield, stats.max_shield)

	# Zone warning pulse
	_update_zone_warning(delta)

	# Kill feed decay
	var i = kill_feed_entries.size() - 1
	while i >= 0:
		var entry = kill_feed_entries[i]
		entry["timer"] -= delta
		if entry["timer"] <= 0:
			entry["label"].queue_free()
			kill_feed_entries.remove_at(i)
		else:
			entry["label"].modulate.a = clamp(entry["timer"], 0.0, 1.0)
		i -= 1

func handle_interaction():
	var pickups = interaction_area.get_overlapping_areas()
	var closest: Pickup = null
	var min_dist = 999.0
	for area in pickups:
		if area is Pickup:
			if not can_sense_item(area.global_position):
				continue
			var d = global_position.distance_to(area.global_position)
			if d < min_dist: min_dist = d; closest = area
	if closest: closest.collect(self)

func handle_healing():
	var main = get_tree().root.get_node_or_null("Main")
	var is_hell = main != null and main.difficulty == 3
	var scarcity_mult = 0.5 if (is_hell and main != null and main.hell_modifier == main.HellModifier.SCARCITY) else 1.0

	# Armor Sponge: 힐 → 쉴드 전환 모드 (HP 회복 없음)
	if _artifact_mods.get("heal_to_shield", false):
		if current_shield >= stats.max_shield: return
		if stats.advanced_heals > 0:
			stats.advanced_heals -= 1
			receive_shield(20.0 * scarcity_mult)
			if Sfx: Sfx.play("heal", global_position)
			if has_node("/root/Telemetry"): get_node("/root/Telemetry").log_economy("heals_used")
			if main and main.mission_tracker:
				main.mission_tracker.on_pressure_heal_used()
				main.mission_tracker.on_player_medkit_used()
			_refresh_slot_hud()
		elif stats.heal_items > 0:
			stats.heal_items -= 1
			receive_shield(10.0 * scarcity_mult)
			if Sfx: Sfx.play("heal", global_position)
			if has_node("/root/Telemetry"): get_node("/root/Telemetry").log_economy("heals_used")
			if main and main.mission_tracker: main.mission_tracker.on_pressure_heal_used()
			_refresh_slot_hud()
		return

	# Zone Battery: 힐 완전 봉인
	if _artifact_mods.get("heal_mult", 1.0) == 0.0: return

	if current_health >= stats.max_health: return
	if stats.advanced_heals > 0:
		stats.advanced_heals -= 1
		var amount = 60.0 * (0.55 if is_hell else 1.0) * scarcity_mult * _artifact_mods.get("heal_mult", 1.0)
		current_health = min(stats.max_health, current_health + amount)
		health_changed.emit(current_health, stats.max_health)
		if Sfx: Sfx.play("heal", global_position)
		if has_node("/root/Telemetry"): get_node("/root/Telemetry").log_economy("heals_used")
		if main and main.mission_tracker:
			main.mission_tracker.on_pressure_heal_used()
			main.mission_tracker.on_player_medkit_used()
		_refresh_slot_hud()
	elif stats.heal_items > 0:
		stats.heal_items -= 1
		_heal_regen += 30.0 * (0.40 if is_hell else 1.0) * scarcity_mult * _artifact_mods.get("heal_mult", 1.0)
		if Sfx: Sfx.play("heal", global_position)
		if has_node("/root/Telemetry"): get_node("/root/Telemetry").log_economy("heals_used")
		if main and main.mission_tracker: main.mission_tracker.on_pressure_heal_used()
		_refresh_slot_hud()

func handle_aiming(delta):
	var camera = camera_pivot.get_node("Camera3D")
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	var cursor_pos = Plane(Vector3.UP, 0.5).intersects_ray(from, to)
	if cursor_pos:
		var target_diff = cursor_pos - global_position
		rotation.y = lerp_angle(rotation.y, atan2(target_diff.x, target_diff.z) + PI, stats.fov_turn_speed * delta)

func _on_shield_changed(_curr, _max): _update_hud()
func _on_health_changed(_curr, _max): _update_hud()
func _update_hud():
	var main = get_tree().root.get_node_or_null("Main")
	var alive = main.alive_count if main else 0
	var total = (main.bot_count + 1) if main else 0
	_update_status_hud(alive, total)

func _update_status_hud(alive: int, total: int = 0):
	var kills = 0; var assists = 0
	if has_node("/root/Telemetry"):
		var tel = get_node("/root/Telemetry")
		if tel.metrics.has("session"):
			kills = tel.metrics.session.kills
			assists = tel.metrics.session.assists
	# HP — 색상: 초록 > 40%, 노랑 > 20%, 빨강 이하
	var hp_ratio = current_health / stats.max_health if stats.max_health > 0 else 0.0
	var hp_col = Color(0.2, 1.0, 0.35) if hp_ratio > 0.4 \
		else (Color(1.0, 0.85, 0.0) if hp_ratio > 0.2 else Color(1.0, 0.25, 0.25))
	if _hp_fill:
		_hp_fill.bg_color = hp_col
	if _hp_bar:
		_hp_bar.max_value = stats.max_health
		_hp_bar.value = current_health
	if _hp_val:
		_hp_val.text = "%d" % int(current_health)
		_hp_val.add_theme_color_override("font_color", hp_col)
	if _sh_bar:
		_sh_bar.max_value = stats.max_shield
		_sh_bar.value = current_shield
	if _sh_val:
		_sh_val.text = "%d" % int(current_shield)
	if _stat_heal_val:  _stat_heal_val.text  = "×%d" % stats.heal_items
	if _stat_mk_val:    _stat_mk_val.text    = "×%d" % stats.advanced_heals
	if _stat_kill_val:  _stat_kill_val.text  = "%d" % kills
	if _stat_asst_val:  _stat_asst_val.text  = "%d" % assists
	if _stat_alive_val: _stat_alive_val.text = "%d/%d" % [alive, total] if total > 0 else "%d" % alive

func _stat_pair(container: HBoxContainer, symbol: String, col: Color) -> Label:
	var sym = Label.new()
	sym.text = symbol
	sym.add_theme_font_size_override("font_size", 15)
	sym.add_theme_color_override("font_color", col)
	sym.add_theme_color_override("font_outline_color", Color.BLACK)
	sym.add_theme_constant_override("outline_size", 6)
	container.add_child(sym)
	var val = Label.new()
	val.add_theme_font_size_override("font_size", 13)
	val.add_theme_color_override("font_color", col)
	val.add_theme_color_override("font_outline_color", Color.BLACK)
	val.add_theme_constant_override("outline_size", 5)
	container.add_child(val)
	return val

func _stat_pair_icon(container: HBoxContainer, icon_tex: ImageTexture, col: Color) -> Label:
	var icon = TextureRect.new()
	icon.texture = icon_tex
	icon.custom_minimum_size = Vector2(14, 14)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.modulate = col
	container.add_child(icon)
	var val = Label.new()
	val.add_theme_font_size_override("font_size", 13)
	val.add_theme_color_override("font_color", col)
	val.add_theme_color_override("font_outline_color", Color.BLACK)
	val.add_theme_constant_override("outline_size", 5)
	container.add_child(val)
	return val

static func _make_hud_icon(shape: String) -> ImageTexture:
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

# ── Slot system — public API (delegates to WeaponSlotManager) ────────────

func receive_weapon(wstats: StatsData) -> bool:
	return slots.receive_weapon(wstats)

func receive_ammo(weapon_type: String, amount: int):
	slots.receive_ammo(weapon_type, amount)

func _on_slot_switched(slot: int, wdata, ammo: int):
	if slot >= 1 and wdata:
		stats.weapon_type   = wdata.weapon_type
		stats.pellet_count  = wdata.pellet_count
		stats.attack_damage = wdata.attack_damage
		stats.fire_rate     = wdata.fire_rate
		stats.attack_range  = wdata.attack_range
		stats.current_ammo  = ammo
	_refresh_slot_hud()

func _on_reload_done():
	_sync_stats_ammo()
	_refresh_slot_hud()

func _on_gun_count_changed(count: int):
	var main = get_tree().root.get_node_or_null("Main")
	if main and main.mission_tracker:
		main.mission_tracker.on_weapon_slot_used(count)

func _sync_stats_ammo():
	if slots.active_slot >= 1:
		stats.current_ammo = slots.slot_ammo[slots.active_slot]

func _notify_mission_tracker_fire(weapon_type: String):
	var main = get_tree().root.get_node_or_null("Main")
	if main and main.mission_tracker:
		main.mission_tracker.on_player_fire(weapon_type)

func _melee_attack():
	reveal()
	_notify_mission_tracker_fire("knife")
	fire_cooldown = MELEE_RATE
	if Sfx: Sfx.play("melee")
	ray_cast.target_position = Vector3(0, 0, -MELEE_RANGE)
	ray_cast.force_raycast_update()
	if ray_cast.is_colliding():
		var hit_pos = ray_cast.get_collision_point()
		var impact = IMPACT_EFFECT_SCN.instantiate()
		get_tree().root.add_child(impact)
		impact.global_position = hit_pos
		var target = ray_cast.get_collider()
		if target.has_method("take_damage"):
			var melee_mult = 0.5 if _artifact_mods.get("red_trigger", false) else _artifact_mods.get("damage_mult", 1.0)
			target.take_damage(MELEE_DAMAGE * melee_mult, "melee", "knife", self)
			if Sfx: Sfx.play("hit", hit_pos)

func _refresh_slot_hud():
	if slot_panels.is_empty(): return
	var active_style = StyleBoxFlat.new()
	active_style.bg_color = Color(0.25, 0.25, 0.25, 0.9)
	active_style.border_color = Color.WHITE
	active_style.set_border_width_all(2)
	active_style.set_corner_radius_all(4)

	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.12, 0.12, 0.12, 0.8)
	normal_style.set_corner_radius_all(4)

	var empty_style = StyleBoxFlat.new()
	empty_style.bg_color = Color(0.25, 0.05, 0.05, 0.85)
	empty_style.set_corner_radius_all(4)

	for i in range(5):
		var panel = slot_panels[i]
		var out_of_ammo = (i >= 1) and slots.weapon_slots[i] != null and slots.slot_ammo[i] <= 0 and slots.slot_reserve[i] <= 0

		if i == slots.active_slot:
			panel.add_theme_stylebox_override("panel", active_style)
		elif out_of_ammo:
			panel.add_theme_stylebox_override("panel", empty_style)
		else:
			panel.add_theme_stylebox_override("panel", normal_style)

		if not slot_icon_rects.is_empty():
			if i == 0:
				slot_icon_rects[i].texture = _make_weapon_icon("knife")
			elif slots.weapon_slots[i] == null:
				slot_icon_rects[i].texture = _make_weapon_icon("")
			else:
				slot_icon_rects[i].texture = _make_weapon_icon(slots.weapon_slots[i].weapon_type)
		if i == 0:
			slot_ammo_labels[i].text = ""
			slot_ammo_labels[i].modulate = Color.WHITE
		elif slots.weapon_slots[i] == null:
			slot_ammo_labels[i].text = ""
		else:
			var ammo  = slots.slot_ammo[i]
			var max_a = slots.weapon_slots[i].max_ammo
			var res   = slots.slot_reserve[i]
			slot_ammo_labels[i].text = "%d/%d+%d" % [ammo, max_a, res]
			if ammo <= 0 and res <= 0:
				slot_ammo_labels[i].modulate = Color.RED
			elif ammo <= max_a / 4:
				slot_ammo_labels[i].modulate = Color.YELLOW
			else:
				slot_ammo_labels[i].modulate = Color.WHITE

func _load_catalog_icon(icon_id: String) -> Texture2D:
	if _catalog_icon_cache.has(icon_id):
		return _catalog_icon_cache[icon_id]

	var texture: Texture2D = null
	var main = get_tree().root.get_node_or_null("Main")
	if main:
		var catalog = main.get("asset_catalog")
		if catalog and catalog.has_method("get_path"):
			var path = catalog.get_path("icons", icon_id, "")
			if path != "" and ResourceLoader.exists(path):
				var loaded = load(path)
				if loaded is Texture2D:
					texture = loaded
			elif path != "" and FileAccess.file_exists(path):
				var image = Image.new()
				if image.load(path) == OK:
					texture = ImageTexture.create_from_image(image)

	_catalog_icon_cache[icon_id] = texture
	return texture

func _make_weapon_icon(wtype: String) -> Texture2D:
	if wtype != "":
		var catalog_icon = _load_catalog_icon("weapon.%s" % wtype)
		if catalog_icon:
			return catalog_icon

	var W := 28; var H := 14
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c: Color
	match wtype:
		"knife":
			c = Color(0.85, 0.85, 0.9)
			for x in range(3, 23): img.set_pixel(x, 6, c); img.set_pixel(x, 7, c)
			for x in range(22, 26): img.set_pixel(x, 7, c)
			for y in range(4, 10): img.set_pixel(2, y, c); img.set_pixel(3, y, c)
		"pistol":
			c = Color(0.55, 0.78, 1.0)
			for x in range(7, 19):
				for y in range(5, 9): img.set_pixel(x, y, c)
			for x in range(18, 26): img.set_pixel(x, 6, c); img.set_pixel(x, 7, c)
			for x in range(8, 12):
				for y in range(8, 13): img.set_pixel(x, y, c)
		"ar":
			c = Color(0.2, 0.88, 0.35)
			for x in range(2, 23):
				for y in range(6, 9): img.set_pixel(x, y, c)
			for x in range(2, 5):
				for y in range(5, 10): img.set_pixel(x, y, c)
			for x in range(22, 28): img.set_pixel(x, 7, c)
			for x in range(11, 17):
				for y in range(9, 14): img.set_pixel(x, y, c)
		"shotgun":
			c = Color(1.0, 0.6, 0.1)
			for x in range(2, 21):
				for y in range(5, 10): img.set_pixel(x, y, c)
			for y in range(4, 10): img.set_pixel(2, y, c); img.set_pixel(3, y, c)
			for x in range(20, 27):
				for y in range(5, 10): img.set_pixel(x, y, c)
			for x in range(20, 27): img.set_pixel(x, 7, Color(0, 0, 0, 0.6))
		"railgun":
			c = Color(0.85, 0.2, 1.0)
			for x in range(0, W): img.set_pixel(x, 7, c)
			for x in range(0, 6):
				for y in range(5, 10): img.set_pixel(x, y, c)
			for i in range(3):
				var cx = 9 + i * 7
				if cx + 1 < W:
					img.set_pixel(cx, 5, c); img.set_pixel(cx, 6, c)
					img.set_pixel(cx, 8, c); img.set_pixel(cx, 9, c)
					img.set_pixel(cx+1, 5, c); img.set_pixel(cx+1, 6, c)
					img.set_pixel(cx+1, 8, c); img.set_pixel(cx+1, 9, c)
		_:
			c = Color(0.45, 0.45, 0.45, 0.65)
			for i in range(3):
				var cx = 7 + i * 7
				img.set_pixel(cx, 6, c); img.set_pixel(cx+1, 6, c)
				img.set_pixel(cx, 7, c); img.set_pixel(cx+1, 7, c)
	return ImageTexture.create_from_image(img)

func _exit_tree():
	_restore_all_occluders()

func _handle_wall_transparency(delta: float):
	var camera = camera_pivot.get_node_or_null("Camera3D")
	if not camera:
		_restore_all_occluders()
		return

	var cam_pos = camera.global_position
	var space_state = get_world_3d().direct_space_state
	var active_meshes: Dictionary = {}
	for target_pos in _get_occluder_sample_points(camera):
		_trace_occluders(space_state, cam_pos, target_pos, active_meshes)

	_update_occluder_fades(active_meshes, delta)

func _get_occluder_sample_points(camera: Camera3D) -> Array:
	var right = camera.global_transform.basis.x
	right.y = 0.0
	if right.length_squared() < 0.001:
		right = Vector3.RIGHT
	right = right.normalized()

	var base = global_position
	return [
		base + Vector3(0.0, 1.45, 0.0),
		base + Vector3(0.0, 1.00, 0.0),
		base + Vector3(0.0, 0.95, 0.0) + right * 0.38,
		base + Vector3(0.0, 0.95, 0.0) - right * 0.38,
		base + Vector3(0.0, 0.45, 0.0),
	]

func _trace_occluders(space_state: PhysicsDirectSpaceState3D, ray_start: Vector3, target_pos: Vector3, active_meshes: Dictionary):
	var ray_delta = target_pos - ray_start
	if ray_delta.length_squared() < 0.001:
		return
	var dir = ray_delta.normalized()
	var ray_from = ray_start
	var exclude: Array = [self]
	for _i in range(OCCLUDER_MAX_RAY_HITS):
		var query = PhysicsRayQueryParameters3D.create(ray_from, target_pos)
		query.exclude = exclude
		query.collision_mask = 1
		var result = space_state.intersect_ray(query)
		if not result: break
		var collider = result.get("collider")
		for mesh in _get_occluder_meshes(collider):
			active_meshes[mesh] = true
		if collider is CollisionObject3D:
			exclude.append(collider)
		ray_from = result["position"] + dir * OCCLUDER_RAY_STEP
		if ray_from.distance_squared_to(target_pos) <= OCCLUDER_RAY_STEP * OCCLUDER_RAY_STEP:
			break

func _get_occluder_meshes(collider) -> Array:
	var meshes: Array = []
	if not collider is Node:
		return meshes
	var node: Node = collider
	var checks: Array = [node]
	var parent = node.get_parent()
	if parent:
		checks.append(parent)
	for check in checks:
		if check and check.is_in_group("occluder"):
			_append_mesh_instances(check, meshes)
	return meshes

func _append_mesh_instances(node: Node, out: Array):
	if node is MeshInstance3D and is_instance_valid(node):
		out.append(node)
	for child in node.get_children():
		_append_mesh_instances(child, out)

func _update_occluder_fades(active_meshes: Dictionary, delta: float):
	for mesh in active_meshes.keys():
		if not is_instance_valid(mesh):
			continue
		var state = _get_or_create_occluder_state(mesh)
		if state.is_empty():
			continue
		state["linger"] = OCCLUDER_FADE_LINGER
		_occluder_fade_states[mesh] = state

	var to_restore: Array = []
	for mesh in _occluder_fade_states.keys():
		if not is_instance_valid(mesh):
			to_restore.append(mesh)
			continue

		var state: Dictionary = _occluder_fade_states[mesh]
		var active = active_meshes.has(mesh)
		if not active:
			state["linger"] = maxf(0.0, float(state.get("linger", 0.0)) - delta)

		var original_alpha = float(state.get("original_alpha", 1.0))
		var target_alpha = OCCLUDER_FADE_ALPHA if active or float(state.get("linger", 0.0)) > 0.0 else original_alpha
		var current_alpha = float(state.get("alpha", original_alpha))
		var speed = OCCLUDER_FADE_IN_SPEED if target_alpha < current_alpha else OCCLUDER_FADE_OUT_SPEED
		var next_alpha = lerpf(current_alpha, target_alpha, minf(1.0, speed * delta))

		state["alpha"] = next_alpha
		_apply_occluder_fade_material(mesh, state, next_alpha)
		_occluder_fade_states[mesh] = state

		if not active and float(state.get("linger", 0.0)) <= 0.0 and absf(next_alpha - original_alpha) <= 0.02:
			to_restore.append(mesh)

	for mesh in to_restore:
		_restore_occluder(mesh)

func _get_or_create_occluder_state(mesh: MeshInstance3D) -> Dictionary:
	if _occluder_fade_states.has(mesh):
		return _occluder_fade_states[mesh]

	var original_override = mesh.get_surface_override_material(0)
	var source_mat: Material = original_override
	if not source_mat and mesh.mesh:
		source_mat = mesh.mesh.surface_get_material(0)

	var original_alpha = 1.0
	if source_mat is BaseMaterial3D:
		original_alpha = source_mat.albedo_color.a

	var fade_mat: Material = null
	if source_mat:
		fade_mat = source_mat.duplicate()
	if not fade_mat or not (fade_mat is BaseMaterial3D):
		var fallback = StandardMaterial3D.new()
		fallback.albedo_color = Color(0.42, 0.42, 0.42, original_alpha)
		fade_mat = fallback

	if fade_mat is BaseMaterial3D:
		fade_mat.resource_local_to_scene = true
		fade_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var c = fade_mat.albedo_color
		c.a = original_alpha
		fade_mat.albedo_color = c

	return {
		"had_override": original_override != null,
		"original_override": original_override,
		"original_alpha": original_alpha,
		"fade_mat": fade_mat,
		"alpha": original_alpha,
		"linger": 0.0,
	}

func _apply_occluder_fade_material(mesh: MeshInstance3D, state: Dictionary, alpha: float):
	var fade_mat = state.get("fade_mat")
	if not fade_mat:
		return
	if fade_mat is BaseMaterial3D:
		var c = fade_mat.albedo_color
		c.a = alpha
		fade_mat.albedo_color = c
	mesh.set_surface_override_material(0, fade_mat)

func _restore_occluder(mesh):
	if not _occluder_fade_states.has(mesh):
		return
	var state: Dictionary = _occluder_fade_states[mesh]
	_occluder_fade_states.erase(mesh)
	if not is_instance_valid(mesh):
		return
	if bool(state.get("had_override", false)):
		mesh.set_surface_override_material(0, state.get("original_override"))
	else:
		mesh.set_surface_override_material(0, null)

func _restore_all_occluders():
	var meshes = _occluder_fade_states.keys()
	for mesh in meshes:
		_restore_occluder(mesh)

func _update_zone_warning(delta: float):
	if not _zone_warning_style: return
	var main = get_tree().root.get_node_or_null("Main")
	if not main:
		_zone_warning_style.border_color.a = 0.0; return
	var self_2d = Vector2(global_position.x, global_position.z)
	if main.zone.is_outside(self_2d):
		_zone_warning_pulse += delta * 3.5
		_zone_warning_style.border_color.a = (sin(_zone_warning_pulse) * 0.5 + 0.5) * 0.58
	else:
		_zone_warning_pulse = 0.0
		_zone_warning_style.border_color.a = maxf(0.0, _zone_warning_style.border_color.a - delta * 5.0)

func _weapon_glyph(wtype: String) -> String:
	match wtype:
		"knife":   return "⚔"
		"pistol":  return "◉"
		"ar":      return "≡"
		"shotgun": return "⊛"
		"railgun": return "⚡"
	return "→"

func add_kill_feed_entry(killer_is_player: bool, player_assisted: bool, killer_name: String = "Bot", victim_name: String = "Bot", weapon_type: String = "", killer_streak: int = 0):
	if not kill_feed_container: return
	var glyph = _weapon_glyph(weapon_type)
	var label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	if killer_is_player:
		var streak_txt = ("  ×%d" % killer_streak) if killer_streak >= 2 else ""
		label.text = "★ YOU%s  %s  %s" % [streak_txt, glyph, victim_name]
		var fsize = clampi(22 + (killer_streak - 1) * 2, 22, 30)
		label.add_theme_font_size_override("font_size", fsize)
		var kill_color: Color
		if killer_streak >= 5:   kill_color = Color(1.0, 0.40, 0.0)
		elif killer_streak >= 3: kill_color = Color(1.0, 0.70, 0.0)
		else:                    kill_color = Color(1.0, 0.95, 0.2)
		label.add_theme_color_override("font_color", kill_color)
		label.add_theme_constant_override("outline_size", clampi(8 + killer_streak - 1, 8, 12))
	elif player_assisted:
		label.text = "◆ %s  %s  %s" % [killer_name, glyph, victim_name]
		label.add_theme_font_size_override("font_size", 17)
		label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.1))
		label.add_theme_constant_override("outline_size", 6)
	else:
		label.text = "%s  %s  %s" % [killer_name, glyph, victim_name]
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		label.add_theme_constant_override("outline_size", 4)
	kill_feed_container.add_child(label)
	kill_feed_entries.append({"label": label, "timer": 4.0 if (killer_is_player or player_assisted) else 2.5})
	if kill_feed_entries.size() > 6:
		kill_feed_entries[0]["label"].queue_free()
		kill_feed_entries.pop_front()

func show_pressure_flash(text: String, success: bool):
	if not _flash_label or not _flash_panel: return
	_flash_label.text = text
	_flash_label.modulate = Color(0.3, 1.0, 0.45) if success else Color(1.0, 0.32, 0.32)
	if _flash_tween: _flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash_panel, "modulate:a", 0.88, 0.12)
	_flash_tween.tween_interval(2.2)
	_flash_tween.tween_property(_flash_panel, "modulate:a", 0.0, 0.45)

func die(killer: Node3D = null):
	_drop_on_death()
	super.die(killer)

func _drop_on_death():
	for i in range(1, 5):
		var wdata = slots.weapon_slots[i]
		if wdata == null: continue
		var item = ItemData.new()
		item.type = ItemData.Type.WEAPON
		item.rarity = ItemData.Rarity.COMMON
		item.item_name = _drop_weapon_name(wdata.weapon_type)
		item.color = _drop_weapon_color(wdata.weapon_type)
		var wstats = wdata.duplicate() as StatsData
		wstats.current_ammo = wstats.max_ammo / 3
		item.weapon_stats = wstats
		var wp = PICKUP_SCN.instantiate()
		get_tree().root.add_child(wp)
		wp.global_position = global_position + Vector3(randf_range(-0.8, 0.8), 0.3, randf_range(-0.8, 0.8))
		wp.init(item)
		var total_ammo = slots.slot_ammo[i] + slots.slot_reserve[i]
		if total_ammo > 0:
			var ammo_item = ItemData.new()
			ammo_item.type = ItemData.Type.AMMO
			ammo_item.rarity = ItemData.Rarity.COMMON
			ammo_item.item_name = _drop_weapon_name(wdata.weapon_type) + " Ammo"
			ammo_item.ammo_weapon_type = wdata.weapon_type
			ammo_item.amount = total_ammo
			ammo_item.color = _drop_weapon_color(wdata.weapon_type)
			var ap = PICKUP_SCN.instantiate()
			get_tree().root.add_child(ap)
			ap.global_position = global_position + Vector3(randf_range(-0.8, 0.8), 0.3, randf_range(-0.8, 0.8))
			ap.init(ammo_item)
	if stats.heal_items > 0:
		var heal_item = ItemData.new()
		heal_item.type = ItemData.Type.HEAL
		heal_item.rarity = ItemData.Rarity.COMMON
		heal_item.item_name = "Health Potion"
		heal_item.amount = stats.heal_items
		heal_item.color = Color(0.2, 1.0, 0.4)
		var hp = PICKUP_SCN.instantiate()
		get_tree().root.add_child(hp)
		hp.global_position = global_position + Vector3(0, 0.3, 0)
		hp.init(heal_item)
	if stats.advanced_heals > 0:
		var adv_item = ItemData.new()
		adv_item.type = ItemData.Type.HEAL
		adv_item.rarity = ItemData.Rarity.RARE
		adv_item.item_name = "MedKit"
		adv_item.amount = stats.advanced_heals
		adv_item.color = Color(1.0, 0.88, 0.1)
		var ap2 = PICKUP_SCN.instantiate()
		get_tree().root.add_child(ap2)
		ap2.global_position = global_position + Vector3(0, 0.3, 0.5)
		ap2.init(adv_item)

func _drop_weapon_name(wtype: String) -> String:
	match wtype:
		"pistol":  return "Pistol"
		"ar":      return "Assault Rifle"
		"shotgun": return "Shotgun"
		"railgun": return "Railgun"
	return wtype.capitalize()

func _drop_weapon_color(wtype: String) -> Color:
	match wtype:
		"pistol":  return Color(0.55, 0.78, 1.0)
		"ar":      return Color(0.2, 0.88, 0.35)
		"shotgun": return Color(1.0, 0.6, 0.1)
		"railgun": return Color(0.85, 0.2, 1.0)
	return Color.WHITE

func shoot_pellet(_idx: int):
	reveal()
	var wdata = slots.weapon_slots[slots.active_slot]
	if not wdata: return
	var spread = 2.0 * _artifact_mods.get("spread_mult", 1.0)
	var pellet_target = Vector3(randf_range(-spread, spread), randf_range(-0.5, 0.5), -wdata.attack_range)
	_internal_shoot(pellet_target)

func _shoot_with_slot(slot: int):
	var wdata = slots.weapon_slots[slot]
	if not wdata or slots.slot_ammo[slot] <= 0: return
	slots.consume_ammo()
	_sync_stats_ammo()
	reveal()
	var shot_vec = Vector3(0, 0, -wdata.attack_range)
	if _artifact_mods.get("spread_all_shots", false):
		# Red Trigger: extreme spray for non-shotgun (shotgun handled via shoot_pellet)
		var s = 4.0 if _artifact_mods.get("red_trigger", false) else _artifact_mods.get("spread_mult", 1.0)
		shot_vec.x = randf_range(-s, s)
		shot_vec.y = randf_range(-s * 0.25, s * 0.25)
	elif wdata.weapon_type == "ar" or wdata.weapon_type == "pistol":
		var is_ar = wdata.weapon_type == "ar"
		_shot_heat = minf(HEAT_MAX, _shot_heat + (HEAT_PER_SHOT_AR if is_ar else HEAT_PER_SHOT_PISTOL))
		var base = BASE_SPREAD_AR if is_ar else BASE_SPREAD_PISTOL
		var heat_spread = base + _shot_heat * (3.5 if is_ar else 2.3)
		shot_vec.x = randf_range(-heat_spread, heat_spread)
		shot_vec.y = randf_range(-heat_spread * 0.15, heat_spread * 0.15)
	_internal_shoot(shot_vec)
	fire_cooldown = wdata.fire_rate
	_play_weapon_shot_sfx(wdata.weapon_type)
	_refresh_slot_hud()
	_notify_mission_tracker_fire(wdata.weapon_type)

func _internal_shoot(target_vec: Vector3):
	var flash = MUZZLE_FLASH_SCN.instantiate()
	add_child(flash); flash.position = Vector3(0, 0.5, -0.5)
	var wdata = slots.weapon_slots[slots.active_slot] if slots.active_slot >= 1 else null
	var is_shotgun = wdata and wdata.weapon_type == "shotgun"
	var recoil_dir = global_transform.basis.z
	velocity += recoil_dir * (6.0 if is_shotgun else 2.0)
	camera_shake_amount = 0.3 if is_shotgun else 0.1
	ray_cast.target_position = target_vec
	ray_cast.force_raycast_update()
	var impact_pos = global_position + (global_transform.basis * target_vec)
	if ray_cast.is_colliding():
		var target = ray_cast.get_collider()
		impact_pos = ray_cast.get_collision_point()
		var impact = IMPACT_EFFECT_SCN.instantiate()
		get_tree().root.add_child(impact)
		impact.global_position = impact_pos
		if target.has_method("take_damage"):
			var wtype = wdata.weapon_type if wdata else stats.weapon_type
			var dmg: float
			if _artifact_mods.get("red_trigger", false):
				dmg = (wdata.attack_damage if wdata else stats.attack_damage) * (1.2 if wtype == "shotgun" else 0.5)
			else:
				dmg = (wdata.attack_damage if wdata else stats.attack_damage) * _artifact_mods.get("damage_mult", 1.0)
			target.take_damage(dmg, "gun", wtype, self)
			if Sfx: Sfx.play("hit", impact_pos)
		else: if Sfx: Sfx.play("impact_wall", impact_pos)
	var trail = BULLET_TRAIL_SCN.instantiate()
	get_tree().root.add_child(trail); trail.init(global_position + Vector3(0, 0.5, 0), impact_pos)

func shoot():
	# Legacy path kept for compatibility (bot AI calls Entity.shoot via super chain)
	if stats.current_ammo <= 0: return
	stats.current_ammo -= 1
	reveal()
	_internal_shoot(Vector3(0, 0, -stats.attack_range))
	fire_cooldown = stats.fire_rate
	_play_weapon_shot_sfx(stats.weapon_type)

func _play_weapon_shot_sfx(weapon_type: String) -> void:
	if not Sfx:
		return
	if Sfx.has_method("play_weapon_shot"):
		Sfx.play_weapon_shot(weapon_type)
	else:
		Sfx.play("shoot")

func _current_surface_id() -> String:
	if is_in_bush:
		return "grass"
	var main = get_tree().root.get_node_or_null("Main")
	if main and main.map_spec:
		var p2 = Vector2(global_position.x, global_position.z)
		for obstacle in main.map_spec.obstacles:
			var type_str = String(obstacle.get("type", ""))
			var op = obstacle.get("pos", [0.0, 0.0])
			var sc = obstacle.get("scale", [1.0, 1.0, 1.0])
			var half_x = float(sc[0]) + 1.5
			var half_z = float(sc[2]) + 1.5
			if abs(p2.x - float(op[0])) <= half_x and abs(p2.y - float(op[1])) <= half_z:
				match type_str:
					"rock_cluster", "canyon_wall":
						return "stone"
					"tree_cluster", "log_pile":
						return "dirt"
	return "dirt"

func apply_artifact(artifact: Dictionary):
	active_artifact = artifact
	_artifact_mods = {
		"damage_mult": 1.0, "spread_mult": 1.0, "spread_all_shots": false, "red_trigger": false,
		"move_speed_mult": 1.0,
		"heal_mult": 1.0, "heal_to_shield": false,
		"shield_recv_mult": 1.0, "zone_dmg_mult": 1.0,
		"footstep_radius_mult": 1.0,
		"zone_battery": false, "zone_battery_regen": 0.0, "zone_battery_range": 0.0,
	}
	for key in artifact.get("mods", {}):
		_artifact_mods[key] = artifact["mods"][key]
	# One-time stat multipliers (applied to already-duplicated stats resource)
	var mods = artifact.get("mods", {})
	if mods.has("max_health_mult"):
		stats.max_health = int(stats.max_health * mods["max_health_mult"])
		current_health = min(current_health, stats.max_health)
		health_changed.emit(current_health, stats.max_health)
	if mods.has("max_shield_mult"):
		stats.max_shield = int(stats.max_shield * mods["max_shield_mult"])
		current_shield = min(current_shield, stats.max_shield)
		shield_changed.emit(current_shield, stats.max_shield)
	if _artifact_label:
		if artifact.is_empty():
			_artifact_label.visible = false
		else:
			_artifact_label.text = "[%s]" % artifact.get("label", "")
			_artifact_label.modulate = artifact.get("color", Color.WHITE)
			_artifact_label.visible = true

func receive_shield(amount: float):
	var mult = _artifact_mods.get("shield_recv_mult", 1.0)
	current_shield = min(stats.max_shield, current_shield + amount * mult)
	shield_changed.emit(current_shield, stats.max_shield)

func get_footstep_radius_mult() -> float:
	return _artifact_mods.get("footstep_radius_mult", 1.0)
