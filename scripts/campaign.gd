extends Node
## Session progress; floor results commit only when descending, so retries restore entry state.
var case_anchors: Dictionary = {}
var inventory_layout: Array[String] = ["pistol", "smg", "c4", "shank"]
var remote_owned := false
var remote_unlocked := false
var current_floor := 1
var active_floor_difficulty := "medium"
var completed_sigils: Dictionary = {}
var narrative_milestones: Dictionary = {}
var boss_defeated := false
var ending_complete := false
var launch_consumed := false
## The last storey checkpoint on the floor being played: {floor, storey, position, milestones, sigil}.
## Retrying (Backspace) restores it; entering a floor from elsewhere or finishing it clears it.
var checkpoint := {}
# Records the run origin for snapshots; ending completion is saved for resumed runs too.
var played_from_start := false
## Committed per-floor results: {floor: {kills, detections, stealth, offense}}. Written only by
## complete_floor(), so a retry restores the state at floor entry.
var floor_stats: Dictionary = {}
var branch_data: Dictionary = {}
## Which start-menu screen to open next (the pause menu's "Level select" sets "levels").
var menu_screen := ""

var difficulty_tuning = {
	"easy": {
		"health": 5,
		"blanket_cooldown": 6.0,
		"blanket_duration": 7.0,
		"suspicion_rate": 1.5,
		"sight_range": 140,
		"attack_speed": 1.0,
		"niro_health": 1.0,
		"drop_rate": 1.2
	},
	"medium": {
		"health": 3,
		"blanket_cooldown": 8.0,
		"blanket_duration": 5.0,
		"suspicion_rate": 2.5,
		"sight_range": 165,
		"attack_speed": 1.0,
		"niro_health": 1.2,
		"drop_rate": 1.0
	},
	"hard": {
		"health": 2,
		"blanket_cooldown": 10.0,
		"blanket_duration": 4.0,
		"suspicion_rate": 3.5,
		"sight_range": 180,
		"attack_speed": 1.2,
		"niro_health": 1.5,
		"drop_rate": 0.8
	},
	"super_hard": {
		"health": 1,
		"blanket_cooldown": 12.0,
		"blanket_duration": 3.0,
		"suspicion_rate": 5.0,
		"sight_range": 200,
		"attack_speed": 1.5,
		"niro_health": 2.0,
		"drop_rate": 0.5
	}
}

func launch_floor() -> int:
	if launch_consumed:
		return 1
	launch_consumed = true
	if OS.has_feature("qa") and "--verify-playthrough" in OS.get_cmdline_user_args():
		var runner = load("res://tools/export_playthrough.gd").new()
		get_tree().root.call_deferred("add_child", runner)
	for argument in OS.get_cmdline_user_args():
		if dev_mode() and argument.begins_with("--level="):
			return clampi(argument.trim_prefix("--level=").to_int(), 1, 5)
	return 1

## Start the story again without deleting permanent unlocks or settings.
func start_new_playthrough() -> void:
	checkpoint.clear()
	floor_snapshots.clear()
	floor_stats.clear()
	case_anchors.clear()
	completed_sigils.clear()
	narrative_milestones.clear()
	carried_kit.clear()
	carried_from = 0
	remote_owned = false
	remote_unlocked = false
	inventory_layout.assign(["pistol", "smg", "c4", "shank"])
	current_floor = 1
	played_from_start = true
	boss_defeated = false
	ending_complete = false
	launch_consumed = false
	fresh_unlocks.clear()
	var behavior = get_node_or_null("/root/PlayerBehavior")
	if behavior != null: behavior.begin_floor(1)
	if can_persist():
		var progress := ConfigFile.new()
		progress.load(progress_path())
		for section in ["checkpoint", "snapshots"]:
			if progress.has_section(section): progress.erase_section(section)
		progress.save(progress_path())

## Level Select replays from the floor entry, not a later retry checkpoint.
func prepare_floor_replay(number: int) -> void:
	if number <= 1:
		start_new_playthrough()
		return
	checkpoint.clear()
	save_checkpoint()
	case_anchors.clear()
	completed_sigils.clear()
	narrative_milestones.clear()
	restore_floor_snapshot(number)

