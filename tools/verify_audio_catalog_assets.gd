extends SceneTree


const REQUIRED_AUDIO := {
	"shoot.pistol": "res://assets/sfx/weapons/pistol_shoot.wav",
	"shoot.ar": "res://assets/sfx/weapons/ar_shoot.wav",
	"shoot.shotgun": "res://assets/sfx/weapons/shotgun_shoot.wav",
	"shoot.railgun": "res://assets/sfx/weapons/railgun_shoot.wav",
	"melee": "res://assets/sfx/weapons/knife_swing.wav",
	"melee.swing.2": "res://assets/sfx/weapons/knife_swing_02.wav",
	"melee.swing.3": "res://assets/sfx/weapons/knife_swing_03.wav",
	"melee.hit": "res://assets/sfx/weapons/knife_hit.ogg",
	"footstep.grass": "res://assets/sfx/footsteps/grass_01.wav",
	"footstep.dirt": "res://assets/sfx/footsteps/dirt_01.wav",
	"footstep.stone": "res://assets/sfx/footsteps/stone_01.wav",
}


func _init() -> void:
	var asset_catalog_script = load("res://src/core/AssetCatalog.gd")
	var sound_manager_script = load("res://src/core/SoundManager.gd")
	var movement_audio_policy = load(
		"res://src/entities/player/PlayerMovementAudioPolicy.gd"
	)
	var asset_catalog = asset_catalog_script.new()
	asset_catalog.load_or_default()

	if asset_catalog.missing_count() != 0:
		_fail("Audio asset promotion must leave no configured catalog paths missing.")
		return

	var sound_manager = sound_manager_script.new()
	sound_manager.set_asset_catalog(asset_catalog)
	for sound_id in REQUIRED_AUDIO:
		var expected_path := String(REQUIRED_AUDIO[sound_id])
		var catalog_path := String(asset_catalog.get_audio_path(sound_id))
		if catalog_path != expected_path:
			_fail("%s path mismatch: expected %s, got %s." % [
				sound_id,
				expected_path,
				catalog_path,
			])
			return
		if not FileAccess.file_exists(catalog_path):
			_fail("%s runtime file is missing: %s." % [sound_id, catalog_path])
			return
		var stream = sound_manager._try_load_file(sound_id)
		if not stream is AudioStream:
			_fail("%s did not load as AudioStream." % sound_id)
			return
		if stream.get_length() <= 0.05:
			_fail("%s stream is empty or too short." % sound_id)
			return
		if sound_id.begins_with("shoot.") and stream.get_length() >= 1.0:
			_fail("%s weapon stream is too long for repeated combat playback." % sound_id)
			return
		if sound_id.begins_with("melee.swing") or sound_id == "melee":
			if stream.get_length() >= 0.35:
				_fail("%s is too long for repeated melee playback." % sound_id)
				return
		if sound_id == "melee.hit" and stream.get_length() >= 0.60:
			_fail("Knife impact stream is too long for close combat feedback.")
			return
		if sound_manager._try_load_file(sound_id) != stream:
			_fail("%s did not reuse its cached stream." % sound_id)
			return

	var weapon_profile_probe := AudioStreamPlayer.new()
	sound_manager._apply_playback_profile(weapon_profile_probe, "shoot.ar")
	if not is_equal_approx(weapon_profile_probe.volume_db, -6.0):
		_fail("AR playback profile must reduce repeated-shot volume.")
		return
	if weapon_profile_probe.pitch_scale < 0.98 or weapon_profile_probe.pitch_scale > 1.02:
		_fail("Weapon pitch variation exceeded the ±2% contract.")
		return
	var pistol_profile_probe := AudioStreamPlayer.new()
	sound_manager._apply_playback_profile(pistol_profile_probe, "shoot.pistol")
	if not is_equal_approx(pistol_profile_probe.volume_db, -8.5):
		_fail("Pistol playback profile must sit below the other gunshots.")
		return
	if pistol_profile_probe.volume_db >= weapon_profile_probe.volume_db:
		_fail("Pistol playback must be quieter than AR playback.")
		return
	var melee_swing_profile_probe := AudioStreamPlayer.new()
	sound_manager._apply_playback_profile(melee_swing_profile_probe, "melee")
	if not is_equal_approx(melee_swing_profile_probe.volume_db, -7.5):
		_fail("Knife swing must stay below the impact layer.")
		return
	var melee_hit_profile_probe := AudioStreamPlayer.new()
	sound_manager._apply_playback_profile(melee_hit_profile_probe, "melee.hit")
	if not is_equal_approx(melee_hit_profile_probe.volume_db, -4.5):
		_fail("Knife impact playback profile mismatch.")
		return
	if melee_hit_profile_probe.volume_db <= melee_swing_profile_probe.volume_db:
		_fail("Knife impact must be clearer than the swing layer.")
		return
	var footstep_profile_probe := AudioStreamPlayer.new()
	sound_manager._apply_playback_profile(footstep_profile_probe, "footstep.grass")
	if not is_equal_approx(footstep_profile_probe.volume_db, 0.0):
		_fail("Accepted footstep volume must remain unchanged.")
		return
	var crouch_footstep_probe := AudioStreamPlayer.new()
	var crouch_volume_db: float = movement_audio_policy.footstep_volume_offset_db(true)
	sound_manager._apply_playback_profile(
		crouch_footstep_probe,
		"footstep.grass",
		crouch_volume_db
	)
	if not is_equal_approx(crouch_footstep_probe.volume_db, -10.0):
		_fail("Crouched footsteps must apply a -10 dB stance offset.")
		return
	if not is_equal_approx(movement_audio_policy.footstep_volume_offset_db(false), 0.0):
		_fail("Standing footsteps must preserve the accepted volume.")
		return
	if not is_equal_approx(movement_audio_policy.footstep_stance_radius_mult(true), 0.45):
		_fail("Crouched footsteps must reduce AI hearing radius to 45%.")
		return
	if not is_equal_approx(movement_audio_policy.footstep_stance_radius_mult(false), 1.0):
		_fail("Standing footsteps must preserve AI hearing radius.")
		return

	weapon_profile_probe.free()
	pistol_profile_probe.free()
	melee_swing_profile_probe.free()
	melee_hit_profile_probe.free()
	footstep_profile_probe.free()
	crouch_footstep_probe.free()
	sound_manager.free()
	print("Audio catalog asset smoke passed: %d streams, missing=0." % REQUIRED_AUDIO.size())
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
