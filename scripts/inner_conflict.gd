extends Node
## Per-floor side of Miro's inner conflict (docs/INNER_CONFLICT.md). Attached to every level scene
## by the PlayerBehavior autoload, so the level scripts need no hooks. It:
##  - splices Miro's two-option replies into existing scenes (data/dialogue_choices.json),
##  - scores real play for PlayerBehavior (cameras turned off, alarms survived, low-health objectives,
##    paintings looked at, logs read; kills and stealth are folded in when the floor commits),
##  - hangs the floor's reactive painting (data/art_branch_matrix.json),
##  - places the floor's records terminals (data/terminal_logs.json),
##  - adds one Bible verse exchange to the Keepers' conversation, keyed to Miro's leaning.
const VISUALS = preload("res://scripts/visual_assets.gd")
const CHOICE_TAG := "choice:"
const REACH := 34.0
const APPROACH := 420.0
## Largest close-up of a painting, in screen pixels (the HUD is 640 x 360).
const VIEWER_MAX := Vector2(220, 170)

var level: Node2D
var behavior: Node
var floor_number := 1
var choices: Array = []
var answered: Dictionary = {}
var choice_selected := 0
var last_dialogue: Array = []
var original_prompt := ""
## Dialogue this node started (terminal pages, a painting) and the prop it hangs over.
var own_dialogue: Array = []
var own_actor: Node2D
var frame: Node2D
var frame_slot: Dictionary = {}
var terminals: Array[Node2D] = []
var catalog: Dictionary = {}
var rights: Dictionary = {}
var viewer: PanelContainer
var viewer_image: TextureRect
var debug_label: Label
var placed := false
# Live scoring state.
var cameras: Array = []
var camera_seen_off: Dictionary = {}
var alert_count := 0
var in_alert := false
var calm_time := 0.0
var low_health := false
var max_health := 3
var progress_seen := 0

func _ready() -> void:
	level = get_parent()
	behavior = get_node("/root/PlayerBehavior")
	process_mode = Node.PROCESS_MODE_ALWAYS
	floor_number = int(get_node("/root/Campaign").current_floor)
	var data = read_json("res://data/dialogue_choices.json")
	for entry in data.get("choices", []):
		if str(entry.id).begins_with("l%d_" % floor_number):
			choices.append(entry)
	for work in read_json("res://data/art_catalog.json").get("works", []):
		catalog[work.id] = work
	rights = read_json("res://data/art_rights.json").get("works", {})
	frame_slot = read_json("res://data/art_branch_matrix.json").get("slots", {}).get(str(floor_number), {})
	max_health = maxi(1, int(level.player.health))
	progress_seen = objective_progress()
	build_viewer()
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_instance_valid(level):
		return
	add_verses()
	place_props()

static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

# --- Two-option replies -------------------------------------------------------------------

func _process(delta: float) -> void:
	if not is_instance_valid(level):
		return
	if not is_same(level.dialogue, last_dialogue):
		splice_choices()
	update_choice_bubble()
	update_own_dialogue()
	if not placed:
		return
	if not level.paused:
		track_play(delta)
	if is_instance_valid(frame) and not frame.assigned and level.player.global_position.distance_to(frame.global_position) < APPROACH:
		assign_frame(true)
	update_hint()
	if is_instance_valid(debug_label) and debug_label.visible:
		debug_label.text = behavior.debug_text() + "\nframe: %s (%s)" % [frame.art_id if is_instance_valid(frame) else "-", frame.branch if is_instance_valid(frame) else "-"]

