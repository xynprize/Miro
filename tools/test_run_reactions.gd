extends "res://tools/test_intro.gd"
func run() -> void:
 var campaign=root.get_node("Campaign")
 campaign.floor_stats={1:{"kills":0,"stealth":0,"detections":20,"loud":20,"offense":20}}
 check(not campaign.run_killed("Rowan"),"Lifetime history cannot accuse a victim in a new run")
 for floor_done in range(1,5):
  var scene=preload("res://scripts/interlude_cinematic.gd").new()
  scene.floor_done=floor_done
  root.add_child(scene);await frames(2)
  check(str(scene.data.lines[0][1])!=str(scene.data.get("hunted_first","")),"No-kill run uses truthful existing neutral dialogue")
  scene.finish();await frames(2)
 campaign.floor_stats={1:{"kills":1,"named_dead":["Rowan"],"offense":10,"stealth":0}}
 check(campaign.run_killed("Rowan") and not campaign.run_killed("Alden"),"Current run identifies the actual killed guard")
 var reactions:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/victim_reactions.json"))
 check("Rowan" in reactions.reports["2"].victims and "Rowan" not in reactions.reports["3"].victims,"Named reports only cover the preceding floor")
 check("Alden" in reactions.reports["3"].victims and "Corvin" in reactions.reports["4"].victims,"All players' possible prior-floor victims have reports")
 var roster:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/guard_roster.json"))
 for name in roster.keepers:
  check(not (name+" is down") in str(roster.keepers[name].body),"A living speaker never reports their own death")
 check(reactions.family_terms.Marta=="daughter" and reactions.family_terms.Rowan=="son" and not reactions.family_terms.has("Corvin"),"Family reaction uses authored gender with neutral fallback")
 print("RUN_REACTIONS_RESULT: ",checks-failures.size(),"/",checks)
 quit(0 if failures.is_empty() else 1)
