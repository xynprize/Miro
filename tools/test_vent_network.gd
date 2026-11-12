extends SceneTree
var level: Node
var checks := 0
var failures := 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func frames(n:=8) -> void:
 for i in range(n):await physics_frame
func run() -> void:
 for floor_number in range(1,6):
  level=load("res://scenes/intro.tscn" if floor_number==1 else "res://scenes/levels/level_%02d.tscn"%floor_number).instantiate()
  root.add_child(level);current_scene=level;await frames(12)
  while not level.dialogue.is_empty():level.finish_dialogue()
  var features:Node=level.world_features
  var vents:Array=features.props.filter(func(p):return is_instance_valid(p) and p.kind=="hide")
  check(vents.size()>=2,"Connected vent openings exist on floor %d"%floor_number)
  for vent in vents:
   check(vent.title=="VENT" and features.vent_wall_clear(vent.position),"Vent title and full wall clearance")
  var network:Node=features.vent_network
  # Connectivity is checked after progression; locked links are covered by
  # test_security_sessions rather than requiring a fresh run to bypass them.
  if floor_number>1:
   for station in level.definition.stations:level.milestones[station.id]=true
   for gate in level.get_node("Gates").get_children():gate.unlock()
  var travelled:=false
  for vent in vents:
   network.enter(vent)
   var target:Node2D=network.opening(1)
   if target==null:continue
   if floor_number==1:
    level.door_open=false
    check(not network.passage_open(target),"Intro story lock seals vent route")
    level.door_open=true
   if not network.passage_open(target):continue
   level.player.in_hiding_spot=true
   var origin:Vector2=vent.global_position
   check(network.travel(1) and level.player.global_position==target.global_position,"Downward duct reaches offset exit")
   check(network.travel(-1) and absf(level.player.global_position.y-origin.y)<32,"Return to previous storey")
   check(features.try_interact() and not level.player.in_hiding_spot,"E releases Miro at selected vent")
   travelled=true;break
  check(travelled,"At least one usable adjacent storey connection")
  level.queue_free();await frames()
 print("VENT_NETWORK_RESULT: ",checks-failures,"/",checks)
 quit(0 if failures==0 else 1)
