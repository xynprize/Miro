extends "res://tools/test_intro.gd"

func floor_scene(number: int) -> void:
 if is_instance_valid(level):
  level.queue_free()
  await frames(2)
 root.get_node("Campaign").checkpoint.clear()
 level=load("res://scenes/levels/level_%02d.tscn" % number).instantiate()
 root.add_child(level)
 current_scene=level
 await frames(5)
 level.finish_dialogue()
 level.player.set_physics_process(false)
 for g in level.guards():
  g.set_physics_process(false)
  g.position=Vector2(-1000,-1000)
 level.world_features.set_process(false)

func run() -> void:
 for number in [2,3,4,5]:
  await floor_scene(number)
  var moved:=0
  for turret in get_nodes_in_group("tower_turrets"):
   if not turret.has_meta("security_origin"):continue
   moved+=1
   var ray=PhysicsRayQueryParameters2D.create(turret.to_global(Vector2(0,-2)), turret.to_global(Vector2(0,8)),1)
   check(not turret.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(),"Moved turret is flush against solid mounting surface")
   var muzzle:Vector2=turret.to_global(Vector2(0,-30))
   ray=PhysicsRayQueryParameters2D.create(muzzle,muzzle+Vector2.UP.rotated(turret.rotation)*8,1)
   check(turret.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(),"Moved turret muzzle opens into room")
   var id:String=root.get_node("Campaign").security_device_id(number,"turret",turret.get_meta("security_origin"))
   level.record_security_checkpoint(turret,false)
   check(level.security_checkpoint.has(id),"Moved turret retains legacy checkpoint identity")
   level.restore_checkpoint_security({"security":level.security_checkpoint.duplicate(true)})
   check(turret.disabled,"Moved turret restores hacked/disabled state")
  check(moved==level.definition.get("features",{}).get("hazards",[]).filter(func(h):return h.kind=="turret" and h.has("legacy_position")).size(),"All moved turrets verified on floor %d"%number)
 for number in [4,5]:
  await floor_scene(number)
  var w=level.world_features
  var p=level.player
  var flasks=w.props.filter(func(n):return n.get_meta("lab_flask",false))
  check(flasks.size()==(12 if number==4 else 2),"Exactly the existing red flasks on floor %d" % number)
  var nav=load("res://scripts/guard_navigation.gd").new(level)
  for bottle in w.props.filter(func(n):return n.get_meta("lab_bottle",false)):
   p.global_position=bottle.global_position+Vector2(-4,-2)
   p.health=p.max_health
   check(w.try_interact() and not bottle.used,"Full health preserves the pale lab bottle")
   p.health=p.max_health-1
   check(w.try_interact() and bottle.used and p.health==p.max_health,"Pale lab bottle heals half a heart")
   var consumed:Array=level.used_potion_positions()
   bottle.used=false
   level.restore_checkpoint_loot({"used_potions":consumed})
   await frames(5)
   check(bottle.used,"Pale bottle consumption survives checkpoint restore")
  for flask in flasks:
   var found:=false
   for point in nav.points:
    p.position=point
    if w.nearby_prop()==flask:
     found=true
     break
   check(found,"Flask reachable from clear standing surface: %s" % flask.position)
   if not found: continue
   p.health=p.max_health
   check(w.try_interact() and not flask.used,"Full health preserves flask")
   p.health=p.max_health-2
   check(w.try_interact() and flask.used and p.health==p.max_health,"Flask heals exactly one heart")
   var saved:Array=level.used_potion_positions()
   flask.used=false
   level.restore_checkpoint_loot({"used_potions":saved})
   await frames(3)
   check(flask.used,"Consumed flask survives checkpoint restoration")
 await floor_scene(5)
 var door=level.areas.get_node("ForestViewpoint")
 level.player.position=door.position+Vector2(0,16)
 level.interact()
 check(not is_instance_valid(level.cinematic),"Final door rejects unfinished fight")
 level.milestones={"DefeatExchange":true}
 level.interact()
 check(not is_instance_valid(level.cinematic),"Final door also requires the sigil")
 level.milestones["FinalSigil"]=true
 level.sigil_placed=true
 level.player.position=Vector2(880,852)
 level.interact()
 check(not is_instance_valid(level.cinematic),"Old viewpoint cannot start ending")
 level.player.position=door.position+Vector2(0,16)
 level.interact()
 var ending=level.cinematic
 level.interact()
 check(is_instance_valid(ending) and level.cinematic==ending,"Repeated door input starts exactly one ending")
 ending.finish()
 await frames(3)
 level.interact()
 check(level.completed and not is_instance_valid(level.cinematic),"Completed door never restarts ending")
 await floor_scene(5)
 var boss=load("res://scenes/brother_boss.tscn").instantiate()
 boss.level=level
 boss.position=Vector2(560,853)
 boss.start_health=12
 boss.engagement=4
 level.add_child(boss)
 boss.set_physics_process(false)
 for phase in [boss.Phase.TELEGRAPH,boss.Phase.RUSH,boss.Phase.RELEASE,boss.Phase.REPOSITION]:
  boss.current_phase=phase
  var health:int=boss.health
  boss.take_damage(1,true)
  check(boss.health==health and not boss.is_vulnerable,"Attack phase rejects damage even with legacy bypass")
 boss.begin_release()
 check(not boss.is_vulnerable and boss.phase_left>0,"Throw has distinct guarded finish")
 boss.begin_recovery()
 var health:int=boss.health
 boss.take_damage(1)
 check(boss.health==health-1 and boss.is_vulnerable,"Recovery is the damage authority")
 print("FINAL_GAMEPLAY_RESULT: ",checks-failures.size(),"/",checks)
 quit(0 if failures.is_empty() else 1)
