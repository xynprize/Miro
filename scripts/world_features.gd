extends Node2D
## Small additive props, finite overheard scenes and offline spatial guard speech.
var level: Node2D
var floor_number := 1
var props: Array[Node2D] = []
var actors: Array[Node] = []
var conversation: Array = []
var conversation_index := -1
var conversation_done := false
var conversation_started := false
var line_left := 0.0
var retry_left := 0.0
var last_line: Dictionary = {}
var voice: AudioStreamPlayer2D
var voice_speaker: Node2D
var subtitle: Label
var speech_bubble: Control
var thought_bubble: Control
var thoughts: Dictionary
var thought_seen: Dictionary = {}
var thought_left := 0.0
var password_panel: PanelContainer
var password_input: LineEdit
var password_status: Label
var password_known := false
var terminal_authenticated := false
var config: Dictionary
var case_anchor_index := -1
var access_point := Vector2.ZERO
var practice_camera: Node
var early_authenticated := false
var trapdoors: Array[Node2D] = []
const NAMES := {1: ["Rowan", "Ivo", "Bram", "Seth"], 2: ["Alden", "Corin", "Dane", "Ellis"], 3: ["Marek", "Oren", "Pavel", "Silas"], 4: ["Tomas", "Ulric", "Venn", "Wren"], 5: ["Yorick", "Zane", "Arlen", "Beck"]}

func setup(owner_level: Node2D, number: int) -> void:
	level = owner_level
	floor_number = number
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/guard_dialogue.json"))
	voice = AudioStreamPlayer2D.new()
	voice.bus = "Voice"
	voice.process_mode = Node.PROCESS_MODE_PAUSABLE
	voice.max_distance = 300
	voice.attenuation = 1.5
	add_child(voice)
	speech_bubble = Control.new()
	speech_bubble.set_script(preload("res://scripts/character_bubble.gd"))
	level.hud.add_child(speech_bubble)
	subtitle = speech_bubble.text_label
	speech_bubble.visible = false
	thought_bubble = Control.new()
	thought_bubble.set_script(preload("res://scripts/character_bubble.gd"))
	thought_bubble.thought = true
	thought_bubble.actor = level.player
	level.hud.add_child(thought_bubble)
	thought_bubble.visible = false
	thoughts = JSON.parse_string(FileAccess.get_file_as_string("res://data/inner_dialogue.json"))
	var keepers: Array[Node] = level.guards()
	for index in range(keepers.size()):
		keepers[index].guard_name = NAMES[number][index % 4]
		keepers[index].voice_index = index % 3
		if number > 1 and not keepers[index].has_method("begin_recovery"):
			keepers[index].weapon_kind = ["pistol", "smg", "flamethrower"][index % (3 if number >= 4 else 2)]
	if config.conversations.has(str(number)) and not keepers.is_empty():
		var first = keepers[0]
		if number == 3:
			first.position = Vector2(330, 236)
		var partner = load("res://scenes/guard.tscn").instantiate()
		partner.name = "ConversationKeeper"
		partner.position = first.position + Vector2(50, 0)
		partner.patrol_left = partner.position.x
		partner.patrol_right = partner.position.x + 100
		partner.level = level
		partner.illness_started = true
		partner.guard_name = NAMES[number][3]
		partner.voice_index = 1
		level.get_node("Guards").add_child(partner)
		actors = [first, partner]
		conversation = config.conversations[str(number)]
		first.facing = 1
		partner.facing = -1
		# Hold a conversation-ready pose; detection and damage still work.
		first.conversation_hold = true
		partner.conversation_hold = true
	setup_trapdoors()
	place_props_after_physics()
	build_password_panel()
	if number in [1, 2]:
		access_point = Vector2(500, 432) if number == 1 else Vector2(440, 432)
		spawn_prop(access_point, "access", "SERVICE PORT")
		if number == 2:
			practice_camera = load("res://scenes/security_camera.tscn").instantiate()
			practice_camera.level = level
			practice_camera.position = Vector2(720, 370)
			level.add_child(practice_camera)

func place_props_after_physics() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	add_props()

