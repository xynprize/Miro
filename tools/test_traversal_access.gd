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
	while not p.is_on_floor():
		await frames(1)
	Input.action_press("jump")
	await frames(1)
	Input.action_release("jump")
	await frames(3)
	check(p.jumps_used == 1 and p.velocity.y < 0, "Ground jump still works during cooldown")
	Input.action_press("jump")
	await frames(1)
	Input.action_release("jump")
	check(p.jumps_used == 1 and p.double_jump_cooldown_left > 0, "Landing doesn't reset double jump cooldown")
	await frames(180)
	check(is_zero_approx(p.double_jump_cooldown_left), "Double jump recharges within three seconds")
	Input.action_press("jump")
	await frames(1)
	Input.action_release("jump")
	await frames(3)
	Input.action_press("jump")
	await frames(1)
	Input.action_release("jump")
	check(p.jumps_used == 2 and p.double_jump_cooldown_left > 2.95, "Second jump works after recharge and starts a three-second cooldown")
	# Use a real collision with the left wall, with the double jump still recharging.
	p.position = Vector2(43, 540)
	p.velocity = Vector2(0, 120)
	Input.action_press("move_left")
	for tick in range(20):
		await frames(1)
		if p.wall_sliding:
			break
	check(p.wall_sliding and p.velocity.y <= p.WALL_SLIDE_SPEED, "Holding toward a wall caps falling speed")
	var cooldown: float = p.double_jump_cooldown_left
	var before_bounce: float = p.position.x
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	check(p.position.x > before_bounce and p.velocity.y < 0 and not p.wall_sliding, "Timed Space launches Miro away from the wall")
	check(p.double_jump_cooldown_left > 0 and p.double_jump_cooldown_left < cooldown, "Wall jump does not consume or reset the double jump cooldown")
	Input.action_release("move_left")
	await frames(45)
	p.position = Vector2(43, 490)
	p.velocity = Vector2(0, 120)
	Input.action_press("move_left")
	await frames(27)
	check(p.wall_sliding and is_zero_approx(p.wall_jump_window_left), "Holding against a wall does not refresh the bounce window")
	Input.action_release("move_left")
	await frames(2)
	check(not p.wall_sliding and p.velocity.y > p.WALL_SLIDE_SPEED, "Letting go restores normal falling speed")
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
		for extra_guard in level.get_node("Guards").get_children():
			if str(extra_guard.name).begins_with("TerminalGuard"):
				extra_guard.set_physics_process(false)  # these tests probe routes, not the terminal posts
		for keeper in ["CraneKeeper", "StroudKeeper", "ThaneKeeper", "HoltKeeper", "LedgeKeeper", "VaultKeeper"]:
			var extra = level.get_node_or_null("Guards/" + keeper)
			if extra != null:
				extra.set_physics_process(false)  # these tests probe ladders, not patrols
		current_scene = level
		await frames(5)
		level.finish_dialogue()
		level.brother_heard = true  # the gate scene plays on its own near the gate; this test only probes geometry
		if number == 2:
			level.milestones["BrotherOffer"] = true  # the offer plays on its own near that spot
		for guard in level.guards():
			guard.set_physics_process(false)
		# This probes ladder geometry independently of the combat tests.
		for hazard in get_nodes_in_group("tower_turrets"):
			if level.is_ancestor_of(hazard):hazard.set_physics_process(false)
		var world = level.world_features
		var clean := true
		for prop in world.props:
			if prop.get_meta("lab_flask", false) or prop.get_meta("lab_bottle",false):continue # Table surface supports these collectibles.
			if not world.placement_clear(prop.position) or not level.has_floor_below(prop.position+Vector2(0,13)):print("BLOCKED_PROP: ",number," ",prop.kind," ",prop.position)
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
		if number == 5:
			# The Foundation's hatches open as Niro retreats; climbing back up uses the opened route.
			for gate in level.get_node("Gates").get_children():
				gate.unlock()
			await frames(2)
		var authored: bool = number in [2, 3, 4]
		if authored:
			# Every ladder on an authored floor can be climbed back up and stepped off at the top.
			for ladder in level.areas.get_children():
				if ladder.kind != "ladder":
					continue
				var top: float = ladder.position.y - ladder.area_size.y / 2 + 4 + 28
				var bottom: float = ladder.position.y + ladder.area_size.y / 2 - 2
				level.player.position = Vector2(ladder.position.x, bottom - 14)
				level.player.velocity = Vector2.ZERO
				await frames(3)
				Input.action_press("climb_up")
				await frames(int((bottom - top) / 85.0 * 60) + 40)
				var toward := "move_right" if ladder.position.x < level.definition.world_size[0] / 2 else "move_left"
				Input.action_press(toward)
				await frames(35)
				Input.action_release("climb_up")
				Input.action_release(toward)
				await frames(30)
				if not (level.player.position.y < top and level.player.is_on_floor()):print("LADDER_FAILURE_STATE ",number," ",ladder.name," pos=",level.player.position," health=",level.player.health," dead=",level.player.is_dead," locked=",level.controls_locked())
				check(level.player.position.y < top and level.player.is_on_floor(), "Floor %d %s can be climbed upward and exited onto its landing" % [number, ladder.name])
			for hatch in world.trapdoors:
				check(not is_instance_valid(hatch.route_gate), "Floor %d hatches are placed so they never drop Miro past a locked gate" % number)
		for ladder_name in ([] if authored else ["FirstLadder", "SecondLadder"]):
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
		if number == 3:
			var terminal = level.areas.get_node("RemoteTerminal")
			level.player.position = terminal.position + Vector2(0, 2)
			level.interact()
			if not world.password_panel.visible:print("TERMINAL_FAILURE_STATE dead=",level.player.is_dead," pos=",level.player.position," strangle=",world.strangle_active()," hint=",world.hint())
			check(world.password_panel.visible, "Terminal wins E interaction over adjacent trapdoor")
			world.password_panel.hide()
	print("TRAVERSAL_ACCESS_RESULT: ", checks - failures.size(), "/", checks, " passed")
	quit(0 if failures.is_empty() else 1)