func enter_floor(number: int) -> void:
	if int(checkpoint.get("floor", 0)) != number:
		checkpoint.clear()
	if number == 1:
		carried_kit = {}
		played_from_start = true
		remote_owned = false
		remote_unlocked = false
	if number == 1 and current_floor != 1:
		case_anchors.clear()
	current_floor = number
	active_floor_difficulty = difficulty()
	unlock_level(number)
	unlock_level_music(number)
	print("FLOOR_READY: ", number)
	for floor_number in completed_sigils.keys():
		if int(floor_number) >= number:
			completed_sigils.erase(floor_number)
	for floor_number in floor_stats.keys():
		if int(floor_number) >= number:
			floor_stats.erase(floor_number)
	for key in narrative_milestones.keys():
		if int(str(key).get_slice(":", 0)) >= number:
			narrative_milestones.erase(key)
	boss_defeated = false
	ending_complete = false
	save_floor_snapshot(number)

## Level select resumes a floor from the state the player had when they first reached it:
## MP3 ownership and unlock, inventory order, earlier floors' results (which pick the
## MISSING/HUNTED branch), story milestones and Miro's play-style profile. Snapshots live in
## memory for the session and, in player mode, in user://progress.cfg so they survive a relaunch.
var floor_snapshots: Dictionary = {}

func save_floor_snapshot(number: int) -> void:
	if number <= 1:
		return
	var behavior = get_node_or_null("/root/PlayerBehavior")
	var committed: Dictionary = {}
	var choices: Dictionary = {}
	if behavior != null:
		for key in behavior.committed:
			if int(key) < number:
				committed[key] = behavior.committed[key]
		for id in behavior.choices:
			if int(str(id).get_slice("_", 0).trim_prefix("l")) < number:
				choices[id] = behavior.choices[id]
	var snapshot := {
		"remote_owned": remote_owned,
		"remote_unlocked": remote_unlocked,
		"inventory_layout": Array(inventory_layout.duplicate()),
		"floor_stats": floor_stats.duplicate(true),
		"carried_kit": carried_kit.duplicate(true),
		"carried_from": carried_from,
		"case_anchors": case_anchors.duplicate(),
		"completed_sigils": completed_sigils.duplicate(),
		"narrative_milestones": narrative_milestones.duplicate(),
		"played_from_start": played_from_start,
		"behavior_committed": committed,
		"behavior_choices": choices,
		"behavior_last_selected": behavior.last_selected if behavior != null else "neutral",
	}
	floor_snapshots[number] = snapshot
	if not can_persist():
		return
	var progress := ConfigFile.new()
	progress.load(progress_path())
	progress.set_value("snapshots", "floor_%d" % number, snapshot)
	progress.save(progress_path())

func floor_snapshot(number: int) -> Dictionary:
	if floor_snapshots.has(number):
		return floor_snapshots[number]
	if not can_persist():
		return {}
	var progress := ConfigFile.new()
	progress.load(progress_path())
	var saved = progress.get_value("snapshots", "floor_%d" % number, {})
	return saved if saved is Dictionary else {}

## Puts the run back the way it was when the player first entered `number`. A floor with no
## snapshot (an older save, or a dev jump) starts fresh: no MP3, neutral branch.
func restore_floor_snapshot(number: int) -> bool:
	var snapshot := floor_snapshot(number)
	remote_owned = bool(snapshot.get("remote_owned", false))
	remote_unlocked = bool(snapshot.get("remote_unlocked", false))
	if snapshot.has("inventory_layout"):
		inventory_layout.assign(snapshot.inventory_layout)
	floor_stats = Dictionary(snapshot.get("floor_stats", {})).duplicate(true)
	carried_kit = Dictionary(snapshot.get("carried_kit", {})).duplicate(true)
	carried_from = int(snapshot.get("carried_from", 0))
	case_anchors = Dictionary(snapshot.get("case_anchors", {})).duplicate()
	completed_sigils = Dictionary(snapshot.get("completed_sigils", {})).duplicate()
	narrative_milestones = Dictionary(snapshot.get("narrative_milestones", {})).duplicate()
	played_from_start = bool(snapshot.get("played_from_start", false))
	var behavior = get_node_or_null("/root/PlayerBehavior")
	if behavior != null:
		behavior.committed = Dictionary(snapshot.get("behavior_committed", {})).duplicate(true)
		behavior.choices = Dictionary(snapshot.get("behavior_choices", {})).duplicate()
		behavior.last_selected = str(snapshot.get("behavior_last_selected", "neutral"))
	return not snapshot.is_empty()

func progress_path() -> String:
	return "user://progress.cfg"

func game_completed() -> bool:
	var progress := ConfigFile.new()
	progress.load(progress_path())
	return bool(progress.get_value("game", "completed", false))

## Editor/dev reviews, tests and QA exports never write the player's progress.
func can_persist() -> bool:
	return not dev_mode() and not OS.has_feature("qa") and not "--script" in OS.get_cmdline_args()

