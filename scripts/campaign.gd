extends Node
## Session progress; floor results commit only when descending, so retries restore entry state.
var case_anchors: Dictionary = {}
var inventory_layout: Array[String] = ["shank", "c4", "gun_1", "gun_2", "remote"]
var remote_owned := false
var remote_unlocked := false
var current_floor := 1
var completed_sigils: Dictionary = {}
var narrative_milestones: Dictionary = {}
var boss_defeated := false
var ending_complete := false
var launch_consumed := false

# Achievement/Event Ledger
var run_stats: Dictionary = {
	"kills": 0,
	"named_kills": 0,
	"c4_kills": 0,
	"strangles": 0,
	"cameras_disabled": 0,
	"turrets_disabled": 0,
	"remote_hacks": 0,
	"distinct_commands": [],
	"consecutive_no_kill": 0,
	"total_guards": 0,
	"niro_encountered": false,
	"niro_defeated": false,
	"judas_pocketed": false
}
var unlocked_achievements: Array[String] = []
var viewed_art: Array[String] = []
var achievements_data: Dictionary = {}

func _ready() -> void:
	var file = FileAccess.open("res://data/achievements.json", FileAccess.READ)
	if file:
		achievements_data = JSON.parse_string(file.get_as_text())

func record_event(event_id: String, payload := {}) -> void:
	# Minimal duplicate protection for specific events
	if event_id == "terminal_command":
		var cmd = payload.get("command", "")
		if cmd in run_stats.distinct_commands: return
		run_stats.distinct_commands.append(cmd)
	
	match event_id:
		"keeper_killed":
			run_stats.kills += 1
			if payload.get("named", false): run_stats.named_kills += 1
			if payload.get("method") == "c4": run_stats.c4_kills += 1
			if payload.get("method") == "strangle": run_stats.strangles += 1
		"strangle":
			# Non-lethal strangle contributes to stealth points
			run_stats.strangles += 1
		"camera_disabled":
			run_stats.cameras_disabled += 1
		"turret_disabled":
			run_stats.turrets_disabled += 1
		"mp3_remote_hack":
			run_stats.remote_hacks += 1
		"pickpocket_judas":
			run_stats.judas_pocketed = true
		"niro_encountered":
			run_stats.niro_encountered = true
		"niro_defeated":
			run_stats.niro_defeated = true
	
	evaluate_achievements()

func evaluate_achievements() -> void:
	# Simple predicate check against achievements.json
	for category in achievements_data:
		for key in achievements_data[category]:
			var ach = achievements_data[category][key]
			var id = ach.id
			if id in unlocked_achievements: continue
			
			# Minimal condition evaluator
			var condition_met = false
			var cond = ach.condition
			if cond == "kills >= 1" and run_stats.kills >= 1: condition_met = true
			elif cond == "kills >= 10" and run_stats.kills >= 10: condition_met = true
			elif cond == "kills >= 50" and run_stats.kills >= 50: condition_met = true
			elif cond == "kills >= 100" and run_stats.kills >= 100: condition_met = true
			elif cond == "named_kills == total_named" and run_stats.named_kills >= 12: condition_met = true # assumed total
			elif cond == "consecutive_no_kill >= 1" and run_stats.consecutive_no_kill >= 1: condition_met = true
			elif cond == "consecutive_no_kill >= 2" and run_stats.consecutive_no_kill >= 2: condition_met = true
			elif cond == "consecutive_no_kill >= 3" and run_stats.consecutive_no_kill >= 3: condition_met = true
			elif cond == "consecutive_no_kill >= 4" and run_stats.consecutive_no_kill >= 4: condition_met = true
			elif cond == "total_kills == 0 && game_completed" and run_stats.kills == 0 and ending_complete: condition_met = true
			elif cond == "floor <= 2 && hacked_terminal" and current_floor <= 2 and run_stats.remote_hacks > 0: condition_met = true
			elif cond == "mp3_remote_hacks >= 1" and run_stats.remote_hacks >= 1: condition_met = true
			elif cond == "c4_kills >= 1" and run_stats.c4_kills >= 1: condition_met = true
			elif cond == "c4_kills >= 3" and run_stats.c4_kills >= 3: condition_met = true
			elif cond == "strangles >= 1" and run_stats.strangles >= 1: condition_met = true
			elif cond == "judas_pocketed" and run_stats.judas_pocketed: condition_met = true
			elif cond == "niro_encountered" and run_stats.niro_encountered: condition_met = true
			elif cond == "niro_defeated" and run_stats.niro_defeated: condition_met = true
			
			if condition_met:
				unlocked_achievements.append(id)
				print("ACHIEVEMENT_UNLOCKED: ", ach.text)
				# Wire beat unlock to MusicDirector
				if ach.has("beat"):
					get_node("/root/MusicDirector").unlock_achievement_beat(ach.beat)

