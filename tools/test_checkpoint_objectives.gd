extends "res://tools/test_intro.gd"
func run() -> void:
 level=load("res://scenes/levels/level_04.tscn").instantiate()
 root.add_child(level);current_scene=level;await frames(10);level.finish_dialogue()
 var deep:=Vector2(710,852)
 var spawn:Vector2=level.get_node("LevelPlan/PlayerSpawn").global_position
 check(level.checkpoint_safe_position(deep,{})==spawn,"Unfinished first objective prevents deep checkpoint")
 var completed:Dictionary={}
 for station in level.definition.stations:
  if float(station.position[1])<deep.y-100:completed[station.id]=true
 check(level.checkpoint_safe_position(deep,completed)==deep,"Completed earlier objectives permit deeper checkpoint")
 var campaign=root.get_node("Campaign")
 campaign.checkpoint={"floor":4,"storey":4,"position":deep,"milestones":{},"retry":true}
 level.apply_checkpoint()
 check(level.player.global_position==spawn and campaign.checkpoint.storey==0,"Old unsafe checkpoints migrate back to entry")
 print("CHECKPOINT_OBJECTIVES_RESULT: ",checks-failures.size(),"/",checks)
 quit(0 if failures.is_empty() else 1)
