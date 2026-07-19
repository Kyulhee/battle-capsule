extends Entity

const PLAYER_MOVEMENT_AUDIO_POLICY = preload(
	"res://src/entities/player/PlayerMovementAudioPolicy.gd"
)

@onready var camera_pivot = $CameraPivot
@onready var ray_cast = $RayCast3D
@onready var hud_label = $CanvasLayer/Control/HPLabel

var fire_cooldown: float = 0.0
var is_crouching: bool = false
var footstep_timer: float = 0.0
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

var _heal_regen: float = 0.0

# ── Artifact System ──────────────────────────────────────────────────────────
var active_artifact: Dictionary = {}
var _artifact_mods: Dictionary = {
	"damage_mult": 1.0, "spread_mult": 1.0, "spread_all_shots": false, "red_trigger": false,
	"shotgun_damage_mult": 1.0, "non_shotgun_damage_mult": 1.0,
	"non_shotgun_spread": 1.0, "red_trigger_reveal_duration": 2.0,
	"move_speed_mult": 1.0,
	"heal_mult": 1.0, "heal_to_shield": false,
	"heal_to_shield_ratio": 1.0, "heal_to_shield_cap": 0.0,
	"armor_sponge_move_speed_min": 1.0,
	"shield_recv_mult": 1.0, "zone_dmg_mult": 1.0,
	"footstep_radius_mult": 1.0, "silent_core_first_shot_miss": false,
	"zone_battery": false, "zone_battery_regen": 0.0, "zone_battery_range": 0.0,
}
var _artifact_label: Label = null
var _artifact_icon: TextureRect = null

# ── Shot Heat (AR / Pistol spread heat-up) ──────────────────────────────────
var _shot_heat: float = 0.0

const MUZZLE_FLASH_SCN = preload("res://src/fx/MuzzleFlash.tscn")
const IMPACT_EFFECT_SCN = preload("res://src/fx/ImpactEffect.tscn")
const BULLET_TRAIL_SCN = preload("res://src/fx/BulletTrail.tscn")
const SHOT_PING_SCN = preload("res://src/fx/ShotPing.tscn")
const PISTOL_STATS = preload("res://src/core/pistol_stats.tres")
const PICKUP_SCN = preload("res://src/entities/pickup/Pickup.tscn")
const DropDisplayCatalogScript = preload("res://src/core/DropDisplayCatalog.gd")
const ItemDisplayFormatterScript = preload("res://src/core/ItemDisplayFormatter.gd")
const PlayerHudBuilderScript = preload("res://src/ui/player/PlayerHudBuilder.gd")
const PlayerSlotHudRendererScript = preload("res://src/ui/player/PlayerSlotHudRenderer.gd")
const ArtifactIconResolverScript = preload("res://src/ui/ArtifactIconResolver.gd")
const PlayerWeaponIconResolverScript = preload("res://src/ui/player/PlayerWeaponIconResolver.gd")
const PlayerTuningScript = preload("res://src/entities/player/PlayerTuning.gd")
const PlayerOccluderFaderScript = preload("res://src/entities/player/PlayerOccluderFader.gd")
const PlayerArtifactRuntimeScript = preload("res://src/entities/player/PlayerArtifactRuntime.gd")
const PlayerArtifactVisualsScript = preload("res://src/entities/player/PlayerArtifactVisuals.gd")
const PlayerNightReadabilityScript = preload("res://src/entities/player/PlayerNightReadability.gd")
const WeaponSlotManagerScript = preload("res://src/core/WeaponSlotManager.gd")

# ── Weapon Slot Inventory ────────────────────────────────────────────────
# slot 0 = knife (melee, always available), slots 1-4 = ranged weapons

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
var _artifact_icon_resolver = ArtifactIconResolverScript.new()
var _weapon_icon_resolver = PlayerWeaponIconResolverScript.new()
var _occluder_fader = PlayerOccluderFaderScript.new()
var _artifact_runtime = PlayerArtifactRuntimeScript.new()
var _artifact_visuals = PlayerArtifactVisualsScript.new()
var _night_readability = PlayerNightReadabilityScript.new()
var _focused_pickup: Pickup = null

