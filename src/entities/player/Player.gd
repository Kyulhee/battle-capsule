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
var kill_feed_container: VBoxContainer = null
var kill_feed_entries: Array = []

var camera_shake_amount: float = 0.0
var camera_shake_decay: float = 5.0

const MUZZLE_FLASH_SCN = preload("res://src/fx/MuzzleFlash.tscn")
const IMPACT_EFFECT_SCN = preload("res://src/fx/ImpactEffect.tscn")
const BULLET_TRAIL_SCN = preload("res://src/fx/BulletTrail.tscn")
const SHOT_PING_SCN = preload("res://src/fx/ShotPing.tscn")
const PISTOL_STATS = preload("res://src/core/pistol_stats.tres")

# ── Weapon Slot Inventory ────────────────────────────────────────────────
# slot 0 = knife (melee, always available), slots 1-4 = ranged weapons
const MELEE_RANGE: float = 1.8
const MELEE_DAMAGE: float = 20.0
const MELEE_RATE: float = 0.55

var weapon_slots: Array = [null, null, null, null, null]  # [0]=knife placeholder, [1-4]=StatsData
var slot_ammo: Array = [0, 0, 0, 0, 0]     # loaded magazine
var slot_reserve: Array = [0, 0, 0, 0, 0]  # reserve / backpack ammo
var active_slot: int = 0
var reload_timer: float = 0.0
var reload_total_time: float = 0.0
var reload_ammo_start: int = 0
var reload_ammo_target: int = 0

var slot_panels: Array = []
var slot_icon_rects: Array = []
var slot_ammo_labels: Array = []

func _ready():
	if stats:
		stats = stats.duplicate()
	super._ready()

	# Zone timer (top-center)
	zone_timer_label = Label.new()
	$CanvasLayer/Control.add_child(zone_timer_label)
	zone_timer_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	zone_timer_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	zone_timer_label.add_theme_font_size_override("font_size", 26)
	zone_timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
	zone_timer_label.add_theme_constant_override("outline_size", 8)
	zone_timer_label.position.y += 8

	# Kill feed (top-right)
	kill_feed_container = VBoxContainer.new()
	$CanvasLayer/Control.add_child(kill_feed_container)
	kill_feed_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	kill_feed_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	kill_feed_container.position.x -= 220
	kill_feed_container.position.y += 60
	kill_feed_container.custom_minimum_size = Vector2(200, 0)

	# Slot bar (bottom-center): 5 boxes — 0=knife, 1-4=weapons
	var slot_bar = HBoxContainer.new()
	$CanvasLayer/Control.add_child(slot_bar)
	slot_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	slot_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	slot_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	slot_bar.position.y -= 8
	slot_bar.position.x -= 165
	slot_bar.add_theme_constant_override("separation", 6)

	var slot_labels = ["K", "1", "2", "3", "4"]
	for i in range(5):
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(60, 68)
		slot_bar.add_child(panel)
		slot_panels.append(panel)

		var vbox = VBoxContainer.new()
		panel.add_child(vbox)
		vbox.add_theme_constant_override("separation", 2)

		var key_lbl = Label.new()
		key_lbl.text = slot_labels[i]
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_lbl.add_theme_font_size_override("font_size", 11)
		key_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		vbox.add_child(key_lbl)

		var icon_rect = TextureRect.new()
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(0, 20)
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	switch_to_slot(0)
	receive_weapon(PISTOL_STATS.duplicate())

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_C: is_crouching = not is_crouching
			KEY_0: switch_to_slot(0)
			KEY_1: switch_to_slot(1)
			KEY_2: switch_to_slot(2)
			KEY_3: switch_to_slot(3)
			KEY_4: switch_to_slot(4)
			KEY_R: _start_reload()

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
	super.take_damage(amount, source, weapon_type, source_node)
	if Sfx: Sfx.play("hurt")
	var overlay = $CanvasLayer/Control/DamageOverlay
	if overlay:
		var tween = create_tween()
		tween.tween_property(overlay, "modulate:a", 0.3, 0.05)
		tween.tween_property(overlay, "modulate:a", 0.0, 0.2)

