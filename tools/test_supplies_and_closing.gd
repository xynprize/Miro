extends "res://tools/test_intro.gd"
func run() -> void:
	var campaign = root.get_node("Campaign")
	for number in range(1, 6):
		campaign.checkpoint.clear()
		campaign.enter_floor(number)
		level = load("res://scenes/intro.tscn" if number == 1 else "res://scenes/levels/level_%02d.tscn" % number).instantiate()
		root.add_child(level)
		current_scene = level
		await frames(20)
		level.finish_dialogue()
		for guard in level.guards():
			guard.set_physics_process(false)
			guard.position = Vector2(-500, -500)
		var player = level.player
		player.set_physics_process(false)
		player.has_supplies = true
		var world = level.world_features
		var potions: Array = world.props.filter(func(prop): return prop.kind == "potion")
		var cases: Array = world.props.filter(func(prop): return prop.kind == "case")
		var hides: Array = world.props.filter(func(prop): return prop.kind in ["hide", "crate"])
		check(not potions.is_empty() and not cases.is_empty() and not hides.is_empty(), "Floor %d has tonics, ammo and hiding boxes" % number)
		for tonic in potions:
			check(((tonic.get_meta("lab_flask", false) or tonic.get_meta("lab_bottle",false)) and level.has_floor_below(tonic.global_position + Vector2(0, 38))) or (world.placement_clear(tonic.global_position) and level.has_floor_below(tonic.global_position + Vector2(0, 13))), "Floor %d tonic %s is clear and supported" % [number, tonic.global_position])
		var selected = potions[0]
		player.health = player.max_health - 2
		for tonic in potions:
			player.global_position = tonic.global_position
			if world.nearby_prop() == tonic:
				selected = tonic
				break
		check(world.try_interact() and selected.used and player.health == mini(player.max_health,player.max_health-2+int(selected.get_meta("heal_amount",1))), "Floor %d tonic restores health" % number)
		world.try_interact()
		check(player.health == mini(player.max_health,player.max_health-2+int(selected.get_meta("heal_amount",1))), "Floor %d consumed tonic cannot heal twice" % number)
		player.has_gun = true
		player.guns.assign(["pistol"])
		player.equipped_gun = "pistol"
		player.controls.reserves.pistol = 0
		player.global_position = cases[0].global_position
		check(world.try_interact() and cases[0].used and player.controls.reserves.pistol > 0, "Floor %d ammo case gives usable reserve rounds" % number)
		var reserve: int = player.controls.reserves.pistol
		world.try_interact()
		check(player.controls.reserves.pistol == reserve, "Floor %d consumed ammo cannot be collected twice" % number)
		for hide in hides:
			player.global_position = hide.global_position
			check(world.try_interact() and player.in_hiding_spot, "Floor %d can enter %s at %s" % [number, hide.title, hide.global_position])
			check(world.try_interact() and not player.in_hiding_spot, "Floor %d can leave %s" % [number, hide.title])
		# Real player pose selection uses the same art on every floor.
		player.position = Vector2(340, 236)
		player.set_physics_process(true)
		await frames(10)
		player.set_physics_process(false)
		player.velocity = Vector2.ZERO
		player.update_visual(0)
		check(player.sprite.texture == player.IDLE, "Floor %d Miro idle pose uses Julia's sprite" % number)
		player.velocity.x = 60
		player.update_visual(0.13)
		check(player.sprite.texture == player.WALK and player.sprite.hframes == 2, "Floor %d Miro walking uses both frames" % number)
		var keeper = level.guards()[0]
		check(keeper.KEEPER_IDLE.get_size() == Vector2(32, 32) and keeper.KEEPER_WALK.get_size() == Vector2(64, 32) and keeper.KEEPER_ATTACK.get_size() == Vector2(64, 32), "Floor %d Keeper idle/walk/attack sheets match drawing geometry" % number)
		if number == 1:
			player.position = world.access_point + Vector2(479, 0)
			check(player.controls.connection_target()!=null, "MP3 connects to a nearby terminal within 480px")
			player.position = world.access_point + Vector2(481, 0)
			check(not player.controls.at_early_port(), "MP3 service port rejects positions outside the 480px wireless range")
		if number == 3:
			# Miro has already left the ladder: search must reach and leave the upper landing.
			player.global_position = Vector2(1300, 1048)
			player.in_hiding_spot = true
			var climber = level.get_node("Guards/DeepKeeper")
			climber.global_position = Vector2(1540, 1244)
			climber.alert_state = IntroGuard.State.SEARCH
			climber.pursuing = true
			climber.last_known_position = Vector2(1450, 1048)
			climber.search_left = 30
			climber.set_physics_process(true)
			await frames(270)
			print("UPPER_LANDING: ", climber.global_position)
			check(climber.global_position.y < 1070 and climber.global_position.x < 1510 and climber.is_on_floor(), "A searching guard climbs UP and steps onto Miro's upper floor")
		if number == 5:
			var boss = load("res://scripts/brother_boss.gd").new()
			boss.level = level
			boss.engagement = 3
			level.add_child(boss)
			boss.set_physics_process(false)
			check(boss.KAEL_IDLE.get_width() == 24 and boss.KAEL_WALK.get_width() == 48 and boss.KAEL_ATTACK.get_width() == 64, "Niro idle/walk/attack sheets use their correct frame widths")
			boss.forced_attack = "throw"
			for repeat in range(20):
				check(boss.telegraph_attack() == "throw" and boss.forced_attack == "throw", "Niro's rendered warning keeps the chosen throw")
			boss.current_phase = boss.Phase.TELEGRAPH
			boss.phase_left = 0
			boss._physics_process(1.0 / 60)
			check(boss.last_attack == "throw" and boss.forced_attack.is_empty() and boss.projectile_live, "Niro executes the attack shown by his warning")
		level.queue_free()
		await frames(3)
	level = null
	var finale = load("res://scenes/credits.tscn").instantiate()
	root.add_child(finale)
	current_scene = finale
	await frames(3)
	finale.credits_time = finale.SONG_LENGTH + 0.99
	await frames(3)
	check(is_instance_valid(finale.closing_scene) and finale.closing_scene.stage == "logo", "Credits automatically end with the supplied RXLA logo")
	var closing = finale.closing_scene
	check(closing.LOGO.get_size() == Vector2(1000, 1000) and closing.PLAYER.get_size().x > 0, "Logo and MP3 artwork load")
	check(absf(closing.STATIC.get_length() - 6.0) < 0.1, "Strong static audio decodes for the full six seconds")
	closing.clock = closing.LOGO_LENGTH - 0.01
	await frames(2)
	check(closing.stage == "static", "RXLA logo advances to the MP3 black-screen cutscene")
	closing.clock = closing.STATIC_LENGTH - 0.01
	await frames(4)
	check(current_scene.scene_file_path == "res://scenes/main_menu.tscn", "Postcredits static finishes and returns to the menu")
	print("SUPPLIES_CLOSING_RESULT: ", checks - failures.size(), "/", checks, " passed")
	quit(0 if failures.is_empty() else 1)
