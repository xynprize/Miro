extends SceneTree
var level
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func frames(count: int = 3) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)
func check(value: bool, name: String) -> void:
	print("PASS: " if value else "FAIL: ", name)
	if not value:
		failures.append(name)
func run() -> void:
	level = load("res://scenes/intro.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames()
	await key(KEY_E)
	check(level.dialogue_index == 1, "E advances exactly one dialogue line")
	await key(KEY_TAB)
	check(level.dialogue.is_empty() and not level.player.has_supplies, "Tab skips without triggering bed interaction")
	await key(KEY_E)
	check(level.player.has_supplies and level.dialogue_index == 0, "E searches bed and begins supply dialogue once")
	await key(KEY_TAB)
	check(not level.controls_locked(), "Skipping supply dialogue restores control")
	await key(KEY_ESCAPE)
	var keeper = level.get_node("Guards/CorruptKeeper")
	var old_position: Vector2 = keeper.position
	await frames(60)
	check(level.paused and keeper.position == old_position, "Escape pauses patrol simulation")
	await key(KEY_ESCAPE)
	check(not level.paused and not paused, "Escape resumes game")
	level.player.position = Vector2(180, 237)
	await frames()
	await key(KEY_Q)
	level.player.controls.use_item()
	check(level.player.is_concealed, "Q selects blanket and use activates stealth")
	await key(KEY_1)
	level.player.controls.use_item()
	check(not level.player.is_concealed, "Selected shank use breaks blanket concealment")
	await frames(490)
	await key(KEY_Q)
	level.player.controls.use_item()
	await key(KEY_SPACE)
	check(level.player.is_concealed and level.player.velocity.y < 0, "Space jumps without breaking timed stealth")
	await frames(50)
	await key(KEY_C)
	check(level.player.dodge_cooldown > 0, "C starts dodge cooldown")
	level.open_door()
	level.player.position = Vector2(600, 237)
	level.player.velocity = Vector2.ZERO
	var guard = level.get_node("Guards/GalleryKeeper")
	guard.position = Vector2(630, 237)
	guard.facing = -1
	guard.alert_state = IntroGuard.State.ALERT
	guard.suspicion = 1
	level.player.facing = 1
	level.player.attack_cooldown = 0
	level.player.shank()
	check(guard.health == 1 and not guard.is_dead, "Alert guard survives first frontal shank")
	level.player.attack_cooldown = 0
	level.player.shank()
	check(guard.is_dead, "Second frontal shank defeats alert guard")
	# Loss of vision searches a fixed remembered point, not a moving invisible player.
	keeper.position = Vector2(360, 237)
	keeper.facing = 1
	keeper.alert_state = IntroGuard.State.ALERT
	keeper.last_known_position = Vector2(385, 237)
	level.player.position = Vector2(385, 237)
	level.player.is_concealed = true
	level.player.stealth_remaining = 5
	await frames(3)
	var remembered: Vector2 = keeper.last_known_position
	level.player.position = Vector2(180, 237)
	await frames(3)
	check(keeper.alert_state == IntroGuard.State.SEARCH and keeper.last_known_position == remembered and not keeper.sees_player, "Losing sight searches memory without tracking hidden player")
	level.player.invulnerability_left = 0
	level.player.dodge_left = 0
	level.player.take_damage(3)
	await frames()
	check(level.player.is_dead and level.overlay.visible, "Fatal damage opens retry overlay")
	await key(KEY_BACKSPACE)
	level = current_scene
	check(level.player.health == 3 and not level.player.has_supplies and not level.door_open and not level.dialogue.is_empty(), "Backspace retries actual scene into initial story state")
	print("CONTROLS_RESULT failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