func _physics_process(delta):
	if is_dead: return
	if fire_cooldown > 0: fire_cooldown -= delta
	if reload_timer > 0:
		reload_timer -= delta
		if reload_timer <= 0:
			_finish_reload()
	handle_aiming(delta)
	var effective_speed = stats.move_speed * (0.45 if is_crouching else 1.0)

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
			if Sfx: Sfx.play("footstep", global_position)
	else:
		footstep_timer = 0.0

	# Fire / melee
	if Input.is_action_pressed("click") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if fire_cooldown <= 0 and reload_timer <= 0:
			if active_slot == 0:
				_melee_attack()
			else:
				var wdata = weapon_slots[active_slot]
				if wdata and slot_ammo[active_slot] > 0:
					if wdata.weapon_type == "shotgun":
						slot_ammo[active_slot] -= 1
						_sync_slot_ammo()
						for i in range(wdata.pellet_count): shoot_pellet(i)
						fire_cooldown = wdata.fire_rate
						if Sfx: Sfx.play("shoot")
						_refresh_slot_hud()
					else:
						_shoot_with_slot(active_slot)
				else:
					if Sfx: Sfx.play("dry_fire")
					fire_cooldown = 0.5
					_try_auto_switch()

	if Input.is_key_pressed(KEY_SPACE) and is_on_floor() and not is_crouching:
		velocity.y = 7.0
		footstep_timer = 0.0
	if Input.is_key_pressed(KEY_E): handle_interaction()
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

func _process(delta):
	if camera_shake_amount > 0:
		var camera = camera_pivot.get_node("Camera3D")
		if camera:
			camera.h_offset = randf_range(-camera_shake_amount, camera_shake_amount)
			camera.v_offset = randf_range(-camera_shake_amount, camera_shake_amount)
			camera_shake_amount = lerp(camera_shake_amount, 0.0, camera_shake_decay * delta)
	var actors = get_tree().get_nodes_in_group("actors")
	for a in actors:
		if not a is Entity or a == self: continue
		if a.has_node("MeshInstance3D"):
			a.get_node("MeshInstance3D").visible = a.is_revealed_to(self)

	# Zone timer label
	var main = get_tree().root.get_node_or_null("Main")
	if main and zone_timer_label:
		if main.is_shrinking:
			zone_timer_label.text = "ZONE CLOSING"
			zone_timer_label.modulate = Color(1.0, 0.3, 0.3)
		else:
			var t = main.zone_timer
			zone_timer_label.text = "ZONE  %ds" % int(max(0, t))
			zone_timer_label.modulate = Color.CYAN if t > 10.0 else Color.YELLOW

	# Reload HUD progress (per-frame count-up animation)
	if reload_timer > 0 and not slot_ammo_labels.is_empty() and active_slot > 0 and reload_total_time > 0:
		var progress = 1.0 - reload_timer / reload_total_time
		var disp_ammo = int(lerp(float(reload_ammo_start), float(reload_ammo_target), progress))
		var wdata_r = weapon_slots[active_slot]
		var max_a_r = wdata_r.max_ammo if wdata_r else 0
		var transferred = disp_ammo - reload_ammo_start
		var disp_res = max(0, slot_reserve[active_slot] - transferred)
		slot_ammo_labels[active_slot].text = "%d/%d+%d" % [disp_ammo, max_a_r, disp_res]
		slot_ammo_labels[active_slot].modulate = Color.YELLOW

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
			var d = global_position.distance_to(area.global_position)
			if d < min_dist: min_dist = d; closest = area
	if closest: closest.collect(self)