func add_props() -> void:
	# Authored flat-floor anchors only: no random world-coordinate placements.
	var anchors := [Vector2(910, 236), Vector2(750, 432), Vector2(550, 656)]
	if floor_number == 1:
		anchors = [Vector2(580, 236), Vector2(900, 432), Vector2(780, 656)]
	var valid: Array[Vector2] = []
	for point in anchors:
		if not level.has_floor_below(point + Vector2(0, 13)):
			continue
		var near_station := false
		for node in level.areas.get_children():
			if node.global_position.distance_to(point) < 70 or (node.kind == "ladder" and Rect2(node.global_position - node.area_size / 2, node.area_size).grow(30).has_point(point)):
				near_station = true
		if not near_station and placement_clear(point):
			valid.append(point)
	if not valid.is_empty():
		var campaign = get_node("/root/Campaign")
		if not campaign.case_anchors.has(floor_number):
			campaign.case_anchors[floor_number] = randi_range(0, valid.size() - 1)
		case_anchor_index = int(campaign.case_anchors[floor_number]) % valid.size()
		spawn_prop(valid[case_anchor_index], "case", "Suppressor case")
	# Enclosed wall recesses; no platform or collision geometry is removed.
	for entry in [[Vector2(900, 432), "VENT"], [Vector2(420, 656), "CRAWLSPACE"]]:
		var point: Vector2 = entry[0]
		var clear: bool = not level.areas.get_children().any(func(area): return area.global_position.distance_to(point) < 70) and not props.any(func(prop): return prop.global_position.distance_to(point) < 70)
		if clear and placement_clear(point) and level.has_floor_below(point + Vector2(0, 13)):
			spawn_prop(point, "hide", entry[1])

func spawn_prop(point: Vector2, kind: String, title: String) -> void:
	var prop := Node2D.new()
	prop.set_script(load("res://scripts/review_prop.gd"))
	prop.position = point
	prop.kind = kind
	prop.title = title
	add_child(prop)
	props.append(prop)

func reachable(point: Vector2, distance := 36.0) -> bool:
	return level.player.global_position.distance_to(point) <= distance and level.clear_sight(level.player.global_position + Vector2(0, -8), point + Vector2(0, -8))

func story_distance() -> float:
	var closest := 48.0
	for area in level.areas.get_children():
		if area.kind in ["bed", "door", "sigil", "exit", "brother", "note"]:
			closest = minf(closest, level.player.global_position.distance_to(area.global_position))
	return closest

func nearby_prop():
	var best = null
	var distance := minf(36, story_distance())
	for prop in props:
		var candidate: float = level.player.global_position.distance_to(prop.global_position)
		if candidate < distance and reachable(prop.global_position) and not (prop.kind == "case" and prop.used):
			best = prop
			distance = candidate
	return best

func nearby_trapdoor():
	var best = null
	var distance := minf(38, story_distance())
	var prop = nearby_prop()
	if prop != null:
		distance = minf(distance, level.player.global_position.distance_to(prop.global_position))
	for trap in trapdoors:
		var handle: Vector2 = trap.global_position + Vector2(0, -28)
		var candidate: float = level.player.global_position.distance_to(handle)
		if absf(level.player.global_position.x - handle.x) <= 16 and candidate < distance and reachable(handle, 38):
			best = trap
			distance = candidate
	return best

func setup_trapdoors() -> void:
	var floor: TileMapLayer = level.get_node("StoneFloors")
	for cell in floor.get_used_cells():
		if floor.get_cell_source_id(cell) != 2:
			continue
		var point := floor.to_global(floor.map_to_local(cell))
		# Do not put an opening through an authored ladder corridor.
		var clear := true
		for area in level.areas.get_children():
			if area.kind == "ladder" and Rect2(area.global_position - area.area_size / 2, area.area_size).grow(18).intersects(Rect2(point - Vector2(14, 14), Vector2(28, 28))):
				clear = false
		if not clear:
			continue
		var trap := StaticBody2D.new()
		trap.set_script(preload("res://scripts/trapdoor.gd"))
		trap.level = level
		var gates = level.get_node_or_null("Gates")
		if gates != null:
			for gate in gates.get_children():
				if point.x < gate.global_position.x:
					trap.route_gate = gate
		trap.position = level.to_local(point)
		level.add_child(trap)
		trapdoors.append(trap)
		floor.erase_cell(cell)

func nearest_loot():
	var best = null
	var distance := 45.0
	for guard in level.guards():
		var candidate: float = guard.global_position.distance_to(level.player.global_position)
		if guard.is_dead and not guard.gun_taken and candidate < distance and level.can_melee_reach(level.player.global_position, guard.global_position):
			best = guard
			distance = candidate
	return best