func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if stats:
		stats = stats.duplicate()
	super._ready()
	_apply_cosmetic_tint()

	var top_hud = PlayerHudBuilderScript.build_top_hud($CanvasLayer/Control)
	zone_timer_label = top_hud["zone_timer_label"] as Label
	mission_hud_label = top_hud["mission_hud_label"] as Label
	pressure_hud_label = top_hud["pressure_hud_label"] as Label
	_flash_panel = top_hud["flash_panel"] as PanelContainer
	_flash_label = top_hud["flash_label"] as Label
	kill_feed_container = top_hud["kill_feed_container"] as VBoxContainer

	if hud_label: hud_label.visible = false
	var status_hud = PlayerHudBuilderScript.build_status_hud($CanvasLayer/Control)
	_hp_bar = status_hud["hp_bar"] as ProgressBar
	_hp_fill = status_hud["hp_fill"] as StyleBoxFlat
	_hp_val = status_hud["hp_val"] as Label
	_sh_bar = status_hud["sh_bar"] as ProgressBar
	_sh_val = status_hud["sh_val"] as Label
	_artifact_icon = status_hud["artifact_icon"] as TextureRect
	_artifact_label = status_hud["artifact_label"] as Label
	_stat_heal_val = status_hud["stat_heal_val"] as Label
	_stat_mk_val = status_hud["stat_mk_val"] as Label
	_stat_kill_val = status_hud["stat_kill_val"] as Label
	_stat_asst_val = status_hud["stat_asst_val"] as Label
	_stat_alive_val = status_hud["stat_alive_val"] as Label

	var slot_hud = PlayerHudBuilderScript.build_slot_hud($CanvasLayer/Control)
	slot_panels = slot_hud["slot_panels"] as Array
	slot_icon_rects = slot_hud["slot_icon_rects"] as Array
	slot_ammo_labels = slot_hud["slot_ammo_labels"] as Array

	if has_node("MeshInstance3D"):
		_mesh_origin_y = $MeshInstance3D.position.y
	_artifact_visuals.attach(self)
	_night_readability.attach(
		self,
		get_node_or_null("VisionSpot") as SpotLight3D,
		get_node_or_null("ProximityLight") as OmniLight3D
	)
	_configure_night_readability()

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

	_zone_warning_style = PlayerHudBuilderScript.build_zone_warning_overlay($CanvasLayer/Control)

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
	var was_in_bush := is_in_bush
	if value and not is_in_bush:
		if has_node("/root/Telemetry"):
			get_node("/root/Telemetry").log_stealth("bush_entries")
	super.set_in_bush(value)
	var result = _artifact_runtime.on_bush_changed(was_in_bush, is_in_bush)
	if not result.is_empty():
		if has_node("/root/Telemetry"):
			get_node("/root/Telemetry").log_artifact_event(String(result.get("event", "")))
		_artifact_visuals.on_artifact_event(String(result.get("event", "")))
		show_status_flash("%s ACTIVE" % String(result.get("label", "Ghost Grass")), false)

func take_damage(amount: float, source: String = "gun", weapon_type: String = "", source_node: Node3D = null):
	if source == "zone":
		amount *= _artifact_mods.get("zone_dmg_mult", 1.0)
	elif source == "gun" and _artifact_runtime.is_ghost_grass_active():
		amount *= _artifact_runtime.get_ghost_grass_incoming_damage_mult()
		_artifact_runtime.cancel_ghost_grass()
		reveal(2.0)
		show_status_flash("GHOST GRASS BROKEN", false)
	super.take_damage(amount, source, weapon_type, source_node)
	_apply_artifact_after_damage()
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
	if _shot_heat > 0.0: _shot_heat = maxf(0.0, _shot_heat - PlayerTuningScript.HEAT_DECAY * delta)
	if _heal_regen > 0:
		var tick = min(PlayerTuningScript.HEAL_REGEN_RATE * delta, min(_heal_regen, stats.max_health - current_health))
		if tick > 0:
			current_health += tick
			_heal_regen -= tick
			health_changed.emit(current_health, stats.max_health)
		else:
			_heal_regen = 0.0
	slots.tick(delta)
	handle_aiming(delta)
	var effective_speed = stats.move_speed * (0.45 if is_crouching else 1.0) * _artifact_move_speed_mult()

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
			footstep_timer = PlayerTuningScript.FOOTSTEP_INTERVAL
			var footstep_volume_db := PLAYER_MOVEMENT_AUDIO_POLICY.footstep_volume_offset_db(
				is_crouching
			)
			if Sfx and Sfx.has_method("play_footstep"):
				Sfx.play_footstep(_current_surface_id(), global_position, footstep_volume_db)
			elif Sfx:
				Sfx.play("footstep", global_position, footstep_volume_db)
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
						var force_silent_miss = _should_silent_core_force_miss("shotgun")
						for i in range(wdata.pellet_count): shoot_pellet(i, force_silent_miss)
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
	_update_pickup_focus()
	if Input.is_action_just_pressed("interact"): handle_interaction()
	if Input.is_key_pressed(KEY_Q): handle_healing()
	super._physics_process(delta)
	_artifact_runtime.tick(delta)
	if _artifact_runtime.is_ghost_grass_active() and reveal_timer <= 0:
		stealth_modifier = min(stealth_modifier, _artifact_runtime.get_ghost_grass_stealth_modifier())
	# Crouch stealth
	if is_crouching and reveal_timer <= 0:
		stealth_modifier = min(stealth_modifier, 0.35)
	# Crouch visual
	if has_node("MeshInstance3D"):
		$MeshInstance3D.scale.y = 0.55 if is_crouching else 1.0
		$MeshInstance3D.position.y = _mesh_origin_y - 0.225 if is_crouching else _mesh_origin_y
	camera_pivot.global_position = global_position

