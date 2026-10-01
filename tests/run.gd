extends Node
## Runs every test file of this folder (test_*.gd), prints the result, and
## quits with status 1 when a test fails. Started by test.sh.

const FOLDER := "res://tests"


func _ready() -> void:
	# The texts checked by the tests are the English ones, whatever the system.
	Settings.set_value("interface", "language", "en")
	var failed := 0
	var passed := 0
	var files := Array(DirAccess.get_files_at(FOLDER)).filter(func(file: String) -> bool:
		return file.begins_with("test_") and file.ends_with(".gd") and file != "test_case.gd")
	files.sort()
	# A name given after "--" runs that file alone.
	var only := OS.get_cmdline_user_args()
	for file: String in files:
		if not only.is_empty() and file.get_basename() not in only:
			continue
		var script: GDScript = load(FOLDER.path_join(file))
		var names := script.get_script_method_list().map(func(method: Dictionary) -> String: return method.name)
		for test: String in names.filter(func(method: String) -> bool: return method.begins_with("test_")):
			# A new instance per test: no test sees what another one left.
			var case: Node = script.new()
			add_child(case)
			seed(1)
			case.before_each()
			await case.call(test)
			case.after_each()
			if case.failures.is_empty():
				passed += 1
			else:
				failed += 1
				print("FAIL  %s  %s" % [file.get_basename(), test])
				for failure: String in case.failures:
					print("        ", failure)
			case.free()
	# Lets the nodes queued for deletion go before leaving.
	for i in 3:
		await get_tree().process_frame
	print("%d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
