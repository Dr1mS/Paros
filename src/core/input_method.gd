extends Node
## Keeps the X11 input method server (ibus, fcitx) out of the app.
##
## With such a server, destroying a window makes Xlib wait for an answer of the
## server (XDestroyIC). That answer can get lost, and the app then freezes for
## good. It happened when a pet window was removed.
## XMODIFIERS=@im=none makes Xlib use its built-in input method, with no server
## and no waiting. The app needs no more: its only text fields hold numbers.
##
## The variable is read when the display opens, before any script runs. So when
## it is not set, the app starts itself again with it, and leaves.
## run.sh and the autostart entry set it themselves: no restart then.

const VARIABLE := "XMODIFIERS"
const WITHOUT_SERVER := "@im=none"
## Set on the second start, so that the app never restarts in a loop.
const RESTARTED := "PAROS_RESTARTED"

## True in a first start that only hands over to its copy.
var leaving := false


func _init() -> void:
	if not needs_restart(DisplayServer.get_name(), OS.get_environment(VARIABLE), OS.has_environment(RESTARTED)):
		return
	OS.set_environment(VARIABLE, WITHOUT_SERVER)
	OS.set_environment(RESTARTED, "1")
	var arguments := OS.get_cmdline_args()
	if not OS.get_cmdline_user_args().is_empty():
		arguments.append("--")
		arguments.append_array(OS.get_cmdline_user_args())
	if OS.create_process(OS.get_executable_path(), arguments) > 0:
		leaving = true
		Engine.get_main_loop().quit()


static func needs_restart(display: String, modifiers: String, restarted: bool) -> bool:
	return display == "X11" and modifiers != WITHOUT_SERVER and not restarted
