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
	var terminal: Vector2 = level.areas.get_node("RemoteTerminal").position + Vector2(0, 8)
	# Overhear the Keepers from a few steps away on their storey.
	level.player.position = world.actors[0].position + Vector2(220, -2)
	await frames(3)
	check(music.catalog.size() >= 25 and music.track_id == "bobblehead", "At least twenty-five runtime tracks (with the secret beats); Level 3 starts Bobblehead")
	var beats := [0]
	var counter := func(_index): beats[0] += 1
	music.beat.connect(counter)
	await frames(80)
	check(beats[0] >= 2 and absf(music.seconds_per_bar() - 4 * 60.0 / 143.55) < 0.01, "Beat clock ticks at Bobblehead's felt tempo")
	music.beat.disconnect(counter)
	for id in music.catalog:
		var stream = load(music.catalog[id].stream)
		check(stream is AudioStream and stream.get_length() > 0, "Runtime track decodes: " + id)
	check(world.actors.size() == 2 and world.actors[0].guard_name != world.actors[1].guard_name, "Conversation has distinct guard voices")
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
	level.player.position = terminal
	level.interact()
	check(world.modal_open() and level.controls_locked(), "Terminal opens a focused password form")
	world.submit_password("ROOT")
	check(level.hack_remaining == 0 and not world.terminal_authenticated, "Password is case sensitive")
	world.submit_password("root")
	check(not world.modal_open() and level.hack_remaining > 0, "Root starts interruptible hack")
	await frames(65)
	check(level.connected_cameras.filter(func(camera): return world.security_storey(camera.global_position.y)==world.security_storey(terminal.y)).all(func(camera): return not camera.is_active), "Authenticated hack disables cameras on the terminal storey")
	level.finish_dialogue()
	# Down the checkpoint stairs: landing in the lower sub-floor brings in the second song.
	var stairs = level.areas.get_node("ThirdLadder")
	level.player.position = Vector2(stairs.position.x, stairs.position.y + stairs.area_size.y / 2 - 20)
	await frames(110)
	check(music.track_id == "cyberpunk", "Cyberpunk takes over on the bar line")
	level.player.position = terminal
	await frames(2)
	check(music.track_id == "cyberpunk", "Backtracking does not restart approach cue")
	music.queue_track("swag")
	var wait: float = music.pending_wait
	check(music.track_id == "cyberpunk" and music.pending_track == "swag" and wait <= music.seconds_per_bar() + 0.01, "Section changes wait for the next bar (at most one)")
	await frames(int(ceil(wait * 60)) + 3)
	check(music.track_id == "swag" and music.seconds_to_next_bar() > music.seconds_per_bar() - 0.2, "Queued track starts on a bar line")
	music.play_track("cyberpunk")
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
	world.try_interact()
	check(not case.used, "Ammunition case waits until Miro carries a gun")
	level.player.has_gun = true
	level.player.guns.append("pistol")
	level.player.equipped_gun = "pistol"
	level.player.controls.sync_slots()
	var reserve: int = level.player.controls.reserves.get("pistol", 0)
	world.try_interact()
	check(case.used and level.player.controls.reserves.pistol == reserve + 8, "Ammunition case adds one magazine of reserve")
	world.try_interact()
	check(level.player.controls.reserves.pistol == reserve + 8, "Used case cannot duplicate ammunition")
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
	check(level.player.ammunition == 5, "Cannot fire from enclosed hiding")
	world.try_interact()
	check(not level.player.in_hiding_spot, "E exits hiding")
	level.player.position = terminal + Vector2(200, 0)
	observer.position = terminal + Vector2(400, 0)
	observer.alert_state = IntroGuard.State.PATROL
	observer.sees_player = false
	level.player.facing = -1
	level.player.attack_cooldown = 0
	level.player.fire_gun()
	check(level.player.ammunition == 4 and observer.alert_state == IntroGuard.State.SEARCH, "Every shot is loud: a guard 200px away investigates")
	var anchor: int = world.case_anchor_index
	await floor_scene(3)
	check(level.world_features.case_anchor_index == anchor, "Retry keeps case placement stable")
	world = level.world_features
	world.actors[0].die()
	await frames(3)
	check(not world.actors[1].conversation_hold, "Death interrupts conversation and releases surviving guard")
	level.player.position = level.areas.get_node("RemoteTerminal").position + Vector2(0, 8)
	world.open_terminal()
	world.submit_password("root")
	check(level.hack_remaining > 0, "Missing/dead speakers cannot soft-lock terminal")
	await floor_scene(5)
	check(music.track_id.is_empty(), "The Foundation opens near-silent until the guitar")
	level.player.position = level.areas.get_node("Guitar").position
	level.interact()
	check(level.dialogue.is_empty() and not level.player.controls.has_guitar, "Guitar waits for the final sigil")
	level.milestones["FinalSigil"] = true
	level.sigil_placed = true
	level.interact()
	level.finish_dialogue()
	check(music.track_id == "shit_crashed", "Guitar pickup starts Shit Crashed")
	level.brother_defeated()
	check(music.track_id.is_empty(), "Boss defeat fades combat cue for the defeat exchange")
	for number in [2, 4]:
		music.start_floor(number)
		check(music.track_id == ["", "", "dope2", "", "plane_drums"][number], "Level %d opens on its approved first track" % number)
	print("MUSIC_WORLD_RESULT: ", checks - failures.size(), "/", checks, " passed")
	quit(0 if failures.is_empty() else 1)
