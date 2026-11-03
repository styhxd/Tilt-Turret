extends Node

var _sfx: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _drive: AudioStreamPlayer
var _high: AudioStreamPlayer
var _cursor := 0
var _combat := false
var _danger := false
var _boss_on := false
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
	_sfx["cannon"] = _thump()
	_sfx["twin"] = _ticks()
	_sfx["missile"] = _glide(160.0, 680.0, 280, 0.34)
	_sfx["crystal"] = _tone(1568.0, 160, 0.22, 5.0)
	_sfx["spike"] = _noise(110, 0.4, 12.0)
	_sfx["crown"] = _tone(880.0, 120, 0.24, 7.0)
	_sfx["dry"] = _noise(45, 0.3, 34.0)
	_sfx["slip"] = _noise(220, 0.46, 6.0)
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


func set_boss(on: bool) -> void:
	_boss_on = on


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
	elif _boss_on and not paused:
		if not _high.playing:
			_high.play()
		_high.volume_db = -11.0
		if drive_on:
			_drive.volume_db = -8.0
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


func _thump() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.22)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	for i in n:
		var t := float(i) / float(rate)
		var env := exp(-t * 14.0)
		var s := sin(TAU * 70.0 * t) * 0.45 + rng.randf_range(-1.0, 1.0) * 0.25
		s *= env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wav(data, rate, false)


func _ticks() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.12)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var ping := 1.0 if t < 0.03 or (t > 0.06 and t < 0.09) else 0.0
		var s := sin(TAU * 1400.0 * t) * ping * 0.28
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wav(data, rate, false)


func _phrase(kind: String) -> AudioStreamWAV:
	var rate := 11025
	var beat := 60.0 / 96.0
	var seconds := beat * 4.0 * 8.0
	var n := int(rate * seconds)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 if kind == "drive" else 4
	var melody: Array[float] = [329.63, 392.0, 440.0, 493.88, 587.33, 493.88, 440.0, 392.0]
	if kind == "danger":
		melody = [329.63, 349.23, 440.0, 466.16, 349.23, 329.63, 311.13, 349.23]
	for i in n:
		var t := float(i) / float(rate)
		var bar := int(t / (beat * 4.0)) % 8
		var beat_pos := fmod(t, beat)
		var s := 0.0
		if kind == "pad":
			var bass := 82.41 if bar % 2 == 0 else 123.47
			s = sin(TAU * bass * t) * 0.24 + sin(TAU * bass * 1.5 * t) * 0.08
		elif kind == "drive":
			var step := int(t / beat)
			var kick := 1.0 if beat_pos < 0.07 and step % 2 == 0 else 0.0
			var hat := 1.0 if beat_pos > beat * 0.48 and beat_pos < beat * 0.48 + 0.025 else 0.0
			s = sin(TAU * 78.0 * t) * kick * 0.5
			s += rng.randf_range(-1.0, 1.0) * hat * 0.16
		else:
			var note := melody[bar]
			var env := exp(-fmod(t, beat * 2.0) * 2.6)
			s = sin(TAU * note * t) * env * 0.18
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wav(data, rate, true)


func _pad() -> AudioStreamWAV:
	return _phrase("pad")


func _drive_bed() -> AudioStreamWAV:
	return _phrase("drive")


func _high_bed() -> AudioStreamWAV:
	return _phrase("danger")


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
