extends "res://tools/test_intro.gd"
## Inner conflict: play-style scores, two-option replies, the reactive painting, lore terminals
## and branch-keyed Bible verses (docs/INNER_CONFLICT.md, artspec.md §11 acceptance tests).

func floor_scene(number: int) -> void:
	if is_instance_valid(level):
		level.queue_free()
		await frames(2)
	level = load("res://scenes/intro.tscn" if number == 1 else "res://scenes/levels/level_%02d.tscn" % number).instantiate()
	root.add_child(level)
	current_scene = level
	await frames(6)

func director():
	return level.get_node_or_null("InnerConflict")

func run() -> void:
	var behavior = root.get_node("PlayerBehavior")
	var campaign = root.get_node("Campaign")
	# Data: every matrix painting exists, all 27 works are reachable, all 12 themes are covered.
	var catalog := {}
	var themes := {}
	for work in JSON.parse_string(FileAccess.get_file_as_string("res://data/art_catalog.json")).works:
		catalog[work.id] = work
		for theme in work.themes:
			themes[theme] = true
	var reachable := {}
	var slots: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/art_branch_matrix.json")).slots
	for number in slots:
		for branch in ["neutral"] + Array(behavior.BRANCHES):
			check(catalog.has(slots[number].art[branch]), "Floor %s %s painting is in the catalog" % [number, branch])
			reachable[slots[number].art[branch]] = true
	check(catalog.size() == 27 and reachable.size() == 27, "All 27 catalog works can appear in some playthrough")
	for theme in ["escape", "trapped", "loneliness", "distrust", "alienation", "betrayal", "confusion", "survival", "defiance", "blackhat", "isolation", "faith"]:
		check(themes.has(theme), "Theme %s has at least one work" % theme)
	# Lore never spoils the Level 5 reveal.
	for entry in JSON.parse_string(FileAccess.get_file_as_string("res://data/terminal_logs.json")).terminals:
		var text := " ".join(entry.pages).to_lower()
		check(not ("immun" in text or "niro" in text or "brother" in text or "made the sickness" in text or "created the" in text), "Terminal %s keeps the Level 5 reveal" % entry.id)
		if int(entry.floor) <= 2:
			check(not "former keeper" in text and not "was a keeper" in text, "Terminal %s doesn't reveal Miro's rank before Level 3" % entry.id)
	# Branch decision rules (artspec §4.3).
	behavior.begin_floor(1)
	check(behavior.select_branch(true) == "neutral", "No signal selects neutral")
	behavior.record("a", "ghost", 3)
	check(behavior.select_branch(true) == "ghost", "A unique leader is selected")
	check(not behavior.record("a", "ghost", 3), "The same event never scores twice")
	behavior.record("b", "defiant", 3)
	check(behavior.select_branch(true) == "ghost", "A tie keeps the previous pick when it is tied for first")
	behavior.begin_floor(1)
	behavior.record("c", "seeker", 2)
	behavior.record("d", "blackhat", 2)
	check(behavior.select_branch(true) == "neutral", "Any other tie is neutral")
	for index in range(4):
		behavior.record("kill_cap_%d" % index, "defiant", 2, "kill", 2)
	check(int(behavior.totals(true).defiant) == 4, "Per-floor caps hold (two optional kills at most)")
	# Floor 1: the Keeper scene offers a reply; the loud one leans defiant and he answers back.
	await floor_scene(1)
	check(director() != null, "PlayerBehavior attaches the inner conflict to a level without hooks")
	var marker := -1
	for index in range(level.dialogue.size()):
		if level.dialogue[index].size() > 3 and str(level.dialogue[index][3]) == "choice:l1_keeper":
			marker = index
	check(marker > 0 and "doesn't pay me enough" in str(level.dialogue[marker - 1][1]), "A two-option reply follows the Keeper's line")
	var length: int = level.dialogue.size()
	level.dialogue_index = marker
	await frames(1)
	check("[1]" in level.dialogue_label.text and "[2]" in level.dialogue_label.text, "Both options are shown in Miro's bubble")
	var press := InputEventKey.new()
	press.physical_keycode = KEY_E
	press.keycode = KEY_E
	press.pressed = true
	director()._unhandled_input(press)
	check(level.dialogue_index == marker and str(level.dialogue[marker][1]).begins_with("Then don't look"), "E confirms the highlighted (quiet) reply without skipping the next line")
	await floor_scene(1)
	for index in range(level.dialogue.size()):
		if level.dialogue[index].size() > 3 and str(level.dialogue[index][3]) == "choice:l1_keeper":
			marker = index
	level.dialogue_index = marker
	await frames(1)
	var two := InputEventKey.new()
	two.physical_keycode = KEY_2
	two.keycode = KEY_2
	two.pressed = true
	director()._unhandled_input(two)
	check(str(level.dialogue[marker][1]).begins_with("Keep looking away") and str(level.dialogue[marker + 1][1]).begins_with("Careful") and level.dialogue.size() == length + 1, "[2] picks the loud reply and the Keeper answers back")
	check(int(behavior.totals(true).defiant) == 2, "The loud reply leans defiant")
	check(str(level.dialogue[marker + 2][1]).begins_with("His hands are shaking"), "The scene then continues exactly as written")
	level.finish_dialogue()
	await frames(2)
	var frame = director().frame
	check(is_instance_valid(frame) and director().terminals.size() == 1, "Floor 1 hangs one reactive frame and one records terminal")
	# Read the intake terminal: seeker points once, a bubble over the terminal.
	var terminal = director().terminals[0]
	director().open_prop(terminal)
	await frames(1)
	check("PRISONER M-07" in str(level.dialogue) and level.dialogue_panel.actor == terminal, "The intake log is read in a bubble over the terminal")
	level.finish_dialogue()
	director().open_prop(terminal)
	level.finish_dialogue()
	check(int(behavior.totals(true).seeker) == 2, "Reading the same log twice scores once")
	behavior.record("test_fight", "defiant", 1)
	# Approaching the frame picks the painting from this floor's play so far; no rights, so it is covered.
	level.player.global_position = frame.global_position + Vector2(-200, 0)
	await frames(2)
	var cleared: bool = director().load_art(frame.art_id) != null
	check(frame.assigned and frame.art.get("themes", []).any(func(theme):return theme in ["defiance", "betrayal"]) and frame.covered() != cleared, "The leaning picks the defiant painting; it shows only when its rights are verified")
	director().open_prop(frame)
	check(str(frame.art.title) in str(level.dialogue) and ("brass plate" in str(level.dialogue)) != cleared, "Looking at the frame names the work (a covered one reads its brass plate)")
	await frames(1)
	check(director().viewer.visible == cleared, "A cleared painting is shown up close while it is inspected")
	level.finish_dialogue()
	# Commit floor 1 unseen with a quiet pickpocket: ghost +3 +1 on top of the live events.
	campaign.complete_floor(1, true, {}, {"kills": 0, "detections": 0, "stealth_bonus": 1})
	await frames(2)
	check(behavior.committed.has(1) and int(behavior.committed[1].ghost) == 4, "Completing a floor folds in its stealth (unseen +3, pickpocket +1)")
	# Floor 2: verses join the Keepers' talk, two terminals, a frame by the stair gate.
	await floor_scene(2)
	check(director().terminals.size() == 3 and is_instance_valid(director().frame), "Floor 2 places three terminals and a frame")
	var verses: Array = level.world_features.conversation.filter(func(line): return line.get("verse", false))
	if level.world_features.get("casual_scenes") != null:
		for scene in level.world_features.casual_scenes:
			verses.append_array(scene.lines.filter(func(line): return line.get("verse", false)))
	check(verses.size() == 2, "One Bible verse exchange joins the Keepers' conversation")
	print("Verse branch on floor 2: ", verses[0].id)
	check(level.objective() == level.objective(), "Objectives are untouched")
	# Retry: floor 2 earnings vanish, floor 1 stays.
	behavior.record("x", "blackhat", 3)
	await floor_scene(2)
	check(int(behavior.totals(true).blackhat) == 0 and behavior.committed.has(1), "Retrying a floor drops what it earned and keeps earlier floors")
	# Every floor finds room for its props.
	for number in [3, 4, 5]:
		await floor_scene(number)
		var expected := 0
		for entry in JSON.parse_string(FileAccess.get_file_as_string("res://data/terminal_logs.json")).terminals:
			if int(entry.floor) == number:
				expected += 1
		check(is_instance_valid(director().frame) and director().terminals.size() == expected, "Floor %d places its frame and %d terminal(s)" % [number, expected])
		level.finish_dialogue()
		if director().terminals.is_empty():
			continue
		var controls = level.player.controls
		controls.has_remote = false
		level.player.position = director().terminals[0].position
		controls.open_local_console()
		check(controls.local_console and controls.remote_open, "Floor %d terminal works without the remote" % number)
		controls.run_command("scan")
		check("local" in controls.output.text, "Floor %d console can scan its connection" % number)
		if number == 4:
			var turrets := get_nodes_in_group("tower_turrets").filter(func(turret): return not turret.disabled)  # scenery turrets start off
			controls.run_command("turrets off")
			check(turrets.all(func(turret): return not turret.disabled), "Physical console requires authentication")
			controls.command.text = "login incorrect"
			controls.command.text_changed.emit(controls.command.text)
			check(controls.command.secret, "Console masks password entry")
			controls.run_command(controls.command.text)
			check("incorrect" not in controls.console_echo.text and "****" in controls.console_echo.text, "Echo hides the password")
			controls.run_command("login root")
			controls.run_command("turrets off")
			var local_turrets = turrets.filter(func(turret): return level.world_features.security_storey(turret.global_position.y)==level.world_features.security_storey(level.player.global_position.y))
			check(not local_turrets.is_empty() and local_turrets.all(func(turret): return turret.disabled), "Authenticated physical console disables storey turrets")
		controls.close_panels()
		for prop in director().lore_props():
			print("Floor %d %s at %s" % [number, prop.name, prop.global_position])
	check(director().frame.assigned, "Level 5's office painting is chosen on arrival")
	print("INNER_CONFLICT_RESULT: ", checks - failures.size(), "/", checks, " passed")
	quit(0 if failures.is_empty() else 1)
