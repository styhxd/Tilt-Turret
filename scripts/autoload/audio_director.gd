extends Node

var _sfx: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _drive: AudioStreamPlayer
var _high: AudioStreamPlayer
var _cursor := 0
var _combat := false
var _danger := false
var _started := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func start() -> void:
	if _started:
		return
	_started = true
	_sfx["click"] = _tone(620.0, 70, 0.35, 18.0)
	_sfx["drop"] = _noise(140, 0.45, 10.0)
	_sfx["shoot"] = _glide(280.0, 140.0, 90, 0.3)
	_sfx["cannon"] = _glide(240.0, 90.0, 140, 0.34)
	_sfx["twin"] = _tone(980.0, 36, 0.22, 32.0)
	_sfx["missile"] = _tone(68.0, 180, 0.4, 5.0)
	_sfx["crystal"] = _tone(1040.0, 160, 0.2, 7.0)
	_sfx["spike"] = _noise(80, 0.32, 20.0)
	_sfx["crown"] = _glide(520.0, 760.0, 90, 0.22)
	_sfx["hit"] = _noise(90, 0.4, 16.0)
	_sfx["kill"] = _tone(180.0, 120, 0.3, 8.0)
	_sfx["balance"] = _arpeggio()
	_sfx["danger"] = _tone(90.0, 180, 0.28, 6.0)
	_sfx["fall"] = _noise(420, 0.55, 4.0)
	_sfx["freeze"] = _tone(520.0, 220, 0.25, 4.0)
	for i in 10:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)
	_music = _loop_player(_pad(), -16.0)
	_drive = _loop_player(_drive_bed(), -14.0)
	_high = _loop_player(_high_bed(), -12.0)
	_apply_layers()


func _process(_delta: float) -> void:
	_apply_layers()


func set_mood(combat: bool, danger: bool) -> void:
	_combat = combat
	_danger = danger


func _loop_player(stream: AudioStream, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.volume_db = volume
	player.stream = stream
	add_child(player)
	return player


func _sync_music() -> void:
	_apply_layers()


func _apply_layers() -> void:
	if _music == null or _drive == null or _high == null:
		return
	if not GameState.music_on:
		_music.stop()
		_drive.stop()
		_high.stop()
		return
	if not _music.playing:
		_music.play()
	_music.volume_db = -16.0
	var paused := get_tree() != null and get_tree().paused
	var drive_on := _combat and not paused
	if drive_on:
		if not _drive.playing:
			_drive.play()
		_drive.volume_db = -12.0
	else:
		_drive.volume_db = -80.0
	if _danger and not paused:
		if not _high.playing:
			_high.play()
		_high.volume_db = -10.0
	else:
		_high.volume_db = -80.0


func set_music(on: bool) -> void:
	GameState.music_on = on
	GameState.save_game()
	_sync_music()


func play(name: String) -> void:
	if not _started:
		return
	if not GameState.sfx_on:
		return
	if not _sfx.has(name):
		return
	var player := _players[_cursor]
	_cursor = (_cursor + 1) % _players.size()
	player.stream = _sfx[name]
	player.play()


func buzz(ms: int) -> void:
	if GameState.sfx_on:
		Input.vibrate_handheld(ms)


func _tone(freq: float, ms: int, volume: float, decay: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * float(ms) / 1000.0)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var env := exp(-t * decay)
		var s := sin(TAU * freq * t) * env * volume
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wav(data, rate, false)


func _noise(ms: int, volume: float, decay: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * float(ms) / 1000.0)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in n:
		var t := float(i) / float(rate)
		var env := exp(-t * decay)
		var s := rng.randf_range(-1.0, 1.0) * env * volume
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wav(data, rate, false)


func _glide(a: float, b: float, ms: int, volume: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * float(ms) / 1000.0)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(n)
		var env := exp(-t * 4.0)
		var freq := lerpf(a, b, t)
		var s := sin(TAU * freq * float(i) / float(rate)) * env * volume
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wav(data, rate, false)


func _arpeggio() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.42)
	var data := PackedByteArray()
	data.resize(n * 2)
	var notes := [523.0, 659.0, 784.0]
	for i in n:
		var t := float(i) / float(rate)
		var step := clampi(int(t / 0.12), 0, 2)
		var local := t - float(step) * 0.12
		var env := exp(-local * 10.0)
		var s := sin(TAU * notes[step] * t) * env * 0.35
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wav(data, rate, false)


func _pad() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.5)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var s := sin(TAU * 55.0 * t) * 0.18 + sin(TAU * 82.5 * t) * 0.08
		s *= 0.35 + 0.15 * sin(TAU * 0.5 * t)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var wav := _wav(data, rate, true)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav


func _drive_bed() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.5)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var beat := 1.0 if fmod(t, 0.5) < 0.08 else 0.0
		var hat := 1.0 if fmod(t + 0.25, 0.5) < 0.03 else 0.0
		var s := sin(TAU * 180.0 * t) * beat * 0.28
		s += sin(TAU * 880.0 * t) * hat * 0.08
		s += sin(TAU * 330.0 * t) * 0.05
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wav(data, rate, true)


func _high_bed() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.5)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var s := sin(TAU * 740.0 * t) * 0.08 + sin(TAU * 988.0 * t) * 0.05
		s *= 0.6 + 0.4 * sin(TAU * 2.0 * t)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wav(data, rate, true)


func _wav(data: PackedByteArray, rate: int, looped: bool) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	if looped:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(data.size() / 2)
	return wav