func mark_game_completed() -> void:
	if not can_persist():
		return
	var progress := ConfigFile.new()
	progress.load(progress_path())
	progress.set_value("game", "completed", true)
	progress.save(progress_path())
	add_track_unlock("lil_uzi2")

func total(key: String) -> int:
	var sum := 0
	for floor_number in floor_stats:
		sum += int(floor_stats[floor_number].get(key, 0))
	return sum

## MISSING (stealth) or HUNTED (offense), from committed floors only. Level 1 is neutral.
func run_killed(keeper_name: String) -> bool:
	for stats: Dictionary in floor_stats.values():
		if keeper_name in stats.get("named_dead", []):return true
	return false

func reputation() -> String:
	if floor_stats.is_empty():
		return "MISSING"
	return "HUNTED" if total("kills") >= 3 or total("offense") > total("stealth") else "MISSING"

func branch() -> Dictionary:
	if branch_data.is_empty():
		branch_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/branch_reactions.json"))
	return branch_data

func branch_line(key: String):
	return branch()[reputation()].get(key, "")

## Style word for the end-of-floor report: GHOST (unseen, no kills), SEEN or HUNTED.
static func style_word(stats: Dictionary) -> String:
	if int(stats.get("kills", 0)) == 0 and int(stats.get("detections", 0)) == 0:
		return "GHOST"
	return "HUNTED" if int(stats.get("kills", 0)) > 0 else "SEEN"

## Scores one floor's raw counts. Unseen floor +2 stealth, plus any unseen bonuses; +1 offense per kill and loud breach.
static func score_floor(raw: Dictionary) -> Dictionary:
	var stats := raw.duplicate()
	var stealth := int(raw.get("stealth_bonus", 0))
	if int(raw.get("detections", 0)) == 0:
		stealth += 2
	stats["stealth"] = stealth
	stats["offense"] = int(raw.get("kills", 0)) + int(raw.get("loud", 0))
	return stats

## MP3 unlocks are saved to disk and never lost. Calm beats come from stealth points
## (unseen floors, quiet thefts); the aggressive ones from Keepers killed across the run.
## Test runs keep their unlocks in memory only.
var session_unlocks: Array = []

## Achievements (easter eggs): saved in progress.cfg, kept in memory for test runs.
var achievements_earned: Dictionary = {}

func has_achievement(id: String) -> bool:
	if not can_persist():
		return achievements_earned.has(id) or (id in ["foreva", "foreva_secret"] and (achievements_earned.has("foreva") or achievements_earned.has("foreva_secret")))
	var progress := ConfigFile.new()
	progress.load(progress_path())
	var earned: Array = Array(progress.get_value("achievements", "earned", []))
	return earned.has(id) or (id in ["foreva", "foreva_secret"] and (earned.has("foreva") or earned.has("foreva_secret")))

## True the first time only.
func unlock_achievement(id: String) -> bool:
	if has_achievement(id):
		return false
	achievements_earned[id] = true
	if can_persist():
		var progress := ConfigFile.new()
		progress.load(progress_path())
		var earned: Array = Array(progress.get_value("achievements", "earned", []))
		earned.append(id)
		progress.set_value("achievements", "earned", earned)
		progress.save(progress_path())
	grant_achievement_track(id)
	queue_achievement_notice(id)
	if id != "all_achievements": check_all_achievements()
	return true

## A secret beat (the Foreva note) goes onto the MP3 for good.
func add_track_unlock(track: String) -> void:
	var tracks_to_unlock := track.split(",")
	for t in tracks_to_unlock:
		var trimmed_t := t.strip_edges()
		var current_unlocks := stored_unlocks()
		if current_unlocks.has(trimmed_t):
			continue
		current_unlocks.append(trimmed_t)
		fresh_unlocks.append(trimmed_t)
		if can_persist():
			var progress := ConfigFile.new()
			progress.load(progress_path())
			progress.set_value("mp3", "unlocked", current_unlocks)
			progress.save(progress_path())
		else:
			session_unlocks = current_unlocks

## Achievement definitions are the authority for both the tracker and rewards.
var achievement_definitions: Array = []
func achievement_data() -> Array:
	if achievement_definitions.is_empty():
		achievement_definitions = JSON.parse_string(FileAccess.get_file_as_string("res://data/achievements.json")).get("achievements", [])
	return achievement_definitions

func grant_achievement_track(id: String) -> void:
	for entry in achievement_data():
		if entry.id == id and not str(entry.get("track", "")).is_empty():
			add_track_unlock(str(entry.track))
			return

