extends SceneTree
var level
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func fresh() -> void:
	for action in InputMap.get_actions():
		Input.action_release(action)
	if is_instance_valid(level):
		level.queue_free()
		await frames(2)
	level = load("res://scenes/intro.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(3)

func supplies() -> void:
	level.finish_dialogue()
	level.interact()
	level.finish_dialogue()
	await frames(3)

func move_to(x: float, limit: int = 500, fight: bool = false) -> bool:
	var p = level.player
	var count := 0
	while absf(p.position.x - x) > 5 and count < limit and not p.is_dead:
		var right: bool = x > p.position.x
		Input.action_press("move_right" if right else "move_left")
		Input.action_release("move_left" if right else "move_right")
		if (p.is_on_wall() and p.is_on_floor()) or (p.is_on_wall() and not p.is_on_floor() and p.jumps_used == 1 and p.velocity.y > -20):
			Input.action_press("jump")
		else:
			Input.action_release("jump")
		if fight:
			for g in level.guards():
				if not g.is_dead and p.position.distance_to(g.position) < 44:
					p.facing = signf(g.position.x - p.position.x)
					p.shank()
		await frames(1)
		count += 1
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("jump")
	for i in range(40):
		if p.is_on_floor() or p.climbing:
			break
		await frames(1)
	await frames(2)
	print("MOVE target=", x, " actual=", p.position, " hp=", p.health)
	return absf(p.position.x - x) <= 8

func run() -> void:
	await fresh()
	check(not level.dialogue.is_empty() and level.player.position.x < 253, "Spawn in cell with opening dialogue")
	check(not level.get_node("Guards/CorruptKeeper").illness_started, "Sickness follows opening, not before")
	await supplies()
	check(level.get_node("Guards/CorruptKeeper").illness_started, "Skipping opening applies illness state")
	check(level.player.has_supplies and level.player.c4_count == 2, "Bed grants shank, blanket and two charges")
	check(await move_to(240), "Walk from bed to locked cell door")
	await frames(2)
	check(level.player.position.x < 244, "Cell door physically blocks player")
	var g = level.get_node("Guards/CorruptKeeper")
	g.position = Vector2(280, 236)
	g.facing = -1
	g.turn_wait = 10
	level.interact()
	check(not level.player.has_key, "Pickpocket denied while guard faces Miro")
	g.facing = 1
	level.interact()
	check(level.player.has_key and not g.is_dead and level.route == "pickpocket", "Unseen pickpocket preserves guard and records route")
	level.interact()
	await frames(2)
	check(level.door_open, "Key opens physical cell door")
	# Cover: test real collision-backed placement and all concealment invalidators.
	level.player.position = Vector2(385, 237)
	await frames(3)
	level.player.toggle_stealth()
	check(level.player.is_concealed, "Stationary blanket in shadow conceals Miro")
	g.position = Vector2(340, 236)
	g.facing = 1
	check(not g.detect_player(), "Guard cannot detect concealed player")
	Input.action_press("move_right")
	await frames(2)
	Input.action_release("move_right")
	check(level.player.is_concealed, "Movement preserves timed stealth")
	level.player.position = Vector2(600, 237)
	await frames(3)
	level.player.toggle_stealth()
	check(not level.player.is_concealed, "Manual cancellation ends stealth anywhere")
	g.position = Vector2(570, 236)
	g.facing = 1
	check(g.detect_player(), "Visible player in facing cone detected")
	g.facing = -1
	check(not g.detect_player(), "Player behind guard is not detected")
	g.position = Vector2(570, 432)
	level.player.position = Vector2(570, 237)
	check(not g.detect_player(), "Guard cannot see player through floor / different tier")
	# Body discovery creates search without revealing the hidden killer.
	level.player.position = Vector2(660, 237)
	await frames(3)
	level.player.stealth_cooldown_left = 0
	level.player.toggle_stealth()
	var witness = level.get_node("Guards/GalleryKeeper")
	witness.position = Vector2(580, 236)
	witness.facing = 1
	g.position = Vector2(620, 236)
	g.die()
	await frames(3)
	check(witness.body_reported and witness.alert_state == IntroGuard.State.SEARCH, "Visible corpse triggers witness search")
	check(not witness.sees_player and level.player.is_concealed, "Corpse discovery does not reveal concealed Miro")
	var casualties: int = level.player.casualty_count
	g.die()
	check(level.player.casualty_count == casualties, "Death is counted only once")
	# Explicit solid occluder on same tier.
	check(not level.clear_sight(Vector2(410, 215), Vector2(480, 215)), "Stone stair physically blocks sight ray")
	# Damage recovery and dodge.
	level.player.invulnerability_left = 0
	level.player.dodge_left = 0
	level.player.take_damage(1)
	level.player.take_damage(1)
	check(level.player.health == 2, "Damage has 0.8 second invulnerability window")
	level.player.invulnerability_left = 0
	level.player.dodge_left = 0.2
	level.player.take_damage(1)
	check(level.player.health == 2, "Dodge avoids an incoming strike")
	# Alternate cell exits in fresh real scenes.
	await fresh()
	await supplies()
	check(await move_to(240), "C4 route reaches door using movement")
	level.plant_c4()
	await frames(3)
	check(level.door_open and level.route == "C4 breach" and level.player.c4_count == 1, "C4 opens lock and reserves one charge")
	check(level.get_node("Guards/CorruptKeeper").alert_state != IntroGuard.State.PATROL, "Blast draws guard investigation")
	level.plant_c4()
	check(level.player.c4_count == 1, "Repeated C4 cannot consume reserved objective charge")
	await fresh()
	await supplies()
	check(await move_to(240), "Shank route reaches door using movement")
	g = level.get_node("Guards/CorruptKeeper")
	g.position = Vector2(280, 236)
	g.facing = 1
	g.turn_wait = 10
	level.player.facing = 1
	level.player.shank()
	check(g.is_dead and level.player.casualty_count == 1, "Reach-through stealth shank kills unaware corrupt guard")
	level.interact()
	level.interact()
	await frames(3)
	check(level.player.has_key and level.player.has_gun and level.door_open, "Loot corpse for key and gun, unlock cell")
	if "--c4" in OS.get_cmdline_user_args():
		await fresh()
		await supplies()
		await move_to(240)
		level.plant_c4()
		await frames(3)
		check(level.route == "C4 breach", "Full traversal uses C4 escape")
	# Full physical route from spawn; no teleports beyond this point.
	check(await move_to(385, 500, true), "Exit cell into gallery")
	check(await move_to(655, 650, true), "Jump staggered shelves and cross upper patrol")
	level.interact()
	check(not level.dialogue.is_empty(), "Barred-gate voice encounter starts")
	level.finish_dialogue()
	check(level.brother_heard, "Voice encounter flag survives skipping")
	check(await move_to(728, 200, true), "Reach first ladder opening")
	Input.action_press("climb_down")
	await frames(160)
	Input.action_release("climb_down")
	check(level.player.position.y > 420 and level.player.position.y < 450, "First ladder descends to middle tier")
	check(await move_to(308, 650, true), "Cross middle patrol toward second ladder")
	Input.action_press("climb_down")
	await frames(190)
	Input.action_release("climb_down")
	check(level.player.position.y > 640 and level.player.position.y < 680, "Second ladder descends to lower tier")
	check(await move_to(620, 600, true), "Cross lower shelf to sigil support")
	level.interact()
	level.finish_dialogue()
	check(level.sigil_placed, "Set required sigil with reserved charge")
	var charges: int = level.player.c4_count
	level.interact()
	check(level.player.c4_count == charges, "Sigil placement is idempotent")
	check(await move_to(1030, 650, true), "Reach lower stair gate through final patrol")
	level.interact()
	check(level.completed and not level.player.is_dead, "Full physical intro route completes alive")
	await fresh()
	check(not level.door_open and not level.sigil_placed and not level.brother_heard and level.player.casualty_count == 0 and level.player.health == 3, "Fresh retry resets all floor progression")
	await supplies()
	level.player.position = Vector2(1030, 656)
	level.interact()
	check(not level.completed, "Exit cannot bypass mandatory sigil")
	print("INTRO_TEST_RESULT: ", checks - failures.size(), "/", checks, " passed")
	quit(0 if failures.is_empty() else 1)