## Inserts a choice right after any line whose text contains a choice's anchor.
func splice_choices() -> void:
	var lines: Array = level.dialogue
	if lines.is_empty() or choices.is_empty():
		last_dialogue = lines
		return
	var result: Array = []
	var changed := false
	for index in range(lines.size()):
		var line = lines[index]
		result.append(line)
		if not line is Array or line.size() < 2 or is_choice(line):
			continue
		for choice in choices:
			if answered.has(choice.id) or not str(line[1]).contains(str(choice.after)):
				continue
			var next = lines[index + 1] if index + 1 < lines.size() else null
			if next is Array and is_choice(next):
				continue
			result.append(["MIRO", choice_text(choice, 0), "thought", CHOICE_TAG + str(choice.id), str(line[0])])
			changed = true
	if changed:
		level.dialogue = result
	last_dialogue = level.dialogue

static func is_choice(line) -> bool:
	return line is Array and line.size() > 3 and str(line[3]).begins_with(CHOICE_TAG)

func choice_by_id(id: String) -> Dictionary:
	for choice in choices:
		if str(choice.id) == id:
			return choice
	return {}

func choice_text(choice: Dictionary, selected: int) -> String:
	var text := str(choice.prompt)
	for index in range(choice.options.size()):
		text += "\n%s[%d] %s" % ["> " if index == selected else "   ", index + 1, choice.options[index].text]
	return text

func current_choice() -> Dictionary:
	if level.dialogue.is_empty() or level.dialogue_index >= level.dialogue.size():
		return {}
	var line = level.dialogue[level.dialogue_index]
	if not is_choice(line):
		return {}
	return choice_by_id(str(line[3]).trim_prefix(CHOICE_TAG))

func update_choice_bubble() -> void:
	var panel = level.dialogue_panel
	if not is_instance_valid(panel):
		return
	var choice := current_choice()
	if original_prompt.is_empty():
		original_prompt = panel.prompt_label.text
	if choice.is_empty():
		if panel.prompt_label.text != get_node("/root/ControllerSettings").prompt(original_prompt):
			panel.prompt_label.text = get_node("/root/ControllerSettings").prompt(original_prompt)
		return
	panel.prompt_label.text = get_node("/root/ControllerSettings").prompt("[1] [2] Choose   [E] Confirm")
	var line: Array = level.dialogue[level.dialogue_index]
	line[1] = choice_text(choice, choice_selected)
	level.dialogue_label.text = line[1]
	panel.follow_actor()

func choose(index: int) -> void:
	var choice := current_choice()
	if choice.is_empty():
		return
	index = clampi(index, 0, choice.options.size() - 1)
	var option: Dictionary = choice.options[index]
	var position: int = level.dialogue_index
	var anchor_speaker := str(level.dialogue[position][4]) if level.dialogue[position].size() > 4 else "MIRO"
	level.dialogue[position] = ["MIRO", str(option.text)]
	if option.has("reply"):
		var speaker := str(option.reply[0])
		level.dialogue.insert(position + 1, [anchor_speaker if speaker == "@anchor" else speaker, str(option.reply[1])])
	answered[choice.id] = index
	choice_selected = 0
	behavior.record_choice(str(choice.id), index, option.get("lean", {}))

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(level) or level.paused:
		return
	var choice := current_choice()
	if not choice.is_empty():
		if event is InputEventJoypadButton and event.pressed:
			match event.button_index:
				JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_LEFT:
					choice_selected = 0
				JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_RIGHT:
					choice_selected = 1
				JOY_BUTTON_A:
					choose(choice_selected)
				_:
					return
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed and not event.echo:
			var key: int = event.physical_keycode
			if key in [KEY_1, KEY_KP_1]:
				choose(0)
			elif key in [KEY_2, KEY_KP_2]:
				choose(1)
			elif key in [KEY_W, KEY_UP, KEY_A, KEY_LEFT]:
				choice_selected = 0
			elif key in [KEY_S, KEY_DOWN, KEY_D, KEY_RIGHT]:
				choice_selected = 1
			elif event.is_action_pressed("interact") or event.is_action_pressed("advance"):
				choose(choice_selected)
			else:
				return # Tab still skips the scene; Esc still pauses.
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") and not event.is_echo():
		var prop = usable_prop()
		if prop != null:
			open_prop(prop)
			get_viewport().set_input_as_handled()