func check_all_achievements() -> void:
	var earned: Array = achievements_earned.keys()
	if can_persist():
		var progress := ConfigFile.new()
		progress.load(progress_path())
		earned = Array(progress.get_value("achievements", "earned", []))
	if earned.has("all_achievements"): return
	for entry in achievement_data():
		if entry.id == "all_achievements": continue
		if not earned.has(entry.id) and not (entry.id == "foreva_secret" and earned.has("foreva")):
			return
	unlock_achievement("all_achievements")

func unlocked_tracks() -> Array:
	check_all_achievements()
	# Keep previously unlocked music, and repair rewards when an earned
	# achievement is assigned its corrected track in a later release.
	var tracks := stored_unlocks()
	var earned: Array = achievements_earned.keys()
	if can_persist():
		var progress := ConfigFile.new()
		progress.load(progress_path())
		earned = Array(progress.get_value("achievements", "earned", []))
	if earned.has("foreva") and not earned.has("foreva_secret"): earned.append("foreva_secret")
	for entry in achievement_data():
		if earned.has(str(entry.id)) and not str(entry.get("track", "")).is_empty() and not tracks.has(entry.track):
			add_track_unlock(str(entry.track))
			tracks.append(entry.track)
	return tracks

func stored_unlocks() -> Array:
	if not can_persist():
		return session_unlocks.duplicate()
	var progress := ConfigFile.new()
	progress.load(progress_path())
	return progress.get_value("mp3", "unlocked", [])

## "stealth_points" or "kills" and the threshold for one mp3_unlocks entry.
static func unlock_rule(entry: Dictionary) -> Array:
	if entry.has("kills"):
		return ["kills", int(entry.kills)]
	return ["stealth", int(entry.get("stealth_points", 0))]

func earns(entry: Dictionary, stealth: int, kills: int) -> bool:
	var rule := unlock_rule(entry)
	return (kills if rule[0] == "kills" else stealth) >= int(rule[1])

## Tracks that finishing the current floor would unlock (shown on the floor report).
func preview_unlocks(floor_stealth: int, floor_kills := 0) -> Array:
	var names: Array = []
	var unlocked := unlocked_tracks()
	for entry in branch().get("mp3_unlocks", []):
		if earns(entry, total("stealth") + floor_stealth, total("kills") + floor_kills) and not unlocked.has(entry.track):
			names.append(track_title(str(entry.track)))
	return names

## Beats earned when the last floor ended; the next floor announces them once.
var fresh_unlocks: Array = []
## What Miro is carrying when a floor ends: guns, ammo, C4, tonics. The next floor hands it back.
var carried_kit: Dictionary = {}
var carried_from := 0

## Achievement tracking: cumulative across the whole run, persisted in progress.cfg.
## Strangle count and named-strangle tracking for strangle_* achievements.
var kill_count := 0
var named_killed: Dictionary = {}
var security_disabled_ids: Dictionary = {}
var strangle_count := 0
var named_strangled: Dictionary = {}
## C4 kill count for c4_spree achievement.
var c4_kill_count := 0
## Camera+turret disable count per floor for hack_early / hack_all.
var security_disabled_count := 0
## Terminal command count and set of distinct commands run, for terminal_5 / terminal_all.
var terminal_command_count := 0
var terminal_commands_run: Dictionary = {}
## Whether mp3_hack has already been unlocked this session.
var mp3_hack_unlocked := false

## Load achievement strangle_count from progress.cfg on startup.
func _ready() -> void:
	if can_persist():
		var progress := ConfigFile.new()
		progress.load(progress_path())
		kill_count = int(progress.get_value("achievements", "kill_count", 0))
		for guard_name in progress.get_value("achievements", "named_killed", []):
			named_killed[guard_name] = true
		for device_id in progress.get_value("achievements", "security_disabled_ids", []):
			security_disabled_ids[device_id] = true
		strangle_count = int(progress.get_value("achievements", "strangle_count", 0))
		var ns = progress.get_value("achievements", "named_strangled", [])
		for n in ns:
			named_strangled[n] = true
		c4_kill_count = int(progress.get_value("achievements", "c4_kill_count", 0))
		security_disabled_count = int(progress.get_value("achievements", "security_disabled_count", 0))
		terminal_command_count = int(progress.get_value("achievements", "terminal_command_count", 0))
		var cmds = progress.get_value("achievements", "terminal_commands_run", [])
		for cmd in cmds:
			terminal_commands_run[terminal_command_id(str(cmd))] = true
	if can_persist():
		call_deferred("unlock_reached_level_music")

