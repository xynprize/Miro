extends "res://tools/test_intro.gd"

func run() -> void:
	await fresh()
	await supplies()
	level.open_door()
	for guard in level.guards():
		guard.set_physics_process(false)
		guard.position = Vector2(1000, 650)
	var player = level.player
	player.position = Vector2(100, 600)
	check(not level.in_cover(player.position), "Test starts outside marked cover")
	player.toggle_stealth()
	check(not player.is_concealed, "Stealth requires shadow cover to activate")

	player.position = Vector2(160, 236)
	player.velocity = Vector2.ZERO
	await frames(2)
	check(level.in_cover(player.position), "Positioned inside shadow cover")
	player.toggle_stealth()
	check(player.is_concealed and player.stealth_remaining == 5, "Stealth activates in shadow cover")

	Input.action_press("move_right")
	await frames(3)
	check(player.is_concealed and is_equal_approx(player.velocity.x, player.movement_speed * 0.55), "Moving stealth uses 55 percent walking speed")
	Input.action_release("move_right")

	Input.action_press("jump")
	await frames(1)
	Input.action_release("jump")
	check(player.is_concealed and player.velocity.y < 0, "Jumping preserves stealth")

	var remaining: float = player.stealth_remaining
	level.start_dialogue([["MIRO", "Wait."]])
	await frames(90)
	check(is_equal_approx(remaining, player.stealth_remaining), "Dialogue freezes stealth duration")
	level.finish_dialogue()

	# Test leaving shadow reveals player
	player.position = Vector2(100, 600)
	await frames(1)
	check(not player.is_concealed and player.stealth_cooldown_left > 7, "Leaving shadow ends stealth immediately and starts cooldown")

	# Cooldown prevents reactivation
	player.toggle_stealth()
	check(not player.is_concealed, "Cooldown prevents reactivation")

	var cooldown: float = player.stealth_cooldown_left
	level.paused = true
	await frames(60)
	check(is_equal_approx(cooldown, player.stealth_cooldown_left), "Pause freezes cooldown")
	level.paused = false

	await frames(int(cooldown * 60) + 10)
	player.position = Vector2(160, 236)
	player.toggle_stealth()
	check(player.is_concealed, "Stealth becomes available after cooldown")

	var guard = level.guards()[0]
	guard.position = player.position + Vector2(30, 0)
	player.check_guard_contact()
	check(player.is_concealed, "Nearby guard without contact does not reveal player")

	guard.position = player.position + Vector2(10, 0)
	player.check_guard_contact()
	check(not player.is_concealed and guard.alert_state == IntroGuard.State.ALERT and guard.sees_player, "Body overlap breaks stealth and alerts contacted guard")
	check(player.stealth_cooldown_left == 8, "Contact starts full cooldown")

	guard.is_dead = true
	player.stealth_cooldown_left = 0
	player.toggle_stealth()
	check(player.is_concealed, "Dead guards do not break stealth")

	player.toggle_stealth()
	check(not player.is_concealed and player.stealth_cooldown_left == 8, "Manual cancellation starts cooldown")

	print("TIMED_STEALTH_RESULT: ", checks - failures.size(), "/", checks, " passed")
	quit(0 if failures.is_empty() else 1)