# --- Props: placement, hints, reading -----------------------------------------------------

func place_props() -> void:
	if not frame_slot.is_empty():
		var point := slot_point(frame_slot)
		var stand := find_spot(point)
		if stand != Vector2.INF:
			frame = Node2D.new()
			frame.set_script(load("res://scripts/art_frame.gd"))
			frame.name = "ReactiveFrame"
			frame.slot_id = str(frame_slot.get("id", ""))
			frame.position = level.to_local(stand)
			add_under_player(frame)
			if str(frame_slot.get("assign", "approach")) == "entry":
				assign_frame(false)
		elif OS.is_debug_build():
			push_warning("InnerConflict: no clear wall for frame %s on floor %d" % [frame_slot.get("id", ""), floor_number])
	for entry in read_json("res://data/terminal_logs.json").get("terminals", []):
		if int(entry.get("floor", 0)) != floor_number:
			continue
		var stand := find_spot(Vector2(entry.position[0], entry.position[1]))
		if stand == Vector2.INF:
			if OS.is_debug_build():
				push_warning("InnerConflict: no clear spot for terminal %s" % entry.id)
			continue
		var terminal := Node2D.new()
		terminal.set_script(load("res://scripts/lore_terminal.gd"))
		terminal.name = "LoreTerminal_" + str(entry.id)
		terminal.log_entry = entry
		terminal.position = level.to_local(stand)
		add_under_player(terminal)
		terminals.append(terminal)
		if level.get("world_features") != null:
			level.world_features.spawn_terminal_guard(stand)
	placed = true

## Drawn over the tower's walls and floors but behind Miro and the Keepers.
func add_under_player(prop: Node2D) -> void:
	level.add_child(prop)
	var player: Node = level.player
	if player.get_parent() == level:
		level.move_child(prop, player.get_index())

func slot_point(slot: Dictionary) -> Vector2:
	if str(slot.get("anchor", "point")) == "start":
		# Hung just ahead of where Miro enters the floor, so every floor shows one.
		return level.player.global_position + Vector2(slot.offset[0], slot.offset[1])
	if str(slot.get("anchor", "point")) == "exit":
		for area in level.areas.get_children():
			if area.get("kind") == "exit":
				return area.global_position + Vector2(slot.offset[0], slot.offset[1])
	var position: Array = slot.get("position", [0, 0])
	return Vector2(position[0], position[1])

## A standing point on the floor at or below `point`, stepping sideways until it is clear of
## stations, ladders, props, the stair gate and other lore props. INF when none fits.
func find_spot(point: Vector2) -> Vector2:
	var space: PhysicsDirectSpaceState2D = level.get_world_2d().direct_space_state
	for step in [0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6, -6, 7, -7, 8, -8, 9, -9, 10, -10]:
		var probe: Vector2 = point + Vector2(step * 28, 0)
		var query := PhysicsRayQueryParameters2D.create(probe + Vector2(0, -12), probe + Vector2(0, 150), 1)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var stand: Vector2 = Vector2(probe.x, hit.position.y - 16)
		if spot_clear(stand):
			return stand
	return Vector2.INF