func level_music_tracks(number: int) -> Array:
	var director = get_node_or_null("/root/MusicDirector")
	if director == null:
		return []
	var tracks: Array = []
	var first: String = str(director.FIRST.get(number, ""))
	if not first.is_empty():
		tracks.append(first)
	if director.SECOND.has(number):
		tracks.append(director.SECOND[number])
	return tracks

func unlock_level_music(number: int) -> void:
	unlock_achievement("reach_level_%d" % number)
	for track in level_music_tracks(number):
		add_track_unlock(track)

func unlock_reached_level_music() -> void:
	# Level 1 is selectable by default, but has not been reached on a fresh profile.
	# Repair existing rewards only; entering the floor grants the first achievement.
	if can_persist() and highest_level() == 1:
		var progress := ConfigFile.new()
		progress.load(progress_path())
		if not "reach_level_1" in progress.get_value("achievements", "earned", []):
			return
	for number in range(1, highest_level() + 1):
		unlock_level_music(number)

## Save strangle_count etc. back to progress.cfg.
func _save_achievement_progress() -> void:
	if not can_persist():
		return
	var progress := ConfigFile.new()
	progress.load(progress_path())
	progress.set_value("achievements", "kill_count", kill_count)
	progress.set_value("achievements", "named_killed", named_killed.keys())
	progress.set_value("achievements", "security_disabled_ids", security_disabled_ids.keys())
	progress.set_value("achievements", "strangle_count", strangle_count)
	progress.set_value("achievements", "named_strangled", named_strangled.keys())
	progress.set_value("achievements", "c4_kill_count", c4_kill_count)
	progress.set_value("achievements", "security_disabled_count", security_disabled_count)
	progress.set_value("achievements", "terminal_command_count", terminal_command_count)
	progress.set_value("achievements", "terminal_commands_run", terminal_commands_run.keys())
	progress.save(progress_path())

## Called when a Keeper is killed. Checks kill-milestone achievements.
func on_keeper_killed(guard_name: String, is_named: bool) -> void:
	kill_count = maxi(kill_count, total("kills")) + 1
	_check_kill_achievement("kill_1", "drill2", kill_count, 1)
	_check_kill_achievement("kill_10", "evilhall2", kill_count, 10)
	_check_kill_achievement("kill_50", "new_age_dancehall", kill_count, 50)
	_check_kill_achievement("kill_100", "ox", kill_count, 100)
	if is_named:
		named_killed[guard_name] = true
	if _all_named_recorded(named_killed) and unlock_achievement("kill_named"):
		grant_achievement_track("kill_named")
	_save_achievement_progress()

func _check_kill_achievement(id: String, track: String, count: int, threshold: int) -> void:
	if count >= threshold and unlock_achievement(id):
		add_track_unlock(track)

## Use roster identities: repeated kills or unnamed reinforcements cannot stand in for missing Keepers.
func _all_named_recorded(recorded: Dictionary) -> bool:
	var roster: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/guard_roster.json"))
	for guard_name in roster.keepers:
		if not recorded.has(guard_name):
			return false
	return not roster.keepers.is_empty()

## Called when a Keeper is strangled. Checks strangle-milestone achievements.
func on_keeper_strangled(guard_name: String, is_named: bool) -> void:
	strangle_count += 1
	if is_named:
		named_strangled[guard_name] = true
	_check_strangle_achievement("strangle_1", "birthday_melody", strangle_count, 1)
	_check_strangle_achievement("strangle_10", "driffannnn", strangle_count, 10)
	_check_strangle_achievement("strangle_50", "fell_from_heaven", strangle_count, 50)
	_check_strangle_achievement("strangle_100", "b6", strangle_count, 100)
	if _all_named_recorded(named_strangled) and unlock_achievement("strangle_named"):
		add_track_unlock("ready_3_go3")
	_save_achievement_progress()

func _check_strangle_achievement(id: String, track: String, count: int, threshold: int) -> void:
	if count >= threshold and unlock_achievement(id):
		add_track_unlock(track)

## Called by dropped_charge when a C4 blast kills a Keeper.
func on_c4_kill() -> void:
	c4_kill_count += 1
	if c4_kill_count >= 3 and unlock_achievement("c4_spree"):
		add_track_unlock("project_dancehall_hard_af_2")
	_save_achievement_progress()

## Called by security_camera.disable() and tower_hazard.disable() when floor <= 2.
func on_security_disabled_early() -> void:
	if unlock_achievement("hack_early"):
		add_track_unlock("project_14")

