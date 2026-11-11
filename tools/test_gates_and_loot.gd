extends "res://tools/test_intro.gd"

func run() -> void:
	for number in [3, 4]:
		if is_instance_valid(level):
			level.queue_free()
			await frames(2)
		level = load("res://scenes/levels/level_%02d.tscn" % number).instantiate()
		root.add_child(level)
		current_scene = level
		await frames(3)
		level.finish_dialogue()
		for guard in level.guards():
			guard.set_physics_process(false)
		if number == 3:
			var gate = level.get_node("Gates").get_child(0)
			var west: Vector2 = gate.position + Vector2(-36, 0)
			var east: Vector2 = gate.position + Vector2(36, 0)
			check(not gate.is_open and not level.clear_sight(west, east), "Floor %d seal physically blocks passage" % number)
			level.player.position = level.areas.get_node("RemoteTerminal").position + Vector2(0, 8)
			level.interact()
			level.world_features.submit_password("root")
			await frames(65)
			level.finish_dialogue()
			await frames(2)
			check(gate.is_open and level.clear_sight(west, east), "Floor %d release clears collision" % number)
			level.player.position = Vector2(west.x, gate.position.y + gate.gate_size.y / 2 - 14)
			check(await move_to(east.x, 300, false), "Player crosses opened seal")
		else:
			check(level.get_node("Gates").get_child_count() == 0, "Floor 4 has no checkpoint gate")
	# Later-floor loot uses the same limited ammunition/noise rules as the intro.
	var guard = level.guards()[0]
	guard.position = Vector2(900, 430)
	guard.die()
	level.player.position = Vector2(900, 430)
	level.interact()
	check(level.player.has_gun and level.player.ammunition == 3, "Fallen Keeper provides a weapon and three rounds")
	level.interact()
	check(level.player.ammunition == 3, "Loot cannot be duplicated")
	# Once a corpse is empty, E may enter an adjacent hiding prop. Exit before firing.
	if level.player.in_hiding_spot:
		level.interact()
	level.player.fire_gun()
	check(level.player.ammunition == 2, "Shot consumes one round")
	print("GATES_LOOT_RESULT: ", checks - failures.size(), "/", checks, " passed")
	quit(0 if failures.is_empty() else 1)
