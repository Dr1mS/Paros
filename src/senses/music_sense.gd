extends Node
## Posts: music {playing: bool}.
## playing: a media player plays, as told by MPRIS on the session bus. A video
## in a browser counts too.
## Without gdbus, or without a player, this sense says that nothing plays.

const POLL_SECONDS := 3.0
## Seconds given to a player to answer. One that hangs must not hold the others.
const TIMEOUT_SECONDS := "2"
const NAMES: PackedStringArray = [
	"call", "--session", "--timeout", TIMEOUT_SECONDS,
	"--dest", "org.freedesktop.DBus",
	"--object-path", "/org/freedesktop/DBus",
	"--method", "org.freedesktop.DBus.ListNames",
]

var _playing := false
var _thread: Thread
var _player := RegEx.create_from_string("org\\.mpris\\.MediaPlayer2\\.[^']+")


func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = POLL_SECONDS
	timer.autostart = true
	timer.timeout.connect(_poll)
	add_child(timer)


func _exit_tree() -> void:
	if _thread:
		_thread.wait_to_finish()


# The queries run in a thread: OS.execute blocks, and a blocked frame freezes the pet.
func _poll() -> void:
	if not Settings.value("pet", "groove"):
		_report(false)
		return
	if _thread:
		if _thread.is_alive():
			return
		_thread.wait_to_finish()
	_thread = Thread.new()
	_thread.start(_query)


func _query() -> void:
	var names := []
	var playing := false
	if OS.execute("gdbus", NAMES, names) == 0:
		for player in players(str(names[0])):
			var status := []
			# Reply looks like "(<'Playing'>,)".
			if OS.execute("gdbus", _status_query(player), status) == 0 and "'Playing'" in str(status[0]):
				playing = true
				break
	_report.call_deferred(playing)


## Bus names of the media players, from the reply to ListNames.
func players(output: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for name in _player.search_all(output):
		found.append(name.get_string())
	return found


func _status_query(player: String) -> PackedStringArray:
	return [
		"call", "--session", "--timeout", TIMEOUT_SECONDS,
		"--dest", player,
		"--object-path", "/org/mpris/MediaPlayer2",
		"--method", "org.freedesktop.DBus.Properties.Get", "org.mpris.MediaPlayer2.Player", "PlaybackStatus",
	]


func _report(playing: bool) -> void:
	if playing != _playing:
		_playing = playing
		Events.post(&"music", {"playing": playing})