## Stable authored identities prevent repeated disables or retries from inflating progress.
func security_device_id(number: int, kind: String, point: Vector2) -> String:
	return "%d:%s:%d:%d" % [number, kind, roundi(point.x), roundi(point.y)]

func security_targets() -> Dictionary:
	var targets: Dictionary = {}
	for number in range(2, 6):
		var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/level_%02d.json" % number))
		var features: Dictionary = definition.get("features", {})
		for camera in features.get("cameras", []):
			if not camera.get("disabled", false):
				var point := Vector2(camera.position[0], camera.position[1])
				targets[security_device_id(number, "camera", point)] = true
		for hazard in features.get("hazards", []):
			if hazard.kind == "turret" and not hazard.get("disabled", false):
				var origin: Array = hazard.get("legacy_position", hazard.position)
				var point := Vector2(origin[0], origin[1])
				targets[security_device_id(number, "turret", point)] = true
		# Compatibility for the original practice/checkpoint layouts.
		if number == 2 and features.get("ports", []).is_empty():
			targets[security_device_id(2, "camera", Vector2(720, 370))] = true
		if number == 3 and not features.has("cameras"):
			for point in [Vector2(450, 180), Vector2(820, 370)]:
				targets[security_device_id(3, "camera", point)] = true
	return targets

func on_security_disabled(kind: String, point: Vector2) -> void:
	var targets := security_targets()
	var id := security_device_id(current_floor, kind, point)
	# Scripted scenery that starts disabled never earns an achievement.
	if not targets.has(id) or security_disabled_ids.has(id):
		return
	security_disabled_ids[id] = true
	security_disabled_count = security_disabled_ids.size()
	if current_floor <= 2:
		on_security_disabled_early()
	var all_disabled := not targets.is_empty()
	for target in targets:
		if not security_disabled_ids.has(target):
			all_disabled = false
	if all_disabled and unlock_achievement("hack_all"):
		add_track_unlock("ken_carson")
	_save_achievement_progress()

## Called by player_controls.run_command for each command typed.
func terminal_command_id(cmd: String) -> String:
	var id := cmd.strip_edges()
	if id.begins_with("cat ") or id.begins_with("login ") or id.begins_with("cd "):
		return id.get_slice(" ", 0)
	return id

func on_terminal_command(cmd: String) -> void:
	var id := terminal_command_id(cmd)
	if not id in ["ls", "cat", "pwd", "whoami", "cd", "login", "scan", "turrets off", "cameras off", "help", "next", "hack", "./unlock.sh", "music", "play", "lights test"] and not cmd.begins_with("play "):
		return
	terminal_command_count += 1
	terminal_commands_run[terminal_command_id(cmd)] = true
	if terminal_command_count >= 5 and unlock_achievement("terminal_5"):
		add_track_unlock("egyptian_beat_2")
	var known_commands := ["ls", "cat", "pwd", "whoami", "cd", "login", "scan", "turrets off"]
	var all_run := known_commands.all(func(c): return terminal_commands_run.has(c))
	if all_run and unlock_achievement("terminal_all"):
		add_track_unlock("space_dancehall_yf")
	_save_achievement_progress()

## Called once when the player uses the MP3 near a terminal.
func on_mp3_hack() -> void:
	if not mp3_hack_unlocked and unlock_achievement("mp3_hack"):
		mp3_hack_unlocked = true
		add_track_unlock("house_cyah_skate")

func update_unlocks() -> Array:
	var earned: Array = []
	var unlocked := unlocked_tracks()
	for entry in branch().get("mp3_unlocks", []):
		if earns(entry, total("stealth"), total("kills")) and not unlocked.has(entry.track):
			unlocked.append(entry.track)
			earned.append(entry.track)
	if not earned.is_empty():
		fresh_unlocks = earned.duplicate()
	if earned.is_empty():
		return earned
	if can_persist():
		var progress := ConfigFile.new()
		progress.load(progress_path())
		progress.set_value("mp3", "unlocked", unlocked)
		progress.save(progress_path())
	else:
		session_unlocks = unlocked
	return earned

## Level select: a player sees only the levels they have reached. Developers (editor runs,
## QA builds, or --dev) see all five; --player forces the player view for testing.
var session_level := 1

func dev_mode() -> bool:
	var args := OS.get_cmdline_user_args()
	if "--player" in args:
		return false
	return "--dev" in args or OS.has_feature("editor") or OS.has_feature("qa")

func highest_level() -> int:
	if dev_mode():
		return 5
	if not can_persist():
		return session_level
	var progress := ConfigFile.new()
	progress.load(progress_path())
	return clampi(int(progress.get_value("levels", "highest", 1)), 1, 5)

