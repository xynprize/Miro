extends SceneTree
var checks := 0
var failures: Array[String] = []
var level
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1
	if not ok:failures.append(label_);push_error(label_)
func frames(n: int) -> void:
	for i in range(n):
		if is_instance_valid(level) and not level.dialogue.is_empty():level.finish_dialogue()
		await physics_frame
func fresh(n: int) -> void:
	if is_instance_valid(level):level.queue_free();await process_frame;await process_frame
	root.get_node("Campaign").checkpoint.clear()
	level=load("res://scenes/intro.tscn" if n==1 else "res://scenes/levels/level_%02d.tscn"%n).instantiate();root.add_child(level);current_scene=level
	await frames(ceili(Engine.physics_ticks_per_second*0.3));level.finish_dialogue();level.set_process(false);level.world_features.set_process(false);level.player.set_physics_process(false);level.player.in_hiding_spot=true
	for g in level.guards():g.set_physics_process(false);g.position=Vector2(-500,-500)
	if level.has_node("Gates"):
		for gate in level.get_node("Gates").get_children():gate.unlock()
	await frames(2)
func run() -> void:
	for n in range(1,6):
		await fresh(n)
		var nav=preload("res://scripts/guard_navigation.gd").new(level)
		var valid:=true
		for id in nav.points.size():
			if not nav.clear_body(nav.points[id]):valid=false
			for edge in nav.links[id]:
				if edge.ladder==null and absf(nav.points[id].y-nav.points[edge.id].y)>28.1:valid=false
		check(valid,"Map %d routes have standing clearance and no two-block jumps"%n)
	for rate in [60,360]:
		Engine.physics_ticks_per_second=rate
		await fresh(3)
		var g=level.guards()[0]
		g.position=Vector2(970,236);g.velocity=Vector2.ZERO;g.conversation_hold=false;g.illness_started=true
		g.alert_state=g.State.SEARCH;g.last_known_position=Vector2(1100,236);g.pursuing=true;g.search_left=14;g.set_physics_process(true)
		var min_x:float=g.position.x
		var max_rise:=0.0
		for i in range(rate*5):
			await frames(1)
			min_x=minf(min_x,g.position.x)
			max_rise=maxf(max_rise,236-g.position.y)
		check(g.position.x<1008 and max_rise<2,"Actual map two-block wall is impassable at %dHz"%rate)
		check(min_x<900,"Blocked search covers a wider reachable area at %dHz"%rate)
		# Visible Miro stands on the actual two-block structure; the guard has a gun.
		g.set_physics_process(false);g.position=Vector2(950,236);g.velocity=Vector2.ZERO;g.facing=1;g.distracted=false
		level.player.position=Vector2(1036,180);level.player.in_hiding_spot=false;level.player.end_stealth();level.player.crouching=false
		level.player.set_physics_process(true)
		await frames(rate/5)
		level.player.set_physics_process(false)
		check(g.can_see_point(level.player.position),"Guard sees standing Miro atop actual two-block obstacle at %dHz"%rate)
		g.alert_state=g.State.ALERT;g.suspicion=1;g.ammunition=8;g.attack_timer=0;g.windup=0;g.set_physics_process(true)
		var shots_before: int=g.ammunition
		await frames(rate*2)
		check(g.ammunition<shots_before,"Guard attacks visible elevated Miro at %dHz"%rate)
		# Route from one storey to another follows authored ladders, not wall jumping.
		await fresh(3)
		g=level.guards()[0];g.position=Vector2(650,433);g.velocity=Vector2.ZERO;g.conversation_hold=false;g.illness_started=true
		var nav=g.navigation()
		var path=nav.route(g.position,Vector2(1456,433))
		check(not path.is_empty() and path[-1].point.distance_to(Vector2(1456,433))<20,"Wide floor route exists at %dHz"%rate)
		g.alert_state=g.State.SEARCH;g.last_known_position=Vector2(1456,433);g.pursuing=true;g.search_left=25;g.set_physics_process(true)
		var arrived:=false
		for i in range(rate*18):
			await frames(1)
			if g.position.distance_to(Vector2(1456,433))<28:arrived=true;break
		check(arrived,"Guard actually roams across the authored floor at %dHz: %s"%[rate,g.position])
		await fresh(3)
		g=level.guards()[0]
		var ladder=level.areas.get_node("FirstLadder")
		var start:=Vector2(ladder.position.x-100,433)
		var target:=Vector2(ladder.position.x-70,236)
		g.position=start;g.velocity=Vector2.ZERO;g.conversation_hold=false;g.illness_started=true
		g.alert_state=g.State.SEARCH;g.last_known_position=target;g.pursuing=true;g.search_left=20;g.set_physics_process(true)
		var landed:=false
		for i in range(rate*8):
			await frames(1)
			if g.position.distance_to(target)<24 and g.is_on_floor():landed=true;break
		check(landed,"Planned route uses authored ladder and exits onto target storey at %dHz"%rate)
	print("GUARD_INTELLIGENCE_RESULT: ",checks-failures.size(),"/",checks)
	quit(0 if failures.is_empty() else 1)
