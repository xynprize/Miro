extends Node2D
## The first floor only. Story flags stay local so R restores the entry state.

@onready var player: IntroPlayer = $Player
@onready var areas: Node2D = $Interactables
var radio_line := ""
## Remaining voiced-line time; manual advance may interrupt it, while Tab skips the conversation.
var line_lock := 0.0
## A cinematic card over the start of a floor or a story beat (scripts/floor_card.gd).
var card: Control
var door_open: bool = false
var sigil_placed: bool = false
## Niro over the remote when Level 1 ends ("The remote crackles").
const FLOOR_END_CRACKLE := "...Miro?"
## What the remote says as each floor's report comes up (floors without an entry stay quiet): the
## written closing line, never the same "Miro" twice.
## Miro answers the remote after the line (floor 2: "From who?" was only text).
const FLOOR_END_REPLIES := {2: "From who?"}
const FLOOR_END_LINES := {1: "...Miro?", 2: "If you go any lower, I can't protect you.", 3: "You've read it by now. Miro, please... let me explain.", 4: "Don't come down here, Miro. Please."}
var crackle_played := false
var brother_heard: bool = false
var completed: bool = false
var paused: bool = false
var route: String = ""
var dialogue: Array = []
var dialogue_index: int = 0
var dialogue_event: String = ""
var message: String = ""
var message_left: float = 0.0
var elapsed: float = 0.0
var hud: CanvasLayer
var status_label: Label
var health_label: RichTextLabel
var objective_label: Label
var hint_label: Label
var message_label: Label
var dialogue_panel: Control
var dialogue_label: Label
var overlay: PanelContainer
var overlay_label: Label
var shot_flash: float = 0.0
var world_features: Node2D
const VISUALS = preload("res://scripts/visual_assets.gd")
var hint_icon: TextureRect
var stealth_meter: Control
var effects: Node2D
# Branch tracking (committed to Campaign only when the floor is completed).
var floor_detections := 0
var was_spotted := false
var voice_remote: TextureRect
var spotted_at := -100.0
var loud_events := 0
var stealth_bonus := 0

func _ready() -> void:
	get_node("/root/Campaign").enter_floor(1)
	process_mode = Node.PROCESS_MODE_ALWAYS
	setup_inputs()
	player.level = self
	if has_node("LevelPlan/PlayerSpawn"):
		player.global_position = $LevelPlan/PlayerSpawn.global_position
	for guard in guards():
		guard.level = self
	build_hud()
	apply_difficulty()
	setup_world_features(1)
	# One more patrol on the second floor, right of the first ladder.
	var annex = load("res://scenes/guard.tscn").instantiate()
	annex.name = "AnnexKeeper"
	annex.position = Vector2(1010, 432)
	annex.patrol_left = 940.0
	annex.patrol_right = 1070.0
	annex.level = self
	annex.illness_started = true
	annex.weapon_kind = "pistol"
	world_features.assign_keeper(annex, "Rocco")
	$Guards.add_child(annex)
	start_dialogue([
		["MIRO", "Stone. Iron. A name scratched into the bed: Miro.\nMine... I think. Nothing before this room.", "thought"],
		["JUDAS", "Awake again. Keep it down, traitor."],
		["MIRO", "Is there anything you can do for me?"],
		["JUDAS", "Depends. Cell 04 gave me his boots. Cell 09 gave me his ration card.\nWhat have you got?"],
		["MIRO", "You're looking at it."],
		["JUDAS", "Then I'm not looking. (He turns away, coughing.)\nThe tower doesn't pay me enough to care."],
		["MIRO", "His hands are shaking. The same marks as the others.\nHe's turned away. This might be my only chance.", "thought"]
	], "intro")
	show_card("floor", "01", "THE PRISONER")
	var launch_floor: int = get_node("/root/Campaign").launch_floor()
	if launch_floor > 1:
		get_tree().call_deferred("change_scene_to_file", "res://scenes/levels/level_%02d.tscn" % launch_floor)

## Settings difficulty: Miro's hearts and the blanket's active/recharge times.
func apply_difficulty() -> void:
	var tuning: Dictionary = get_node("/root/Campaign").tuning()
	player.health = int(tuning.health)
	player.max_health = player.health
	player.stealth_cooldown = float(tuning.stealth_cooldown)
	player.stealth_duration = float(tuning.stealth_duration)