func _artifact_move_speed_mult() -> float:
	if _artifact_mods.has("armor_sponge_move_speed_min") and float(_artifact_mods.get("armor_sponge_move_speed_min", 1.0)) < 1.0:
		if stats.max_shield <= 0:
			return 1.0
		var shield_ratio = clampf(current_shield / stats.max_shield, 0.0, 1.0)
		return lerpf(1.0, float(_artifact_mods.get("armor_sponge_move_speed_min", 1.0)), shield_ratio)
	return float(_artifact_mods.get("move_speed_mult", 1.0))

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

func _configure_night_readability() -> void:
	var metadata := {}
	var main = get_tree().root.get_node_or_null("Main")
	if main:
		var current_map_spec = main.get("map_spec")
		if current_map_spec != null:
			var raw_metadata = current_map_spec.get("metadata")
			if typeof(raw_metadata) == TYPE_DICTIONARY:
				metadata = raw_metadata
		if metadata.is_empty():
			metadata["id"] = String(main.get("map_spec_path"))
	_night_readability.configure_for_metadata(metadata)

func debug_night_readability_state() -> Dictionary:
	return _night_readability.debug_state()

func is_night_readability_active() -> bool:
	return _night_readability.is_active()

func get_night_awareness_signature() -> float:
	var signature := super.get_night_awareness_signature()
	if not _night_readability.is_active():
		return signature
	signature = maxf(signature, 0.45)
	var speed := Vector2(velocity.x, velocity.z).length()
	if stats and speed >= stats.move_speed * 0.5:
		signature = maxf(signature, 0.65)
	return signature

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
		slot_ammo_labels[slots.active_slot].text = ItemDisplayFormatterScript.slot_ammo_text(disp_ammo, max_a_r, disp_res)
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

	_artifact_visuals.tick(delta, _build_artifact_visual_context())

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
	var closest = _get_interaction_pickup()
	if closest and closest.collect(self):
		if closest == _focused_pickup:
			_focused_pickup = null

func _update_pickup_focus() -> void:
	var closest = _get_interaction_pickup()
	if closest == _focused_pickup:
		return
	if is_instance_valid(_focused_pickup) and _focused_pickup.has_method("set_focused"):
		_focused_pickup.set_focused(false)
	_focused_pickup = closest
	if is_instance_valid(_focused_pickup) and _focused_pickup.has_method("set_focused"):
		_focused_pickup.set_focused(true)

func _get_interaction_pickup() -> Pickup:
	var pickups = interaction_area.get_overlapping_areas()
	var closest: Pickup = null
	var min_dist = INF
	for area in pickups:
		if area is Pickup:
			if not can_sense_item(area.global_position):
				continue
			var d = global_position.distance_to(area.global_position)
			if d < min_dist:
				min_dist = d
				closest = area
	return closest

