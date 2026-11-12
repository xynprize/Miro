extends "res://tools/test_intro.gd"
func run() -> void:
	level=load("res://scenes/levels/level_03.tscn").instantiate()
	root.add_child(level)
	current_scene=level
	await frames(15)
	level.finish_dialogue()
	for guard in level.guards():
		guard.set_physics_process(false)
		guard.position=Vector2(-600,-600)
	var world=level.world_features
	var victim=level.get_node("Guards/StairKeeper")
	var player=level.player
	player.set_physics_process(false)
	player.has_supplies=true
	player.position=Vector2(385,432)
	victim.position=Vector2(400,432)
	victim.facing=1
	victim.alert_state=IntroGuard.State.PATROL
	var kills: int=player.casualty_count
	level.interact()
	check(world.strangle_active() and not victim.asleep,"E begins a brief takedown instead of instantly sleeping the guard")
	world.set_process(false)
	player.has_gun=true
	player.guns.assign(["smg"])
	player.equipped_gun="smg"
	player.ammunition=4
	player.controls.active="smg"
	Input.action_press("use_item")
	await frames(2)
	check(player.ammunition==4,"Held fire cannot shoot during the brief strangle commitment")
	Input.action_release("use_item")
	world.update_strangle(0.10)
	check(world.strangle_left>0 and not victim.asleep,"Progress ring remains active before the 0.24s finish")
	level.paused=true
	var left: float=world.strangle_left
	world.set_process(true)
	await frames(20)
	check(is_equal_approx(left,world.strangle_left),"Pause freezes the quick strangle progress")
	level.paused=false
	world.set_process(false)
	world.update_strangle(0.13)
	check(not victim.asleep,"Takedown is still pending at 0.23 seconds")
	world.update_strangle(0.02)
	check(victim.asleep and victim.strangled and not victim.is_dead and not world.strangle_active(),"At 0.24 seconds the guard enters the same sleeping pose, alive")
	check(player.casualty_count==kills,"Quick strangle adds no kill or blood casualty")
	victim.asleep=false
	victim.strangled=false
	victim.alert_state=IntroGuard.State.PATROL
	level.try_strangle()
	player.health-=1
	world.update_strangle(0.25)
	check(not victim.asleep and not world.strangle_active() and not victim.conversation_hold,"Taking damage interrupts the attempt without granting a takedown")
	# Compare discovery of an unconscious colleague with discovery of a bloody corpse.
	player.in_hiding_spot=true
	player.position=Vector2(950,432)
	var observer=level.get_node("Guards/DeepKeeper")
	observer.position=Vector2(500,432)
	observer.facing=-1
	observer.alert_state=IntroGuard.State.PATROL
	observer.pursuing=false
	observer.suspicion=0
	victim.fall_asleep()
	var nearby=level.get_node("Guards/EntryClerk")
	nearby.position=Vector2(540,432)
	nearby.alert_state=IntroGuard.State.PATROL
	nearby.pursuing=false
	observer._physics_process(1.0/60)
	check(not nearby.pursuing,"Seeing a sleeper does not raise a floor-wide pursuit")
	check(observer.alert_state==IntroGuard.State.SEARCH and not observer.pursuing and observer.suspicion<1 and observer.search_left<=7,"A sleeping guard triggers a lower-suspicion local search")
	check("Sleeping" in world.subtitle.text or world.subtitle.text.length()>0,"Discovery uses a dedicated sleep reaction subtitle")
	observer.alert_state=IntroGuard.State.PATROL
	observer.pursuing=false
	observer.suspicion=0
	victim.asleep=false
	victim.is_dead=true
	observer._physics_process(1.0/60)
	check(level.guard_assignments.has(nearby.get_instance_id()) and (nearby.search_left>0 or nearby.turn_wait>0),"Corpse discovery gives a nearby Keeper a coordinated search or cover job")
	check(observer.pursuing and observer.suspicion==1 and observer.search_left>10,"A dead guard still triggers the stronger grief and pursuit response")
	observer.seen_bodies.clear()
	observer.seen_sleepers.clear()
	observer.alert_state=IntroGuard.State.ALERT
	observer.pursuing=true
	victim.is_dead=false
	victim.asleep=true
	observer._physics_process(1.0/60)
	check(observer.pursuing,"Noticing a sleeper never clears an existing pursuit")
	print("STRANGLE_REACTIONS_RESULT: ",checks-failures.size(),"/",checks," passed")
	quit(0 if failures.is_empty() else 1)