func setup_inputs() -> void:
	var bindings := {"slow_walk": [KEY_SHIFT], "move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "climb_up": [KEY_W, KEY_UP], "climb_down": [KEY_S, KEY_DOWN], "jump": [KEY_SPACE], "dodge": [KEY_ALT, KEY_C], "attack": [], "cloak": [], "explosive": [], "fire": [], "interact": [KEY_E], "advance": [KEY_ENTER], "skip": [KEY_TAB], "pause_game": [KEY_ESCAPE], "retry": [KEY_BACKSPACE]}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)

	for action in ["pad_use", "pad_focus"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
	add_pad_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	add_pad_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	add_pad_axis("climb_up", JOY_AXIS_LEFT_Y, -1.0)
	add_pad_axis("climb_down", JOY_AXIS_LEFT_Y, 1.0)
	add_pad_axis("pad_use", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	add_pad_axis("pad_focus", JOY_AXIS_TRIGGER_LEFT, 1.0)
	# Back/Select skips a dialogue (Tab on the keyboard).
	for pair in [["dodge", JOY_BUTTON_B], ["advance", JOY_BUTTON_A], ["pause_game", JOY_BUTTON_START], ["skip", JOY_BUTTON_BACK]]:
		var event := InputEventJoypadButton.new()
		event.button_index = pair[1]
		InputMap.action_add_event(pair[0], event)

	# Menus and pop-ups (the Level 3 checkpoint login) take A to press and B to back out.
	for pair in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var event := InputEventJoypadButton.new()
		event.button_index = pair[1]
		if not InputMap.action_has_event(pair[0], event):
			InputMap.action_add_event(pair[0], event)

	get_node("/root/InputBindings").apply()
	apply_controller_deadzone()
	var settings = get_node("/root/ControllerSettings")
	if not settings.changed.is_connected(apply_controller_deadzone):
		settings.changed.connect(apply_controller_deadzone)

func apply_controller_deadzone() -> void:
	var value: float = get_node("/root/ControllerSettings").preferences.deadzone
	for action in ["move_left", "move_right", "climb_up", "climb_down"]:
		InputMap.action_set_deadzone(action, value)

func add_pad_axis(action: String, axis: int, direction: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = direction
	InputMap.action_add_event(action, event)

func controls_locked() -> bool:
	return is_instance_valid(get_node("/root/InputBindings").panel) or (is_instance_valid(player.controls) and player.controls.locked()) or is_instance_valid(player.pending_guard) or paused or not dialogue.is_empty() or completed or (is_instance_valid(world_features) and world_features.modal_open())

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(get_node("/root/InputBindings").panel): return
	if event.is_pressed() and get_node("/root/InputBindings").matches(event, "return_menu"):
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return
	if completed and event.is_action_pressed("advance") and not event.is_echo():
		get_node("/root/Campaign").complete_floor(1, sigil_placed, {"BrotherVoice": brother_heard}, floor_raw_stats())
		get_node("/root/Campaign").update_unlocks()
		get_viewport().set_input_as_handled()
		play_interlude(1, "res://scenes/levels/level_02.tscn")
		return
	# Retry on a controller: Square (X) on the death or floor-complete screen only, never mid-play.
	var pad_retry: bool = (player.is_dead or completed) and event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_X
	if (event.is_action_pressed("retry") or pad_retry) and not event.is_echo():
		# A retry resumes from the floor's last storey checkpoint (see scaffold_level).
		var saved: Dictionary = get_node("/root/Campaign").checkpoint
		if not saved.is_empty():
			saved["retry"] = true
		get_tree().paused = false
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()
	elif event.is_action_pressed("pause_game") and not completed:
		paused = not paused
		get_tree().paused = paused
		get_viewport().set_input_as_handled()
	elif not dialogue.is_empty() and not paused:
		if event.is_action_pressed("advance") or event.is_action_pressed("interact"):
			dialogue_index += 1
			if dialogue_index >= dialogue.size():
				finish_dialogue()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("skip"):
			finish_dialogue()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and not event.is_echo():
		world_features.next_strangle_requires_hold = true
		interact()
		world_features.next_strangle_requires_hold = false
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and get_node("/root/InputBindings").matches(event, "hint") and not controls_locked() and not player.is_dead:
		# Z: Miro thinks through what to do next, in his thought bubble.
		if is_instance_valid(world_features):
			world_features.think(z_hint(), "", true)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not paused:
		elapsed += delta
		update_stuck(delta)
		message_left = maxf(0, message_left - delta)
		shot_flash = maxf(0, shot_flash - delta)
	# The voice behind the bars speaks on its own as Miro reaches the gate.
	if not brother_heard and dialogue.is_empty() and not controls_locked() and not player.is_dead and player.is_on_floor() and nearby("brother", 90):
		start_brother()
	var pursuing := false
	var searching := false
	for guard in guards():
		if not guard.is_dead:
			pursuing = pursuing or (guard.sees_player and guard.alert_state == IntroGuard.State.ALERT)
			searching = searching or guard.alert_state != IntroGuard.State.PATROL or guard.pursuing or guard.windup > 0 or guard.burst_left > 0
	if pursuing and not was_spotted and counts_detection():
		floor_detections += 1
	was_spotted = pursuing
	# Being seen isn't forgotten the instant the Keepers lose track: stay "searching" a while.
	if pursuing:
		spotted_at = elapsed
	searching = searching or (spotted_at >= 0.0 and elapsed - spotted_at < 8.0)
	player.detection_state = "SPOTTED" if pursuing else ("HIDDEN" if (player.is_concealed or player.in_hiding_spot) else ("SEARCHING" if searching else ("CLEAR" if spotted_at >= 0.0 or floor_detections > 0 else "UNSEEN")))
	var status := player.detection_state
	if player.has_key:
		status += " · KEY"
	var halves := clampi(player.health, 0, 20)
	var hearts := "[img=13x12]res://assets/misc/health_heart.png[/img] ".repeat(halves / 2)
	if halves % 2 == 1:
		hearts += "[img=7x12 region=0,0,7,12]res://assets/misc/health_heart.png[/img] "
	var health_text := "MIRO   " + hearts + "   " + status
	if health_label.text != health_text:
		health_label.text = health_text
	status_label.text = get_node("/root/ControllerSettings").prompt(player.stealth_status()) if player.has_supplies else ""
	objective_label.text = get_node("/root/ControllerSettings").prompt(objective())
	hint_label.text = get_node("/root/ControllerSettings").prompt(context_hint())
	hint_icon.texture = null if player.controls.pad_prompts else VISUALS.hint_texture(hint_label.text)
	hint_icon.visible = hint_icon.texture != null
	stealth_meter.visible = player.has_supplies
	stealth_meter.value = player.stealth_remaining / player.stealth_duration if player.is_concealed else 1.0 - player.stealth_cooldown_left / player.stealth_cooldown
	message_label.text = get_node("/root/ControllerSettings").prompt(message) if message_left > 0 else ""
	dialogue_panel.visible = not dialogue.is_empty() and not paused
	line_lock = maxf(0.0, line_lock - get_process_delta_time())
	if not dialogue.is_empty():
		var line: Array = dialogue[dialogue_index]
		var anchor := speaker_anchor(str(line[0]))
		dialogue_panel.actor = anchor
		var marked_thought: bool = line.size() > 2 and str(line[2]) == "thought"
		dialogue_panel.thought = str(line[0]) == "MIRO" and anchor == player and (marked_thought or is_thought_line(str(line[1])))
		var label := str(line[0])
		if anchor == player and str(line[0]) not in ["MIRO"]:
			label += " · remote" if str(line[0]) in ["NIRO", "THE VOICE", "BROTHER"] else ""
		dialogue_panel.speaker = label
		dialogue_label.text = get_node("/root/ControllerSettings").prompt(str(line[1]))
		dialogue_panel.follow_actor()
		# Niro's lines over the remote come out of the radio: bitcrushed, static, dropouts.
		var spoken_text := str(line[1])
		if line.size() > 3 and str(line[3]).begins_with("choice:"):
			var choice: Dictionary = get_node("InnerConflict").current_choice()
			spoken_text = str(choice.get("prompt", spoken_text))
		var key := "%d:%s" % [dialogue_index, spoken_text]
		if key != radio_line:
			radio_line = key
			var radio = get_node("/root/RemoteRadio")
			var niro_line := str(line[0]) in ["NIRO", "THE VOICE", "BROTHER", "A VOICE BEYOND THE BARS"]
			if niro_line and anchor == player:
				radio.say(str(line[1]))
			elif niro_line:
				radio.say_in_room(str(line[1]), "niro", "Voice", 0.0, anchor)
			elif str(line[0]) == "TOWER PA":
				radio.say_in_room(str(line[1]), "pa")
			elif str(line[0]) == "JUDAS":
				radio.say_in_room(str(line[1]), "judas", "Voice", 0.0, anchor)
			elif str(line[0]) in ["PRISONER", "THE PRISONER"]:
				radio.say_in_room(str(line[1]), "prisoner", "Voice", 0.0, anchor)
			elif str(line[0]) == "MIRO":
				radio.say_in_room(spoken_text, "miro", "Thought" if dialogue_panel.thought else "Voice")
			else:
				radio.stop()
			line_lock = 0.0
			if radio.audible() and niro_line:
				var length: float = radio.speaking_left
				if (radio.room.playing or radio.room_is_spatial()) and radio.room.stream != null:
					length = maxf(length, radio.room.stream.get_length())
				line_lock = minf(length, 14.0)
		# The MP3 pops up at the side of the screen while his brother's voice comes through it.
		voice_remote.visible = str(line[0]) in ["NIRO", "THE VOICE", "BROTHER"] and anchor == player
		voice_remote.modulate.a = 0.75 + 0.25 * sin(elapsed * 9.0)
	elif not radio_line.is_empty():
		voice_remote.visible = false
		radio_line = ""
		get_node("/root/RemoteRadio").stop()
	# Paused: the pause menu (scripts/pause_menu.gd) covers the screen instead.
	overlay.visible = completed or player.is_dead
	if completed:
		if not crackle_played:
			# The remote crackles with his brother's voice as the floor report comes up.
			crackle_played = true
			var reply: String = FLOOR_END_REPLIES.get(int(get("definition").number) if get("definition") != null else 1, "")
			if not reply.is_empty():
				# Miro answers the remote once it has finished speaking.
				var wait: float = get_node("/root/RemoteRadio").clip_length(str(FLOOR_END_LINES.get(int(get("definition").number), ""))) + 0.5
				get_tree().create_timer(wait).timeout.connect(func(): get_node("/root/RemoteRadio").say_in_room(reply, "miro", "Voice"))
			var end_line: String = FLOOR_END_LINES.get(int(get("definition").number) if get("definition") != null else 1, "")
			if not end_line.is_empty():
				get_node("/root/RemoteRadio").say(end_line)
		var raw := floor_raw_stats()
		overlay_label.text = get_node("/root/ControllerSettings").prompt("THE PRISONER\n\nThe first mark is set. The remote crackles: \"...Miro?\"\n\nEscape: %s   ·   %s   ·   Kills %d   ·   Seen %d\n\n[Enter] Descend to Level 2\n[Backspace] Replay the floor" % [route, get_node("/root/Campaign").style_word(raw), raw.kills, raw.detections])
	elif player.is_dead:
		overlay_label.text = get_node("/root/ControllerSettings").prompt("THE TOWER KEEPS ITS PRISONERS\n\n[Backspace] Retry from the cell\nTry cover, a quiet key theft, or dodge the wind-up.")
	queue_redraw()

## Z: Miro thinks it through. Up to three hints per objective, each press more direct
## (a nudge, then where, then exactly what to do), so a stuck player is never stuck for long.
var hint_tiers: Dictionary = {}
var stuck_key := ""
var stuck_time := 0.0
const STUCK_SECONDS := 60.0

const L1_HINTS := {
	"supplies": ["Something is hidden under my bed. I can feel the shape of it.",
		"The bed is right here in the cell. Stand at it.",
		"Walk to the bed in the cell and press E."],
	"door": ["Judas has a key. Or the lock could just stop existing.",
		"Wait for him to turn away and take the key [E]. Or set a charge on the lock: [2], right click.",
		"Stand behind Judas while he faces away and press E. Or select C4 [2], right click the lock, step back, left click."],
	"brother": ["Maybe I can use my blanket to hide.", "The gallery leads to a barred gate. Someone's waiting there.",
		"Go right along the gallery, past the cells, to the bars.",
		"Walk right to the barred gate and press E."],
	"sigil": ["'Leave a mark.' Down where the tower holds itself up.",
		"Take the ladders down to the lowest floor.",
		"On the bottom floor, find the support and press E."],
	"exit": ["The stairs down. Lower right.",
		"Bottom floor, far right.",
		"Walk to the lower-right stair gate and press E."],
}

func hint_key() -> String:
	if not player.has_supplies:
		return "supplies"
	if not door_open:
		return "door"
	if not brother_heard:
		return "brother"
	if not sigil_placed:
		return "sigil"
	return "exit"

func hint_lines(key: String) -> Array:
	return L1_HINTS.get(key, [])

func z_hint() -> String:
	if is_instance_valid(world_features):
		var security_tip: String = world_features.security_hint()
		if not security_tip.is_empty():return security_tip
	var key := hint_key()
	var lines: Array = hint_lines(key)
	if lines.is_empty():
		var goal := objective()
		if "\n" in goal:
			goal = goal.get_slice("\n", 1)
		return goal
	var tier := int(hint_tiers.get(key, 0))
	hint_tiers[key] = mini(tier + 1, lines.size() - 1)
	stuck_time = 0.0
	return str(lines[mini(tier, lines.size() - 1)])

## After a minute on the same objective, the bottom strip offers Z.
func update_stuck(delta: float) -> void:
	var key := hint_key()
	if key != stuck_key:
		stuck_key = key
		stuck_time = 0.0
	elif not controls_locked():
		stuck_time += delta

func stuck() -> bool:
	return stuck_time >= STUCK_SECONDS

func counts_detection() -> bool:
	return true

func floor_raw_stats() -> Dictionary:
	var named_dead: Array[String] = []
	for guard in guards():
		if guard.is_dead and not guard.guard_name.is_empty():named_dead.append(guard.guard_name)
	return {"kills": player.casualty_count, "detections": floor_detections, "stealth_bonus": stealth_bonus, "loud": loud_events, "named_dead": named_dead}

func objective() -> String:
	if completed:
		return "01 / THE PRISONER   •   COMPLETE"
	if not player.has_supplies:
		return "01 / THE PRISONER\nSearch beneath your bed. [E]"
	if not door_open:
		return "Escape the cell\nSteal the key, use the shank, or breach the lock."
	if not brother_heard:
		return "Find a way down\nFollow the gallery to the barred gate."
	if not sigil_placed:
		return "Leave a mark\nDescend the ladders. Find the lower support."
	return "The way below\nReach the lower-right stair gate. [E]"

## Which character a forced line hangs over. Documents hang over the note being read.
func speaker_anchor(speaker: String) -> Node2D:
	match speaker:
		"MIRO":
			return player
		"JUDAS", "KEEPER":
			if has_node("Guards/CorruptKeeper"):
				return get_node("Guards/CorruptKeeper")
		"NIRO", "BROTHER":
			var boss = get("brother")
			if boss != null and is_instance_valid(boss):
				return boss
			return player
		"A VOICE BEYOND THE BARS":
			var gate = nearby("brother", 200)
			return gate if gate else player
		"THE VOICE":
			# His brother is never in the room as "The Voice": it always comes through the remote.
			return player
	var reading = nearby("note", 90)
	if reading == null:
		reading = nearby("sigil", 90)
	if reading == null:
		reading = nearby("brother", 90)
	return reading if reading else player

## Miro's lines in brackets or with no one to talk to read as thoughts.
func is_thought_line(text: String) -> bool:
	return text.begins_with("(") or speaker_listener() == null

func speaker_listener():
	for line in dialogue:
		if str(line[0]) != "MIRO":
			return line
	return null

func show_card(mode: String, heading: String, title_text: String, detail := "", accent := Color("c69fa5"), length := 3.4) -> void:
	if is_instance_valid(card):
		card.finish()
	card = Control.new()
	card.set_script(preload("res://scripts/floor_card.gd"))
	card.mode = mode
	card.heading = heading
	card.title_text = title_text
	card.detail = detail
	card.accent = accent
	card.length = length
	card.level = self
	hud.add_child(card)

## The cinematic between floors (scripts/interlude_cinematic.gd), then the next scene.
func kit_snapshot() -> Dictionary:
	var c = player.controls
	var carried_c4 := player.c4_count
	for charge in c.planted:
		if is_instance_valid(charge) and bool(charge.get_meta("inventory_charge", true)):
			carried_c4 += 1
	return {
		"has_supplies": player.has_supplies, "has_gun": player.has_gun, "guns": Array(player.guns),
		"gun_ammo": player.gun_ammo.duplicate(), "equipped_gun": player.equipped_gun, "ammunition": player.ammunition,
		"c4_count": carried_c4, "reserves": c.reserves.duplicate(), "health": player.health,
	}

func play_interlude(floor_done: int, next_scene: String) -> void:
	get_node("/root/Campaign").carried_kit = kit_snapshot()
	get_node("/root/Campaign").carried_from = floor_done
	if DisplayServer.get_name() == "headless":
		get_tree().change_scene_to_file(next_scene)
		return
	var layer := CanvasLayer.new()
	layer.layer = 95
	var scene: Control = preload("res://scripts/interlude_cinematic.gd").new()
	scene.floor_done = floor_done
	scene.finished.connect(func(): get_tree().change_scene_to_file(next_scene))
	layer.add_child(scene)
	add_child(layer)

func start_dialogue(lines: Array, event: String = "") -> void:
	dialogue = lines
	dialogue_index = 0
	dialogue_event = event
	player.velocity = Vector2.ZERO

func finish_dialogue() -> void:
	var event := dialogue_event
	dialogue = []
	dialogue_index = 0
	dialogue_event = ""
	if event == "intro":
		var guard: IntroGuard = $Guards/CorruptKeeper
		guard.illness_started = true
		guard.facing = 1
		guard.turn_wait = 4.0
		notify("Judas doubles over, coughing. Search your bed. [E]", 8)
	elif event == "brother":
		brother_heard = true

func guards() -> Array[Node]:
	return get_tree().get_nodes_in_group("guards")

## Light sources (torches, lamps) registered by the level art; moss watchers count too.
var light_points: Array[Vector2] = []
const LIGHT_RADIUS := 70.0

## The tower is dark by nature, so the blanket hides Miro anywhere except inside a light's
## radius. A crouching Miro slips under the radius (the glow is above him).
func in_light(point: Vector2, crouched := false) -> bool:
	if crouched:
		return false
	for light in light_points:
		if get("definition") == null:
			# Level 1 keeps its authored torch boxes (the quiet route is tuned to them).
			if absf(light.x - point.x) < LIGHT_RADIUS and absf(light.y - point.y) < 150.0:
				return true
			continue
		# Floors 2-5: a lamp lights only its own floor: it hangs above Miro, and its pool is an oval under it.
		var below: float = point.y - light.y
		if below > -60.0 and below < 150.0:
			var across := (light.x - point.x) / 56.0
			var down := below / 150.0
			if across * across + down * down < 1.0:
				return true
	return false

## True where the blanket works (kept under its old name for the HUD and tests).
func in_cover(point: Vector2) -> bool:
	return not in_light(point, is_instance_valid(player) and player.crouching)

func ladder_at(point: Vector2):
	for area in areas.get_children():
		if area.kind == "ladder" and area.contains(point):
			return area
	return null

func clear_sight(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	query.hit_from_inside = true
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func has_floor_below(point: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(point, point + Vector2(0, 22), 1)
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func can_melee_reach(from: Vector2, to: Vector2) -> bool:
	# The cell bars permit a reach-through attack on the nearby keeper.
	var lock_position: Vector2 = $Interactables/CellLock.global_position
	if not door_open and from.x < lock_position.x and to.x > lock_position.x and to.x < lock_position.x + 38 and absf(from.y - to.y) < 25 and absf(from.y - lock_position.y) < 40:
		return true
	return clear_sight(from, to)

func closest_guard(maximum: float = 45.0):
	var best = null
	var distance := maximum
	for guard in guards():
		var candidate: float = guard.global_position.distance_to(player.global_position)
		if candidate < distance and can_melee_reach(player.global_position, guard.global_position):
			distance = candidate
			best = guard
	return best

func nearby(kind: String, maximum: float = 48.0):
	for area in areas.get_children():
		if area.kind == kind and area.global_position.distance_to(player.global_position) < maximum:
			return area
	return null

func context_hint() -> String:
	if world_features:
		var feature_hint: String = world_features.hint()
		if not feature_hint.is_empty(): return feature_hint
	if controls_locked() or player.is_dead:
		return ""
	if nearby("bed") and not player.has_supplies:
		return "[E] Search beneath the bed"
	var guard = world_features.nearest_loot() if world_features.loot_takes_priority() else closest_guard()
	if guard:
		if (guard.is_dead or guard.asleep) and (not guard.gun_taken or (guard.sick_guard and not guard.key_taken)):
			return "[E] Search fallen Keeper"
		if guard.sick_guard and not guard.key_taken:
			return "[E] Pickpocket when he turns away   /   [F] Melee   /   [3] C4"
	if nearby("door", 65) and not door_open:
		return "[E] Unlock with key   /   [3] C4"
	if nearby("sigil"):
		return "The mark is set." if sigil_placed else "[E] Set your mark on the support"
	if nearby("exit", 65):
		return "[E] Descend" if sigil_placed else "Leave your mark at the support before descending."
	if nearby("brother", 75) and not brother_heard:
		return "[E] Listen at the barred gate"
	if nearby("note"):
		return "[E] Read the quarantine order"
	if player.is_concealed:
		return "Move carefully • touching a Keeper breaks stealth"
	if ladder_at(player.global_position):
		return "[W / S] Climb. Keepers can follow you."
	if stuck():
		return "Not sure where to go? [Z] Think it through"
	return "A/D Move · [Space] twice Double jump · [C] Dash\nLeft Ctrl Crouch · Shift Quiet walk · [Q] Blanket · [Esc] Controls"

## Achievement hook shared with later floors; combat behavior remains in IntroGuard.
func on_keeper_killed(guard) -> void:
	get_node("/root/Campaign").on_keeper_killed(str(guard.guard_name), true)

## E behind an unaware Keeper strangles him: out cold, no blood, not a casualty.
func try_strangle() -> bool:
	if world_features != null and world_features.strangle_active():
		return true
	if world_features == null or world_features.loot_takes_priority():
		return false
	var victim = world_features.strangle_target()
	if victim == null:
		return false
	world_features.begin_strangle(victim)
	return true

func finish_strangle(victim: IntroGuard) -> void:
	victim.strangle()
	stealth_bonus += 1
	# A quiet takedown feeds the ghost branch (the artwork), never the offense one.
	var behavior = get_node_or_null("/root/PlayerBehavior")
	if behavior != null:
		behavior.record("strangle_%d" % victim.get_instance_id(), "ghost", 2)
	get_node("/root/SoundFX").play_sound("swing", -12, 0.7)
	notify("He goes limp. Out cold, not dead. [E] to loot him.")
	# Achievement tracking
	var campaign = get_node("/root/Campaign")
	var is_named: bool = not str(victim.get("guard_name")).is_empty()
	campaign.on_keeper_strangled(str(victim.get("guard_name")), is_named)

func interact() -> void:
	if controls_locked() or player.is_dead:
		return
	if player.controls.recover_charge():
		return
	if try_strangle():
		return
	if world_features and world_features.try_interact():
		return
	var bed = nearby("bed")
	if bed and not player.has_supplies:
		player.has_supplies = true
		player.c4_count = 3 # Three optional charges; the sigil has a separate story reserve.
		bed.activated = true
		bed.queue_redraw()
		start_dialogue([
			["MIRO", "Wire. Powder. Two charges, hidden beneath the bed.\nI've been building these in secret. My hands remember; I don't."],
			["MIRO", "A sharpened spoon. My blanket. Something I scratched\non the wrapping: 'Leave a mark. Keep going down.'"],
			["MIRO", "His key, while he faces away [E]. The spoon for close work [1, left click].\nThe charges [2]: right click to set one, left click to blow it.", "thought"]
		])
		return
	var guard = world_features.nearest_loot() if world_features.loot_takes_priority() else closest_guard()
	if guard and (((guard.is_dead or guard.asleep) and (not guard.gun_taken or (guard.sick_guard and not guard.key_taken))) or (guard.sick_guard and not guard.key_taken)):
		if not player.has_supplies:
			notify("Gather your hidden supplies before leaving.")
			return
		if guard.is_dead or guard.asleep:
			if guard.sick_guard and not guard.key_taken:
				player.has_key = true
				player.controls.collect_remote()
				guard.key_taken = true
				if route == "":
					route = "shank"
			if not guard.gun_taken:
				player.loot_weapon(guard)
			else:
				notify("Nothing else to take.")
		elif guard.facing * (player.global_position.x - guard.global_position.x) < -6 and guard.alert_state != IntroGuard.State.ALERT:
			guard.key_taken = true
			player.controls.collect_remote()
			player.has_key = true
			route = "pickpocket"
			stealth_bonus += 1
			notify("The key slips free. No one noticed. [E] at the lock to open it.")
			# Achievement: pickpocket Judas
			get_node("/root/Campaign").unlock_achievement("pickpocket_judas")
			get_node("/root/Campaign").add_track_unlock("skillibeng_type_beat")
		else:
			notify("He can see your hand. Wait until he turns his back.")
		return
	if nearby("door", 65) and not door_open:
		if player.has_key:
			open_door()
			notify("A quiet click. Shadow alcoves can hide you: press [Q].", 7)
		else:
			notify("Locked. Steal the key from Judas, loot him, or use C4 [2].")
		return
	if nearby("brother", 75) and not brother_heard:
		start_brother()
		return
	if nearby("note"):
		start_dialogue([["QUARANTINE ORDER", "Keepers: report every cough, including your own.\nNo names. Record the cell numbers only.\nTransfer all marked prisoners to the lower ward."]])
		return
	if nearby("sigil") and not sigil_placed:
		if not player.has_supplies:
			notify("The materials are hidden beneath your bed.")
			return
		if not brother_heard:
			start_brother()
			return
		sigil_placed = true
		get_node("/root/SoundFX").play_sound("sigil", -16)
		# The reserved story charge is separate from the three optional charges.
		var anchor = nearby("sigil")
		anchor.activated = true
		anchor.queue_redraw()
		make_noise(anchor.global_position, 240)
		start_dialogue([["MIRO", "This shape... I know it. My hands won't stop shaking.\nOne mark. Then down. Whoever wrote that wanted me to leave."]])
		return
	if nearby("exit", 65):
		if sigil_placed:
			completed = true
			player.velocity = Vector2.ZERO
		else:
			notify("'Leave a mark.' The support to the left feels familiar.")

func start_brother() -> void:
	var response := "You took his life. Was that necessary?" if player.casualty_count > 0 else "You got past him without killing. There is still time to stop."
	start_dialogue([
		["THE VOICE", "Miro. Please. Don't go any lower.\n%s" % response],
		["MIRO", "You know my name. Do I know you?"],
		["THE VOICE", "You used to. Stay there. Let me help you."],
		["MIRO", "That voice should mean something. It hurts that it doesn't.\nI can't stay here.", "thought"]
	], "brother")

func plant_c4() -> void:
	if controls_locked():
		return
	if not player.has_supplies:
		notify("The C4 is hidden beneath your bed. [E]")
	elif door_open:
		notify("Keep the remaining charge. Find the marked support below.")
	elif not nearby("door", 65):
		notify("Move close to the cell lock to place C4.")
	elif player.c4_count > 0:
		player.c4_count -= 1
		player.end_stealth()
		route = "C4 breach"
		loud_events += 1
		open_door()
		shot_flash = 0.4
		emit_effect("breach", $Interactables/CellLock.global_position)
		get_node("/root/SoundFX").play_sound("collapse", -20)
		make_noise(player.global_position, 700)
		notify("The lock bursts. Keepers heard it! Find shadow or fight your way through.", 7)
	else:
		notify("Out of optional C4. The marked support still has its story charge.")

func open_door() -> void:
	get_node("/root/SoundFX").play_sound("gate", -17)
	door_open = true
	$CellDoor/CollisionShape2D.set_deferred("disabled", true)
	$Interactables/CellLock.activated = true
	$Interactables/CellLock.queue_redraw()

func make_noise(point: Vector2, radius: float) -> void:
	for guard in guards():
		if not guard.is_dead and guard.global_position.distance_to(point) < radius:
			guard.investigate(point)

func notify(text: String, duration: float = 4.0) -> void:
	message = text
	message_left = duration

func label_at(parent: Node, pos: Vector2, size: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f2d3ab"))
	label.add_theme_color_override("font_shadow_color", Color("272744"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(label)
	return label

func panel_at(pos: Vector2, size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.size = size
	panel.theme = VISUALS.ui_theme()
	panel.add_theme_stylebox_override("panel", VISUALS.panel_style())
	hud.add_child(panel)
	return panel

var pause_menu: CanvasLayer

func build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 20
	add_child(hud)
	pause_menu = CanvasLayer.new()
	pause_menu.set_script(preload("res://scripts/pause_menu.gd"))
	pause_menu.level = self
	add_child(pause_menu)
	var header := ColorRect.new()
	header.size = Vector2(640, 48)
	header.color = Color(0.15, 0.15, 0.26, 0.92)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(header)
	voice_remote = TextureRect.new()
	voice_remote.texture = preload("res://assets/weapons/remote.svg")
	voice_remote.custom_minimum_size = Vector2(26, 33)
	voice_remote.size = Vector2(26, 33)
	voice_remote.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	voice_remote.position = Vector2(606, 150)
	voice_remote.mouse_filter = Control.MOUSE_FILTER_IGNORE
	voice_remote.visible = false
	hud.add_child(voice_remote)
	var inventory := Control.new()
	inventory.set_script(preload("res://scripts/weapon_inventory.gd"))
	inventory.player = player
	inventory.position = Vector2(14, 55)
	inventory.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(inventory)
	health_label = RichTextLabel.new()
	health_label.position = Vector2(14, 10)
	health_label.size = Vector2(348, 18)
	health_label.bbcode_enabled = true
	health_label.scroll_active = false
	health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_label.add_theme_font_size_override("normal_font_size", 11)
	hud.add_child(health_label)
	status_label = label_at(hud, Vector2(14, 26), Vector2(348, 16), 11)
	status_label.clip_text = true
	objective_label = label_at(hud, Vector2(370, 10), Vector2(254, 48), 11)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_icon = TextureRect.new()
	hint_icon.position = Vector2(12, 329)
	hint_icon.size = Vector2(24, 24)
	hint_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hint_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hud.add_child(hint_icon)
	hint_label = label_at(hud, Vector2(42, 333), Vector2(584, 22), 11)
	stealth_meter = Control.new()
	stealth_meter.set_script(preload("res://scripts/stealth_meter.gd"))
	stealth_meter.position = Vector2(245, 42)
	stealth_meter.size = Vector2(104, 4)
	hud.add_child(stealth_meter)
	message_label = label_at(hud, Vector2(14, 295), Vector2(612, 34), 11)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Forced dialogue lives in a bubble beside the speaker so Miro and the play area stay visible.
	# The bottom of the screen is reserved for the objective cue line and short notices.
	dialogue_panel = Control.new()
	dialogue_panel.set_script(preload("res://scripts/character_bubble.gd"))
	dialogue_panel.dialogue = true
	hud.add_child(dialogue_panel)
	dialogue_panel.visible = false
	dialogue_label = dialogue_panel.text_label
	overlay = panel_at(Vector2(45, 65), Vector2(550, 240))
	overlay_label = label_at(overlay, Vector2.ZERO, Vector2(510, 200), 13)
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _draw() -> void:
	if shot_flash > 0:
		draw_circle(to_local($Interactables/CellLock.global_position), (0.4 - shot_flash) * 160, Color(0.95, 0.83, 0.67, shot_flash))

func setup_world_features(number: int) -> void:
	effects = Node2D.new()
	effects.set_script(preload("res://scripts/visual_effects.gd"))
	add_child(effects)
	effects.level = self
	world_features = Node2D.new()
	world_features.set_script(load("res://scripts/world_features.gd"))
	add_child(world_features)
	world_features.setup(self, number)
	get_node("/root/MusicDirector").start_floor(number)

func emit_effect(cue: String, point: Vector2) -> void:
	if is_instance_valid(effects):
		effects.emit_burst(cue, point)
