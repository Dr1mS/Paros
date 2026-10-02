class_name Desktop
## Actions on the desktop around Paros. Linux only.
## Without a display (headless run, as in the tests) the actions do nothing.


## Programs started and not yet seen finished.
static var _helpers: Array[int] = []


## Starts a program without waiting for it.
static func start(program: String, arguments: PackedStringArray) -> void:
	# Asking whether a finished program still runs lets the system forget it.
	# Without that, each one stays as a zombie until the app closes.
	_helpers = _helpers.filter(func(pid: int) -> bool: return OS.is_process_running(pid))
	var pid := OS.create_process(program, arguments)
	if pid > 0:
		_helpers.append(pid)


## Turns the monitors on, or off (power saving). GNOME turns them off as soon
## as the screen is locked: this is how to get them back.
static func set_screen_power(on: bool) -> void:
	if _is_headless():
		return
	start("gdbus", [
		"call", "--session", "--dest", "org.gnome.Mutter.DisplayConfig", "--object-path", "/org/gnome/Mutter/DisplayConfig",
		"--method", "org.freedesktop.DBus.Properties.Set", "org.gnome.Mutter.DisplayConfig", "PowerSaveMode",
		"<int32 %d>" % (0 if on else 3),
	])


## Brings the terminal of a process to the front. Needs the Paros GNOME Shell
## extension: alone, an application cannot raise another window under Wayland.
## The window is found by the process and its ancestors, then by its title.
static func focus_terminal(pid: int, title: String) -> void:
	if _is_headless():
		return
	start("gdbus", [
		"call", "--session", "--dest", "org.gnome.Shell", "--object-path", "/org/paros/Desktop",
		"--method", "org.paros.Desktop.Activate", str(lineage(pid)), title,
	])


## The process, then its parent, and so on up. The terminal window of a
## session belongs to one of them.
static func lineage(pid: int) -> Array[int]:
	var pids: Array[int] = []
	while pid > 1 and pids.size() < 16:
		pids.append(pid)
		pid = _parent(pid)
	return pids


## Screen that holds the point, in screen coordinates.
static func screen_at(point: Vector2) -> Rect2:
	for screen in DisplayServer.get_screen_count():
		var rect := Rect2(DisplayServer.screen_get_position(screen), DisplayServer.screen_get_size(screen))
		if rect.has_point(point):
			return rect
	return Rect2()


## Rings the bell of the terminal that runs a process: its tab gets a mark.
static func ring_terminal(pid: int) -> void:
	if _is_headless():
		return
	var terminal := FileAccess.open("/proc/%d/fd/0" % pid, FileAccess.WRITE)
	if terminal:
		terminal.store_string("\a")


## Text of a /proc or /sys file. These files announce a size that is not
## theirs (0, or a whole page), so reading "the whole file" returns nothing or
## adds garbage: ask for a fixed amount and keep what comes.
static func read_kernel_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_buffer(4096).get_string_from_utf8() if file else ""


static func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


static func _parent(pid: int) -> int:
	# "pid (name) state ppid ...": the name may hold spaces, so split after it.
	var stat := read_kernel_file("/proc/%d/stat" % pid)
	var after_name := stat.substr(stat.rfind(")") + 2).split(" ")
	return after_name[1].to_int() if after_name.size() > 1 else 0
