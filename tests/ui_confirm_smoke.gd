extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func verify_confirmation(dialog: Control, cancel_label: String, description: String) -> void:
	check(dialog.visible, description + " opens")
	check(str(dialog.get("ok_button_text")) in ["Выйти", "Выйти без сохранения", "Начать заново"], description + " has a clear confirm action")
	check(str(dialog.get("cancel_button_text")) == cancel_label, description + " has a clear cancel action")
	var ok_button := dialog.call("get_ok_button") as Button
	var cancel_button := dialog.call("get_cancel_button") as Button
	check(ok_button != null and not ok_button.disabled, description + " confirm button is enabled")
	check(dialog.get_signal_connection_list("confirmed").size() == 1, description + " confirm action is wired")
	cancel_button.pressed.emit()
	await process_frame
	check(not dialog.visible, description + " closes on cancel")

func run() -> void:
	var menu: Node = load("res://MainMenu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu._exit_pressed()
	await verify_confirmation(menu.exit_confirmation, "Остаться", "Main menu exit confirmation")
	menu.queue_free()
	await process_frame
	var pause: Node = load("res://scripts/pause_menu.gd").new()
	root.add_child(pause)
	pause.open_pause()
	pause._exit_pressed()
	await verify_confirmation(pause.exit_confirmation, "Остаться", "Pause exit confirmation")
	root.get_tree().paused = false
	if failures > 0:
		quit(1)
		return
	print("PASS: Confirm action requests application exit")
	create_timer(1.0).timeout.connect(func():
		push_error("FAIL: Confirm action did not exit the application")
		quit(1)
	)
	pause._exit_pressed()
	pause.exit_confirmation.get_ok_button().pressed.emit()