func score_floor(kills: int, detections: int, bonuses: int) -> Dictionary:
	var stealth = bonuses
	if detections == 0:
		stealth += 2
	elif detections == 1:
		stealth += 1
	elif detections == 2:
		stealth += 0.5

	# Add stealth points for each non-lethal strangle performed this floor
	stealth += minf(2.0, float(run_stats.strangles))

	var offense = kills + (1 if detections > 0 else 0) # simplified loud

	if kills == 0:
		run_stats.consecutive_no_kill += 1
	else:
		run_stats.consecutive_no_kill = 0
	
	# Process Numerical Beat Unlocks (from branch_reactions.json)
	_check_numerical_unlocks(stealth, offense)

	return {"stealth": stealth, "offense": offense}

func _check_numerical_unlocks(stealth: float, offense: int) -> void:
	var reactions = {}
	var file = FileAccess.open("res://data/branch_reactions.json", FileAccess.READ)
	if file:
		reactions = JSON.parse_string(file.get_as_text())
	
	if reactions.is_empty(): return
	
	# Check calm beats (stealth thresholds)
	if reactions.has("calm"):
		for threshold in reactions.calm:
			var thresh_val = threshold.keys()[0]
			var beat_id = threshold.values()[0]
			if stealth >= float(thresh_val):
				get_node("/root/MusicDirector").unlock_achievement_beat(beat_id)
	
	# Check aggressive beats (kill thresholds)
	if reactions.has("aggressive"):
		for threshold in reactions.aggressive:
			var thresh_val = threshold.keys()[0]
			var beat_id = threshold.values()[0]
			if offense >= int(thresh_val):
				get_node("/root/MusicDirector").unlock_achievement_beat(beat_id)

func launch_floor() -> int:
	if launch_consumed:
		return 1
	launch_consumed = true
	if OS.has_feature("qa") and "--verify-playthrough" in OS.get_cmdline_user_args():
		var runner = load("res://tools/export_playthrough.gd").new()
		get_tree().root.call_deferred("add_child", runner)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--level="):
			return clampi(argument.trim_prefix("--level=").to_int(), 1, 5)
	return 1

func enter_floor(number: int) -> void:
	if number == 1:
		remote_owned = false
		remote_unlocked = false
	if number == 1 and current_floor != 1:
		case_anchors.clear()
	current_floor = number
	print("FLOOR_READY: ", number)
	for floor_number in completed_sigils.keys():
		if int(floor_number) >= number:
			completed_sigils.erase(floor_number)
	for key in narrative_milestones.keys():
		if int(str(key).get_slice(":", 0)) >= number:
			narrative_milestones.erase(key)
	boss_defeated = false
	ending_complete = false

func complete_floor(number: int, sigil: bool, milestones: Dictionary) -> void:
	if sigil:
		completed_sigils[number] = true
	for key in milestones:
		narrative_milestones["%d:%s" % [number, key]] = milestones[key]
	if number == 5:
		boss_defeated = milestones.has("BrotherEncounter")
		ending_complete = milestones.has("ForestViewpoint")
