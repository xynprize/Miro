extends "res://tools/test_intro.gd"
func run() -> void:
	await fresh()
	await supplies()
	var keeper = level.guards()[0]
	keeper.set_physics_process(false)
	keeper.die()
	level.player.position = keeper.position
	level.interact()
	check(level.player.controls.has_remote, "First Keeper corpse supplies remote")
	for number in [2, 3]:
		level.queue_free()
		await frames(2)
		level = load("res://scenes/levels/level_%02d.tscn" % number).instantiate()
		root.add_child(level)
		current_scene = level
		await frames(4)
		level.finish_dialogue()
		for guard in level.guards():
			guard.set_physics_process(false)
		var c = level.player.controls
		check(c.has_remote, "Remote ownership follows Miro to floor %d" % number)
		c.open_remote()
		c.run_command("hack")
		c.run_command("cameras off")
		check(level.hack_remaining == 0, "Remote cannot bypass local range or authentication")
		level.player.position = level.world_features.access_point if number == 2 else Vector2(300, 232)
		c.run_command("scan")
		check("local" in c.output.text, "Nearby access point is discoverable")
		c.run_command("login wrong")
		check("denied" in c.output.text, "Wrong password is rejected")
		c.run_command("login root")
		c.run_command("cameras off")
		if number == 2:
			check(not level.world_features.practice_camera.is_active and level.milestones.is_empty(), "Optional floor 2 hack disables camera without completing story objectives")
		else:
			await frames(65)
			level.finish_dialogue()
			check(level.milestones.has("RemoteTerminal") and level.connected_cameras.all(func(camera): return not camera.is_active), "Remote completes required floor 3 checkpoint through existing hack sequence")
	print("REMOTE_RESULT: ", checks - failures.size(), "/", checks, " passed")
	quit(0 if failures.is_empty() else 1)
