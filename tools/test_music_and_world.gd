extends "res://tools/test_intro.gd"

func floor_scene(number: int) -> void:
	if is_instance_valid(level):
		level.queue_free()
		await frames(2)
	level = load("res://scenes/levels/level_%02d.tscn" % number).instantiate()
	root.add_child(level)
	current_scene = level
	await frames(3)
	level.finish_dialogue()

func run() -> void:
	await floor_scene(3)
	var music = root.get_node("MusicDirector")
	var world = level.world_features
	level.player.position.x = 160
	await frames(3)
	check(music.catalog.size() == 9 and music.track_id == "swag", "Nine runtime tracks; Level 3 starts Swag")
	for id in music.catalog:
		var stream = load(music.catalog[id].stream)
		check(stream is AudioStream and stream.get_length() > 0, "Runtime track decodes: " + id)
	check(world.actors.size() == 2 and world.actors[0].voice_index != world.actors[1].voice_index, "Conversation has distinct guard voices")
	check(world.conversation_started and not level.controls_locked(), "Overhearing does not lock controls")
	var remaining: float = world.line_left
	level.paused = true
	await frames(60)
	check(is_equal_approx(world.line_left, remaining), "Pause freezes conversation timing")
	level.paused = false
	for tick in range(2000):
		if world.conversation_done:
			break
		await frames(1)
	check(world.conversation_done and world.password_known, "Finite conversation reveals root in hearing range")
	check(world.actors.all(func(actor): return not actor.conversation_hold), "Conversation releases guards")
	check(world.actors.all(func(actor): return actor.facing == 1), "Guards turn away after conversation")
	for guard in level.guards():
		guard.set_physics_process(false)
	level.player.position = Vector2(300, 232)
	level.interact()
	check(world.modal_open() and level.controls_locked(), "Terminal opens a focused password form")
	world.submit_password("ROOT")
	check(level.hack_remaining == 0 and not world.terminal_authenticated, "Password is case sensitive")
	world.submit_password("root")
	check(not world.modal_open() and level.hack_remaining > 0, "Root starts interruptible hack")
	await frames(65)
	check(level.connected_cameras.all(func(camera): return not camera.is_active), "Authenticated hack disables cameras")
	level.finish_dialogue()
	check(music.track_id == "sumcrazy", "Entering checkpoint selects Sum Crazy Shi")
	level.player.position = Vector2(100, 232)
	await frames(2)
	check(music.track_id == "sumcrazy", "Backtracking does not restart approach cue")
	level.start_dialogue([["TEST", "A spoken scene."]])
	await frames(50)
	check(music.duck_db < -7, "Music ducks under dialogue")
	level.finish_dialogue()
	# Local props do not grant ammunition or require the blanket.
	var hide
	var case
	for prop in world.props:
		if prop.kind == "hide": hide = prop
		if prop.kind == "case": case = prop
	check(hide != null and case != null, "Accessible authored hiding and case anchors spawned")
	for guard in level.guards():
		guard.position = Vector2(900, 236)
	level.player.position = case.global_position
	level.player.detection_state = "UNSEEN"
	var ammo: int = level.player.ammunition
	world.try_interact()
	check(level.player.controls.spares == 1 and case.used and level.player.ammunition == ammo, "Case stores one three-shot suppressor without granting ammunition")
	world.try_interact()
	check(level.player.controls.spares == 1, "Used case cannot duplicate spare attachments")
	level.player.has_gun = true
	level.player.guns.append("pistol")
	level.player.controls.sync_slots()
	var press := InputEventKey.new()
	press.physical_keycode = KEY_3
	press.pressed = true
	Input.parse_input_event(press)
	await frames(65)
	press = InputEventKey.new()
	press.physical_keycode = KEY_3
	press.pressed = false
	Input.parse_input_event(press)
	check(level.player.suppressor_uses == 3 and level.player.controls.spares == 0, "Hold gun key attaches stored suppressor")
	level.player.position = hide.global_position
	world.try_interact()
	check(level.player.in_hiding_spot and not level.player.is_concealed, "Enclosed hide works separately from blanket")
	var observer = level.guards()[0]
	observer.position = level.player.position + Vector2(40, 0)
	observer.facing = -1
	check(not observer.detect_player(), "Hiding recess blocks guard detection")
	var camera = level.connected_cameras[0]
	camera.position = level.player.position + Vector2(0, -52)
	camera.facing_angle = PI / 2
	camera.sweep_time = 0
	check(not camera.detects_player(), "Hiding recess blocks camera detection")
	level.player.has_gun = true
	level.player.ammunition = 5
	level.player.attack_cooldown = 0
	level.player.fire_gun()
	check(level.player.ammunition == 5 and level.player.suppressor_uses == 3, "Cannot fire from enclosed hiding")
	world.try_interact()
	check(not level.player.in_hiding_spot, "E exits hiding")
	level.player.position = Vector2(500, 656)
	observer.position = Vector2(700, 656)
	observer.alert_state = IntroGuard.State.PATROL
	observer.sees_player = false
	level.player.facing = -1
	for index in range(3):
		level.player.attack_cooldown = 0
		level.player.fire_gun()
	check(level.player.suppressor_uses == 0 and level.player.ammunition == 2, "Three fired shots exhaust suppressor")
	check(observer.alert_state == IntroGuard.State.PATROL, "Suppressed shots do not alert guard 200px away")
	level.player.attack_cooldown = 0
	level.player.fire_gun()
	check(observer.alert_state == IntroGuard.State.SEARCH, "Fourth shot restores full noise radius")
	level.player.ammunition = 0
	level.player.suppressor_uses = 3
	level.player.attack_cooldown = 0
	level.player.fire_gun()
	check(level.player.suppressor_uses == 3, "Empty trigger consumes no suppressor charge")
	var anchor: int = world.case_anchor_index
	await floor_scene(3)
	check(level.world_features.case_anchor_index == anchor, "Retry keeps case placement stable")
	world = level.world_features
	world.actors[0].die()
	await frames(3)
	check(not world.actors[1].conversation_hold, "Death interrupts conversation and releases surviving guard")
	level.player.position = Vector2(300, 232)
	world.open_terminal()
	world.submit_password("root")
	check(level.hack_remaining > 0, "Missing/dead speakers cannot soft-lock terminal")
	await floor_scene(5)
	check(music.track_id == "shit_crashed", "Final approach plays Shit Crashed 2")
	level.milestones = {"FinalSigil": true, "FinalOffer": true}
	level.player.position = level.areas.get_node("BrotherEncounter").position
	level.interact()
	check(is_instance_valid(level.brother) and music.track_id == "robot_attack", "Active boss combat starts Robot Attack")
	level.brother_defeated()
	check(music.track_id.is_empty(), "Boss defeat fades combat cue for fatal exchange")
	print("MUSIC_WORLD_RESULT: ", checks - failures.size(), "/", checks, " passed")
	quit(0 if failures.is_empty() else 1)
