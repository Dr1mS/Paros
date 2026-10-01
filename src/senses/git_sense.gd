extends Node
## Posts: repo_state {session, branch, dirty, behind, conflict}, repo_cleaned
## {session}: a commit just left the working tree with nothing to commit.
##   branch: checked out branch, empty outside a git checkout.
##   dirty: lines added or removed and not committed.
##   behind: commits of the upstream branch missing here, as of the last fetch.
##   conflict: a merge or a rebase waits to be finished.
## Follows the folder of each Claude Code session. Runs git in a thread: it can
## take seconds in a large repository.

const POLL_SECONDS := 10.0
## In the .git folder while a merge, a rebase or a cherry-pick is not finished.
const UNFINISHED: Array[String] = ["MERGE_HEAD", "rebase-merge", "rebase-apply", "CHERRY_PICK_HEAD"]

## Session id -> folder.
var _folders := {}
## Session id -> last state posted.
var _states := {}
## Session id -> last commit seen. Not posted: it changes at each commit.
var _heads := {}
var _thread: Thread
var _numbers := RegEx.create_from_string("(\\d+) (insertion|deletion)")


func _ready() -> void:
	Events.sensed.connect(_on_sensed)
	var timer := Timer.new()
	timer.wait_time = POLL_SECONDS
	timer.autostart = true
	timer.timeout.connect(_poll)
	add_child(timer)


func _exit_tree() -> void:
	if _thread:
		_thread.wait_to_finish()


func _on_sensed(event: StringName, data: Dictionary) -> void:
	match event:
		&"session_opened", &"session_changed":
			if _folders.get(data.session) != data.cwd:
				_folders[data.session] = data.cwd
				_poll()
		&"session_closed":
			_folders.erase(data.session)
			_states.erase(data.session)
			_heads.erase(data.session)


func _poll() -> void:
	if _folders.is_empty() or not Settings.value("git", "enabled"):
		return
	if _thread:
		if _thread.is_alive():
			return
		_thread.wait_to_finish()
	_thread = Thread.new()
	_thread.start(_inspect_all.bind(_folders.duplicate()))


func _inspect_all(folders: Dictionary) -> void:
	for session: String in folders:
		_report.call_deferred(session, _inspect(folders[session]))


func _inspect(folder: String) -> Dictionary:
	var state := {"branch": "", "dirty": 0, "behind": 0, "conflict": false, "head": "", "clean": true}
	# --no-optional-locks: never hold the index lock against a git command of the user.
	var status := []
	if OS.execute("git", ["--no-optional-locks", "-C", folder, "status", "--porcelain=v2", "--branch"], status) != 0:
		return state
	for line in str(status[0]).split("\n"):
		if line.begins_with("# branch.oid "):
			state.head = line.trim_prefix("# branch.oid ")
		elif not line.is_empty() and not line.begins_with("#"):
			# One line per changed or untracked file.
			state.clean = false
		if line.begins_with("# branch.head "):
			state.branch = line.trim_prefix("# branch.head ").replace("(detached)", "")
		elif line.begins_with("# branch.ab "):
			# "# branch.ab +ahead -behind".
			state.behind = line.get_slice(" -", 1).to_int()
		elif line.begins_with("u "):
			state.conflict = true
	for marker in UNFINISHED:
		var path := folder.path_join(".git").path_join(marker)
		state.conflict = state.conflict or FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)

	var diff := []
	if OS.execute("git", ["--no-optional-locks", "-C", folder, "diff", "--shortstat", "HEAD"], diff) == 0:
		for found in _numbers.search_all(str(diff[0])):
			state.dirty += found.get_string(1).to_int()
	return state


func _report(session: String, state: Dictionary) -> void:
	if not _folders.has(session):
		return
	var head: String = state.head
	var clean: bool = state.clean
	state.erase("head")
	state.erase("clean")
	if clean and _heads.has(session) and head != _heads[session] and not head.is_empty():
		Events.post(&"repo_cleaned", {"session": session})
	_heads[session] = head
	if state != _states.get(session):
		_states[session] = state
		var data := state.duplicate()
		data.session = session
		Events.post(&"repo_state", data)
