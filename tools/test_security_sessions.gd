extends "res://tools/test_intro.gd"

func run() -> void:
	root.get_node("Campaign").checkpoint.clear()
	level = load("res://scenes/levels/level_03.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(12)
	level.finish_dialogue()
	level.player.set_physics_process(false)
	for guard in level.guards():guard.set_physics_process(false)
	var c = level.player.controls
	c.has_remote = true
	c.remote_unlocked = true
	var terminal = level.areas.get_node("RemoteTerminal")
	level.player.position = terminal.position + Vector2(-200, 0)
	var s = c.security()
	check("Authenticate" in s.execute("cameras hack"), "Security requires authentication within wireless range")
	level.world_features.terminal_authenticated = true
	c.logged_in[terminal.get_instance_id()] = true
	check(not level.milestones.has("RemoteTerminal"), "Authentication alone never opens checkpoint")
	var result: String = s.execute("cameras off")
	check(level.milestones.has("RemoteTerminal") and level.hack_remaining == 0.0, "Authenticated wireless camera command completes checkpoint without 90px cancellation")
	var elsewhere: int = level.world_features.security_storey(terminal.position.y)-1
	check(s.devices("security_cameras").all(func(cam):return level.world_features.security_storey(cam.position.y) != elsewhere), "Device list is scoped to Miro's storey")
	s.execute("cameras on")
	check(s.devices("security_cameras").any(func(cam):return cam.is_active), "Cameras on restores intact cameras")
	c.local_console = true
	check("Unknown command" in s.execute("cameras hack") and "Unknown command" in s.execute("turrets hack"), "Terminal exposes its own commands without an MP3-only message")
	c.local_console = false
	result = s.execute("cameras hack")
	check(s.viewing and not c.gameplay_ready(), "MP3 camera feed disables player actions")
	check(not level.controls_locked(), "Feed leaves guard and projectile simulation running")
	check(s.cameras.all(func(cam):return cam.is_active and level.world_features.security_storey(cam.position.y)==s.storey()), "Feed cycles only powered cameras on current storey")
	var key := InputEventAction.new()
	key.action = "climb_down"
	key.pressed = true
	s.handle_input(key)
	check(s.viewing, "W/S cycling keeps feed active")
	level.player.position = Vector2(-900, -900)
	s._process(0.01)
	check(not s.viewing and level.player.get_node("Camera2D").is_current(), "Losing terminal range restores player camera")
	level.player.position = terminal.position + Vector2(-200, 0)
	s.execute("turrets off")
	check(s.devices("tower_turrets").all(func(t):return t.disabled), "Turrets off affects current storey")
	s.execute("turrets on")
	check(s.devices("tower_turrets").all(func(t):return not t.disabled), "Turrets on restores surviving devices")
	s.execute("turrets hack")
	check(s.cooldown == 10.0 and s.devices("tower_turrets").any(func(t):return t.hack_left==1.5), "MP3 turret override lasts 1.5s with shared cooldown")
	check("cooling down" in s.execute("turrets hack"), "Repeated override cannot extend its duration")
	check(s.devices("tower_turrets").all(func(t):return t.HACK_GUARD_RANGE > t.RANGE), "Hacked turrets see guards farther than Miro")
	var network = level.world_features.vent_network
	var vents: Array = level.world_features.props.filter(func(p):return p.kind=="hide")
	var third = vents.filter(func(p):return level.world_features.security_storey(p.position.y)==2)[0]
	network.enter(third)
	var fourth = network.opening(1)
	level.milestones.clear()
	check(not network.passage_open(fourth), "Third-to-fourth storey duct cannot bypass checkpoint")
	level.complete_security_hack()
	for gate in level.get_node("Gates").get_children():gate.unlock()
	check(network.passage_open(fourth), "Checkpoint completion unlocks adjacent vent link")
	network.enter(fourth)
	var fifth = network.opening(1)
	check(not network.passage_open(fifth), "Later duct cannot bypass RankRecord")
	level.milestones["RankRecord"] = true
	check(network.passage_open(fifth), "Reading RankRecord unlocks next region")
	check(not level.definition.features.hazards.any(func(h):return h.kind=="turret" and h.position[0]<60 and h.position[1]>750 and h.position[1]<868), "Fourth-storey left turret removed")
	# Crossfire retains the same damage path as hostile fire and expires with
	# the override instead of changing allegiance in mid-flight.
	level.player.in_hiding_spot = false
	level.player.end_stealth()
	level.player.position = Vector2(450,432)
	level.player.health = 6
	level.player.invulnerability_left = 0.0
	var turret = s.devices("tower_turrets")[0] if not s.devices("tower_turrets").is_empty() else null
	# Select the original storey turret after moving Miro for a clear shot.
	if turret == null:
		for candidate in get_nodes_in_group("tower_turrets"):
			if not candidate.is_in_group("security_cameras"):turret=candidate;break
	turret.disabled = false
	turret.hack_left = 1.5
	var shot = Node2D.new()
	shot.set_script(preload("res://scripts/weapon_projectile.gd"))
	shot.level = level
	shot.position = level.player.position + Vector2(-20,-4)
	shot.direction = Vector2.RIGHT
	shot.override_turret = turret
	shot.crossfire = true
	level.add_child(shot)
	shot.set_physics_process(false)
	shot._physics_process(0.04)
	check(level.player.health<6, "Hacked turret crossfire still hurts Miro")
	await frames(2)
	print("SECURITY_SESSIONS_RESULT: ",checks-failures.size(),"/",checks)
	quit(0 if failures.is_empty() else 1)
