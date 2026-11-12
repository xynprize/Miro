extends "res://tools/test_intro.gd"
func run() -> void:
	await fresh()
	await supplies()
	level.player.has_gun = true
	level.player.ammunition = 6
	level.player.position = Vector2(300, 236)
	for guard in level.guards():
		guard.set_physics_process(false)
		guard.position = Vector2(900, 656)
	var target = level.guards()[0]
	target.position = Vector2(350, 236)
	level.player.facing = 1
	level.player.fire_gun()
	check(not target.is_dead, "Round travels instead of applying instant damage")
	await frames(12)
	check(target.health == 12, "Traveling bullet hits target")
	for shot in range(3):
		level.player.attack_cooldown = 0
		level.player.fire_gun()
		await frames(12)
	check(target.is_dead, "Four pistol shots defeat a guard")
	var observer = level.guards()[1]
	observer.position = Vector2(600, 236)
	observer.sees_player = false
	observer.alert_state = IntroGuard.State.PATROL
	level.player.facing = -1
	level.player.attack_cooldown = 0
	level.player.fire_gun()
	check(observer.acoustic_left > 0.0 and observer.facing < 0.0, "Every fired shot is acknowledged by nearby guards")
	await frames(45)
	level.player.position = Vector2(220, 236)
	observer.position = Vector2(280, 236)
	level.player.facing = 1
	level.player.attack_cooldown = 0
	level.player.fire_gun()
	await frames(20)
	check(not observer.is_dead, "Locked cell wall blocks swept bullet")
	print("MOUSE_PROJECTILE_RESULT: ", checks - failures.size(), "/", checks, " passed")
	quit(0 if failures.is_empty() else 1)
