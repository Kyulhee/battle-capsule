extends Node
# Autoloaded as "Sfx"
# Plays catalog audio paths when present, then res://assets/sfx/{name}.wav,
# and finally falls back to procedural audio.
# 3D sounds: pass a world position. UI/player sounds: omit position (plays flat 2D).

const SOUND_VOLUME_DB := {
	"shoot.pistol": -8.5,
	"shoot.ar": -6.0,
	"shoot.shotgun": -3.0,
	"shoot.railgun": -4.0,
	"melee": -7.5,
	"melee.swing.2": -7.5,
	"melee.swing.3": -7.5,
	"melee.hit": -4.5,
}
const WEAPON_PITCH_VARIATION := 0.02
const MELEE_SWING_IDS := ["melee", "melee.swing.2", "melee.swing.3"]

var asset_catalog = null
var _stream_cache: Dictionary = {}
var _audio_rng := RandomNumberGenerator.new()
var _last_melee_swing_index := -1

func _ready() -> void:
	_audio_rng.randomize()

func set_asset_catalog(catalog) -> void:
	asset_catalog = catalog
	_stream_cache.clear()

func play(
	sound_name: String,
	pos: Vector3 = Vector3.ZERO,
	volume_offset_db: float = 0.0
):
	var stream = _try_load_file(sound_name)
	var fallback_name = sound_name
	if not stream and asset_catalog and asset_catalog.has_method("get_audio_fallback"):
		fallback_name = asset_catalog.get_audio_fallback(sound_name)
	if not stream:
		stream = _generate_procedural(fallback_name)
	if not stream:
		return
	if pos != Vector3.ZERO:
		_play_3d(stream, pos, sound_name, volume_offset_db)
	else:
		_play_2d(stream, sound_name, volume_offset_db)

func play_weapon_shot(weapon_type: String, pos: Vector3 = Vector3.ZERO):
	play("shoot.%s" % weapon_type, pos)


func play_melee_swing(pos: Vector3 = Vector3.ZERO) -> void:
	var next_index := _audio_rng.randi_range(0, MELEE_SWING_IDS.size() - 1)
	if MELEE_SWING_IDS.size() > 1 and next_index == _last_melee_swing_index:
		next_index = (next_index + 1) % MELEE_SWING_IDS.size()
	_last_melee_swing_index = next_index
	play(String(MELEE_SWING_IDS[next_index]), pos)


func play_melee_hit(pos: Vector3 = Vector3.ZERO) -> void:
	play("melee.hit", pos)


func play_footstep(
	surface_id: String = "",
	pos: Vector3 = Vector3.ZERO,
	volume_offset_db: float = 0.0
):
	var sound_id = "footstep.%s" % surface_id if surface_id != "" else "footstep"
	play(sound_id, pos, volume_offset_db)

func _try_load_file(sound_name: String) -> AudioStream:
	if _stream_cache.has(sound_name):
		return _stream_cache[sound_name]

	if asset_catalog and asset_catalog.has_method("get_audio_path"):
		var catalog_path = asset_catalog.get_audio_path(sound_name)
		var catalog_stream = _load_stream(catalog_path)
		if catalog_stream:
			_stream_cache[sound_name] = catalog_stream
			return catalog_stream

	var path = "res://assets/sfx/" + sound_name + ".wav"
	var legacy_stream = _load_stream(path)
	if legacy_stream:
		_stream_cache[sound_name] = legacy_stream
		return legacy_stream
	return null

func _load_stream(path: String) -> AudioStream:
	if path == "":
		return null
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path) and path.get_extension().to_lower() == "wav":
		return AudioStreamWAV.load_from_file(path)
	return null

func _play_3d(
	stream: AudioStream,
	pos: Vector3,
	sound_name: String = "",
	volume_offset_db: float = 0.0
):
	var player = AudioStreamPlayer3D.new()
	get_tree().root.add_child(player)
	player.global_position = pos
	player.stream = stream
	player.unit_size = 10.0
	player.max_distance = 60.0
	_apply_playback_profile(player, sound_name, volume_offset_db)
	player.play()
	player.finished.connect(player.queue_free)

func _play_2d(
	stream: AudioStream,
	sound_name: String = "",
	volume_offset_db: float = 0.0
):
	var player = AudioStreamPlayer.new()
	get_tree().root.add_child(player)
	player.stream = stream
	_apply_playback_profile(player, sound_name, volume_offset_db)
	player.play()
	player.finished.connect(player.queue_free)

func _apply_playback_profile(
	player,
	sound_name: String,
	volume_offset_db: float = 0.0
) -> void:
	player.volume_db = float(SOUND_VOLUME_DB.get(sound_name, 0.0)) + volume_offset_db
	if sound_name.begins_with("shoot."):
		player.pitch_scale = _audio_rng.randf_range(
			1.0 - WEAPON_PITCH_VARIATION,
			1.0 + WEAPON_PITCH_VARIATION
		)

# ── Procedural generator ─────────────────────────────────────────────────────

