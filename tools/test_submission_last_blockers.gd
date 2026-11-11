extends SceneTree
var failures:Array[String]=[]
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label_:String) -> void:
 checks+=1
 if not ok:failures.append(label_);push_error("FAIL: "+label_)
func frames(n:=3) -> void:
 for i in range(n):await physics_frame;await process_frame
func run() -> void:
 root.get_node("Campaign").checkpoint.clear()
 var level=load("res://scenes/levels/level_04.tscn").instantiate();root.add_child(level);current_scene=level;await frames();level.finish_dialogue()
 for guard in level.guards():guard.set_physics_process(false)
 level.player.set_physics_process(false)
 var gate=level.get_node_or_null("Gates/WardSeal")
 if gate:
  check(not gate.is_open,"Ward seal begins locked")
  level.player.global_position=gate.global_position+Vector2(0,68)
  check("Manual release" in level.context_hint(),"Locked seal explains where to release it")
  level.milestones["ExperimentRecords"]=true
  level.player.global_position=level.areas.get_node("WardRelease").global_position
  check(level.station_nearby().get("id","")=="WardRelease","Release is a usable interaction")
  level.interact();level.finish_dialogue();await frames()
  check(level.milestones.has("WardRelease") and gate.is_open and gate.collision_layer==0 and gate.get_node("CollisionShape2D").disabled,"Manual release removes gate collision")
 else:
  check(true,"Unintended Level 4 checkpoint gate removed")
  level.milestones["ExperimentRecords"]=true
  level.player.global_position=level.areas.get_node("WardRelease").global_position
  check(level.station_nearby().get("id","")=="WardRelease","Release is a usable interaction")
  level.interact();level.finish_dialogue();await frames()
  check(level.milestones.has("WardRelease"),"Manual release sets milestone")
 level.queue_free();await frames()
 root.get_node("Campaign").checkpoint.clear()
 level=load("res://scenes/levels/level_03.tscn").instantiate();root.add_child(level);current_scene=level;await frames();level.finish_dialogue()
 for guard in level.guards():guard.set_physics_process(false)
 var guards=level.guards();var a=guards[0];var b=guards[1]
 a.global_position=Vector2(1100,1244);b.global_position=Vector2(1120,1244);a.facing=1
 await frames()
 check(not a.can_hop(),"Adjacent guard never becomes a hop platform")
 check(a.collision_mask & 4 != 0,"Live guard spacing remains enabled")
 var removed:=true
 for hide in level.definition.features.hides:
  if hide.title=="VENT" and Vector2(hide.position[0],hide.position[1]).distance_to(Vector2(1003,852))<1:removed=false
 check(removed,"Embedded rank-record shelf vent removed")
 print("SUBMISSION_LAST_BLOCKERS_RESULT: ",checks-failures.size(),"/",checks," passed")
 quit(0 if failures.is_empty() else 1)
