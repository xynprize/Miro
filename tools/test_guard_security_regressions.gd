extends "res://tools/test_intro.gd"

func run() -> void:
	var campaign = root.get_node("Campaign")
	campaign.checkpoint.clear()
	level = load("res://scenes/levels/level_03.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(12)
	level.finish_dialogue()
	level.player.set_physics_process(false)
	level.player.in_hiding_spot = true
	var party: Array = level.guards().slice(0,3)
	for g in level.guards():
		g.set_physics_process(false)
		g.position = Vector2(-500,-500)
	var a = party[0]
	var b = party[1]
	a.position = Vector2(800,628)
	b.position = Vector2(880,628)
	b.is_dead = true
	a.facing = 1.0
	check(a.notices_body(b.position), "Same-storey corpse is visible above floor ray")
	a._physics_process(0.016)
	check(a.seen_bodies.has(b.get_instance_id()), "Corpse discovery records a reaction once")
	a.alert_state = IntroGuard.State.PATROL
	a.distracted = true
	a.conversation_hold = true
	level.player.position = a.position + Vector2(-100,0)
	a.take_damage(1,true)
	check(not a.distracted and not a.conversation_hold and a.alert_state==IntroGuard.State.SEARCH and a.facing<0, "Shot survivor breaks conversation and turns to attack origin")
	a.position = Vector2(800,628)
	a.facing = 1
	level.make_noise(Vector2(700,628),500)
	check(a.facing<0 and a.turn_wait>0, "Gunshot acknowledged even when investigator post is occupied")
	a.facing = 1
	level.make_noise(Vector2(700,490),500)
	check(a.facing<0 and a.acoustic_left>0, "Ceiling watcher impact is heard across the same storey")
	level.player.in_hiding_spot = false
	level.player.position = Vector2(100,236)
	level.player.set_physics_process(true)
	await frames(6)
	level.update_checkpoint()
	# Save a complete snapshot at an eligible landing, then mutate the live run.
	level.milestones["RemoteTerminal"] = true
	level.player.position = Vector2(500,432)
	await frames(6)
	level.update_checkpoint()
	var saved: Dictionary = campaign.checkpoint.duplicate(true)
	check(not saved.is_empty(), "Eligible storey captures retry snapshot")
	a.is_dead = true
	level.security_checkpoint["later_device"] = {"destroyed":true}
	level.milestones["RankRecord"] = true
	level.update_checkpoint()
	check(campaign.checkpoint==saved, "Later kills, security and objectives cannot rewrite an older checkpoint")
	var early: Vector2 = level.checkpoint_safe_position(Vector2(800,1048),{})
	check(early==level.get_node("LevelPlan/PlayerSpawn").global_position, "Incomplete earlier objective rejects deeper checkpoint")
	check(not level.model_incident_valid(level.incident_id+1), "Stale model incident is rejected")
	check(level.player.respawn_cloak_left<=2.0, "Spawn protection is bounded to two seconds")
	print("GUARD_SECURITY_REGRESSIONS_RESULT: ",checks-failures.size(),"/",checks)
	quit(0 if failures.is_empty() else 1)
