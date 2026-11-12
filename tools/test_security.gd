extends "res://tools/test_intro.gd"

func run() -> void:
	level = load("res://scenes/levels/level_03.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(3)
	level.finish_dialogue()
	level.player.end_stealth()
	var camera = level.connected_cameras[0]
	var terminal: Vector2 = level.areas.get_node("RemoteTerminal").position
	var at_terminal := terminal + Vector2(0, 8)
	camera.set_physics_process(false)
	camera.facing_angle = 1.57
	camera.position = terminal + Vector2(0, -50)
	camera.sweep_time = 0
	level.player.position = at_terminal
	check(camera.detects_player(), "Camera detects exposed player inside cone")
	level.player.is_concealed = true
	check(not camera.detects_player(), "Blanket concealment blocks detection")
	level.player.is_concealed = false
	level.player.position = terminal + Vector2(-200, -50)
	check(not camera.detects_player(), "Outside cone is safe")
	level.player.position = terminal + Vector2(0, 50)
	check(not camera.detects_player(), "Stone floor occludes camera")
	level.player.position = at_terminal
	var original_count: int = level.guards().size()
	camera._physics_process(1.0 / 60.0)
	check(level.guards().size() == original_count + 2, "Watcher detection calls two reserves")
	check(level.floor_alerts == 1, "Detection raises floor alert")
	var responders: Array = level.guards().filter(func(guard): return guard.alert_state == IntroGuard.State.SEARCH and guard.pursuing)
	check(responders.size() == 1, "Watcher alert calls reserves and assigns a single investigator")
	for guard in level.guards():
		guard.set_physics_process(false)
	level.camera_alert(level.player.position)
	check(level.guards().size() == original_count + 2, "Repeated sighting does not duplicate the reserve squad")
	level.interact()
	check(level.world_features.modal_open(), "Terminal requests a password")
	level.world_features.submit_password("wrong")
	check(level.hack_remaining == 0, "Wrong password cannot start hack")
	level.world_features.submit_password("root")
	await frames(25)
	check(camera.is_active and not level.milestones.has("RemoteTerminal"), "Hack cannot finish early")
	level.paused = true
	var remaining: float = level.hack_remaining
	await frames(70)
	check(is_equal_approx(remaining, level.hack_remaining), "Pause freezes hack timer")
	level.paused = false
	level.player.position = at_terminal + Vector2(-200, 0)
	await frames(2)
	check(level.hack_remaining == 0 and camera.is_active, "Leaving terminal cancels hack")
	level.player.position = at_terminal
	level.interact()
	await frames(65)
	var terminal_storey: int = level.world_features.security_storey(terminal.y)
	var on_storey := 0
	var elsewhere_active := 0
	for linked in level.connected_cameras:
		if level.world_features.security_storey(linked.global_position.y) == terminal_storey:
			on_storey += 1
			check(not linked.is_active, "Completed hack disables camera on the terminal's storey")
		elif linked.is_active:
			elsewhere_active += 1
	check(on_storey > 0 and elsewhere_active > 0, "Hack affects its storey and leaves other storeys active")
	level.finish_dialogue()
	check(level.milestones.has("RemoteTerminal"), "Skipping completion dialogue preserves hack")
	check(not camera.detects_player(), "Disabled camera cannot detect")
	level.queue_free()
	await frames(2)
	level = load("res://scenes/levels/level_03.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(2)
	check(level.connected_cameras[0].is_active and level.milestones.is_empty(), "Reload restores checkpoint")
	print("SECURITY_RESULT: ", checks - failures.size(), "/", checks, " passed")
	quit(0 if failures.is_empty() else 1)
