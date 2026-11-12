extends "res://tools/test_intro.gd"

func run() -> void:
	level = load("res://scenes/levels/level_02.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(8)
	level.finish_dialogue()
	var player = level.player
	player.set_physics_process(false)
	player.in_hiding_spot = true
	var port: Array = level.definition.features.ports[0]
	var point := Vector2(float(port[0]), float(port[1]))
	var party: Array = level.guards().slice(0, 3)
	for guard in level.guards():
		guard.set_physics_process(false)
		guard.global_position = Vector2(-500, -500)
	for i in party.size():
		party[i].global_position = point + Vector2([-144, -96, 0][i], 0)
		party[i].alert_state = IntroGuard.State.PATROL
		party[i].sees_player = false
	await physics_frame
	for i in range(8):
		level.make_noise(point + Vector2(i, 0), 600.0)
	if "--local-guard-model" in OS.get_cmdline_user_args():
		await create_timer(1.8).timeout
	var responders: Array = party.filter(func(g): return level.guard_assignments.get(g.get_instance_id(),{}).get("role","") == "investigate")
	check(responders.size() == 1, "Eight shots near the actual Level 2 terminal assign only one investigator")
	check(party.any(func(g): return g.alert_state == IntroGuard.State.PATROL and g.turn_wait >= 2.5), "A second guard covers from a distinct position")
	if not responders.is_empty():
		check(responders[0].last_known_position.distance_to(point) < 28.0, "Investigator follows the incident location")
	var jobs: Array = level.guard_assignments.values()
	check(jobs.size() >= 2 and jobs[0].point.distance_to(jobs[1].point) >= 56.0, "Investigator and cover posts are exclusive and separated")
	# Godot and Qwen settle the immediate response first.  The delayed Jev slot
	# uses only a still-vacant post, giving a lost-sighting search a third lane.
	await create_timer(6.0 if "--jev-guard-shadow" in OS.get_cmdline_user_args() else 1.4).timeout
	var perimeter_jobs: Array = level.guard_assignments.values().filter(func(job): return job.role == "perimeter")
	check(perimeter_jobs.size() == 1, "Delayed perimeter assignment fills one later search lane")
	if not perimeter_jobs.is_empty():
		check(perimeter_jobs[0].point.distance_to(point) >= 56.0, "Perimeter post stays clear of the incident post")
	print("GUARD_INCIDENTS_RESULT: ", checks - failures.size(), "/", checks)
	quit(0 if failures.is_empty() else 1)