func handle_healing():
	var main = get_tree().root.get_node_or_null("Main")
	var is_hell = main != null and main.difficulty == 3
	var scarcity_mult = 0.5 if (is_hell and main != null and main.hell_modifier == main.HellModifier.SCARCITY) else 1.0

	# Armor Sponge: 힐 → 쉴드 전환 모드 (HP 회복 없음)
	if _artifact_mods.get("heal_to_shield", false):
		var shield_cap = minf(stats.max_shield, float(_artifact_mods.get("heal_to_shield_cap", stats.max_shield)))
		if shield_cap <= 0.0:
			shield_cap = stats.max_shield
		if current_shield >= shield_cap: return
		var conversion_ratio = maxf(0.0, float(_artifact_mods.get("heal_to_shield_ratio", 1.0)))
		if stats.advanced_heals > 0:
			stats.advanced_heals -= 1
			var advanced_base_amount = float(_artifact_mods.get("heal_to_shield_advanced_base", 60.0)) * (0.55 if is_hell else 1.0)
			_receive_shield_capped(advanced_base_amount * conversion_ratio * scarcity_mult, shield_cap)
			if Sfx: Sfx.play("heal", global_position)
			if has_node("/root/Telemetry"): get_node("/root/Telemetry").log_economy("heals_used")
			if main and main.mission_tracker:
				main.mission_tracker.on_pressure_heal_used()
				main.mission_tracker.on_player_medkit_used()
			_refresh_slot_hud()
		elif stats.heal_items > 0:
			stats.heal_items -= 1
			var common_base_amount = float(_artifact_mods.get("heal_to_shield_common_base", 30.0)) * (0.40 if is_hell else 1.0)
			_receive_shield_capped(common_base_amount * conversion_ratio * scarcity_mult, shield_cap)
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

func apply_health_capacity_lock(max_health: float = 1.0) -> void:
	stats.max_health = maxf(1.0, max_health)
	current_health = min(stats.max_health, maxf(1.0, current_health))
	_heal_regen = 0.0
	health_changed.emit(current_health, stats.max_health)

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
	fire_cooldown = PlayerTuningScript.MELEE_RATE
	if Sfx:
		if Sfx.has_method("play_melee_swing"):
			Sfx.play_melee_swing()
		else:
			Sfx.play("melee")
	ray_cast.target_position = Vector3(0, 0, -PlayerTuningScript.MELEE_RANGE)
	ray_cast.force_raycast_update()
	if ray_cast.is_colliding():
		var hit_pos = ray_cast.get_collision_point()
		var impact = IMPACT_EFFECT_SCN.instantiate()
		get_tree().root.add_child(impact)
		impact.global_position = hit_pos
		var target = ray_cast.get_collider()
		if target.has_method("take_damage"):
			var melee_mult = _artifact_mods.get("melee_damage_mult", _artifact_mods.get("damage_mult", 1.0))
			target.take_damage(PlayerTuningScript.MELEE_DAMAGE * melee_mult, "melee", "knife", self)
			if Sfx:
				if Sfx.has_method("play_melee_hit"):
					Sfx.play_melee_hit(hit_pos)
				else:
					Sfx.play("hit", hit_pos)

func _refresh_slot_hud():
	PlayerSlotHudRendererScript.refresh(
		slot_panels,
		slot_icon_rects,
		slot_ammo_labels,
		slots,
		Callable(_weapon_icon_resolver, "make_weapon_icon").bind(_get_asset_catalog())
	)

func _get_asset_catalog():
	var main = get_tree().root.get_node_or_null("Main")
	if main:
		return main.get("asset_catalog")
	return null

func _exit_tree():
	_occluder_fader.restore_all()

func _handle_wall_transparency(delta: float):
	var camera = camera_pivot.get_node_or_null("Camera3D")
	if not camera:
		_occluder_fader.restore_all()
		return

	_occluder_fader.tick(self, camera, delta)

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

func show_status_flash(text: String, success: bool):
	if not _flash_label or not _flash_panel: return
	_flash_label.text = text
	_flash_label.modulate = Color(0.3, 1.0, 0.45) if success else Color(1.0, 0.32, 0.32)
	if _flash_tween: _flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash_panel, "modulate:a", 0.88, 0.12)
	_flash_tween.tween_interval(2.2)
	_flash_tween.tween_property(_flash_panel, "modulate:a", 0.0, 0.45)

