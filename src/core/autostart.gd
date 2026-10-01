class_name Autostart
## Launch at login. Linux: an XDG .desktop file in ~/.config/autostart.
## Windows: a .cmd file in the Startup folder.


static func is_supported() -> bool:
	return OS.get_name() in ["Linux", "Windows"]


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
	if file == null:
		return
	if OS.get_name() == "Windows":
		file.store_string('start "" %s\r\n' % command)
	else:
		file.store_string("[Desktop Entry]\nType=Application\nName=Paros\nExec=%s\n" % command)


static func _path() -> String:
	if OS.get_name() == "Windows":
		return OS.get_environment("APPDATA").path_join("Microsoft/Windows/Start Menu/Programs/Startup/paros.cmd")
	var config := OS.get_environment("XDG_CONFIG_HOME")
	if config.is_empty():
		config = OS.get_environment("HOME").path_join(".config")
	return config.path_join("autostart/paros.desktop")
