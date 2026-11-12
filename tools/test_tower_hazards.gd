extends "res://tools/test_intro.gd"

func run() -> void:
	level = load("res://scenes/levels/level_04.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(3)
	level.finish_dialogue()
	for guard in level.guards():
		guard.set_physics_process(false)

	var spikes: Area2D
	var turret: Area2D
	var wall_spikes: Area2D
	var ceiling_spikes: Area2D
	for child in level.get_children():
		if child.get_script() == preload("res://scripts/tower_hazard.gd"):
			if child.kind == "spikes" and spikes == null:
				spikes = child
			elif child.kind == "turret" and turret == null:
				turret = child
			elif child.kind == "spikes":
				if is_equal_approx(child.rotation, PI / 2.0):
					wall_spikes = child
				elif is_equal_approx(child.rotation, PI):
					ceiling_spikes = child
	check(spikes != null and turret != null, "Ward loads both hazards from its blueprint")
	if not spikes or not turret:
		quit(1)
		return

	# Combat fixture keeps its known shadow lane; authored wall placements have separate physics checks.
	turret.position = Vector2(1246,868)
	turret.rotation = 0.0
	turret.aim = PI
	var player: IntroPlayer = level.player
	var starting_health := player.health
	player.position = spikes.position + Vector2(0, -55)
	await frames(3)
	check(player.health == starting_health, "Passing above spikes is safe")
	player.position = turret.position + Vector2(168, -15)
	await frames(3)
	player.invulnerability_left = 0.0
	player.toggle_stealth()
	check(player.is_concealed, "Ward shadow lets Miro use the blanket")
	await frames(70)
	check(player.health == starting_health, "Turret leaves hidden Miro alone")
	player.end_stealth()
	await frames(30)
	check(player.health == starting_health and is_zero_approx(turret.charge), "Shadow alone hides Miro from the turret")
	# Step out of the shadow, still in the turret's line of fire.
	for offset in range(168, 40, -8):
		player.position = turret.position + Vector2(offset, -15)
		if not level.in_cover(player.global_position):
			break
	await frames(125)
	check(absf(angle_difference(turret.aim, 0.0)) < 0.08, "Turret head turns toward Miro")
	check(player.health < starting_health, "An exposed Miro can be hit by the turret")
	player.position = turret.position + Vector2(-34, -15)
	player.facing = 1
	for hit in range(4):
		player.attack_cooldown = 0.0
		player.shank()
		check(turret.health == 8 - 2 * hit, "Stab %d takes one HP (two hits) of the turret's five" % (hit + 1))
	player.attack_cooldown = 0.0
	player.shank()
	await frames(2)
	check(not is_instance_valid(turret), "Fifth stab destroys the turret")
	player.invulnerability_left = 5.0
	player.position = spikes.position + Vector2(0, -15)
	await frames(8)
	check(player.is_dead and player.health == 0, "Spikes kill on contact even during damage invulnerability")
	check(wall_spikes != null and ceiling_spikes != null, "Ward has side and ceiling mounts")
	if wall_spikes and ceiling_spikes:
		player.set_physics_process(false)
		for trap in [wall_spikes, ceiling_spikes]:
			player.is_dead = false
			player.health = starting_health
			var outward := Vector2.UP.rotated(trap.rotation)
			player.position = trap.position + outward * (13.0 if trap == wall_spikes else 18.0)
			await frames(5)
			check(player.is_dead, "Mounted spikes kill on contact at rotation %s" % trap.rotation)
	level.queue_free()
	await frames(2)
	level = load("res://scenes/levels/level_05.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(2)
	level.finish_dialogue()
	var turret_mounts := {}
	var spike_mounts := {}
	for child in level.get_children():
		if child.get_script() == preload("res://scripts/tower_hazard.gd"):
			var mount := roundi(rad_to_deg(child.rotation))
			if child.kind == "turret":
				turret_mounts[mount] = child
			else:
				spike_mounts[mount] = true
	check(turret_mounts.has_all([0, -90, 180]) and spike_mounts.has_all([0, -90, 180]), "Foundation loads floor, wall and ceiling mounts for both hazards")
	player = level.player
	player.set_physics_process(false)
	# These fixed test spots can fall in a shadow, which now hides Miro: test aim in the open.
	for area in level.areas.get_children():
		if area.kind == "cover":
			area.kind = "note"
	for mount in [180, -90]:
		if not turret_mounts.has(mount):
			continue
		var mounted: Node2D = turret_mounts[mount]
		player.position = Vector2(1036, 432) if mount == 180 else Vector2(1005, 656)
		player.health = starting_health
		player.invulnerability_left = 0.0
		await frames(170)
		var expected_aim := (player.global_position - mounted.to_global(mounted.PIVOT)).angle()
		check(absf(angle_difference(mounted.aim, expected_aim)) < 0.08 and player.health < starting_health,
			"Turret tracks and lands a shot from mount %d" % mount)
	if turret_mounts.has(-90):
		var mounted: Node2D = turret_mounts[-90]
		player.health = starting_health
		player.invulnerability_left = 0.0
		player.controls.has_guitar = true
		player.controls.strum()
		check(mounted.stun_left > 4.95 and mounted.charge == 0.0, "A strum stuns the wall turret immediately and clears its charge")
		await frames(90)
		check(player.health == starting_health and mounted.stun_left > 0, "Stunned turret cannot fire")
		await frames(220)
		check(is_zero_approx(mounted.stun_left), "Turret recovers after five seconds")
	if turret_mounts.has(0):
		var floor_turret: Node2D = turret_mounts[0]
		player.position = floor_turret.position + Vector2(-50, -15)
		player.mouse_aim = false
		player.facing = 1
		player.has_gun = true
		player.equipped_gun = "pistol"
		player.ammunition = 3
		# Keepers (a terminal guard spawns late) must not stand in the line of fire.
		for stray in level.guards():
			stray.queue_free()
		await frames(2)
		player.ammunition = 12
		for hit in range(9):
			player.attack_cooldown = 0.0
			player.fire_gun()
			await frames(8)
			check(floor_turret.health == 9 - hit, "Pistol shot %d takes one hit of the turret's ten" % (hit + 1))
		player.attack_cooldown = 0.0
		player.fire_gun()
		await frames(8)
		check(not is_instance_valid(floor_turret), "Tenth pistol shot destroys the turret")
	print("TOWER_HAZARDS_RESULT: %d/%d passed" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
