extends Node

const POOL_SIZE := 12
const SAMPLE_RATE := 22050

var _pool: Array[AudioStreamPlayer] = []
var _next_idx: int = 0
var _sfx: Dictionary = {}

func _ready() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = &"Master"
		add_child(player)
		_pool.append(player)
	_build_placeholder_sfx()

func play_sfx(id: String, volume: float = 1.0, pitch: float = -1.0) -> void:
	if not _sfx.has(id):
		return
	var player := _get_player()
	player.stream = _sfx[id]
	player.volume_db = linear_to_db(clampf(volume, 0.0, 1.0))
	player.pitch_scale = pitch if pitch > 0.0 else randf_range(0.94, 1.06)
	player.play()

func _get_player() -> AudioStreamPlayer:
	var player := _pool[_next_idx]
	_next_idx = (_next_idx + 1) % POOL_SIZE
	if player.playing:
		player.stop()
	return player

func _build_placeholder_sfx() -> void:
	_sfx["gunfire"] = _make_noise_burst(0.07, 0.55, 40.0)
	_sfx["gunfire_heavy"] = _make_noise_burst(0.11, 0.65, 28.0)
	_sfx["gunfire_smg"] = _make_noise_burst(0.042, 0.4, 58.0)
	_sfx["gunfire_rifle"] = _make_noise_burst(0.065, 0.52, 44.0)
	_sfx["gunfire_sniper"] = _make_noise_burst(0.095, 0.68, 30.0)
	_sfx["gunfire_melta"] = _make_sweep(200.0, 70.0, 0.16, 0.58)
	_sfx["gunfire_launcher"] = _make_sweep(110.0, 42.0, 0.24, 0.62)
	_sfx["gunfire_lmg"] = _make_noise_burst(0.075, 0.56, 36.0)
	_sfx["gunfire_pistol"] = _make_noise_burst(0.048, 0.38, 52.0)
	_sfx["chest_open"] = _make_sweep(260.0, 620.0, 0.22, 0.5)
	_sfx["impact_enemy"] = _make_tone(180.0, 0.08, 0.45, 14.0)
	_sfx["impact_wall"] = _make_tone(90.0, 0.1, 0.35, 10.0)
	_sfx["impact_crit"] = _make_tone(320.0, 0.12, 0.5, 12.0)
	_sfx["player_hurt"] = _make_tone(140.0, 0.14, 0.4, 8.0)
	_sfx["player_death"] = _make_tone(80.0, 0.45, 0.55, 3.5)
	_sfx["enemy_death"] = _make_tone(110.0, 0.22, 0.42, 5.0)
	_sfx["ability_void"] = _make_sweep(420.0, 120.0, 0.18, 0.45)
	_sfx["ability_aoe"] = _make_sweep(220.0, 60.0, 0.28, 0.5)
	_sfx["ability_shield"] = _make_tone(260.0, 0.25, 0.38, 4.0)
	_sfx["ability_chain"] = _make_sweep(680.0, 280.0, 0.16, 0.42)

func _make_tone(freq: float, duration: float, volume: float, decay: float) -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / SAMPLE_RATE
		var env := exp(-decay * t)
		var sample := sin(TAU * freq * t) * volume * env
		_write_sample(data, i, sample)
	return _wrap_wav(data)

func _make_sweep(freq_start: float, freq_end: float, duration: float, volume: float) -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / SAMPLE_RATE
		var blend := float(i) / maxf(count - 1, 1)
		var freq := lerpf(freq_start, freq_end, blend)
		var env := (1.0 - blend) * exp(-3.0 * t)
		var sample := sin(TAU * freq * t) * volume * env
		_write_sample(data, i, sample)
	return _wrap_wav(data)

func _make_noise_burst(duration: float, volume: float, decay: float) -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / SAMPLE_RATE
		var env := exp(-decay * t)
		var sample := randf_range(-1.0, 1.0) * volume * env
		_write_sample(data, i, sample)
	return _wrap_wav(data)

func _write_sample(data: PackedByteArray, index: int, sample: float) -> void:
	var s16 := int(clampi(int(sample * 32767.0), -32768, 32767))
	data[index * 2] = s16 & 0xFF
	data[index * 2 + 1] = (s16 >> 8) & 0xFF

func _wrap_wav(data: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav
