extends Node2D
## The first floor only. Story flags stay local so R restores the entry state.

@onready var player: IntroPlayer = $Player
@onready var areas: Node2D = $Interactables
var door_open: bool = false
var sigil_placed: bool = false
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
var objective_label: Label
var hint_label: Label
var message_label: Label
var dialogue_panel: PanelContainer
var dialogue_label: Label
var speaker_label: Label
var speaker_portrait: Control
var overlay: PanelContainer
var overlay_label: Label
var shot_flash: float = 0.0
var world_features: Node2D
const VISUALS = preload("res://scripts/visual_assets.gd")
var hint_icon: TextureRect
var stealth_meter: Control
var effects: Node2D

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
	setup_world_features(1)
	start_dialogue([
		["MIRO", "Stone. Iron. A name scratched into the bed: Miro.\nMine... I think. Nothing before this room."],
		["KEEPER", "Awake again? The Keepers call you a traitor.\nI call you late with my payment. No coin, no medicine."],
		["MIRO", "What medicine? What happened to me?"],
		["KEEPER", "Don't play innocent. I know you...\nWait. That taste... I can't..."],
		["MIRO", "His hands are shaking. The same marks as the others.\nHe's turned away. This might be my only chance."]
	], "intro")
	var launch_floor: int = get_node("/root/Campaign").launch_floor()
	if launch_floor > 1:
		get_tree().call_deferred("change_scene_to_file", "res://scenes/levels/level_%02d.tscn" % launch_floor)

