extends Node

var _sfx: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _cursor := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sfx["click"] = _tone(620.0, 70, 0.35, 18.0)
	_sfx["drop"] = _noise(140, 0.45, 10.0)
	_sfx["shoot"] = _tone(310.0, 60, 0.22, 22.0)
	_sfx["hit"] = _noise(90, 0.4, 16.0)
	_sfx["kill"] = _tone(180.0, 120, 0.3, 8.0)
	_sfx["balance"] = _chime()
	_sfx["danger"] = _tone(90.0, 180, 0.28, 6.0)
	_sfx["fall"] = _noise(420, 0.55, 4.0)
	_sfx["freeze"] = _tone(520.0, 220, 0.25, 4.0)
	for i in 6:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -20.0
	add_child(_music)
	_music.stream = _pad()
	_sync_music()


func _sync_music() -> void:
	if GameState.music_on:
		if not _music.playing:
			_music.play()
	else:
		_music.stop()


func set_music(on: bool) -> void:
	GameState.music_on = on
	GameState.save_game()
	_sync_music()


func play(name: String) -> void:
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


func _chime() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.28)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var env := exp(-t * 7.0)
		var s := (sin(TAU * 660.0 * t) * 0.5 + sin(TAU * 990.0 * t) * 0.35) * env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wav(data, rate, false)


func _pad() -> AudioStreamWAV:
	var rate := 22050
	var n := rate * 2
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


func _wav(data: PackedByteArray, rate: int, looped: bool) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	if looped:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return wav
