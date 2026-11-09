extends "res://scripts/intro_level.gd"
## Playable blockout controller. Milestones stand in for unfinished set pieces.
var definition: Dictionary
var milestones: Dictionary = {}
var pending_milestone: String = ""
var connected_cameras: Array[Node] = []
var hack_remaining := 0.0
var floor_alerts := 0
var brother: Node
var cinematic: Control

func _ready() -> void:
	definition = JSON.parse_string(FileAccess.get_file_as_string(get_meta("blueprint")))
	get_node("/root/Campaign").enter_floor(int(definition.number))
	process_mode = Node.PROCESS_MODE_ALWAYS
	setup_inputs()
	player.level = self
	player.position = $LevelPlan/PlayerSpawn.position
	player.has_supplies = true
	player.c4_count = int(definition.get("demolition_charges", 1)) + 1 # One optional charge; story supports stay reserved.
	door_open = true
	brother_heard = true
	for guard in guards():
		guard.level = self
		guard.illness_started = true
	build_hud()
	setup_world_features(int(definition.number))
	player.controls.has_remote = get_node("/root/Campaign").remote_owned
	player.controls.remote_unlocked = get_node("/root/Campaign").remote_unlocked
	if int(definition.number) == 3:
		for point in [Vector2(450, 180), Vector2(820, 370)]:
			var camera = load("res://scenes/security_camera.tscn").instantiate()
			camera.position = point
			camera.level = self
			add_child(camera)
			connected_cameras.append(camera)
	start_dialogue([[definition.title.to_upper(), definition.opening]])

func _process(delta: float) -> void:
	super._process(delta)
	if not controls_locked() and definition.has("music_region"):
		var entry: Dictionary = definition.music_region.entry
		var in_region := player.position.x >= float(entry.get("minimum_x", -INF)) and player.position.y >= float(entry.get("minimum_y", -INF)) and player.position.y <= float(entry.get("maximum_y", INF))
		var ready_milestone := not entry.has("requires_milestone") or milestones.has(entry.requires_milestone)
		if in_region and ready_milestone and (not entry.get("requires_landing", true) or player.is_on_floor()):
			get_node("/root/MusicDirector").second_section(int(definition.number))
	if hack_remaining > 0 and not controls_locked():
		var range_limit := 48.0
		# MP3 Remote Hack allows greater range and potential cross-floor access
		if player.controls.has_remote and player.controls.remote_unlocked:
			range_limit = 170.0
		
		if player.is_dead or player.global_position.distance_to(areas.get_node("RemoteTerminal").global_position) >= range_limit:
			hack_remaining = 0
			notify("Reprogramming interrupted. Move closer to the terminal.")
		else:
			hack_remaining = maxf(0, hack_remaining - delta)
			if hack_remaining == 0:
				for camera in connected_cameras:
					camera.disable()
				pending_milestone = "RemoteTerminal"
				
				# Record the event in Campaign
				get_node("/root/Campaign").record_event("camera_disabled", {"count": connected_cameras.size()})
				if player.controls.has_remote and player.controls.remote_unlocked:
					get_node("/root/Campaign").record_event("mp3_remote_hack")
				
				start_dialogue([["CHECKPOINT", "Reprogramming complete. Linked security cameras disabled."]], "milestone")
	if completed:
		overlay_label.text = "%s\n\n%s\n\n[Backspace] Retry   [Enter] Descend" % [definition.title.to_upper(), definition.closing]
		if int(definition.number) == 5:
			overlay_label.text = "MIRO\n\nThe end.\n\n[Backspace] Replay final floor   [Enter] New run"

func _unhandled_input(event: InputEvent) -> void:
	if completed and event.is_action_pressed("advance") and not event.is_echo():
		get_node("/root/Campaign").complete_floor(int(definition.number), sigil_placed, milestones)
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file("res://scenes/levels/level_%02d.tscn" % (int(definition.number) + 1) if definition.number < 5 else "res://scenes/intro.tscn")
		return
	super._unhandled_input(event)

func objective() -> String:
	for station in definition.stations:
		if not milestones.has(station.id):
			return "%02d / %s\n%s" % [int(definition.number), definition.title.to_upper(), station.objective]
	return "%s\nReach the stair gate. [E]" % definition.title

func station_nearby() -> Dictionary:
	var nearest: Dictionary = {}
	var distance := 48.0
	for station in definition.stations:
		var node := areas.get_node(NodePath(station.id)) as Node2D
		var candidate := node.global_position.distance_to(player.global_position)
		if candidate < distance:
			nearest = station
			distance = candidate
	return nearest

