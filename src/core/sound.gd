extends Node
## Sounds made from code, no audio file: square waves and noise.

const RATE := 22050.0
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

var _player := AudioStreamPlayer.new()
var _playback: AudioStreamGeneratorPlayback


func _ready() -> void:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = RATE
	stream.buffer_length = 1.0
	_player.stream = stream
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()


func play(tune: StringName) -> void:
	if not Settings.value("sound", "enabled"):
		return
	var volume: float = Settings.value("sound", "volume") / 100.0 * LEVEL
	for note: Array in TUNES[tune]:
		var frames := int(note[0] * RATE)
		# No room left: a sound is already queued, drop this one.
		if _playback.get_frames_available() < frames:
			return
		var voices := note.slice(1)
		for i in frames:
			var sample := 0.0
			for frequency: float in voices:
				if frequency == NOISE:
					sample += randf_range(-1.0, 1.0)
				else:
					sample += 1.0 if fmod(i * frequency / RATE, 1.0) < 0.5 else -1.0
			# Fades out over the note, so that it does not click.
			var loudness := volume * (1.0 - float(i) / frames) / maxi(voices.size(), 1)
			_playback.push_frame(Vector2.ONE * sample * loudness)
