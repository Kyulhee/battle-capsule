extends Entity

@onready var camera_pivot = $CameraPivot
@onready var ray_cast = $RayCast3D
@onready var hud_label = $CanvasLayer/Control/HPLabel

var fire_cooldown: float = 0.0

@onready var interaction_area = $InteractionArea
var weapon_label: Label = null

var camera_shake_amount: float = 0.0
var camera_shake_decay: float = 5.0

const MUZZLE_FLASH_SCN = preload("res://src/fx/MuzzleFlash.tscn")
const IMPACT_EFFECT_SCN = preload("res://src/fx/ImpactEffect.tscn")
const BULLET_TRAIL_SCN = preload("res://src/fx/BulletTrail.tscn")
const SHOT_PING_SCN = preload("res://src/fx/ShotPing.tscn")

func _ready():
	if stats:
		stats = stats.duplicate()
	super._ready()
	
	# Create Weapon Label at the bottom
	weapon_label = Label.new()
	$CanvasLayer/Control.add_child(weapon_label)
	weapon_label.set_anchors_and_offsets_preset(12, 0, 40) # 12 = PRESET_BOTTOM_CENTER
	weapon_label.grow_horizontal = 2 # GROW_DIRECTION_BOTH
	weapon_label.position.y -= 80 # Adjust up from bottom
	weapon_label.add_theme_font_size_override("font_size", 36)
	weapon_label.add_theme_color_override("font_outline_color", Color.BLACK)
	weapon_label.add_theme_constant_override("outline_size", 12)
	
	health_changed.connect(_on_health_changed)
	shield_changed.connect(_on_shield_changed)
	if ray_cast:
		ray_cast.enabled = true
		ray_cast.add_exception(self)
		# Hit Layer 2 (Actors) and Layer 4 (High Obstacles)
		ray_cast.collision_mask = 2 | 8
	_on_health_changed(current_health, stats.max_health)

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
	handle_aiming(delta)
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
		velocity.x = lerp(velocity.x, direction.x * stats.move_speed, stats.acceleration * delta)
		velocity.z = lerp(velocity.z, direction.z * stats.move_speed, stats.acceleration * delta)
	else:
		velocity.x = lerp(velocity.x, 0.0, stats.friction * delta)
		velocity.z = lerp(velocity.z, 0.0, stats.friction * delta)
	if Input.is_action_pressed("click") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if fire_cooldown <= 0:
			if stats.current_ammo > 0:
				if stats.weapon_type == "shotgun":
					stats.current_ammo -= 1
					for i in range(stats.pellet_count): shoot_pellet(i)
					fire_cooldown = stats.fire_rate
					if Sfx: Sfx.play("shoot")
				else: shoot()
			else:
				if Sfx: Sfx.play("dry_fire")
				fire_cooldown = 0.5
	if Input.is_key_pressed(KEY_E): handle_interaction()
	if Input.is_key_pressed(KEY_Q): handle_healing()
	super._physics_process(delta)
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
		hud_label.text = "HP: %d/%d | SHIELD: %d/%d | Ammo: %d | Heals: %d | Alive: %d" % [
			current_health, stats.max_health,
			current_shield, stats.max_shield,
			stats.current_ammo, stats.heal_items,
			get_tree().get_nodes_in_group("actors").filter(func(a): return a is Entity and not a.is_dead).size()
		]
	if weapon_label:
		weapon_label.text = stats.weapon_type.to_upper().replace("_", " ")

func shoot_pellet(_idx: int):
	reveal()
	var spread = 0.15
	var pellet_target = Vector3(randf_range(-2, 2), randf_range(-0.5, 0.5), -stats.attack_range)
	_internal_shoot(pellet_target)

func _internal_shoot(target_vec: Vector3):
	var flash = MUZZLE_FLASH_SCN.instantiate()
	add_child(flash); flash.position = Vector3(0, 0.5, -0.5)
	var recoil_dir = global_transform.basis.z
	var recoil_strength = 6.0 if stats.weapon_type == "shotgun" else 2.0
	camera_shake_amount = 0.3 if stats.weapon_type == "shotgun" else 0.1
	velocity += recoil_dir * recoil_strength
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
			var dist = global_position.distance_to(target.global_position)
			target.take_damage(stats.attack_damage, "gun", stats.weapon_type, self)
			if Sfx: Sfx.play("hit", impact_pos)
		else: if Sfx: Sfx.play("impact_wall", impact_pos)
	var trail = BULLET_TRAIL_SCN.instantiate()
	get_tree().root.add_child(trail); trail.init(global_position + Vector3(0, 0.5, 0), impact_pos)

func shoot():
	if stats.current_ammo <= 0: return
	stats.current_ammo -= 1
	reveal()
	_internal_shoot(Vector3(0, 0, -stats.attack_range))
	fire_cooldown = stats.fire_rate
	if Sfx: Sfx.play("shoot")