func context_hint() -> String:
	if world_features and not world_features.hint().is_empty():
		return world_features.hint()
	if is_instance_valid(brother) and not brother.is_dead:
		return "[1] select shank, click during RECOVER • [C] Dodge • Space Jump"
	if hack_remaining > 0:
		return "Reprogramming… %d%% • stay within reach" % int((1 - hack_remaining) * 100)
	if controls_locked() or player.is_dead:
		return ""
	var station := station_nearby()
	if not station.is_empty():
		return "Completed: " + station.title if milestones.has(station.id) else "[E] " + station.title
	var guard = closest_guard()
	if guard and guard.is_dead and not guard.gun_taken:
		return "[E] Search fallen Keeper"
	if nearby("exit", 65):
		return "[E] Descend once this floor's objectives are complete"
	if player.is_concealed:
		return "Move carefully • touching a Keeper breaks stealth"
	if ladder_at(player.global_position):
		return "[W / S] Climb"
	return "A/D Move   Space Jump   C Dash   1–5 Select   Q Blanket   Esc Controls"

func interact() -> void:
	if controls_locked() or player.is_dead:
		return
	if player.controls.recover_charge():
		return
	if world_features and world_features.try_interact():
		return
	var station := station_nearby()
	if not station.is_empty():
		if milestones.has(station.id):
			notify("Already complete: " + station.title)
			return
		for required in station.requires:
			if not milestones.has(required):
				notify("First: " + str(required).replace("_", " "))
				return
		pending_milestone = station.id
		if station.id == "ForestViewpoint":
			pending_milestone = ""
			cinematic = load("res://scenes/ending_cinematic.tscn").instantiate()
			cinematic.level = self
			cinematic.finished.connect(finish_ending)
			hud.add_child(cinematic)
			return
		if station.id == "BrotherEncounter":
			pending_milestone = ""
			if not is_instance_valid(brother):
				brother = load("res://scenes/brother_boss.tscn").instantiate()
				brother.level = self
				brother.position = player.position + Vector2(85, -10)
				add_child(brother)
				get_node("/root/MusicDirector").second_section(5)
				notify("RUSH / THROW: watch his tell. Dodge with C; select 1 and click during RECOVER.", 8)
			return
		if station.id == "RemoteTerminal":
			pending_milestone = ""
			if not world_features.terminal_authenticated:
				world_features.open_terminal()
			elif hack_remaining <= 0:
				hack_remaining = 1.0
			return
		start_dialogue(station.lines, "milestone")
		return
	var guard = closest_guard()
	if guard and guard.is_dead and not guard.gun_taken:
		player.loot_weapon(guard)
		return
	if nearby("exit", 65):
		if milestones.size() == definition.stations.size() and sigil_placed:
			completed = true
			player.velocity = Vector2.ZERO
		else:
			notify("Follow the remaining objective before descending.")

func finish_dialogue() -> void:
	if dialogue_event == "milestone" and not pending_milestone.is_empty():
		milestones[pending_milestone] = true
		if has_node("Gates"):
			for gate in $Gates.get_children():
				if gate.unlock_milestone == pending_milestone:
					gate.unlock()
		var node = areas.get_node(NodePath(pending_milestone))
		node.activated = true
		node.queue_redraw()
		if node.kind == "sigil":
			get_node("/root/SoundFX").play_sound("sigil", -16)
			sigil_placed = true
			var charge_count := 1
			for station in definition.stations:
				if station.id == pending_milestone:
					charge_count = int(station.get("charge_count", 1))
			player.c4_count = maxi(0, player.c4_count - charge_count)
			make_noise(node.global_position, 220)
		pending_milestone = ""
	dialogue = []
	dialogue_index = 0
	dialogue_event = ""

func can_melee_reach(from: Vector2, to: Vector2) -> bool:
	return clear_sight(from, to)

func plant_c4() -> void:
	notify("This floor's charge is reserved for its sigil support. [E]")

func camera_alert(point: Vector2) -> void:
	floor_alerts += 1
	for guard in guards():
		if not guard.is_dead:
			guard.investigate(point)
	notify("CAMERA ALERT • Keepers are searching your last seen position.")

func brother_defeated() -> void:
	get_node("/root/MusicDirector").silence()
	milestones["BrotherEncounter"] = true
	areas.get_node("BrotherEncounter").activated = true
	areas.get_node("BrotherEncounter").queue_redraw()
	for station in definition.stations:
		if station.id == "DyingExchange":
			pending_milestone = "DyingExchange"
			start_dialogue(station.lines, "milestone")

func controls_locked() -> bool:
	return is_instance_valid(cinematic) or super.controls_locked()

func finish_ending() -> void:
	milestones["ForestViewpoint"] = true
	completed = true
	get_node("/root/Campaign").complete_floor(5, sigil_placed, milestones)