func show_pressure_flash(text: String, success: bool):
	show_status_flash(text, success)

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
		item.item_name = DropDisplayCatalogScript.weapon_name(wdata.weapon_type)
		item.color = DropDisplayCatalogScript.weapon_color(wdata.weapon_type)
		var wstats = wdata.duplicate() as StatsData
		wstats.current_ammo = wstats.max_ammo / 3
		item.weapon_stats = wstats
		var wp = PICKUP_SCN.instantiate()
		get_tree().root.add_child(wp)
		wp.global_position = global_position + Vector3(randf_range(-0.8, 0.8), 0.3, randf_range(-0.8, 0.8))
		wp.init(item, "player_drop")
		var total_ammo = slots.slot_ammo[i] + slots.slot_reserve[i]
		if total_ammo > 0:
			var ammo_item = ItemData.new()
			ammo_item.type = ItemData.Type.AMMO
			ammo_item.rarity = ItemData.Rarity.COMMON
			ammo_item.item_name = DropDisplayCatalogScript.ammo_name(wdata.weapon_type)
			ammo_item.ammo_weapon_type = wdata.weapon_type
			ammo_item.amount = total_ammo
			ammo_item.color = DropDisplayCatalogScript.weapon_color(wdata.weapon_type)
			var ap = PICKUP_SCN.instantiate()
			get_tree().root.add_child(ap)
			ap.global_position = global_position + Vector3(randf_range(-0.8, 0.8), 0.3, randf_range(-0.8, 0.8))
			ap.init(ammo_item, "player_drop")
	if stats.heal_items > 0:
		var heal_item = ItemData.new()
		heal_item.type = ItemData.Type.HEAL
		heal_item.rarity = ItemData.Rarity.COMMON
		heal_item.item_name = DropDisplayCatalogScript.common_heal_name()
		heal_item.amount = stats.heal_items
		heal_item.color = Color(0.2, 1.0, 0.4)
		var hp = PICKUP_SCN.instantiate()
		get_tree().root.add_child(hp)
		hp.global_position = global_position + Vector3(0, 0.3, 0)
		hp.init(heal_item, "player_drop")
	if stats.advanced_heals > 0:
		var adv_item = ItemData.new()
		adv_item.type = ItemData.Type.HEAL
		adv_item.rarity = ItemData.Rarity.RARE
		adv_item.item_name = DropDisplayCatalogScript.rare_heal_name()
		adv_item.amount = stats.advanced_heals
		adv_item.color = Color(1.0, 0.88, 0.1)
		var ap2 = PICKUP_SCN.instantiate()
		get_tree().root.add_child(ap2)
		ap2.global_position = global_position + Vector3(0, 0.3, 0.5)
		ap2.init(adv_item, "player_drop")

func _reveal_for_fire(weapon_type: String) -> void:
	if weapon_type != "knife" and _artifact_runtime.is_ghost_grass_active():
		_artifact_runtime.cancel_ghost_grass()
	var duration := 2.0
	if weapon_type != "knife" and _artifact_mods.get("red_trigger", false):
		duration = float(_artifact_mods.get("red_trigger_reveal_duration", duration))
	reveal(duration)


func _should_silent_core_force_miss(weapon_type: String) -> bool:
	if weapon_type == "knife":
		return false
	if not _artifact_mods.get("silent_core_first_shot_miss", false):
		return false
	return reveal_timer <= 0.0


func _silent_core_miss_vector(target_vec: Vector3, attack_range: float) -> Vector3:
	var miss_vec := target_vec
	var side := -1.0 if randf() < 0.5 else 1.0
	miss_vec.x = side * maxf(absf(miss_vec.x), maxf(6.0, attack_range * 0.16))
	miss_vec.y += randf_range(-1.0, 1.0)
	return miss_vec


func shoot_pellet(_idx: int, force_miss: bool = false):
	_reveal_for_fire("shotgun")
	var wdata = slots.weapon_slots[slots.active_slot]
	if not wdata: return
	var spread = 2.0 * _artifact_mods.get("spread_mult", 1.0)
	var pellet_target = Vector3(randf_range(-spread, spread), randf_range(-0.5, 0.5), -wdata.attack_range)
	if force_miss:
		pellet_target = _silent_core_miss_vector(pellet_target, wdata.attack_range)
	_internal_shoot(pellet_target, force_miss)