## Cleared floors get a check on level select (real progress, also in dev).
func level_completed(number: int) -> bool:
	if number >= 5:
		return game_completed() or (not can_persist() and session_level > 5)
	if not can_persist():
		return session_level > number
	var progress := ConfigFile.new()
	progress.load(progress_path())
	return int(progress.get_value("levels", "highest", 1)) > number

func level_unlocked(number: int) -> bool:
	return number <= highest_level()

func unlock_level(number: int) -> void:
	session_level = maxi(session_level, clampi(number, 1, 5))
	if not can_persist():
		return
	var progress := ConfigFile.new()
	progress.load(progress_path())
	if int(progress.get_value("levels", "highest", 1)) < number:
		progress.set_value("levels", "highest", clampi(number, 1, 5))
		progress.save(progress_path())

## Difficulty (Settings): Miro's health, blanket recharge, Level 5 wave size and how sharp
## the Keepers are. Medium is the authored balance; tests always run on Medium unless asked.
const DIFFICULTIES := {
	"easy": {"label": "Easy", "health": 10, "stealth_cooldown": 5.0, "stealth_duration": 6.0, "wave_extra": -1, "suspicion": 0.65, "sight": 140.0, "windup": 0.9, "attack_gap": 2.8, "chase": 66.0, "niro_health": 0.8},
	"medium": {"label": "Medium", "health": 6, "stealth_cooldown": 8.0, "stealth_duration": 5.0, "wave_extra": 0, "suspicion": 1.0, "sight": 165.0, "windup": 0.65, "attack_gap": 2.1, "chase": 78.0, "niro_health": 1.0},
	"hard": {"label": "Hard", "health": 4, "stealth_cooldown": 11.0, "stealth_duration": 4.0, "wave_extra": 1, "suspicion": 1.4, "sight": 190.0, "windup": 0.5, "attack_gap": 1.6, "chase": 88.0, "niro_health": 1.3},
	"super_hard": {"label": "Super Hard", "health": 2, "stealth_cooldown": 12.0, "stealth_duration": 3.0, "wave_extra": 2, "suspicion": 2.0, "sight": 210.0, "windup": 0.4, "attack_gap": 1.2, "chase": 95.0, "niro_health": 2.0},
}
var difficulty_override := ""

func difficulty() -> String:
	if not difficulty_override.is_empty():
		return difficulty_override
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--difficulty="):
			var chosen := argument.trim_prefix("--difficulty=")
			if DIFFICULTIES.has(chosen):
				return chosen
	if "--script" in OS.get_cmdline_args():
		return "medium"
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	var saved := str(config.get_value("game", "difficulty", "medium"))
	return saved if DIFFICULTIES.has(saved) else "medium"

func set_difficulty(id: String) -> void:
	if not DIFFICULTIES.has(id):
		return
	if not can_persist():
		difficulty_override = id
		return
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value("game", "difficulty", id)
	config.save("user://settings.cfg")

## Scale pickups only: magazine capacity and existing ammunition stay unchanged.
func ammo_amount(base: int) -> int:
	if base <= 0: return 0
	match difficulty():
		"easy": return ceili(base * 1.5)
		"hard": return maxi(1, floori(base * 2.0 / 3.0))
		"super_hard": return maxi(1, floori(base / 3.0))
	return base

func tuning() -> Dictionary:
	return DIFFICULTIES[difficulty()]

## Checkpoints survive closing the game (player mode): picking the floor from level select
## resumes from its last storey.
func save_checkpoint() -> void:
	if not can_persist():
		return
	var progress := ConfigFile.new()
	progress.load(progress_path())
	progress.set_value("checkpoint", "data", checkpoint.duplicate(true))
	progress.save(progress_path())

func saved_checkpoint(number: int) -> Dictionary:
	if int(checkpoint.get("floor", 0)) == number:
		return checkpoint
	if not can_persist():
		return {}
	var progress := ConfigFile.new()
	progress.load(progress_path())
	var data = progress.get_value("checkpoint", "data", {})
	return data if data is Dictionary and int(data.get("floor", 0)) == number else {}

func complete_floor(number: int, sigil: bool, milestones: Dictionary, raw_stats: Dictionary = {}) -> void:
	checkpoint.clear()
	save_checkpoint()
	floor_stats[number] = score_floor(raw_stats)
	floor_stats[number]["difficulty"] = active_floor_difficulty
	unlock_level(number + 1)
	if sigil:
		completed_sigils[number] = true
	for key in milestones:
		narrative_milestones["%d:%s" % [number, key]] = milestones[key]
	if number == 5:
		boss_defeated = milestones.has("BrotherEncounter")
		ending_complete = milestones.has("ForestViewpoint")
		if ending_complete:
			mark_game_completed()
			if completed_super_hard() and unlock_achievement("complete_super_hard"):
				add_track_unlock("robot_attack")
	check_peaceful_achievements()

