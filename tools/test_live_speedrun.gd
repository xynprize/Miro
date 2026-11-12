extends "res://tools/test_intro.gd"
func scene(number: int) -> void:
 if is_instance_valid(level):
  level.queue_free()
  await frames(3)
 root.get_node("Campaign").checkpoint.clear()
 level=load("res://scenes/intro.tscn" if number==1 else "res://scenes/levels/level_%02d.tscn"%number).instantiate()
 root.add_child(level)
 current_scene=level
 await frames(8)
 level.finish_dialogue()
 level.player.set_physics_process(false)
 for g in level.guards():g.set_physics_process(false)

func run() -> void:
 await scene(2)
 var alden=level.guards().filter(func(g):return g.guard_name=="Alden")[0]
 for state in [IntroGuard.State.PATROL,IntroGuard.State.SEARCH]:
  alden.asleep=false
  alden.alert_state=state
  alden.pursuing=state==IntroGuard.State.SEARCH
  alden.facing=1
  alden.search_left=10
  alden.last_known_position=alden.position+Vector2(-150,0)
  level.player.position=alden.position+Vector2(-22,0)
  level.player.health=level.player.max_health
  level.world_features.next_strangle_requires_hold=true
  Input.action_press("interact")
  check(level.try_strangle(),"Alden accepts held strangle while patrolling/searching")
  alden.set_physics_process(true)
  await frames(25)
  alden.set_physics_process(false)
  Input.action_release("interact")
  check(alden.asleep,"Alden held strangle finishes")
 var w=level.world_features
 var turrets:Array=get_nodes_in_group("tower_turrets").filter(func(t):return level.is_ancestor_of(t) and not t.is_in_group("security_cameras") and not t.disabled)
 check(not turrets.is_empty(),"First turret exists for its automatic tutorial")
 if not turrets.is_empty():
  level.player.global_position=turrets[0].target_point()+Vector2(40,0)
  w.turret_hinted=false;w.thought_seen.erase("turret_hint");w.thought_left=0;w.pending_thoughts.clear()
  w.update_turret_hint()
  check(w.turret_hinted and w.thought_seen.has("turret_hint") and w.thought_bubble.text_label.text==w.TURRET_HINT,"Turret proximity automatically plays its own hint")
 await scene(1)
 var judas=level.guards().filter(func(g):return g.sick_guard)[0]
 judas.key_taken=false
 judas.facing=1
 level.player.position=judas.position+Vector2(-22,0)
 check(level.world_features.strangle_target()!=judas,"Judas retains tutorial key prerequisite")
 var music=root.get_node("MusicDirector")
 music.start_floor(2)
 music.track_time=18
 music.start_floor(2)
 check(music.track_id==music.FIRST[2] and music.track_time==0,"Retry restarts the current floor's cue")
 music.section_id=""
 music.start_floor(5)
 check(music.track_id.is_empty(),"New Foundation visit preserves its quiet opening")
 music.guitar_section()
 music.track_time=18
 music.start_floor(5)
 check(music.track_id==music.GUITAR_TRACK and music.track_time==0,"Foundation retry resumes guitar music immediately")
 music.second_section(5)
 music.track_time=18
 music.start_floor(5)
 check(music.track_id==music.SECOND[5] and music.track_time==0,"Deep Foundation retry restarts second cue")
 await scene(5)
 var p=level.player
 var c=p.controls
 p.position=Vector2(560,853)
 p.health=p.max_health
 p.facing=1
 c.collect_guitar()
 c.select_item("guitar")
 c.focus=false
 c.select_item("shank")
 c.pad_aim=true
 p.aim_direction=Vector2.UP
 check(p.knife_aim_direction().is_equal_approx(Vector2.UP),"Held knife follows free aim")
 var victim=level.guards()[0]
 for g in level.guards():g.position=Vector2(-2000,-2000)
 victim.position=p.position+Vector2(0,-30)
 victim.asleep=false
 victim.health=2
 p.attack_cooldown=0
 p.shank()
 check(p.melee_direction.is_equal_approx(Vector2.UP) and victim.health<2,"Knife swing and hit follow the aimed direction")
 victim.position=Vector2(-2000,-2000)
 c.pad_aim=false
 c.select_item("guitar")
 check(not c.guitar_guarding() and not c.block_melee(p.position+Vector2(20,0)),"Equipped guitar alone cannot block")
 Input.action_press("focus_item")
 c.focus=true
 check(c.guitar_guarding() and c.block_melee(p.position+Vector2(20,0)),"Held right click blocks frontal melee")
 check(not c.block_melee(p.position+Vector2(-20,0)),"Melee behind the guard remains dangerous")
 for guarding in [false,true]:
  c.focus=guarding
  if guarding:Input.action_press("focus_item")
  else:Input.action_release("focus_item")
  p.invulnerability_left=0
  p.health=p.max_health
  var shot=preload("res://scripts/weapon_projectile.gd").new()
  shot.level=level
  shot.enemy=true
  shot.niro_round=true
  shot.position=p.position+Vector2(-24,-5)
  shot.direction=Vector2.RIGHT
  level.add_child(shot)
  shot.set_physics_process(false)
  shot._physics_process(0.06)
  check(not shot.enemy if guarding else p.health<p.max_health,"Niro round deflects only with active right-click guard")
  shot.queue_free()
  await frames(2)
 Input.action_release("focus_item")
 c.focus=false
 var flow=level.flow
 flow.step=flow.Step.OFFICE
 flow.spawn_niro()
 level.finish_dialogue()
 var boss=level.brother
 boss.set_physics_process(false)
 boss.begin_release()
 check(boss.phase_left>=0.65 and not boss.is_vulnerable,"Niro has a substantial guarded attack finish")
 for row in range(4):
  for g in level.guards():
   if g!=boss:
    g.position=Vector2(-2000,-2000)
    g.set_physics_process(false)
  flow.wave_guards.clear()
  flow.row=row
  flow.engagement=row+1
  flow.final_waves_sent=0
  flow.final_wave_wait=0
  flow.update_final_waves(0.1)
  check(flow.wave_guards.size()==(0 if row==0 else 4),"Reinforcements respect encounter stage on storey %d"%row)
  for g in flow.wave_guards:
   check(is_instance_valid(g) and absf(g.position.y-flow.ROW_FLOOR_Y[row])<3,"Reinforcement stands on its current storey")
  flow.final_wave_wait=0
  flow.update_final_waves(0.1)
  check(flow.wave_guards.size()==(0 if row==0 else 4),"Crowd cap holds additional waves until space clears")
 check(level.areas.get_node("FinalOffer").kind=="brother","Remote offer retains automatic story trigger identity")
 print("LIVE_SPEEDRUN_RESULT: ",checks-failures.size(),"/",checks)
 quit(0 if failures.is_empty() else 1)