func spot_clear(stand: Vector2) -> bool:
	# Check the full frame, including its border, against raised map geometry.
	var frame_shape := RectangleShape2D.new()
	frame_shape.size = Vector2(64, 64)
	var frame_query := PhysicsShapeQueryParameters2D.new()
	frame_query.shape = frame_shape
	frame_query.transform = Transform2D(0, stand + Vector2(0,-40))
	frame_query.collision_mask = 1
	if not level.get_world_2d().direct_space_state.intersect_shape(frame_query).is_empty():
		return false
	var frame_rect := Rect2(stand + Vector2(-32,-72), Vector2(64,64))
	for dressing in level.get_children():
		if dressing.get_script() == preload("res://scripts/scaffold_art.gd"):
			for furniture: Rect2 in dressing.furniture_rects.values():
				if frame_rect.intersects(furniture):return false
	var poster = level.get("poster")
	if is_instance_valid(poster) and poster.global_position.distance_to(stand + Vector2(0, -44)) < 72.0:
		return false
	var features = level.world_features
	if is_instance_valid(features) and not features.placement_clear(stand):
		return false
	for area in level.areas.get_children():
		var kind := str(area.get("kind"))
		# Doors, sigils, gates and station markers keep a wide berth: a painting never hangs over them.
		if kind != "cover" and kind != "ladder" and area.global_position.distance_to(stand) < (110 if kind in ["exit", "brother", "sigil", "door"] else 78):
			return false
	# Authored set pieces (the Foundation labs, ward chambers) are wide: keep clear of them too.
	for piece in (level.get("definition").get("props", []) if level.get("definition") != null else []):
		if absf(float(piece.position[0]) - stand.x) < 110.0 and absf(float(piece.position[1]) - stand.y) < 60.0:
			return false
	if is_instance_valid(features):
		for prop in features.props:
			if is_instance_valid(prop) and prop.global_position.distance_to(stand) < 56:
				return false
	for other in lore_props():
		if other.global_position.distance_to(stand) < 90:
			return false
	return true

func lore_props() -> Array[Node2D]:
	var list: Array[Node2D] = []
	if is_instance_valid(frame):
		list.append(frame)
	list.append_array(terminals)
	return list

## The lore prop E would use: in reach, same storey, and nothing of the level's own competing.
func usable_prop():
	if not placed or level.controls_locked() or level.player.is_dead or level.player.in_hiding_spot:
		return null
	var features = level.world_features
	if is_instance_valid(features) and not features.hint().is_empty():
		return null
	var player_point: Vector2 = level.player.global_position
	for area in level.areas.get_children():
		var kind := str(area.get("kind"))
		if kind != "cover" and kind != "ladder" and area.global_position.distance_to(player_point) < 48:
			return null
	if level.has_method("closest_guard"):
		var guard = level.closest_guard()
		if guard != null and not guard.is_dead and not guard.asleep:
			return null
	var best = null
	var distance := REACH
	for prop in lore_props():
		var offset: Vector2 = prop.global_position - player_point
		if absf(offset.y) < 26 and absf(offset.x) < distance:
			best = prop
			distance = absf(offset.x)
	return best

func update_hint() -> void:
	var prop = usable_prop()
	if prop == null:
		return
	var text := "[E] Look at the painting" if prop == frame else ("[E] Open terminal · MP3 connects nearby" if level.player.controls.pad_prompts else "[E] Read records  •  [T] Open security console")
	level.hint_label.text = get_node("/root/ControllerSettings").prompt(text)
	level.hint_icon.texture = VISUALS.hint_texture(text)
	level.hint_icon.visible = level.hint_icon.texture != null

func open_prop(prop: Node2D) -> void:
	var lines: Array = []
	if prop == frame:
		if not frame.assigned:
			assign_frame(true)
		var work: Dictionary = frame.art
		if work.is_empty():
			return
		if frame.covered():
			lines.append(["PAINTING", "A dust sheet hangs over the frame. The brass plate reads:\n%s\n%s, %s" % [work.title, work.artist, work.year]])
		else:
			lines.append(["PAINTING", "%s\n%s, %s\n%s" % [work.title, work.artist, work.year, work.institution]])
		lines.append(["PAINTING", "Scratched into the frame, in a Keeper's hand:\n\"%s\"" % work.prison_label])
		frame.inspected = true
		frame.queue_redraw()
		behavior.record("art_" + str(frame.slot_id), "seeker", 1, "art", 2)
		get_node("/root/Campaign").unlock_achievement("art_" + str(frame.art_id))
	else:
		var entry: Dictionary = prop.log_entry
		var pages: Array = entry.get("pages", [])
		for page in pages:
			lines.append(["RECORDS · " + str(entry.file).to_upper(), str(page)])
		prop.read = true
		behavior.record("lore_" + str(entry.id), "seeker", 2, "lore", 2)
	own_dialogue = lines
	own_actor = prop
	level.start_dialogue(lines)
	last_dialogue = level.dialogue

