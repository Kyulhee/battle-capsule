extends SceneTree


const REQUIRED_AUDIO := {
	"shoot.pistol": "res://assets/sfx/weapons/pistol_shoot.wav",
	"shoot.ar": "res://assets/sfx/weapons/ar_shoot.wav",
	"shoot.shotgun": "res://assets/sfx/weapons/shotgun_shoot.wav",
	"shoot.railgun": "res://assets/sfx/weapons/railgun_shoot.wav",
	"footstep.grass": "res://assets/sfx/footsteps/grass_01.wav",
	"footstep.dirt": "res://assets/sfx/footsteps/dirt_01.wav",
	"footstep.stone": "res://assets/sfx/footsteps/stone_01.wav",
}


func _init() -> void:
	var asset_catalog_script = load("res://src/core/AssetCatalog.gd")
	var sound_manager_script = load("res://src/core/SoundManager.gd")
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
	var footstep_profile_probe := AudioStreamPlayer.new()
	sound_manager._apply_playback_profile(footstep_profile_probe, "footstep.grass")
	if not is_equal_approx(footstep_profile_probe.volume_db, 0.0):
		_fail("Accepted footstep volume must remain unchanged.")
		return

	weapon_profile_probe.free()
	footstep_profile_probe.free()
	sound_manager.free()
	print("Audio catalog asset smoke passed: %d streams, missing=0." % REQUIRED_AUDIO.size())
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
