extends "res://tools/test_intro.gd"
func run() -> void:
	await fresh()
	await supplies()
	for guard in level.guards():
		guard.set_physics_process(false)
		guard.position = Vector2(900, 656)
	var p = level.player
	var guards = level.guards()
	guards[0].weapon_kind = "pistol"
	guards[1].weapon_kind = "smg"
	guards[2].weapon_kind = "flamethrower"
	p.loot_weapon(guards[0])
	p.loot_weapon(guards[1])
	check(p.guns.size() == 2 and p.equipped_gun == "smg", "Two distinct guns can be carried")
	p.loot_weapon(guards[2])
	check(level.controls_locked() and not guards[2].gun_taken, "Third gun requires a choice before looting")
	p.resolve_weapon_choice(-1)
	check(not guards[2].gun_taken and p.guns.size() == 2 and not level.controls_locked(), "Cancel preserves inventory and corpse loot")
	p.loot_weapon(guards[2])
	p.resolve_weapon_choice(1)
	check(p.guns == ["pistol", "flamethrower"] and guards[2].gun_taken, "Explicit replacement keeps two guns")
	p.position = Vector2(300, 236)
	p.suppressor_uses = 3
	p.fire_gun()
	check(p.suppressor_uses == 3 and p.ammunition == 15, "Flamethrower consumes fuel but no suppressor charges")
	p.select_gun(0)
	p.suppressor_uses = 3 # Fixture: attach a fresh suppressor to this pistol.
	check(p.ammunition == 2, "Switching restores independent pistol ammunition")
	p.attack_cooldown = 0
	p.fire_gun()
	check(p.suppressor_uses == 2 and p.ammunition == 1, "Pistol consumes one suppressor use per round")
	p.select_gun(1)
	check(p.ammunition == 15, "Switching back preserves spent fuel")
	# SMG supports the same three-shot suppressor.
	p.equipped_gun = "smg"
	p.suppressor_uses = 3 # Fresh attachment on the SMG, independent of the pistol.
	p.ammunition = 12
	p.attack_cooldown = 0
	guards[0].position = Vector2(600, 236)
	guards[0].sees_player = false
	guards[0].alert_state = IntroGuard.State.PATROL
	p.fire_gun()
	check(p.ammunition == 11 and p.suppressor_uses == 2 and guards[0].alert_state == IntroGuard.State.PATROL, "SMG consumes one suppressor charge and remains silent")
	p.equipped_gun = "pistol"
	p.ammunition = 4
	p.suppressor_uses = 3
	for shot in range(3):
		p.attack_cooldown = 0
		p.fire_gun()
	check(p.suppressor_uses == 0, "Exactly three pistol shots exhaust suppressor")
	guards[0].alert_state = IntroGuard.State.PATROL
	p.attack_cooldown = 0
	p.fire_gun()
	check(guards[0].alert_state == IntroGuard.State.SEARCH, "Fourth pistol shot is audible")
	p.suppressor_uses = 3
	p.attack_cooldown = 0
	p.fire_gun()
	check(p.suppressor_uses == 3, "Empty trigger does not spend suppressor charge")
	p.equipped_gun = "flamethrower"
	p.ammunition = 15
	guards[0].position = Vector2(900, 656)
	await frames(60)
	p.position = Vector2(220, 236)
	guards[1].position = Vector2(280, 236)
	p.facing = 1
	p.attack_cooldown = 0
	p.fire_gun()
	await frames(40)
	check(guards[1].health == 2, "Flame cannot pass through locked cell wall")
	p.position = Vector2(300, 236)
	guards[1].position = Vector2(350, 236)
	p.attack_cooldown = 0
	p.fire_gun()
	await frames(20)
	check(guards[1].health == 1, "Flame damages a reachable target")
	# Enemy rounds use the player collision layer and respect dodge immunity.
	guards[0].position = Vector2(350, 236)
	guards[0].shot_direction = Vector2.LEFT
	guards[0].burst_left = 1
	p.health = 3
	p.invulnerability_left = 0
	guards[0].shoot_weapon()
	await frames(20)
	check(p.health == 2, "Keeper projectile damages Miro")
	p.invulnerability_left = 0
	p.dodge_left = 1
	guards[0].shoot_weapon()
	await frames(10)
	check(p.health == 2, "Dodge protects Miro from gunfire")
	print("WEAPON_INVENTORY_RESULT: ", checks - failures.size(), "/", checks, " passed")
	quit(0 if failures.is_empty() else 1)
