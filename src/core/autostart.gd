class_name Autostart
## Launch at login on Linux: an XDG .desktop file in ~/.config/autostart.


static func is_supported() -> bool:
	return OS.get_name() == "Linux"


static func is_enabled() -> bool:
	return FileAccess.file_exists(_path())


static func set_enabled(enabled: bool) -> void:
	if not enabled:
		DirAccess.remove_absolute(_path())
		return
	var command := '"%s"' % OS.get_executable_path()
	# Not an exported build: the executable is Godot itself, it needs the project path.
	if OS.has_feature("editor"):
		command += ' --path "%s"' % ProjectSettings.globalize_path("res://")
	DirAccess.make_dir_recursive_absolute(_path().get_base_dir())
	var file := FileAccess.open(_path(), FileAccess.WRITE)
	if file:
		file.store_string("[Desktop Entry]\nType=Application\nName=Paros\nExec=%s\n" % command)


static func _path() -> String:
	var config := OS.get_environment("XDG_CONFIG_HOME")
	if config.is_empty():
		config = OS.get_environment("HOME").path_join(".config")
	return config.path_join("autostart/paros.desktop")
