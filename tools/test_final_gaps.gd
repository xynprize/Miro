extends "res://tools/test_intro.gd"
## Last gaps: the guitar deflects shots, hunting Keepers climb after Miro, extra Keepers on 3-4.
func run() -> void:
	level = load("res://scenes/levels/level_03.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(3)
	level.finish_dialogue()
	check(level.has_node("Guards/EntryClerk") and level.has_node("Guards/DeepKeeper"), "Level 3 has its extra Keepers")
	check(level.get_node("Guards/EntryClerk").guard_name == "Sable", "Extra Keeper is named and voiced")
	# Guitar deflection.
	for guard in level.guards():
		guard.set_physics_process(false)
		guard.position = Vector2(-500, -500)
	var player = level.player
	player.controls.has_guitar = true
	player.controls.select_item("guitar")
	Input.action_press("focus_item")
	player.controls.focus = true
	player.position = Vector2(400, 236)
	var shooter = level.get_node("Guards/EntryClerk")
	shooter.position = Vector2(520, 236)
	var bullet := Node2D.new()
	bullet.set_script(load("res://scripts/weapon_projectile.gd"))
	bullet.level = level
	bullet.shooter = shooter
	bullet.enemy = true
	bullet.direction = Vector2(-1, 0)
	bullet.speed = 280.0
	bullet.remaining = 260.0
	bullet.position = Vector2(470, 232)
	level.add_child(bullet)
	var health_before: int = player.health
	await frames(40)
	check(player.health == health_before, "The guitar takes the hit without damage")
	check(not is_instance_valid(bullet) or not bullet.enemy, "The round is turned back")
	Input.action_release("focus_item")
	# Ladder following.
	var ladder = level.areas.get_node("FifthLadder")
	player.set_physics_process(false)
	player.global_position = ladder.global_position + Vector2(0, -60)
	player.climbing = true
	var climber = level.get_node("Guards/DeepKeeper")
	climber.set_physics_process(true)
	climber.global_position = ladder.global_position + Vector2(0, 70)
	climber.alert_state = IntroGuard.State.ALERT
	climber.pursuing = true
	var start_y: float = climber.global_position.y
	await frames(50)
	check(climber.global_position.y < start_y - 20.0, "A hunting Keeper climbs the ladder after Miro")
	player.climbing = false
	# A searching Keeper walks to the ladder and climbs down to where he last saw Miro.
	var searcher = level.get_node("Guards/VaultWestKeeper")
	searcher.set_physics_process(true)
	searcher.global_position = Vector2(1480, 1048)
	searcher.alert_state = IntroGuard.State.SEARCH
	searcher.pursuing = false
	searcher.search_left = 30.0
	searcher.last_known_position = Vector2(1500, 1244)
	var before_y: float = searcher.global_position.y
	searcher.set_physics_process(false)
	for step in range(300):
		searcher.last_known_position = Vector2(1500, 1244)
		searcher.ladder_search(1.0 / 60.0)
		await frames(1)
	check(searcher.global_position.y > before_y + 25.0 and absf(searcher.global_position.x - 1540.0) < 64.0, "A searching Keeper takes the ladder down to the floor he last saw Miro")
	# The checkpoint hack opens the gate even if another scene starts at the same moment.
	level.queue_free()
	await frames(2)
	level = load("res://scenes/levels/level_03.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(10)
	level.finish_dialogue()
	for stray in level.guards():
		stray.set_physics_process(false)
	level.player.global_position = level.areas.get_node("RemoteTerminal").global_position + Vector2(0, 8)
	# Miro has already shot one of the linked watchers dead.
	for watcher in level.connected_cameras:
		if is_instance_valid(watcher):
			watcher.take_turret_hit(2)
			break
	level.world_features.open_terminal()
	level.world_features.submit_password("root")
	await frames(30)
	level.start_dialogue([["TOWER PA", "Something interrupts."]])
	await frames(20)
	level.finish_dialogue()
	await frames(90)
	check(level.milestones.has("RemoteTerminal") and level.get_node("Gates/CheckpointGate").is_open, "The hack opens the checkpoint gate even when another scene interrupts")
	# Last floor: the guitar takes the blanket's Q slot and the blanket is gone.
	root.get_node("Campaign").enter_floor(5)
	level.queue_free()
	await frames(2)
	level = load("res://scenes/levels/level_05.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(10)
	level.finish_dialogue()
	level.player.controls.collect_guitar()
	level.player.controls.select_item("blanket")
	check(not level.player.controls.blanket_removed(), "Blanket remains available on the last floor")
	level.player.controls.select_item("guitar")
	check(level.player.controls.active == "guitar" and level.player.controls.slots.has("guitar") and not level.player.controls.blanket_removed(), "Guitar uses a weapon slot and Q remains blanket")
	var flow = level.flow
	for g in level.guards():g.set_physics_process(false);g.position=Vector2(-1000,-1000)
	flow.row = 3
	flow.engagement = 3
	flow.spawn_niro()
	flow.final_wave_wait = 0.0
	var before: int = flow.wave_guards.size()
	flow.update_final_waves(0.1)
	check(flow.final_waves_sent == 1 and flow.wave_guards.size() >= before + 4, "A wave of Keepers joins the final Niro fight")
	for g in flow.wave_guards:g.fall_asleep()
	flow.final_wave_wait = 0.0
	flow.update_final_waves(0.1)
	check(flow.final_waves_sent == 2, "A second wave follows")
	for g in flow.wave_guards:g.fall_asleep()
	flow.final_wave_wait = 0.0
	flow.update_final_waves(0.1)
	check(flow.final_waves_sent == 3, "A third bounded reinforcement wave follows")
	flow.final_wave_wait = 0.0
	flow.update_final_waves(0.1)
	check(flow.final_waves_sent == 3, "No more than three extra waves")
	# Strangle: only from behind, no blood, not a casualty.
	level.queue_free()
	await frames(2)
	level = load("res://scenes/levels/level_03.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(10)
	level.finish_dialogue()
	for stray in level.guards():
		stray.set_physics_process(false)
		stray.global_position = Vector2(-600, -600)
	var victim = level.get_node("Guards/StairKeeper")
	victim.global_position = Vector2(400, 432)
	victim.facing = 1.0
	level.player.global_position = Vector2(415, 432)
	await frames(3)
	check(level.world_features.strangle_target() == null, "No strangling from the front")
	victim.facing = 1.0
	level.player.global_position = Vector2(385, 432)
	await frames(3)
	check(level.world_features.strangle_target() == victim, "Strangle is offered from behind")
	var kills_before: int = level.player.casualty_count
	level.interact()
	await frames(18)
	check(victim.asleep and victim.strangled and not victim.is_dead and level.player.casualty_count == kills_before, "Strangling leaves him out cold, not dead, and costs no casualty")
	# Controller: skip has a pad button, and retry is never bound to a pad button mid-play.
	var has_pad_skip := InputMap.action_get_events("skip").any(func(event): return event is InputEventJoypadButton)
	check(has_pad_skip, "Dialogue skip has a controller button (Back/Select)")
	check(not InputMap.action_get_events("retry").any(func(event): return event is InputEventJoypadButton), "Retry is not on a pad button during play")
	level = null
	print("FINAL_GAPS_RESULT: ", checks - failures.size(), "/", checks, " passed")
	quit(0 if failures.is_empty() else 1)