## Completed peaceful floors award the achievement IDs as well as their MP3 tracks.
func check_peaceful_achievements() -> void:
	var peaceful := 0
	for stats in floor_stats.values():
		if int(stats.get("kills", 0)) == 0:
			peaceful += 1
	for entry in [["ghost_1", "pinkghost", 1], ["ghost_2", "destroyed_lonely", 2], ["ghost_3", "jazzyhall", 3], ["ghost_4", "reaper", 4]]:
		if peaceful >= int(entry[2]) and unlock_achievement(entry[0]):
			add_track_unlock(entry[1])
	if ending_complete and peaceful == 5 and total("kills") == 0 and unlock_achievement("ghost_full"):
		add_track_unlock("dancehall_lonesome")

## Every floor must have been played on Super Hard; changing settings at the finale is insufficient.
func completed_super_hard() -> bool:
	for number in range(1, 6):
		if not floor_stats.has(number) or floor_stats[number].get("difficulty", "") != "super_hard":
			return false
	return true

## Commit both parts of the trapdoor reward together, with one progress-file write.
func record_trapdoor_use() -> bool:
	const ID := "trapdoor_used"
	const TRACK := "trapdoor_bonus"
	var persist := can_persist()
	var progress := ConfigFile.new()
	var earned: Array = achievements_earned.keys()
	var tracks: Array = session_unlocks.duplicate()
	if persist:
		progress.load(progress_path())
		earned = Array(progress.get_value("achievements", "earned", []))
		tracks = Array(progress.get_value("mp3", "unlocked", []))
	var first := not earned.has(ID)
	var new_track := not tracks.has(TRACK)
	if not first and not new_track: return false
	if first: earned.append(ID)
	if new_track:
		tracks.append(TRACK)
		fresh_unlocks.append(TRACK)
	achievements_earned[ID] = true
	if persist:
		progress.set_value("achievements", "earned", earned)
		progress.set_value("mp3", "unlocked", tracks)
		progress.save(progress_path())
	else:
		session_unlocks = tracks
	if first: queue_achievement_notice(ID)
	check_all_achievements()
	return first

var pending_achievement_notices: Array[String] = []
var achievement_notice: CanvasLayer

func track_title(track: String) -> String:
	var director = get_node_or_null("/root/MusicDirector")
	if director != null and director.catalog.has(track):
		return str(director.catalog[track].get("source", director.catalog[track].get("title", track))).get_basename()
	return track

func queue_achievement_notice(id: String) -> void:
	pending_achievement_notices.append(id)
	if DisplayServer.get_name() != "headless":
		call_deferred("show_next_achievement_notice")

func show_next_achievement_notice() -> void:
	if is_instance_valid(achievement_notice) or pending_achievement_notices.is_empty():return
	var id: String = pending_achievement_notices.pop_front()
	var label_text := "Painting discovered" if id.begins_with("art_") else id.replace("_", " ").capitalize()
	var track := ""
	var lookup := "foreva_secret" if id == "foreva" else id
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/achievements.json"))
	for entry in definitions.get("achievements", []):
		if entry.id == lookup:
			label_text = str(entry.label)
			track = str(entry.get("track", ""))
			break
	achievement_notice = CanvasLayer.new()
	achievement_notice.name = "AchievementToast"
	achievement_notice.layer = 150
	achievement_notice.process_mode = Node.PROCESS_MODE_ALWAYS
	achievement_notice.set_meta("achievement_id", id)
	add_child(achievement_notice)
	var panel := PanelContainer.new()
	panel.position = Vector2(350, 250)
	panel.custom_minimum_size = Vector2(282, 64)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", preload("res://scripts/visual_assets.gd").panel_style())
	achievement_notice.add_child(panel)
	var label := Label.new()
	label.name = "AchievementText"
	label.text = "ACHIEVEMENT UNLOCKED\n" + label_text + ("\nBeat: " + track_title(track) + " · [B] Cycle beats" if not track.is_empty() else "")
	label.add_theme_font_size_override("font_size", 10)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 250
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	get_tree().create_timer(4.5, true).timeout.connect(func():
		if is_instance_valid(achievement_notice):achievement_notice.queue_free()
		achievement_notice = null
		show_next_achievement_notice())