func _shoot_with_slot(slot: int):
	var wdata = slots.weapon_slots[slot]
	if not wdata or slots.slot_ammo[slot] <= 0: return
	var force_silent_miss = _should_silent_core_force_miss(wdata.weapon_type)
	slots.consume_ammo()
	_sync_stats_ammo()
	_reveal_for_fire(wdata.weapon_type)
	var shot_vec = Vector3(0, 0, -wdata.attack_range)
	if _artifact_mods.get("spread_all_shots", false):
		# Red Trigger: extreme spray for non-shotgun (shotgun handled via shoot_pellet)
		var s = _artifact_mods.get("spread_mult", 1.0)
		if _artifact_mods.get("red_trigger", false):
			s = _artifact_mods.get("non_shotgun_spread", s)
		shot_vec.x = randf_range(-s, s)
		shot_vec.y = randf_range(-s * 0.25, s * 0.25)
	elif wdata.weapon_type == "ar" or wdata.weapon_type == "pistol":
		var is_ar = wdata.weapon_type == "ar"
		var heat_gain = PlayerTuningScript.HEAT_PER_SHOT_AR if is_ar else PlayerTuningScript.HEAT_PER_SHOT_PISTOL
		_shot_heat = minf(PlayerTuningScript.HEAT_MAX, _shot_heat + heat_gain)
		var base = PlayerTuningScript.BASE_SPREAD_AR if is_ar else PlayerTuningScript.BASE_SPREAD_PISTOL
		var heat_spread = base + _shot_heat * (3.5 if is_ar else 2.3)
		shot_vec.x = randf_range(-heat_spread, heat_spread)
		shot_vec.y = randf_range(-heat_spread * 0.15, heat_spread * 0.15)
	if force_silent_miss:
		shot_vec = _silent_core_miss_vector(shot_vec, wdata.attack_range)
	_internal_shoot(shot_vec, force_silent_miss)
	fire_cooldown = wdata.fire_rate
	_play_weapon_shot_sfx(wdata.weapon_type)
	_refresh_slot_hud()
	_notify_mission_tracker_fire(wdata.weapon_type)

func _internal_shoot(target_vec: Vector3, force_miss: bool = false):
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
		if target.has_method("take_damage") and not force_miss:
			var wtype = wdata.weapon_type if wdata else stats.weapon_type
			var dmg: float
			if _artifact_mods.get("red_trigger", false):
				var red_trigger_mult = _artifact_mods.get("non_shotgun_damage_mult", 1.0)
				if wtype == "shotgun":
					red_trigger_mult = _artifact_mods.get("shotgun_damage_mult", 1.0)
				dmg = (wdata.attack_damage if wdata else stats.attack_damage) * red_trigger_mult
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
	var force_silent_miss = _should_silent_core_force_miss(stats.weapon_type)
	stats.current_ammo -= 1
	_reveal_for_fire(stats.weapon_type)
	var shot_vec = Vector3(0, 0, -stats.attack_range)
	if force_silent_miss:
		shot_vec = _silent_core_miss_vector(shot_vec, stats.attack_range)
	_internal_shoot(shot_vec, force_silent_miss)
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
	if main and main.map_definition and main.map_definition.has_method("get_surface_id_at"):
		return String(main.map_definition.get_surface_id_at(
			Vector2(global_position.x, global_position.z),
			"dirt"
		))
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

func _current_weapon_type() -> String:
	if slots.active_slot == 0:
		return "knife"
	if slots.active_slot >= 1 and slots.active_slot < slots.weapon_slots.size():
		var wdata = slots.weapon_slots[slots.active_slot]
		if wdata:
			return String(wdata.weapon_type)
	return String(stats.weapon_type)

func _zone_battery_visual_state() -> Dictionary:
	var result = {"near": false, "charging": false}
	if not _artifact_mods.get("zone_battery", false) or is_dead:
		return result
	var main = get_tree().root.get_node_or_null("Main")
	if not main or not main.zone:
		return result
	var rng = float(_artifact_mods.get("zone_battery_range", 0.0))
	if rng <= 0.0:
		return result
	var pos2d = Vector2(global_position.x, global_position.z)
	var dist_from_center = pos2d.distance_to(main.zone.current_center)
	var dist_inside_edge = main.zone.current_radius - dist_from_center
	var near_edge = dist_inside_edge >= 0.0 and dist_inside_edge <= rng
	result["near"] = near_edge
	result["charging"] = near_edge and current_shield < stats.max_shield
	return result