func loot_takes_priority() -> bool:
	var guard = nearest_loot()
	if guard == null:
		return false
	var distance: float = guard.global_position.distance_to(level.player.global_position)
	var prop = nearby_prop()
	return distance <= story_distance() and (prop == null or distance <= prop.global_position.distance_to(level.player.global_position))

func hint() -> String:
	if level.controls_locked():
		return ""
	if level.player.controls.nearest_charge() != null:
		return "[E] Recover C4"
	if level.player.in_hiding_spot:
		return "[E] Leave hiding spot • movement and attacks disabled inside"
	if loot_takes_priority():
		return ""
	var trap = nearby_trapdoor()
	if trap != null:
		if not trap.available():
			return "Trapdoor locked · open checkpoint / ward seal first"
		return "Trapdoor open · closes when clear" if trap.is_open else "[E] Open trapdoor · 5 seconds"
	var prop = nearby_prop()
	if prop and prop.kind == "access":
		return "[E] Service port · select remote to connect"
	if prop:
		return "[E] Take suppressor • 3 shots" if prop.kind == "case" else "[E] Hide in " + prop.title.to_lower()
	return ""

func try_interact() -> bool:
	if level.player.in_hiding_spot:
		level.player.in_hiding_spot = false
		return true
	if loot_takes_priority():
		if floor_number > 1:
			level.player.loot_weapon(nearest_loot())
			return true
		return false
	var trap = nearby_trapdoor()
	if trap != null:
		trap.activate()
		return true
	var prop = nearby_prop()
	if prop == null:
		return false
	if prop.kind == "access":
		level.player.controls.open_remote()
		return true
	if prop.kind == "case":
		prop.used = true
		prop.queue_redraw()
		level.player.controls.collect_suppressor()
	else:
		if level.player.detection_state == "SPOTTED" or level.guards().any(func(guard): return guard.detect_player()):
			level.notify("Break sight before entering a hiding spot.")
			return true
		level.player.end_stealth()
		level.player.in_hiding_spot = true
		level.player.velocity = Vector2.ZERO
		level.notify("Hidden in " + prop.title.to_lower() + ". [E] Leave")
	return true

func _process(delta: float) -> void:
	queue_redraw()
	update_bubbles(delta)
	if not is_instance_valid(level) or level.paused:
		return
	if is_instance_valid(voice_speaker):
		voice.global_position = voice_speaker.global_position
		if voice_speaker.is_dead:
			voice.stop()
			subtitle.text = ""
		elif not last_line.is_empty():
			subtitle.visible = voice_speaker.global_position.distance_to(level.player.global_position) < 230 and not level.controls_locked()
			if subtitle.visible and last_line.has("clue"):
				password_known = true
	if level.controls_locked():
		voice.stream_paused = true
		return
	voice.stream_paused = false
	if level.player.is_dead:
		abort_conversation()
		return
	line_left = maxf(0, line_left - delta)
	if line_left == 0:
		subtitle.text = ""
		last_line = {}
	if conversation_done or actors.is_empty():
		return
	if actors.any(func(actor): return actor.is_dead or actor.alert_state != IntroGuard.State.PATROL):
		abort_conversation()
		retry_left = 8
		return
	retry_left = maxf(0, retry_left - delta)
	if retry_left > 0:
		return
	if not conversation_started:
		if level.player.global_position.distance_to(actors[0].global_position) > 250:
			return
		conversation_started = true
		conversation_index = -1
		for actor in actors:
			actor.conversation_hold = true
	if line_left <= 0:
		conversation_index += 1
		if conversation_index >= conversation.size():
			conversation_done = true
			for actor in actors:
				actor.conversation_hold = false
				actor.facing = 1
				actor.turn_away_left = 5.0
			return
		var line: Dictionary = conversation[conversation_index]
		speak(actors[int(line.speaker)], line.id, line.text, line)