func _generate_procedural(type: String) -> AudioStreamWAV:
	match type:
		# Gunfire: sharp noise burst, fast exponential decay
		"shoot":        return _noise_burst(0.070, 28.0, 0.65)
		# Bullet impact on body: softer thump
		"hit":          return _noise_burst(0.060, 20.0, 0.45)
		# Bullet impact on wall: dry click
		"impact_wall":  return _noise_burst(0.045, 22.0, 0.28)
		# Player takes damage: low thud
		"hurt":         return _noise_burst(0.100, 10.0, 0.50)
		# Empty magazine click
		"dry_fire":     return _noise_burst(0.022, 55.0, 0.20)
		# Death: long noise fade + descending tone
		"death":        return _death_sound()
		# Pickup: short rising ping
		"pickup":       return _tone_sweep(480.0, 1050.0, 0.13, false)
		# Heal: warm ascending sweep with harmonic
		"heal":         return _tone_sweep(260.0, 620.0,  0.28, true)
		# Footstep: very short soft thud
		"footstep":     return _noise_burst(0.030, 40.0, 0.14)
		# Zone warning: double-beep alarm
		"melee":        return _noise_burst(0.040, 15.0, 0.30)
		"reload":       return _reload_sound()
		"zone_warning": return _alarm_beep()
	if type.begins_with("shoot."):
		return _generate_procedural("shoot")
	if type.begins_with("footstep."):
		return _generate_procedural("footstep")
	return null

# White noise shaped by an exponential decay envelope
func _noise_burst(duration: float, decay_rate: float, volume: float) -> AudioStreamWAV:
	var rate   = 44100
	var count  = int(rate * duration)
	var buf    = PackedByteArray()
	buf.resize(count * 2)
	var rng = RandomNumberGenerator.new()
	rng.seed = int(decay_rate * 1000 + duration * 100000)
	for i in range(count):
		var t   = float(i) / float(count)
		var env = exp(-t * decay_rate)
		var s   = int(rng.randf_range(-1.0, 1.0) * 32767.0 * env * volume)
		buf.encode_s16(i * 2, s)
	return _build_wav(buf, rate)

# Sine sweep from freq_start to freq_end with a bell-curve volume envelope.
# add_harmonic adds a fifth interval (×1.5) blended at 30% for warmth.
func _tone_sweep(freq_start: float, freq_end: float, duration: float, add_harmonic: bool) -> AudioStreamWAV:
	var rate   = 44100
	var count  = int(rate * duration)
	var buf    = PackedByteArray()
	buf.resize(count * 2)
	var phase  = 0.0
	var phase2 = 0.0
	for i in range(count):
		var t    = float(i) / float(count)
		var freq = lerp(freq_start, freq_end, t)
		var env  = sin(t * PI)
		var val  = sin(phase * TAU)
		if add_harmonic:
			val = val * 0.7 + sin(phase2 * TAU) * 0.3
		buf.encode_s16(i * 2, int(val * 32767.0 * env * 0.50))
		phase  += freq / float(rate)
		if phase  > 1.0: phase  -= 1.0
		if add_harmonic:
			phase2 += (freq * 1.5) / float(rate)
			if phase2 > 1.0: phase2 -= 1.0
	return _build_wav(buf, rate)

# Noise burst + descending sine undertone, quadratic fade
func _death_sound() -> AudioStreamWAV:
	var rate     = 44100
	var duration = 0.55
	var count    = int(rate * duration)
	var buf      = PackedByteArray()
	buf.resize(count * 2)
	var rng   = RandomNumberGenerator.new()
	rng.seed  = 7331
	var phase = 0.0
	for i in range(count):
		var t     = float(i) / float(count)
		var env   = pow(1.0 - t, 2.0)
		var noise = rng.randf_range(-1.0, 1.0) * 0.55
		var freq  = lerp(200.0, 55.0, t)
		var tone  = sin(phase * TAU) * 0.45
		buf.encode_s16(i * 2, int((noise + tone) * 32767.0 * env * 0.55))
		phase += freq / float(rate)
		if phase > 1.0: phase -= 1.0
	return _build_wav(buf, rate)

# Two-pulse alarm: 800 Hz beep × 2 with a short gap between
func _alarm_beep() -> AudioStreamWAV:
	var rate     = 44100
	var duration = 0.50
	var count    = int(rate * duration)
	var buf      = PackedByteArray()
	buf.resize(count * 2)
	var phase    = 0.0
	for i in range(count):
		var t     = float(i) / float(count)
		var in_p1 = t < 0.20
		var in_p2 = t >= 0.28 and t < 0.48
		var env   = 0.0
		if in_p1:
			env = sin((t / 0.20) * PI)
		elif in_p2:
			env = sin(((t - 0.28) / 0.20) * PI)
		buf.encode_s16(i * 2, int(sin(phase * TAU) * 32767.0 * env * 0.55))
		phase += 800.0 / float(rate)
		if phase > 1.0: phase -= 1.0
	return _build_wav(buf, rate)

func _reload_sound() -> AudioStreamWAV:
	var rate   = 44100
	var duration = 0.28
	var count  = int(rate * duration)
	var buf    = PackedByteArray()
	buf.resize(count * 2)
	var rng = RandomNumberGenerator.new()
	rng.seed = 99137
	for i in range(count):
		var t = float(i) / float(count)
		var in_c1 = t < 0.06
		var in_c2 = t >= 0.14 and t < 0.22
		var env = 0.0
		if in_c1: env = exp(-t * 90.0)
		elif in_c2: env = exp(-(t - 0.14) * 70.0)
		buf.encode_s16(i * 2, int(rng.randf_range(-1.0, 1.0) * 32767.0 * env * 0.45))
	return _build_wav(buf, rate)

func _build_wav(buf: PackedByteArray, rate: int) -> AudioStreamWAV:
	var s        = AudioStreamWAV.new()
	s.format     = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate   = rate
	s.data       = buf
	return s
