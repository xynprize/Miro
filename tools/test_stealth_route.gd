extends SceneTree
var level
var failures: Array[String] = []
var spotted: bool = false
func _initialize() -> void:
	call_deferred("run")
func tick(count: int = 1) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
		for guard in level.guards():
			if guard.sees_player and guard.alert_state == IntroGuard.State.ALERT:
				if not spotted:
					print("FIRST SPOTTED by ", guard.name, " at ", level.player.position, " guard=", guard.position, " facing=", guard.facing)
				spotted = true
func check(value: bool, name: String) -> void:
	if not value:
		failures.append(name)
	print("PASS: " if value else "FAIL: ", name, " at ", level.player.position)
func walk(x: float, count: int = 650, use_cover := false) -> void:
	for i in range(count):
		if absf(level.player.position.x - x) < 4 or level.player.is_dead:
			break
		if use_cover and level.in_cover(level.player.position) and not level.player.is_concealed and level.player.stealth_cooldown_left <= 0:
			level.player.toggle_stealth()
		var right: bool = x > level.player.position.x
		Input.action_press("move_right" if right else "move_left")
		Input.action_release("move_left" if right else "move_right")
		if (level.player.is_on_wall() and level.player.is_on_floor()) or (level.player.is_on_wall() and not level.player.is_on_floor() and level.player.jumps_used == 1 and level.player.velocity.y > -20):
			Input.action_press("jump")
		else:
			Input.action_release("jump")
		await tick()
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("jump")
	await tick(2)
func run() -> void:
	level = load("res://scenes/intro.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await tick(3)
	level.finish_dialogue()
	level.interact()
	level.finish_dialogue()
	await walk(240)
	# Wait for an actual patrol window; do not move or rewrite guards.
	for i in range(900):
		var guard = level.get_node("Guards/CorruptKeeper")
		if guard.facing > 0 and level.player.position.distance_to(guard.position) < 45:
			level.interact()
			break
		await tick()
	check(level.player.has_key, "Natural patrol permits quiet key theft")
	level.interact()
	await walk(310)
	if not level.player.is_concealed and level.player.stealth_cooldown_left <= 0:
		level.player.toggle_stealth()
	check(level.player.is_concealed, "Use first refuge immediately outside the cell")
	await walk(385)
	if not level.player.is_concealed and level.player.stealth_cooldown_left <= 0:
		level.player.toggle_stealth()
	check(level.player.is_concealed, "Timed stealth persists while crossing the gallery")
	await walk(575)
	await tick(10)
	check(level.player.position.y < 200, "Upper staggered shelves provide high route")
	while level.player.is_concealed or level.player.stealth_cooldown_left > 0:
		await tick()
	for i in range(600):
		var guard = level.get_node("Guards/GalleryKeeper")
		if guard.facing < 0 and guard.position.x < 575:
			break
		await tick()
	Input.action_press("jump")
	await tick(1)
	Input.action_release("jump")
	while not level.in_cover(level.player.position):
		Input.action_press("move_right")
		await tick()
	if not level.player.is_concealed and level.player.stealth_cooldown_left <= 0:
		level.player.toggle_stealth()
	await walk(688)
	for i in range(60):
		if level.player.is_on_floor():
			break
		await tick()
	await tick(35)
	level.interact()
	level.finish_dialogue()
	check(level.brother_heard, "Quiet route reaches mysterious voice")
	for i in range(900):
		var keeper = level.get_node("Guards/GalleryKeeper")
		if keeper.alert_state == IntroGuard.State.PATROL and keeper.facing < 0:
			break
		await tick()
	await walk(728)
	Input.action_press("climb_down")
	await tick(260)
	Input.action_release("climb_down")
	check(level.player.position.y > 420, "Stealth route descends first ladder")
	await walk(590)
	await tick(8)
	check(level.player.position.y < 400, "Middle raised route bypasses floor patrol")
	while level.player.is_concealed or level.player.stealth_cooldown_left > 0:
		await tick()
	for i in range(600):
		var guard = level.get_node("Guards/PassageKeeper")
		if guard.facing > 0 and guard.position.x > 620:
			break
		await tick()
	level.player.toggle_stealth()
	await walk(400)
	if not level.player.is_concealed and level.player.stealth_cooldown_left <= 0:
		level.player.toggle_stealth()
	await tick(45)
	await walk(308)
	Input.action_press("climb_down")
	await tick(300)
	Input.action_release("climb_down")
	await walk(620)
	level.interact()
	level.finish_dialogue()
	check(level.sigil_placed, "Quiet route sets required sigil")
	await walk(740)
	if not level.player.is_concealed and level.player.stealth_cooldown_left <= 0:
		level.player.toggle_stealth()
	await tick(45)
	await walk(850)
	await tick(8)
	check(level.player.position.y < 630, "Lower high route passes above guard")
	while level.player.stealth_cooldown_left > 0:
		await tick()
	for i in range(600):
		var guard = level.get_node("Guards/LowerKeeper")
		if guard.facing < 0 and guard.position.x < 830:
			break
		await tick()
	Input.action_press("jump")
	await tick(1)
	Input.action_release("jump")
	await walk(1030, 650, true)
	level.interact()
	check(level.completed, "Continuous nonlethal route reaches intro ending")
	check(level.player.casualty_count == 0 and level.player.health == 3, "No casualties or damage on stealth route")
	check(not spotted, "Stealth route never reaches confirmed detection")
	print("STEALTH_ROUTE_RESULT failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
