class_name Desktop
## Actions on the desktop around Paros. Linux (GNOME extension, /proc, and a
## helper script that reads the terminals, see linux/paros-terminal.py) and
## Windows (helper script, see windows/paros-desktop.ps1).
## Without a display (headless run, as in the tests) the actions do nothing.

const HELPER_SCRIPT := "res://windows/paros-desktop.ps1"
const TERMINAL_SCRIPT := "res://linux/paros-terminal.py"
const TERMINAL_RETRY_SECONDS := 60.0
## The helper rewrites its files more often than this. Older: it is gone.
const STALE_SECONDS := 30.0

## Programs started and not yet seen finished.
static var _helpers: Array[int] = []
## Windows: pid -> [parent pid, creation time], read from the helper.
static var _processes := {}
static var _processes_read_at := -1.0
static var _processes_fresh := false
static var _requests := 0
## Linux: process of the helper that reads the terminals. 0: not started.
static var _terminal_helper := 0
## Time of its last start, in seconds. It is not started again sooner than
## TERMINAL_RETRY_SECONDS later: without python3-gi it ends at once.
static var _terminal_started_at := -INF


## Folder of the files shared with the hook script and the desktop helper: the
## runtime folder, else the temporary one (Windows has no XDG_RUNTIME_DIR).
static func runtime_dir() -> String:
	for variable: String in ["XDG_RUNTIME_DIR", "TEMP"]:
		if OS.has_environment(variable):
			return OS.get_environment(variable)
	return "/tmp"


static func home() -> String:
	return OS.get_environment("USERPROFILE" if OS.get_name() == "Windows" else "HOME")


## Windows: starts the helper that tells the desktop (focused window, idle time,
## media, battery) and does what Windows allows only from inside (raising a
## terminal). It ends when this app ends.
static func start_helper() -> void:
	if OS.get_name() != "Windows" or _is_headless():
		return
	var folder := runtime_dir().path_join("paros")
	DirAccess.make_dir_recursive_absolute(folder.path_join("requests"))
	# The script lives in the project, or in the exported package: a program cannot run it from there.
	var script := folder.path_join("paros-desktop.ps1")
	var file := FileAccess.open(script, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(FileAccess.get_file_as_string(HELPER_SCRIPT))
	file.close()
	start("powershell.exe", [
		"-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", script,
		"-ParentPid", str(OS.get_process_id()), "-Dir", folder,
	])


## File where the helper that reads the terminals tells which ones show the
## advisor at work.
static func advising_path() -> String:
	return runtime_dir().path_join("paros/advising.txt")


## Linux: starts, or stops, the helper that reads the visible text of the
## terminals to see a session ask its advisor. It ends when this app ends.
static func watch_terminals(on: bool) -> void:
	if OS.get_name() != "Linux" or _is_headless():
		return
	var running := _terminal_helper > 0 and OS.is_process_running(_terminal_helper)
	if on == running:
		return
	if not on:
		OS.kill(_terminal_helper)
		_terminal_helper = 0
		return
	if not may_start_terminal_helper(Time.get_ticks_msec() / 1000.0):
		return
	var folder := runtime_dir().path_join("paros")
	DirAccess.make_dir_recursive_absolute(folder)
	# As for the Windows helper: a program cannot run a script from the package.
	var script := folder.path_join("paros-terminal.py")
	var file := FileAccess.open(script, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(FileAccess.get_file_as_string(TERMINAL_SCRIPT))
	file.close()
	_terminal_helper = OS.create_process("python3", ["-I", script, "--parent", str(OS.get_process_id()), "--out", advising_path()])


## True when the helper that reads the terminals may be started at the given
## time, in seconds: not too soon after its last start. Notes that start.
static func may_start_terminal_helper(now: float) -> bool:
	if now - _terminal_started_at < TERMINAL_RETRY_SECONDS:
		return false
	_terminal_started_at = now
	return true


## Windows: what the helper last wrote about the desktop. Empty without helper.
static func windows_state() -> Dictionary:
	var path := runtime_dir().path_join("paros/desktop.json")
	if Time.get_unix_time_from_system() - FileAccess.get_modified_time(path) >= STALE_SECONDS:
		return {}
	var text := FileAccess.get_file_as_string(path)
	var state: Variant = JSON.parse_string(text) if not text.is_empty() else null
	return state if state is Dictionary else {}


## Windows: the processes known to the helper, pid (as text) -> [parent pid,
## creation time as text]. Empty when the helper does not run (yet): callers
## must then assume nothing. Read at most once a second.
static func processes() -> Dictionary:
	var now := Time.get_ticks_msec() / 1000.0
	if _processes_read_at >= 0.0 and now - _processes_read_at < 1.0:
		return _processes if _processes_fresh else {}
	_processes_read_at = now
	var path := runtime_dir().path_join("paros/processes.json")
	# Not there yet while the helper starts: no error, nothing known.
	var text := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
	_processes_fresh = parsed is Dictionary and Time.get_unix_time_from_system() - float(parsed.get("updated", 0)) < STALE_SECONDS
	if _processes_fresh:
		_processes = parsed.get("processes", {})
	return _processes if _processes_fresh else {}


## Does the process of a session still run? A crashed session leaves its
## registry file behind. created: the "procStart" of that file, the creation
## time of the process: the same number with another process means the pid was reused.
static func is_process_running(pid: int, created := "") -> bool:
	match OS.get_name():
		"Linux":
			return DirAccess.dir_exists_absolute("/proc/%d" % pid)
		"Windows":
			var known := processes()
			if known.is_empty():
				return true
			var entry: Variant = known.get(str(pid))
			return entry != null and (created.is_empty() or str(entry[1]) == "0" or str(entry[1]) == created)
	return true


## Asks the helper for something. One file per request, written then renamed
## so that the helper never reads half of it.
static func _request(fields: PackedStringArray) -> void:
	var folder := runtime_dir().path_join("paros/requests")
	_requests += 1
	var name := "%d-%d" % [Time.get_ticks_usec(), _requests]
	var file := FileAccess.open(folder.path_join(name + ".part"), FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\t".join(fields))
	file.close()
	DirAccess.rename_absolute(folder.path_join(name + ".part"), folder.path_join(name + ".txt"))


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
	if OS.get_name() == "Windows":
		# The helper raises the window, and the tab when the terminal has tabs.
		_request(["focus", str(pid), ",".join(PackedStringArray(Array(lineage(pid)).map(func(ancestor: int) -> String: return str(ancestor)))), title])
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
	if _is_headless() or pid <= 0:
		return
	if OS.get_name() == "Windows":
		_request(["ring", str(pid)])
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
	if OS.get_name() == "Windows":
		var entry: Variant = processes().get(str(pid))
		return int(entry[0]) if entry != null else 0
	# "pid (name) state ppid ...": the name may hold spaces, so split after it.
	var stat := read_kernel_file("/proc/%d/stat" % pid)
	var after_name := stat.substr(stat.rfind(")") + 2).split(" ")
	return after_name[1].to_int() if after_name.size() > 1 else 0
