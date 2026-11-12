extends "res://tools/test_intro.gd"
## Level 5 "The Foundation": guitar > waves on the bar > Niro x3 retreats > final non-fatal fight.

var flow
var music

func run() -> void:
	seed(97005070)
	music = root.get_node("MusicDirector")
	level = load("res://scenes/levels/level_05.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(3)
	flow = level.flow
	check(level.definition.title == "The Foundation" and not "brother" in level.definition.opening.to_lower(), "Level 5 is The Foundation with a non-spoiler opening")
	level.finish_dialogue()
	check(flow != null and music.track_id.is_empty(), "Office starts near-silent with the encounter flow ready")
	# Hatch 1 holds until Niro retreats: the ladder cannot be used yet.
	check(await move_to(728, 400), "Reach the first hatch")
	Input.action_press("climb_down")
	await frames(90)
	Input.action_release("climb_down")
	check(level.player.position.y < 300, "Closed hatch blocks the descent")
	check(await move_to(300, 600), "Return to the final sigil")
	level.interact()
	level.finish_dialogue()
	check(level.milestones.has("FinalSigil") and level.sigil_placed, "Final sigil placed in the office")
	# Guitar pickup.
	check(await move_to(190, 300), "Reach the guitar")
	level.interact()
	check(level.dialogue_event == "milestone", "Guitar opens its scene")
	var bar_phase := [-1.0]
	flow.wave_started.connect(func(_row): bar_phase[0] = fmod(music.beat_position(), 4.0))
	level.finish_dialogue()
	check(level.player.controls.has_guitar and level.player.controls.active == "guitar", "Guitar is taken and selected")
	level.player.controls.show_inventory()
	check(level.player.controls.slots.has("guitar") and not level.player.controls.blanket_removed(), "Guitar occupies a weapon slot while blanket stays available")
	level.player.controls.guitar_button.pressed.emit()
	check(level.player.controls.active == "guitar" and not level.player.controls.inventory_open, "Inventory guitar entry equips it")
	# Fixture: the scripted section checks the flow, not survival; the final fight below uses normal health.
	level.player.health = 99
	check(music.track_id == "shit_crashed", "Picking up the guitar starts Shit Crashed")
	await frames(150)
	check(flow.step == flow.Step.WAVE and flow.wave_guards.size() == 3, "Wave 1 enters")
	check(bar_phase[0] >= 0 and (bar_phase[0] < 0.25 or bar_phase[0] > 3.75), "Wave enters on a bar line")
	# Sleep the wave with the guitar: lootable, not a kill.
	for guard in flow.wave_guards:
		guard.set_physics_process(false)
		guard.position = level.player.position + Vector2(60 + flow.wave_guards.find(guard) * 25, 0)
	await frames(2)
	level.player.controls.strum_cooldown = 0
	check(level.player.controls.strum() == 3, "One strum reaches the whole wave")
	check(flow.wave_guards.all(func(guard): return guard.asleep and not guard.detect_player()), "Strummed Keepers sleep and stop seeing Miro")
	check(level.player.casualty_count == 0, "Sleeping Keepers are not kills")
	level.player.position = flow.wave_guards[0].position + Vector2(-10, 0)
	await frames(2)
	level.interact()
	check(flow.wave_guards[0].gun_taken and level.player.guns.size() == 1, "A sleeping Keeper can be looted")
	for guard in flow.wave_guards:
		guard.set_physics_process(true)
	await clear_second_wave(1)
	check(is_instance_valid(level.brother) and level.brother.engagement == 1, "Niro appears after the wave")
	check(level.dialogue_event == "niro_1" and level.dialogue.size() >= 6, "First meeting carries the reveal face to face")
	level.finish_dialogue()
	check(level.milestones.has("FinalOffer"), "Reveal completes Face Niro")
	var boss = level.brother
	check(boss.attacks() == ["rush"], "First meeting teaches the rush only")
	boss.receive_shank()
	check(boss.health == 12, "Telegraph is guarded")
	level.paused = true
	var timer: float = boss.phase_left
	await frames(40)
	check(is_equal_approx(timer, boss.phase_left), "Pause freezes Niro")
	level.paused = false
	await damage_until_retreat(boss, 9)
	check(level.milestones.has("NiroRetreat1") and level.get_node("Gates/Hatch1").is_open, "Niro retreats at 9 and Hatch 1 opens")
	# Down to the second floor by ladder.
	check(await descend_ladder(728, 170, 410), "Climb down through Hatch 1")
	await frames(150)
	check(flow.step == flow.Step.WAVE and flow.wave_guards.size() == 4, "Wave 2 enters on the second floor")
	for guard in flow.wave_guards:
		guard.die()
	await clear_second_wave(2)
	boss = level.brother
	check(is_instance_valid(boss) and boss.engagement == 2 and boss.health == 9 and "throw" in boss.attacks(), "Second meeting keeps damage and adds the throw")
	level.finish_dialogue()
	await damage_until_retreat(boss, 6)
	check(level.get_node("Gates/Hatch2").is_open, "Hatch 2 opens after the second retreat")
	check(await descend_ladder(308, 190, 640), "Drop to the third floor")
	await frames(130)
	check(music.track_id == "hot_shit", "Hot Shit takes over for the second half")
	check(flow.wave_guards.size() == 4, "Wave 3 enters")
	for guard in flow.wave_guards:
		guard.fall_asleep()
	await clear_second_wave(3)
	boss = level.brother
	level.finish_dialogue()
	check(boss.engagement == 3 and "call" in boss.attacks(), "Third meeting can call guards")
	var before: int = flow.wave_guards.size()
	boss.forced_attack = "call"
	boss.current_phase = boss.Phase.TELEGRAPH
	boss.phase_left = 0
	await frames(2)
	check(flow.wave_guards.size() == before + 1, "Niro calls a Keeper in")
	await damage_until_retreat(boss, 3)
	check(level.get_node("Gates/Hatch3").is_open, "Hatch 3 opens after the third retreat")
	for guard in level.guards():
		if not guard.is_dead and not guard.asleep and guard != boss:
			guard.fall_asleep()
	check(await descend_ladder(952, 200, 830), "Climb down to the deepest floor")
	level.player.health = 6
	await frames(150)
	boss = level.brother
	check(boss.engagement == 4 and boss.health == 6, "Final fight on the deepest floor")
	check(level.dialogue_event == "niro_4" and str(level.dialogue[0][1]).length() > 10, "Final meeting opens with the branch line")
	level.finish_dialogue()
	await fight_brother()
	if not boss.is_dead or level.player.is_dead:
		print("BROTHER_RESULT: failed final encounter")
		quit(1)
		return
	check(boss.is_dead and not boss.is_queued_for_deletion(), "Niro is beaten but not killed")
	check(level.milestones.has("BrotherEncounter") and level.pending_milestone == "DefeatExchange", "Defeat starts the defeat exchange")
	check(music.track_id.is_empty(), "Music falls away for the exchange")
	level.finish_dialogue()
	check(level.milestones.has("DefeatExchange"), "Skip preserves defeat exchange completion")
	check(await move_to(level.areas.get_node("ForestViewpoint").position.x, 800), "Reach the final door")
	level.interact()
	check(is_instance_valid(level.cinematic), "One interaction at the final door starts the ending")
	if not is_instance_valid(level.cinematic):
		quit(1)
		return
	level.cinematic.finish()
	check(level.completed, "The Foundation completes")
	print("BROTHER_RESULT: ", checks - failures.size(), "/", checks, " passed")
	quit(0 if failures.is_empty() else 1)

func damage_until_retreat(boss, target: int) -> void:
	while boss.health > target and is_instance_valid(boss):
		boss.begin_recovery()
		boss.invulnerability_left = 0
		boss.receive_shank()
	check(boss.current_phase == boss.Phase.RETREAT and boss.health == target, "Niro retreats at %d health" % target)
	await frames(70)

func descend_ladder(x: float, hold: int, expected_y: float) -> bool:
	if not await move_to(x, 900):
		return false
	Input.action_press("climb_down")
	await frames(hold)
	Input.action_release("climb_down")
	await frames(30)
	print("DESCEND to y=", level.player.position.y)
	return level.player.position.y > expected_y

func fight_brother() -> void:
	var boss = level.brother
	level.player.controls.select_item("guitar")
	for tick in range(2400):
		if boss.is_dead or level.player.is_dead:
			break
		Input.action_press("focus_item")
		level.player.controls.focus = true
		level.player.facing = signf(boss.position.x - level.player.position.x)
		var offset: float = boss.position.x - level.player.position.x
		Input.action_release("move_left")
		Input.action_release("move_right")
		if boss.is_vulnerable:
			if absf(offset) <= 120 and level.player.controls.strum_cooldown <= 0:
				level.player.controls.strum()
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
	Input.action_release("focus_item")
	print("FINAL_FIGHT_PROBE boss_hp=",boss.health," player_hp=",level.player.health," gear=",level.player.controls.active)
	check(boss.is_dead and not level.player.is_dead, "Final fight won with movement, melee and guitar deflection")

func clear_second_wave(meeting: int) -> void:
	for tick in range(600):
		if is_instance_valid(level.brother) and level.brother.engagement == meeting:
			break
		if flow.step == flow.Step.WAVE and flow.waves_on_row == 2:
			for guard in flow.wave_guards:
				if is_instance_valid(guard):guard.fall_asleep()
		await frames(1)
	check(flow.waves_on_row == 2, "Two waves arrive before Niro meeting %d"%meeting)
