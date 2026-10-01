extends Node
## Sounds made from code, no audio file in the project: square waves and noise.
##
## Linux: the audio driver of the engine is off (project setting), because its
## thread costs CPU all the time, sound or not. Each tune is written once as a
## WAV file in the runtime folder and played by a system player.
## Elsewhere: played by the engine, through a generator stream.

const RATE := 22050
## Loudness at full volume. A square wave at 1 is harsh.
const LEVEL := 0.22
## Name -> notes. A note: seconds, then frequencies in hertz played together.
## No frequency: silence. NOISE: white noise.
const NOISE := -1.0
const TUNES := {
	# Two rising notes.
	&"success": [[0.09, 660.0], [0.16, 990.0]],
	# Two falling notes, the last one with a neighbor a semitone above: it grates.
	&"failure": [[0.12, 330.0], [0.24, 220.0, 233.0]],
	&"thud": [[0.08, NOISE]],
	&"knock": [[0.05, 140.0, NOISE], [0.16], [0.05, 140.0, NOISE]],
}
## System players, first one found is used.
const PLAYERS: Array[String] = ["pw-play", "paplay", "aplay"]

## System player to call. Empty: play through the engine.
var _player := ""
var _folder := OS.get_environment("XDG_RUNTIME_DIR").path_join("paros")
var _playback: AudioStreamGeneratorPlayback


func _ready() -> void:
	if AudioServer.get_driver_name() == "Dummy":
		# Without a display (the tests), stay silent.
		if DisplayServer.get_name() != "headless":
			_player = _find_player()
		_write_files()
		Settings.changed.connect(_write_files)
		return
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = RATE
	stream.buffer_length = 1.0
	var speaker := AudioStreamPlayer.new()
	speaker.stream = stream
	add_child(speaker)
	speaker.play()
	_playback = speaker.get_stream_playback()


func play(tune: StringName) -> void:
	if not Settings.value("sound", "enabled"):
		return
	if _playback:
		var samples := synthesize(tune)
		# No room left: a sound is already queued, drop this one.
		if _playback.get_frames_available() >= samples.size():
			for sample in samples:
				_playback.push_frame(Vector2.ONE * sample)
	elif not _player.is_empty():
		OS.create_process(_player, [_path(tune)])


## Samples of the tune at the volume of the settings, between -1 and 1.
func synthesize(tune: StringName) -> PackedFloat32Array:
	var volume: float = Settings.value("sound", "volume") / 100.0 * LEVEL
	var samples := PackedFloat32Array()
	for note: Array in TUNES[tune]:
		var frames := int(note[0] * RATE)
		var voices := note.slice(1)
		for i in frames:
			var sample := 0.0
			for frequency: float in voices:
				if frequency == NOISE:
					sample += randf_range(-1.0, 1.0)
				else:
					sample += 1.0 if fmod(i * frequency / RATE, 1.0) < 0.5 else -1.0
			# Fades out over the note, so that it does not click.
			samples.append(sample * volume * (1.0 - float(i) / frames) / maxi(voices.size(), 1))
	return samples


## The tune as a WAV file: 16 bits, one channel.
func to_wav(samples: PackedFloat32Array) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var header := PackedByteArray()
	header.resize(44)
	header.encode_u32(4, 36 + data.size())
	header.encode_u32(16, 16)  # Size of the format block.
	header.encode_u16(20, 1)  # PCM.
	header.encode_u16(22, 1)  # Channels.
	header.encode_u32(24, RATE)
	header.encode_u32(28, RATE * 2)  # Bytes per second.
	header.encode_u16(32, 2)  # Bytes per frame.
	header.encode_u16(34, 16)  # Bits per sample.
	header.encode_u32(40, data.size())
	for field: Array in [[0, "RIFF"], [8, "WAVE"], [12, "fmt "], [36, "data"]]:
		for i in 4:
			header[field[0] + i] = field[1].unicode_at(i)
	return header + data


# The volume is in the samples: written again when the settings change.
func _write_files() -> void:
	DirAccess.make_dir_recursive_absolute(_folder)
	for tune: StringName in TUNES:
		var file := FileAccess.open(_path(tune), FileAccess.WRITE)
		if file:
			file.store_buffer(to_wav(synthesize(tune)))


func _path(tune: StringName) -> String:
	return _folder.path_join("%s.wav" % tune)


func _find_player() -> String:
	for player in PLAYERS:
		if OS.execute("sh", ["-c", "command -v %s" % player]) == 0:
			return player
	return ""