func _build_artifact_visual_context() -> Dictionary:
	var zone_battery_state = _zone_battery_visual_state()
	var shield_ratio = 0.0
	if stats.max_shield > 0:
		shield_ratio = clampf(current_shield / float(stats.max_shield), 0.0, 1.0)
	var move_vec = Vector2(velocity.x, velocity.z)
	var move_dir = move_vec.normalized() if move_vec.length() > 0.01 else Vector2.ZERO
	return {
		"is_dead": is_dead,
		"is_crouching": is_crouching,
		"weapon_type": _current_weapon_type(),
		"move_speed": move_vec.length(),
		"move_dir_x": move_dir.x,
		"move_dir_z": move_dir.y,
		"shield_ratio": shield_ratio,
		"zone_battery_near": bool(zone_battery_state.get("near", false)),
		"zone_battery_charging": bool(zone_battery_state.get("charging", false)),
		"ghost_grass_active": _artifact_runtime.is_ghost_grass_active(),
	}

func apply_artifact(artifact: Dictionary):
	active_artifact = artifact
	_artifact_runtime.configure(artifact)
	_artifact_visuals.configure(artifact)
	_artifact_mods = {
		"damage_mult": 1.0, "spread_mult": 1.0, "spread_all_shots": false, "red_trigger": false,
		"shotgun_damage_mult": 1.0, "non_shotgun_damage_mult": 1.0,
		"non_shotgun_spread": 1.0, "red_trigger_reveal_duration": 2.0,
		"move_speed_mult": 1.0,
		"heal_mult": 1.0, "heal_to_shield": false,
		"heal_to_shield_ratio": 1.0, "heal_to_shield_cap": 0.0,
		"armor_sponge_move_speed_min": 1.0,
		"shield_recv_mult": 1.0, "zone_dmg_mult": 1.0,
		"footstep_radius_mult": 1.0, "silent_core_first_shot_miss": false,
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
	if float(mods.get("heal_mult", 1.0)) == 0.0:
		apply_health_capacity_lock(1.0)
	_update_artifact_hud_icon(artifact)
	if has_node("/root/Telemetry"):
		get_node("/root/Telemetry").log_artifact_selected(String(artifact.get("id", "none")))

func _update_artifact_hud_icon(artifact: Dictionary) -> void:
	if _artifact_label:
		_artifact_label.visible = false
	if _artifact_icon == null:
		return
	if artifact.is_empty():
		_artifact_icon.visible = false
		_artifact_icon.texture = null
		_artifact_icon.tooltip_text = ""
		return
	_artifact_icon.texture = _artifact_icon_resolver.make_artifact_icon(artifact, _get_asset_catalog(), 30)
	_artifact_icon.modulate = Color.WHITE
	_artifact_icon.tooltip_text = String(artifact.get("label", ""))
	_artifact_icon.visible = true

func _apply_artifact_after_damage() -> void:
	if is_dead:
		return
	var result = _artifact_runtime.evaluate_after_damage(
		current_health,
		stats.max_health,
		current_shield,
		stats.max_shield
	)
	if result.is_empty():
		return
	receive_shield(float(result.get("shield", 0.0)))
	if result.get("ammo_purge", false):
		slots.clear_all_ammo()
		_sync_stats_ammo()
		_refresh_slot_hud()
	if has_node("/root/Telemetry"):
		get_node("/root/Telemetry").log_artifact_event(String(result.get("event", "")))
	_artifact_visuals.on_artifact_event(String(result.get("event", "")))
	var flash_text = "%s +%d SHIELD" % [
		String(result.get("label", "Emergency Shell")),
		int(roundf(float(result.get("shield", 0.0)))),
	]
	if result.get("ammo_purge", false):
		flash_text += " / AMMO LOST"
	show_status_flash(flash_text, true)

func receive_shield(amount: float):
	var mult = _artifact_mods.get("shield_recv_mult", 1.0)
	current_shield = min(stats.max_shield, current_shield + amount * mult)
	shield_changed.emit(current_shield, stats.max_shield)

func _receive_shield_capped(amount: float, shield_cap: float) -> void:
	var cap = clampf(shield_cap, 0.0, stats.max_shield)
	if cap <= 0.0 or current_shield >= cap:
		return
	var mult = float(_artifact_mods.get("shield_recv_mult", 1.0))
	current_shield = minf(cap, current_shield + amount * mult)
	shield_changed.emit(current_shield, stats.max_shield)

func get_footstep_radius_mult() -> float:
	var stance_mult := PLAYER_MOVEMENT_AUDIO_POLICY.footstep_stance_radius_mult(is_crouching)
	return stance_mult * _artifact_runtime.get_footstep_radius_mult(
		_artifact_mods.get("footstep_radius_mult", 1.0)
	)
