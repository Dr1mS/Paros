class_name Desktop
## Actions on the desktop around Paros. Linux only.


## Brings the terminal of a process to the front. Needs the Paros GNOME Shell
## extension: alone, an application cannot raise another window under Wayland.
## The window is found by the process and its ancestors, then by its title.
static func focus_terminal(pid: int, title: String) -> void:
	OS.create_process("gdbus", [
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
	var terminal := FileAccess.open("/proc/%d/fd/0" % pid, FileAccess.WRITE)
	if terminal:
		terminal.store_string("\a")


## Text of a /proc file. These files announce a size of 0, so reading "the
## whole file" returns nothing: ask for a fixed amount instead.
static func read_proc(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_buffer(4096).get_string_from_utf8() if file else ""


static func _parent(pid: int) -> int:
	# "pid (name) state ppid ...": the name may hold spaces, so split after it.
	var stat := read_proc("/proc/%d/stat" % pid)
	var after_name := stat.substr(stat.rfind(")") + 2).split(" ")
	return after_name[1].to_int() if after_name.size() > 1 else 0
