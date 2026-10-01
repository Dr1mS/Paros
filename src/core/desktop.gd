class_name Desktop
## Actions on the desktop around Paros. Linux only.


## Brings the terminal of a process to the front. Needs the Paros GNOME Shell
## extension: alone, an application cannot raise another window under Wayland.
## The window is found by the process and its ancestors, then by its title.
static func focus_terminal(pid: int, title: String) -> void:
	var pids: PackedStringArray = []
	while pid > 1 and pids.size() < 16:
		pids.append(str(pid))
		pid = _parent(pid)
	OS.create_process("gdbus", [
		"call", "--session", "--dest", "org.gnome.Shell", "--object-path", "/org/paros/Desktop",
		"--method", "org.paros.Desktop.Activate", "[%s]" % ", ".join(pids), title,
	])


## Rings the bell of the terminal that runs a process: its tab gets a mark.
static func ring_terminal(pid: int) -> void:
	var terminal := FileAccess.open("/proc/%d/fd/0" % pid, FileAccess.WRITE)
	if terminal:
		terminal.store_string("\a")


static func _parent(pid: int) -> int:
	# "pid (name) state ppid ...": the name may hold spaces, so split after it.
	var stat := FileAccess.get_file_as_string("/proc/%d/stat" % pid)
	var after_name := stat.substr(stat.rfind(")") + 2).split(" ")
	return after_name[1].to_int() if after_name.size() > 1 else 0