## While a lore prop is being read: hang the bubble over it and show the painting up close.
func update_own_dialogue() -> void:
	var active: bool = not own_dialogue.is_empty() and is_same(level.dialogue, own_dialogue) and not level.paused
	if not active:
		if not is_same(level.dialogue, own_dialogue):
			own_dialogue = []
		if is_instance_valid(viewer):
			viewer.visible = false
		return
	if is_instance_valid(own_actor):
		level.dialogue_panel.actor = own_actor
		level.dialogue_panel.follow_actor()
	var showing := own_actor == frame and is_instance_valid(frame) and frame.texture != null
	viewer.visible = showing
	if showing and viewer_image.texture != frame.texture:
		# The close-up's frame hugs the painting: same shape, a thin border, no empty mat.
		viewer_image.texture = frame.texture
		var picture: Vector2 = frame.texture.get_size()
		var fit := minf(VIEWER_MAX.x / picture.x, VIEWER_MAX.y / picture.y)
		viewer_image.custom_minimum_size = (picture * fit).floor()
		viewer.reset_size()
	if showing:
		# The close-up sits on the opposite half of the screen from the frame and its caption.
		var screen_x: float = frame.get_global_transform_with_canvas().origin.x
		viewer.position = Vector2(16 if screen_x > 320 else 640 - viewer.size.x - 16, 52)

func build_viewer() -> void:
	viewer = PanelContainer.new()
	viewer.theme = VISUALS.ui_theme()
	var border := VISUALS.panel_style()
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		border.set_content_margin(side, 5)
	viewer.add_theme_stylebox_override("panel", border)
	viewer.position = Vector2(16, 52)
	viewer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewer_image = TextureRect.new()
	viewer_image.custom_minimum_size = VIEWER_MAX
	viewer_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	viewer_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	viewer_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	viewer_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewer.add_child(viewer_image)
	viewer.visible = false
	level.hud.add_child(viewer)
	if OS.is_debug_build():
		debug_label = level.label_at(level.hud, Vector2(14, 250), Vector2(612, 40), 9)
		debug_label.visible = false

func _input(event: InputEvent) -> void:
	# F9 (debug builds only): show the five scores, the leaning and this floor's painting.
	if is_instance_valid(debug_label) and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F9:
		debug_label.visible = not debug_label.visible
		get_viewport().set_input_as_handled()

# --- Reactive painting --------------------------------------------------------------------

func assign_frame(include_pending: bool) -> void:
	var branch: String = behavior.select_branch(include_pending)
	var campaign = get_node("/root/Campaign")
	var themes: Dictionary = {"neutral":["trapped","alienation"],"ghost":["loneliness","isolation","escape"],"blackhat":["blackhat","distrust","confusion"],"defiant":["defiance","betrayal"],"survivor":["survival","escape"],"seeker":["faith","confusion"]}
	var matching: Array = []
	var weights: Dictionary = {}
	for id in catalog:
		var affinity := 0
		for theme in catalog[id].get("themes", []):
			if themes.get(branch, themes.neutral).has(theme):affinity += 1
		if affinity > 0:
			matching.append(id)
			weights[id] = affinity
	var fresh: Array = matching.filter(func(id):return not campaign.has_achievement("art_" + str(id)))
	var pool: Array = fresh if not fresh.is_empty() else matching
	var weighted: Array = []
	for id in pool:
		for weight in range(int(weights[id])):weighted.append(id)
	var picks: Array = []
	if not weighted.is_empty():picks.append(weighted.pick_random())
	pool.shuffle()
	for id in pool:
		if not picks.has(id):picks.append(id)
	var shown_id: String = str(picks[0]) if not picks.is_empty() else ""
	var image: Texture2D = null
	for id in picks:
		if not catalog.has(id):
			continue
		image = load_art(id)
		if image != null:
			shown_id = id
			break
	frame.hang(catalog.get(shown_id, {}), image, branch)

