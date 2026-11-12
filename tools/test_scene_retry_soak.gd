extends SceneTree
var checks := 0
var failures: Array[String] = []
var snapshots: Array = []
var started := Time.get_ticks_msec()
func _initialize() -> void: call_deferred("run")
func _process(_delta: float) -> bool:
	if Time.get_ticks_msec()-started > 180000:
		push_error("FAIL: scene retry soak exceeded wall-clock timeout")
		quit(2)
	return false
func frames(count: int) -> void:
	for i in range(ceili(count * Engine.physics_ticks_per_second / 60.0)): await physics_frame
	await process_frame
func check(ok: bool, label_: String) -> void:
	checks += 1
	if not ok:
		failures.append(label_)
		push_error("FAIL: "+label_)
func run() -> void:
	var campaign=root.get_node("Campaign")
	var controller=root.get_node("ControllerSettings")
	var bindings=root.get_node("InputBindings")
	var spatial=root.get_node("SpatialAudio")
	var music=root.get_node("MusicDirector")
	var original_mode: bool=controller.using_controller
	var original_preset: String=bindings.preset
	await frames(6)
	var base_nodes := get_node_count()
	var base_sources: int=spatial.audio_viewport.get_child_count()
	var level
	for difficulty in campaign.DIFFICULTIES:
		campaign.difficulty_override=difficulty
		for number in range(1,6):
			campaign.checkpoint.clear()
			var path := "res://scenes/intro.tscn" if number == 1 else "res://scenes/levels/level_%02d.tscn" % number
			level=load(path).instantiate()
			root.add_child(level)
			current_scene=level
			await frames(6)
			# A cached supply anchor can permit one extra valid prop on retry.
			# Compare the structural tree separately from that bounded variation;
			# scene teardown and zero-orphan checks below still include every prop.
			var settled_props: int = level.world_features.props.size()
			var settled_nodes: int = get_node_count()-settled_props
			for retry in range(6):
				var label_: String="%s floor%d entry%d" % [difficulty,number,retry]
				check(level.player.max_health == int(campaign.DIFFICULTIES[difficulty].health),label_+" difficulty health")
				check(not level.player.is_dead,label_+" player alive at spawn")
				check(get_node_count()-level.world_features.props.size() == settled_nodes,label_+" settled structural node count remains stable")
				check(absi(level.world_features.props.size()-settled_props)<=1,label_+" generated prop variation remains bounded")
				check(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)==0,label_+" no orphans")
				for guard in level.guards():
					if not guard is IntroGuard: continue
					guard.asleep=true
					check(guard.is_in_group("discoverable_guards"),label_+" sleeping guard registered")
					guard.asleep=false
					guard.is_dead=true
					check(guard.is_in_group("discoverable_guards"),label_+" dead guard registered")
					guard.is_dead=false
					check(not guard.is_in_group("discoverable_guards"),label_+" revived guard removed")
				controller.using_controller=retry%2 == 0
				bindings.preset=["Default","Bumper Jumper","Tactical","Bumper Jumper Tactical","Southpaw"][retry%5]
				bindings.apply()
				check(controller.prompt("[E] Interact") == (controller.pad_prompt("[E] Interact") if controller.using_controller else bindings.keyboard_prompt("[E] Interact")),label_+" prompt follows current bindings")
				music.prefetch_track("swag")
				music.prefetch_track("cyberpunk")
				music.prefetch_track("sumcrazy")
				if not level.dialogue.is_empty(): level.finish_dialogue()
				level.emit_effect("hit",level.player.global_position)
				var p=level.player
				p.has_gun=true
				p.guns.assign(["smg"])
				p.equipped_gun="smg"
				p.ammunition=100
				p.controls.active="smg"
				p.fire_gun()
				snapshots.append({"floor":number,"difficulty":difficulty,"retry":retry,"nodes":get_node_count(),"sources":spatial.audio_viewport.get_child_count(),"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC)})
				if retry < 5:
					var event:=InputEventAction.new()
					event.action="retry"
					event.pressed=true
					level._unhandled_input(event)
					await scene_changed
					level=current_scene
					await frames(6)
			level.queue_free()
			current_scene=null
			await frames(8)
			check(get_node_count()==base_nodes,"%s floor%d releases all scene nodes" % [difficulty,number])
			check(spatial.audio_viewport.get_child_count()==base_sources,"%s floor%d releases spatial sources" % [difficulty,number])
			check(get_nodes_in_group("discoverable_guards").is_empty(),"%s floor%d leaves no stale body registry" % [difficulty,number])
			print("SOAK_FLOOR_COMPLETE ",difficulty," ",number)
	bindings.preset=original_preset
	bindings.apply()
	controller.using_controller=original_mode
	campaign.difficulty_override=""
	var file:=FileAccess.open("user://scene-retry-soak.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"entries":snapshots,"wall_ms":Time.get_ticks_msec()-started},"\t"))
	print("SCENE_RETRY_SOAK_RESULT: ",checks-failures.size(),"/",checks," passed; entries=",snapshots.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