func speak(actor: Node2D, id: String, text: String, extra: Dictionary = {}) -> void:
	voice.stop()
	voice_speaker = actor
	speech_bubble.actor = actor
	voice.global_position = actor.global_position
	var path := "res://assets/audio/voice/%s.mp3" % id
	var duration := maxf(2.5, text.length() * 0.055)
	if ResourceLoader.exists(path):
		voice.stream = load(path)
		duration = voice.stream.get_length()
		if DisplayServer.get_name() != "headless":
			voice.play()
	line_left = duration + 0.35
	subtitle.text = "%s: %s" % [actor.guard_name, text]
	last_line = extra.duplicate()
	if last_line.is_empty():
		last_line = {"bark": true}

func bark(actor: Node2D, kind: String) -> void:
	abort_conversation()
	if voice.playing:
		return
	speak(actor, "%s_%d" % [kind, actor.voice_index], config.barks[kind].text)

func abort_conversation() -> void:
	if conversation_started and not conversation_done:
		conversation_started = false
		conversation_done = true
		conversation_index = -1
		voice.stop()
		line_left = 0
		last_line = {}
		subtitle.text = ""
	for actor in actors:
		actor.conversation_hold = false

func voice_audible() -> bool:
	return line_left > 0 and is_instance_valid(voice_speaker) and not voice_speaker.is_dead and voice_speaker.global_position.distance_to(level.player.global_position) < 230

func update_bubbles(delta: float) -> void:
	if not is_instance_valid(level):
		return
	speech_bubble.visible = voice_audible() and not level.controls_locked() and not level.player.is_dead
	speech_bubble.follow_actor()
	thought_bubble.visible = false
	if level.controls_locked() or level.player.is_dead:
		return
	if speech_bubble.visible:
		return
	if thought_left > 0:
		thought_left = maxf(0, thought_left - delta)
		thought_bubble.visible = thought_left > 0
		thought_bubble.follow_actor()
		return
	for entry in thoughts.get(str(floor_number), []):
		if thought_seen.has(entry.id):
			continue
		var ready := true
		if entry.has("milestone"):
			ready = floor_number > 1 and level.milestones.has(entry.milestone)
		if entry.has("minimum_y"):
			ready = ready and level.player.position.y >= entry.minimum_y
		if ready:
			thought_seen[entry.id] = true
			thought_bubble.text_label.text = "MIRO · thinking\n" + entry.text
			thought_left = maxf(5, entry.text.length() * 0.075)
			break

func build_password_panel() -> void:
	password_panel = level.panel_at(Vector2(110, 95), Vector2(420, 190))
	var box := VBoxContainer.new()
	password_panel.add_child(box)
	var title := Label.new()
	title.text = "CHECKPOINT LOGIN"
	box.add_child(title)
	password_input = LineEdit.new()
	password_input.placeholder_text = "Password (case-sensitive)"
	box.add_child(password_input)
	password_input.text_submitted.connect(submit_password)
	var login := Button.new()
	login.text = "Log in"
	login.pressed.connect(func(): submit_password(password_input.text))
	box.add_child(login)
	var slip := Button.new()
	slip.text = "Inspect maintenance slip"
	slip.pressed.connect(func(): password_known = true; password_status.text = "Maintenance slip: root (all lowercase).")
	box.add_child(slip)
	password_status = Label.new()
	password_status.text = "Listen nearby, or inspect the maintenance slip."
	box.add_child(password_status)
	var cancel := Button.new()
	cancel.text = "Close"
	cancel.pressed.connect(func(): password_panel.hide())
	box.add_child(cancel)
	password_panel.hide()

func open_terminal() -> void:
	password_panel.show()
	password_input.text = ""
	password_status.text = "Overheard password: root" if password_known else "Listen nearby, or inspect the maintenance slip."
	password_input.grab_focus()

func submit_password(text: String) -> void:
	if text != "root":
		password_status.text = "Access denied. Password is case-sensitive."
		return
	terminal_authenticated = true
	password_panel.hide()
	level.hack_remaining = 1.0

func modal_open() -> bool:
	return is_instance_valid(password_panel) and password_panel.visible

func _exit_tree() -> void:
	if is_instance_valid(voice):
		voice.stop()
		voice.stream = null
	actors.clear()
	voice_speaker = null

func placement_clear(point: Vector2) -> bool:
	for area in level.areas.get_children():
		if area.kind == "ladder" and Rect2(area.global_position - area.area_size / 2, area.area_size).grow(30).has_point(point):
			return false
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 26)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, point + Vector2(0, 1.5))
	query.collision_mask = 1
	query.margin = 0
	return get_world_2d().direct_space_state.intersect_shape(query).is_empty()
