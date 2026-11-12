extends "res://tools/test_intro.gd"
func run() -> void:
 for number in [2,3,4]:
  if is_instance_valid(level):
   level.queue_free()
   await frames(3)
  level=load("res://scenes/levels/level_%02d.tscn"%number).instantiate()
  root.add_child(level)
  current_scene=level
  await frames(10)
  level.finish_dialogue()
  level.player.set_physics_process(false)
  for g in level.guards():g.set_physics_process(false)
  var art
  for node in level.get_children():
   if node.get_script()==preload("res://scripts/scaffold_art.gd"):art=node
  check(art!=null,"Authored art exists on floor %d"%number)
  if number in [2,3]:
   var made:=0
   for row in range(6):
    var floor_y:float=level.definition.storeys[row]
    for step in range(5 if number==2 else 4):
     var anchor:float=(220+step*330+row*37) if number==2 else (370+step*400+row*53)
     var width:float=52 if number==2 and row>=3 else 54 if number==2 else 26
     var height:float=52 if number==2 and row>=3 else 23 if number==2 else 44
     if anchor>float(level.definition.world_size[0])-120:continue
     var at:float=art.furniture_x(anchor,width,height,floor_y)
     if at==INF:continue
     made+=1
     var rect=Rect2(at-4,floor_y-height-4,width+8,height+3)
     var clear:=true
     for tile in level.definition.tiles:
      if rect.intersects(Rect2(tile[0]*28,tile[1]*28,28,28)):clear=false
     check(clear,"Background furniture clears all map blocks")
   check(made>=10,"Furniture remains distributed across floor %d"%number)
   for port in level.definition.features.get("ports",[]):
    for rect:Rect2 in art.furniture_rects.values():
     check(not rect.intersects(Rect2(Vector2(port[0],port[1])-Vector2(34,28),Vector2(68,48))),"Furniture clears service port")
  var conflict=level.get_node("InnerConflict")
  if is_instance_valid(conflict.frame):
   var shape=RectangleShape2D.new()
   shape.size=Vector2(60,52)
   var q=PhysicsShapeQueryParameters2D.new()
   q.shape=shape
   q.transform=Transform2D(0,conflict.frame.global_position+Vector2(0,-44))
   q.collision_mask=1
   check(level.get_world_2d().direct_space_state.intersect_shape(q).is_empty(),"Full painting frame clears raised blocks")
 await level_guards()
 print("LIVE_LAYOUT_RESULT: ",checks-failures.size(),"/",checks)
 quit(0 if failures.is_empty() else 1)

func level_guards() -> void:
 level.queue_free()
 await frames(3)
 level=load("res://scenes/levels/level_02.tscn").instantiate()
 root.add_child(level)
 current_scene=level
 await frames(8)
 level.finish_dialogue()
 level.set_process(false)
 level.world_features.set_process(false)
 level.player.set_physics_process(false)
 level.player.in_hiding_spot=true
 for g in level.guards():
  g.set_physics_process(false)
  g.position=Vector2(-1000,-1000)
 var party=level.guards().slice(0,3)
 for i in range(3):
  var g=party[i]
  g.position=Vector2(600+i*30,237)
  g.facing=1 if i%2==0 else -1
  g.patrol_left=560
  g.patrol_right=760
  g.conversation_hold=false
  g.sick_guard=false
  g.set_physics_process(true)
 var changed=[-1000,-1000,-1000]
 var facing=[party[0].facing,party[1].facing,party[2].facing]
 var flickers:=0
 for tick in range(600):
  await frames(1)
  for i in range(3):
   if party[i].facing!=facing[i]:
    if tick-changed[i]<=2:flickers+=1
    changed[i]=tick
    facing[i]=party[i].facing
 check(flickers==0,"Three close patrols never flicker their facing on adjacent frames")
 for g in party:g.set_physics_process(false)
 var one=party[0]
 var two=party[1]
 one.position=Vector2(378,209)
 one.asleep=true
 two.position=Vector2(351,237)
 two.facing=1
 await frames(2)
 check(not two.can_hop(),"Occupied perch prevents repeated hops onto sleeping body")
 var ladder=level.areas.get_node("FirstLadder")
 one.asleep=false
 one.position=Vector2(ladder.position.x-70,237)
 two.position=Vector2(ladder.position.x+70,237)
 var below=party[2]
 below.position=Vector2(ladder.position.x-40,433)
 below.sees_player=false
 below.pursuing=true
 below.alert_state=IntroGuard.State.SEARCH
 check(below.wait_for_crossing(ladder,Vector2(ladder.position.x+60,237),1.0/60.0) and below.crossing==null and not below.pursuing,"Excess searcher remains downstairs when two guards cover upper landing")