## A painting is shown only when tools/fetch_art.py verified its rights and saved the file.
func load_art(id: String) -> Texture2D:
	if str(rights.get(id, {}).get("status", "")) != "verified":
		return null
	var path := str(catalog[id].asset_path)
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var picture := Image.load_from_file(path)
		if picture != null and not picture.is_empty():
			return ImageTexture.create_from_image(picture)
	return null

# --- Bible verses in the Keepers' talk ----------------------------------------------------

func add_verses() -> void:
	var features = level.world_features
	if not is_instance_valid(features) or features.conversation.is_empty():
		return
	var verses := read_json("res://data/branch_verses.json")
	var branch: String = behavior.select_branch_preview()
	var pool: Array = verses.get(branch, verses.get("neutral", []))
	if pool.is_empty():
		return
	var index := floor_number % pool.size()
	var lines: Array = []
	for line_index in range(pool[index].size()):
		var line: Dictionary = pool[index][line_index].duplicate()
		line["id"] = "verse_%s_%d_%d" % [branch, index, line_index]
		line["verse"] = true
		lines.append(line)
	if features.has_method("add_casual_lines"):
		# The same pair keeps talking after their main conversation: the verse is casual chatter.
		features.add_casual_lines(lines, features.actors.duplicate())
	else:
		features.conversation = features.conversation.duplicate(true)
		features.conversation.append_array(lines)

# --- Scoring real play ----------------------------------------------------------------------

func objective_progress() -> int:
	var count := 0
	var milestones = level.get("milestones")
	if milestones is Dictionary:
		count += milestones.size()
	for flag in ["sigil_placed", "door_open", "brother_heard"]:
		if level.get(flag) == true:
			count += 1
	return count

func track_play(delta: float) -> void:
	var player = level.player
	# Blackhat: every camera Miro turns off (terminal or remote), and the checkpoint console.
	if cameras.is_empty():
		for child in level.get_children():
			if child.has_method("disable") and child.get("is_active") != null:
				cameras.append(child)
	for index in range(cameras.size()):
		var camera = cameras[index]
		if is_instance_valid(camera) and not camera.is_active and not camera.get_meta("pre_disabled",false) and not camera_seen_off.has(index):
			camera_seen_off[index] = true
			behavior.record("camera_%d" % index, "blackhat", 3, "camera", 2)
	var milestones = level.get("milestones")
	if milestones is Dictionary and milestones.has("RemoteTerminal"):
		behavior.record("console", "blackhat", 2)
	# Survivor: get caught, break the chase and live; finish an objective while badly hurt.
	var forced: bool = level.has_method("counts_detection") and not level.counts_detection()
	if level.was_spotted and not forced:
		in_alert = true
		calm_time = 0.0
	elif in_alert and not player.is_dead:
		calm_time += delta
		if calm_time >= 5.0:
			in_alert = false
			alert_count += 1
			behavior.record("escape_%d" % alert_count, "survivor", 2, "escape", 2)
	max_health = maxi(max_health, int(player.health))
	if not player.is_dead and player.health > 0 and float(player.health) / max_health <= 0.34:
		low_health = true
	var progress := objective_progress()
	if progress > progress_seen:
		if low_health and not player.is_dead:
			behavior.record("hurt_objective_%d" % progress, "survivor", 2, "hurt_objective", 2)
			low_health = false
		progress_seen = progress