func setup_inputs() -> void:
	var bindings := {"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "climb_up": [KEY_W, KEY_UP], "climb_down": [KEY_S, KEY_DOWN], "jump": [KEY_SPACE], "dodge": [KEY_C], "attack": [], "cloak": [], "explosive": [], "fire": [], "interact": [KEY_E], "advance": [KEY_ENTER], "skip": [KEY_TAB], "pause_game": [KEY_ESCAPE], "retry": [KEY_BACKSPACE]}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)

func controls_locked() -> bool:
	return (is_instance_valid(player.controls) and player.controls.locked()) or is_instance_valid(player.pending_guard) or paused or not dialogue.is_empty() or completed or (is_instance_valid(world_features) and world_features.modal_open())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_F10:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return
	if completed and event.is_action_pressed("advance") and not event.is_echo():
		get_node("/root/Campaign").complete_floor(1, sigil_placed, {"BrotherVoice": brother_heard})
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file("res://scenes/levels/level_02.tscn")
		return
	if event.is_action_pressed("retry") and not event.is_echo():
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
		interact()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not paused:
		elapsed += delta
		message_left = maxf(0, message_left - delta)
		shot_flash = maxf(0, shot_flash - delta)
	var pursuing := false
	var searching := false
	for guard in guards():
		if not guard.is_dead:
			pursuing = pursuing or (guard.sees_player and guard.alert_state == IntroGuard.State.ALERT)
			searching = searching or guard.alert_state == IntroGuard.State.SEARCH or guard.alert_state == IntroGuard.State.SUSPICIOUS
	player.detection_state = "SPOTTED" if pursuing else ("HIDDEN" if player.is_concealed else ("SEARCHING / unseen" if searching else "UNSEEN"))
	status_label.text = "MIRO   " + "♥ ".repeat(maxi(0, player.health)) + "    " + player.detection_state
	if player.has_key:
		status_label.text += " · KEY"
	if player.has_supplies:
		status_label.text += "\n" + player.stealth_status()
	objective_label.text = objective()
	hint_label.text = context_hint()
	hint_icon.texture = VISUALS.hint_texture(hint_label.text)
	hint_icon.visible = hint_icon.texture != null
	stealth_meter.visible = player.has_supplies
	stealth_meter.value = player.stealth_remaining / player.stealth_duration if player.is_concealed else 1.0 - player.stealth_cooldown_left / player.stealth_cooldown
	message_label.text = message if message_left > 0 else ""
	dialogue_panel.visible = not dialogue.is_empty()
	if not dialogue.is_empty():
		var line: Array = dialogue[dialogue_index]
		dialogue_label.text = line[1]
		speaker_label.text = line[0]
		speaker_portrait.speaker = line[0]
	overlay.visible = paused or completed or player.is_dead
	if completed:
		overlay_label.text = "THE PRISONER\n\nThe first mark is set. Below, someone is coughing.\n\nEscape: %s   |   Casualties: %d\n\n[Enter] Descend to Level 2\n[Backspace] Replay the floor" % [route, player.casualty_count]
	elif player.is_dead:
		overlay_label.text = "THE TOWER KEEPS ITS PRISONERS\n\n[Backspace] Retry from the cell\nTry cover, a quiet key theft, or dodge the wind-up."
	elif paused:
		overlay_label.text = "PAUSED\nA/D Move · W/S Ladders · Space twice Double jump\nC Dash · Left Ctrl Crouch · E Interact / recover C4\n1–5 Select · Q Blanket · N Inventory\nLeft click Use · Right click Focus / place C4\nR Reload · Hold gun key Attach suppressor\nBlanket: shadows only · 5s active / 8s cooldown\nEsc Resume · Backspace Retry · F10 Menu"
		overlay_label.text += "\n[M] Sound: " + ("OFF" if get_node("/root/SoundFX").muted else "ON")
	queue_redraw()

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
		notify("The Keeper doubles over, coughing. Search your bed. [E]", 8)
	elif event == "brother":
		brother_heard = true

func guards() -> Array[Node]:
	return get_tree().get_nodes_in_group("guards")

func in_cover(point: Vector2) -> bool:
	var list := areas if is_instance_valid(areas) else get_node_or_null("Interactables")
	if not list:
		return false
	for area in list.get_children():
		if area.kind == "cover":
			var rect: Rect2 = Rect2(area.global_position - area.area_size / 2, area.area_size)
			var expanded := Rect2(rect.position.x - 6, rect.position.y - 45, rect.size.x + 12, rect.size.y + 45)
			if expanded.has_point(point):
				return true
	return false

func ladder_at(point: Vector2):
	for area in areas.get_children():
		if area.kind == "ladder" and area.contains(point):
			return area
	return null

func clear_sight(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
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
	if world_features and not world_features.hint().is_empty():
		return world_features.hint()
	if controls_locked() or player.is_dead:
		return ""
	if nearby("bed") and not player.has_supplies:
		return "[E] Search beneath the bed"
	var guard = world_features.nearest_loot() if world_features.loot_takes_priority() else closest_guard()
	if guard:
		if guard.is_dead and (not guard.gun_taken or (guard.sick_guard and not guard.key_taken)):
			return "[E] Search fallen Keeper"
		if guard.sick_guard and not guard.key_taken:
			return "[E] Pickpocket when he turns away   /   [1] Shank   /   [2] C4"
	if nearby("door", 65) and not door_open:
		return "[E] Unlock with key   /   [2] C4 with C4"
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
		return "[W / S] Climb. Keepers cannot use ladders."
	return "A / D  Move    Space  Jump    C  Dash    Esc  Controls"

func interact() -> void:
	if controls_locked() or player.is_dead:
		return
	if player.controls.recover_charge():
		return
	if world_features and world_features.try_interact():
		return
	
	# Check for strangle opportunity from behind
	var guard = closest_guard()
	if guard and not guard.is_dead:
		var diff = guard.global_position - player.global_position
		if absf(diff.y) < 20 and diff.x * player.facing < -10:
			if not guard.detect_player():
				guard.strangle()
				get_node("/root/Campaign").record_event("strangle")
				return

	var bed = nearby("bed")
	if bed and not player.has_supplies:
		player.has_supplies = true
		player.c4_count = 2
		bed.activated = true
		bed.queue_redraw()
		start_dialogue([
			["MIRO", "Wire. Powder. Two charges, hidden beneath the bed.\nI've been building these in secret. My hands remember; I don't."],
			["MIRO", "A sharpened spoon. My blanket. Something I scratched\non the wrapping: 'Leave a mark. Keep going down.'"],
			["ESCAPE", "[E] Take the key while the Keeper faces away.\n[1] selects shank. Left click attacks.\n[2] C4: right click places, left click detonates."]
		])
		return
	var guard = world_features.nearest_loot() if world_features.loot_takes_priority() else closest_guard()
	if guard and ((guard.is_dead and (not guard.gun_taken or (guard.sick_guard and not guard.key_taken))) or (guard.sick_guard and not guard.key_taken)):
		if not player.has_supplies:
			notify("Gather your hidden supplies before leaving.")
			return
		if guard.is_dead:
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
			notify("The key slips free. No one noticed. [E] at the lock to open it.")
		else:
			notify("He can see your hand. Wait until he turns his back.")
		return
	if nearby("door", 65) and not door_open:
		if player.has_key:
			open_door()
			notify("A quiet click. Shadow alcoves can hide you: select Q and click.", 7)
		else:
			notify("Locked. Steal the key, loot the Keeper, or use C4 [2].")
		return
	if nearby("brother", 75) and not brother_heard:
		start_brother()
		return
	if nearby("note"):
		start_dialogue([["QUARANTINE ORDER", "No medicine without the Keeper's seal.\nNo names. Record the cell numbers only.\nTransfer all marked prisoners to the lower ward."]])
		return
	if nearby("sigil") and not sigil_placed:
		if not player.has_supplies or player.c4_count < 1:
			notify("The materials are hidden beneath your bed.")
			return
		if not brother_heard:
			start_brother()
			return
		sigil_placed = true
		get_node("/root/SoundFX").play_sound("sigil", -16)
		player.c4_count -= 1
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
		["A VOICE BEYOND THE BARS", "Miro. Please. Don't go any lower.\n%s" % response],
		["MIRO", "You know my name. Do I know you?"],
		["THE VOICE", "You used to. Stay there. Let me help you."],
		["MIRO", "That voice should mean something. It hurts that it doesn't.\nI can't stay here."]
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
	elif player.c4_count > 1:
		player.c4_count -= 1
		player.end_stealth()
		route = "C4 breach"
		open_door()
		shot_flash = 0.4
		emit_effect("breach", $Interactables/CellLock.global_position)
		get_node("/root/SoundFX").play_sound("collapse", -20)
		make_noise(player.global_position, 700)
		notify("The lock bursts. Keepers heard it! Find shadow or fight your way through.", 7)

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

func build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 20
	add_child(hud)
	var header := ColorRect.new()
	header.size = Vector2(640, 48)
	header.color = Color(0.15, 0.15, 0.26, 0.92)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(header)
	var inventory := Control.new()
	inventory.set_script(preload("res://scripts/weapon_inventory.gd"))
	inventory.player = player
	inventory.position = Vector2(14, 55)
	inventory.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(inventory)
	status_label = label_at(hud, Vector2(14, 10), Vector2(348, 50), 11)
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
	dialogue_panel = panel_at(Vector2(16, 222), Vector2(608, 126))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	dialogue_panel.add_child(columns)
	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(text_column)
	dialogue_label = label_at(text_column, Vector2.ZERO, Vector2(430, 76), 12)
	dialogue_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var footer := label_at(text_column, Vector2.ZERO, Vector2(430, 14), 9)
	footer.text = "[E / Enter] Continue     [Tab] Skip"
	var speaker_column := VBoxContainer.new()
	speaker_column.custom_minimum_size.x = 100
	columns.add_child(speaker_column)
	speaker_portrait = Control.new()
	speaker_portrait.set_script(load("res://scripts/dialogue_portrait.gd"))
	speaker_portrait.custom_minimum_size = Vector2(100, 66)
	speaker_column.add_child(speaker_portrait)
	speaker_label = label_at(speaker_column, Vector2.ZERO, Vector2(100, 24), 10)
	speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speaker_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