func handle_healing():
	if stats.heal_items > 0 and current_health < stats.max_health:
		stats.heal_items -= 1
		current_health = min(stats.max_health, current_health + 50.0)
		if Sfx: Sfx.play("heal", global_position)
		_on_health_changed(current_health, stats.max_health)
		if has_node("/root/Telemetry"): get_node("/root/Telemetry").log_economy("heals_used")

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
	if hud_label:
		hud_label.text = "HP: %d/%d | SHIELD: %d/%d | Heals: %d | Alive: %d" % [
			current_health, stats.max_health,
			current_shield, stats.max_shield,
			stats.heal_items,
			get_tree().get_nodes_in_group("actors").filter(func(a): return a is Entity and not a.is_dead).size()
		]
	_refresh_slot_hud()

# ── Slot system ──────────────────────────────────────────────────────────

func switch_to_slot(slot: int):
	if slot < 0 or slot > 4: return
	reload_timer = 0.0
	active_slot = slot
	if slot >= 1:
		var wdata = weapon_slots[slot]
		if wdata:
			stats.weapon_type   = wdata.weapon_type
			stats.pellet_count  = wdata.pellet_count
			stats.attack_damage = wdata.attack_damage
			stats.fire_rate     = wdata.fire_rate
			stats.attack_range  = wdata.attack_range
			stats.current_ammo  = slot_ammo[slot]
	_refresh_slot_hud()

func receive_weapon(wstats: StatsData) -> bool:
	# Reject duplicate weapon type
	for i in range(1, 5):
		if weapon_slots[i] != null and weapon_slots[i].weapon_type == wstats.weapon_type:
			return false
	# Fill first empty slot 1-4
	for i in range(1, 5):
		if weapon_slots[i] == null:
			weapon_slots[i] = wstats
			slot_ammo[i] = wstats.current_ammo  # starts at 1/3 magazine (set in .tres)
			slot_reserve[i] = 0
			switch_to_slot(i)
			return true
	# All slots full — replace active weapon slot
	if active_slot >= 1:
		weapon_slots[active_slot] = wstats
		slot_ammo[active_slot] = wstats.current_ammo
		slot_reserve[active_slot] = 0
		switch_to_slot(active_slot)
		return true
	return false

func receive_ammo(weapon_type: String, amount: int):
	for i in range(1, 5):
		var wdata = weapon_slots[i]
		if wdata and wdata.weapon_type == weapon_type:
			var res_max = _get_reserve_max(weapon_type)
			slot_reserve[i] = min(res_max, slot_reserve[i] + amount)
			_refresh_slot_hud()
			return

func _try_auto_switch():
	# Prefer slots with ammo already loaded
	for i in range(1, 5):
		if weapon_slots[i] != null and slot_ammo[i] > 0:
			switch_to_slot(i)
			return
	# Then slots with reserve (auto-reload)
	for i in range(1, 5):
		if weapon_slots[i] != null and slot_reserve[i] > 0:
			switch_to_slot(i)
			_start_reload()
			return
	switch_to_slot(0)

func _sync_slot_ammo():
	if active_slot >= 1:
		stats.current_ammo = slot_ammo[active_slot]

func _start_reload():
	if active_slot == 0: return
	var wdata = weapon_slots[active_slot]
	if not wdata: return
	if slot_reserve[active_slot] <= 0: return  # no reserve
	if slot_ammo[active_slot] >= wdata.max_ammo: return  # magazine full
	if reload_timer > 0: return
	var transfer = min(slot_reserve[active_slot], wdata.max_ammo - slot_ammo[active_slot])
	reload_ammo_start  = slot_ammo[active_slot]
	reload_ammo_target = slot_ammo[active_slot] + transfer
	reload_total_time  = _get_reload_time()
	reload_timer       = reload_total_time
	if Sfx: Sfx.play("reload")

func _finish_reload():
	var wdata = weapon_slots[active_slot]
	if wdata:
		var transferred = reload_ammo_target - reload_ammo_start
		slot_ammo[active_slot]    = reload_ammo_target
		slot_reserve[active_slot] = max(0, slot_reserve[active_slot] - transferred)
		_sync_slot_ammo()
	_refresh_slot_hud()

func _get_reload_time() -> float:
	var wdata = weapon_slots[active_slot]
	if not wdata: return 1.5
	match wdata.weapon_type:
		"shotgun": return 2.8
		"railgun": return 4.5
		"ar":      return 2.0
		_:         return 1.3  # pistol

