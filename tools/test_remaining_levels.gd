extends "res://tools/test_intro.gd"

func run() -> void:
	for number in range(2, 6):
		if is_instance_valid(level):
			level.queue_free()
			await frames(2)
		level = load("res://scenes/levels/level_%02d.tscn" % number).instantiate()
		root.add_child(level)
		current_scene = level
		await frames(3)
		level.finish_dialogue()
		var definition: Dictionary = level.definition
		check(definition.sources.size() >= 5, "Level %d has per-document references" % number)
		for source in definition.sources:
			check(FileAccess.file_exists("res://" + source.path), "Source exists: " + source.path)
		for station in definition.stations:
			if level.milestones.has(station.id):
				continue
			var point := Vector2(station.position[0], station.position[1])
			if point.y > 300 and level.player.position.y < 300:
				var ladder = level.get_node("Interactables/FirstLadder")
				check(await move_to(ladder.position.x, 800, true), "Level %d reaches first ladder" % number)
				Input.action_press("climb_down")
				await frames(170)
				Input.action_release("climb_down")
				check(level.player.position.y > 410, "Level %d descends first tier" % number)
			if point.y >= 550 and level.player.position.y < 550:
				check(await move_to(308, 800, true), "Level %d reaches second ladder" % number)
				Input.action_press("climb_down")
				await frames(190)
				Input.action_release("climb_down")
				check(level.player.position.y > 640, "Level %d reaches lower tier" % number)
			check(await move_to(point.x, 800, true), "Reach " + station.id)
			await frames(10)
			level.interact()
			if station.id == "RemoteTerminal":
				level.world_features.submit_password("root")
				await frames(65)
			if station.id == "BrotherEncounter":
				await fight_brother()
			if station.id == "ForestViewpoint":
				check(is_instance_valid(level.cinematic), "Forest viewpoint starts cinematic")
				level.cinematic.finish()
				check(level.completed and level.milestones.has("ForestViewpoint"), "Skip ending applies completion")
				continue
			check(not level.dialogue.is_empty(), "Open " + station.id)
			level.finish_dialogue()
			check(level.milestones.has(station.id), "Complete/skip " + station.id)
			var charges: int = level.player.c4_count
			level.interact()
			check(level.dialogue.is_empty() and level.player.c4_count == charges, "No duplicate " + station.id)
		check(level.sigil_placed, "Level %d requires its own sigil" % number)
		if number < 5:
			check(await move_to(1030, 800, true), "Level %d reaches exit" % number)
			level.interact()
		check(level.completed and not level.player.is_dead, "Level %d scaffold traversed alive" % number)
	print("REMAINING_LEVELS_RESULT: ", checks - failures.size(), "/", checks, " passed")
	quit(0 if failures.is_empty() else 1)

func fight_brother() -> void:
	var boss = level.brother
	for tick in range(2400):
		if boss.is_dead or level.player.is_dead:
			break
		var offset: float = boss.position.x - level.player.position.x
		Input.action_release("move_left")
		Input.action_release("move_right")
		if boss.is_vulnerable:
			if absf(offset) > 32:
				Input.action_press("move_right" if offset > 0 else "move_left")
			level.player.facing = signf(offset)
			level.player.shank()
		else:
			if absf(offset) < 75:
				Input.action_press("move_left" if offset > 0 else "move_right")
			if boss.current_phase == boss.Phase.RUSH and absf(offset) < 80:
				Input.action_press("jump")
		if boss.projectile_live and boss.projectile.distance_to(level.player.position) < 100:
			Input.action_press("jump")
		await frames(1)
		Input.action_release("jump")
	Input.action_release("move_left")
	Input.action_release("move_right")
	check(boss.is_dead and not level.player.is_dead, "Defeat brother using movement and shank")
