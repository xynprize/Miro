extends "res://tools/test_intro.gd"
class WeaponArtCheck:
	static func has_flamethrower() -> bool:
		return preload("res://scripts/weapon_art.gd").TEXTURES.has("flamethrower")
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
	guards[2].weapon_kind = "pistol"
	p.loot_weapon(guards[0])
	p.loot_weapon(guards[1])
	check(p.guns.size() == 2 and p.equipped_gun == "smg", "Two distinct guns can be carried")
	var reserve: int = p.controls.reserves.get("pistol", 0)
	p.loot_weapon(guards[2])
	check(guards[2].gun_taken and p.controls.reserves.pistol == reserve + 3, "A duplicate gun becomes reserve ammunition (at least 3 bullets)")
	guards[2].gun_taken = false
	guards[2].weapon_kind = "smg"
	p.select_gun(0)
	check(p.ammunition == 3, "Switching restores independent pistol ammunition")
	p.position = Vector2(300, 236)
	p.attack_cooldown = 0
	guards[0].position = Vector2(600, 236)
	guards[0].sees_player = false
	guards[0].alert_state = IntroGuard.State.PATROL
	p.fire_gun()
	check(p.ammunition == 2 and guards[0].acoustic_left > 0.0 and guards[0].facing < 0.0, "Pistol shot is heard and faced even when another guard investigates")
	p.select_gun(1)
	check(p.equipped_gun == "smg" and p.ammunition == 12, "Switching back preserves the scarce SMG pickup magazine")
	p.ammunition = 0
	p.attack_cooldown = 0
	p.fire_gun()
	check(p.ammunition == 0, "Empty trigger fires nothing")
	check(not WeaponArtCheck.has_flamethrower(), "Flamethrower is out of the game")
	guards[0].position = Vector2(900, 656)
	await frames(60)
	# Enemy rounds use the player collision layer and respect dodge immunity.
	guards[0].position = Vector2(350, 236)
	guards[0].shot_direction = Vector2.LEFT
	guards[0].burst_left = 1
	p.health = 6
	p.invulnerability_left = 0
	guards[0].shoot_weapon()
	await frames(20)
	check(p.health == 4, "Keeper projectile damages Miro (a pistol round takes a heart)")
	p.invulnerability_left = 0
	p.dodge_left = 1
	guards[0].shoot_weapon()
	await frames(10)
	check(p.health == 4, "Dodge protects Miro from gunfire")
	print("WEAPON_INVENTORY_RESULT: ", checks - failures.size(), "/", checks, " passed")
	quit(0 if failures.is_empty() else 1)