func _get_reserve_max(wtype: String) -> int:
	match wtype:
		"pistol":  return 30
		"ar":      return 60
		"shotgun": return 12
		"railgun": return 6
		_:         return 30

func _melee_attack():
	reveal()
	fire_cooldown = MELEE_RATE
	if Sfx: Sfx.play("melee")
	ray_cast.target_position = Vector3(0, 0, -MELEE_RANGE)
	ray_cast.force_raycast_update()
	if ray_cast.is_colliding():
		var target = ray_cast.get_collider()
		if target.has_method("take_damage"):
			target.take_damage(MELEE_DAMAGE, "melee", "knife", self)
			if Sfx: Sfx.play("hit", ray_cast.get_collision_point())

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
		var out_of_ammo = (i >= 1) and weapon_slots[i] != null and slot_ammo[i] <= 0 and slot_reserve[i] <= 0

		if i == active_slot:
			panel.add_theme_stylebox_override("panel", active_style)
		elif out_of_ammo:
			panel.add_theme_stylebox_override("panel", empty_style)
		else:
			panel.add_theme_stylebox_override("panel", normal_style)

		if not slot_icon_rects.is_empty():
			if i == 0:
				slot_icon_rects[i].texture = _make_weapon_icon("knife")
			elif weapon_slots[i] == null:
				slot_icon_rects[i].texture = _make_weapon_icon("")
			else:
				slot_icon_rects[i].texture = _make_weapon_icon(weapon_slots[i].weapon_type)
		if i == 0:
			slot_ammo_labels[i].text = ""
			slot_ammo_labels[i].modulate = Color.WHITE
		elif weapon_slots[i] == null:
			slot_ammo_labels[i].text = ""
		else:
			var ammo = slot_ammo[i]
			var max_a = weapon_slots[i].max_ammo
			var res   = slot_reserve[i]
			slot_ammo_labels[i].text = "%d/%d+%d" % [ammo, max_a, res]
			if ammo <= 0 and res <= 0:
				slot_ammo_labels[i].modulate = Color.RED
			elif ammo <= max_a / 4:
				slot_ammo_labels[i].modulate = Color.YELLOW
			else:
				slot_ammo_labels[i].modulate = Color.WHITE

func _make_weapon_icon(wtype: String) -> ImageTexture:
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

func show_kill_notification():
	if not kill_feed_container: return
	var label = Label.new()
	label.text = "ELIMINATED"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	kill_feed_container.add_child(label)
	kill_feed_entries.append({"label": label, "timer": 3.0})
	if kill_feed_entries.size() > 5:
		kill_feed_entries[0]["label"].queue_free()
		kill_feed_entries.pop_front()

func shoot_pellet(_idx: int):
	reveal()
	var wdata = weapon_slots[active_slot]
	if not wdata: return
	var pellet_target = Vector3(randf_range(-2, 2), randf_range(-0.5, 0.5), -wdata.attack_range)
	_internal_shoot(pellet_target)

func _shoot_with_slot(slot: int):
	var wdata = weapon_slots[slot]
	if not wdata or slot_ammo[slot] <= 0: return
	slot_ammo[slot] -= 1
	_sync_slot_ammo()
	reveal()
	_internal_shoot(Vector3(0, 0, -wdata.attack_range))
	fire_cooldown = wdata.fire_rate
	if Sfx: Sfx.play("shoot")
	_refresh_slot_hud()

func _internal_shoot(target_vec: Vector3):
	var flash = MUZZLE_FLASH_SCN.instantiate()
	add_child(flash); flash.position = Vector3(0, 0.5, -0.5)
	var wdata = weapon_slots[active_slot] if active_slot >= 1 else null
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
			var dmg = wdata.attack_damage if wdata else stats.attack_damage
			var wtype = wdata.weapon_type if wdata else stats.weapon_type
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
	if Sfx: Sfx.play("shoot")
