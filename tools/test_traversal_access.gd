extends "res://tools/test_intro.gd"
func run() -> void:
	await fresh()
	await supplies()
	for guard in level.guards():
		guard.set_physics_process(false)
	var p = level.player
	p.position = Vector2(100, 656)
	await frames(5)
	var start: float = p.position.y
	var peak := start
	Input.action_press("jump")
	await frames(1)
	Input.action_release("jump")
	for tick in range(60):
		peak = minf(peak, p.position.y)
		if p.jumps_used == 1 and p.velocity.y >= -850.0 / 60.0:
			Input.action_press("jump")
			await frames(1)
			Input.action_release("jump")
		await frames(1)
	var height := start - peak
	print("COMBINED_JUMP_HEIGHT: ", height)
	check(absf(height - 65.17) < 0.15, "Two apex-timed jumps together match Fran's 65.17px reference")
	check(p.jumps_used <= 2, "Jump count never exceeds two")
	var traps = level.world_features.trapdoors
	check(traps.size() > 0, "Orange connector tiles become trapdoors")
	var trap = traps[1]
	p.position = trap.position + Vector2(0, -28)
	level.interact()
	await frames(2)
	check(trap.is_open and trap.collision.disabled, "Opening removes collision")
	var remaining: float = trap.open_left
	level.paused = true
	await frames(40)
	check(is_equal_approx(trap.open_left, remaining), "Pause freezes trapdoor countdown")
	level.paused = false
	p.set_physics_process(false)
	p.position = trap.position
	await frames(310)
	check(trap.is_open and trap.open_left == 0, "Occupied opening remains open after five seconds")
	p.position = Vector2(100, 656)
	await frames(3)
	check(not trap.is_open and not trap.collision.disabled, "Trapdoor closes after occupant clears opening")
	trap.activate()
	await frames(290)
	check(trap.is_open, "Unoccupied hatch stays open for the full five-second window")
	await frames(15)
	check(not trap.is_open, "Unoccupied hatch automatically closes after five seconds")
	for number in range(1, 6):
		level.queue_free()
		await frames(2)
		var path := "res://scenes/intro.tscn" if number == 1 else "res://scenes/levels/level_%02d.tscn" % number
		level = load(path).instantiate()
		root.add_child(level)
		current_scene = level
		await frames(5)
		level.finish_dialogue()
		for guard in level.guards():
			guard.set_physics_process(false)
		var world = level.world_features
		var clean := true
		for prop in world.props:
			clean = clean and world.placement_clear(prop.position)
			clean = clean and level.has_floor_below(prop.position + Vector2(0, 13))
		check(clean, "Floor %d crates, hides and service ports have clear standing space and ladder clearance" % number)
		var markers_clear := true
		for area in level.areas.get_children():
			if area.kind in ["note", "sigil"]:
				if not world.placement_clear(area.position):
					print("BLOCKED_MARKER: ", number, " ", area.name, " ", area.position)
				markers_clear = markers_clear and world.placement_clear(area.position)
		check(markers_clear, "Floor %d terminal, note and charge markers are outside solid tiles" % number)
		var separate := true
		for hatch in world.trapdoors:
			for area in level.areas.get_children():
				if area.kind == "ladder":
					separate = separate and not Rect2(area.position - area.area_size / 2, area.area_size).grow(18).intersects(Rect2(hatch.position - Vector2(14, 14), Vector2(28, 28)))
		check(separate, "Floor %d trapdoors do not overlap ladder corridors" % number)
		for ladder_name in ["FirstLadder", "SecondLadder"]:
			var ladder = level.areas.get_node(ladder_name)
			level.player.position = Vector2(ladder.position.x, 432 if ladder_name == "FirstLadder" else 656)
			level.player.velocity = Vector2.ZERO
			await frames(3)
			Input.action_press("climb_up")
			await frames(190 if ladder_name == "FirstLadder" else 220)
			Input.action_press("move_right")
			await frames(35)
			Input.action_release("climb_up")
			Input.action_release("move_right")
			await frames(30)
			var ceiling := 260 if ladder_name == "FirstLadder" else 460
			check(level.player.position.y < ceiling and level.player.is_on_floor(), "Floor %d %s can be climbed upward and exited onto its landing" % [number, ladder_name])
		if number in [3, 4]:
			var hatch = world.trapdoors[0]
			for candidate in world.trapdoors:
				if is_instance_valid(candidate.route_gate):
					hatch = candidate
			hatch.activate()
			check(not hatch.is_open, "Floor %d hatch cannot strand player behind a locked story gate" % number)
			hatch.route_gate.unlock()
			hatch.activate()
			check(hatch.is_open, "Floor %d hatch unlocks once its return route is open" % number)
		if number == 3:
			level.player.position = Vector2(300, 232)
			level.interact()
			check(world.password_panel.visible, "Terminal wins E interaction over adjacent trapdoor")
			world.password_panel.hide()
	print("TRAVERSAL_ACCESS_RESULT: ", checks - failures.size(), "/", checks, " passed")
	quit(0 if failures.is_empty() else 1)
