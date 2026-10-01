extends Node
## Posts: user_idle, user_active.
## Asks GNOME (Mutter IdleMonitor) for the time since the last keyboard or
## mouse input. On other desktops the query fails and this sense stays silent.

const POLL_SECONDS := 5.0
const QUERY: PackedStringArray = [
	"call", "--session",
	"--dest", "org.gnome.Mutter.IdleMonitor",
	"--object-path", "/org/gnome/Mutter/IdleMonitor/Core",
	"--method", "org.gnome.Mutter.IdleMonitor.GetIdletime",
]

var _was_idle := false
var _thread: Thread
var _digits := RegEx.create_from_string("\\d+$")


func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = POLL_SECONDS
	timer.autostart = true
	timer.timeout.connect(_poll)
	add_child(timer)


func _exit_tree() -> void:
	if _thread:
		_thread.wait_to_finish()


# The query runs in a thread: OS.execute blocks, and a blocked frame freezes the pet.
func _poll() -> void:
	if _thread:
		if _thread.is_alive():
			return
		_thread.wait_to_finish()
	_thread = Thread.new()
	_thread.start(_query)


func _query() -> void:
	var output := []
	if OS.execute("gdbus", QUERY, output) != 0:
		return
	# Reply looks like "(uint64 1234,)".
	var found := _digits.search(str(output[0]).strip_edges().trim_suffix(",)"))
	if found:
		_report.call_deferred(found.get_string().to_int())


func _report(idle_ms: int) -> void:
	var idle: bool = idle_ms >= Settings.value("sleep", "idle_minutes") * 60_000.0
	if idle != _was_idle:
		_was_idle = idle
		Events.post(&"user_idle" if idle else &"user_active")
