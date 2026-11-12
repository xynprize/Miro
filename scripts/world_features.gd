extends Node2D
## Small additive props, finite overheard scenes and offline spatial guard speech.
const STRANGLE_TIME := 0.24
var strangle_victim: IntroGuard
var strangle_left := 0.0
var strangle_health := 0
var previous_hold := false
var next_strangle_requires_hold := false
var strangle_requires_hold := false
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
var voice: Node2D
var voice_speaker: Node2D
var subtitle: Label
var speech_bubble: Control
var thought_bubble: Control
## Niro (or the voice) talking through Miro's remote: a tagged bubble over Miro, radio audio.
var remote_bubble: Control
var remote_left := 0.0
var thoughts: Dictionary
var thought_seen: Dictionary = {}
var thought_left := 0.0
var password_panel: PanelContainer
var password_input: LineEdit
var password_status: Label
var password_known := false
## Controller-friendly login: once the password is known, one button enters it.
var password_use: Button
var password_slip: Button
var terminal_authenticated := false
var config: Dictionary
var case_anchor_index := -1
var access_point := Vector2.ZERO
var practice_camera: Node
var early_authenticated := false
var trapdoors: Array[Node2D] = []
## Miro's inner voice plays on the Thought bus (long, spacey reverb). Drop clips at
## res://assets/audio/voice/thought_<floor>_<id>.mp3 to voice a thought.
var thought_voice: AudioStreamPlayer
const CAMERA_HACK_HINT := "Maybe I can hack the cameras from a terminal, or use my MP3 nearby."
const TURRET_HINT := "Maybe I can hack that turret from a terminal, or use my MP3 nearby. C4 would work too."
var turret_hinted := false
var vent_network: Node
## Individual Keeper profiles and authored casting (data/guard_roster.json).
var roster: Dictionary = {}
## Extra overheard scenes after the main conversation: huddles and add_casual_lines().
## Each: {actors, lines, index, started, done}. Only one voice speaks at a time.
var casual_scenes: Array = []
var mutter_wait := 6.0
var muttered: Dictionary = {}
const MUTTER_RANGE := 190.0
const MUTTER_GAP := 14.0

func setup(owner_level: Node2D, number: int) -> void:
	level = owner_level
	floor_number = number
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/guard_dialogue.json"))
	voice = preload("res://scripts/world_audio_source.gd").new()
	voice.bus = "Voice"
	voice.process_mode = Node.PROCESS_MODE_PAUSABLE
	# Heard clearly from the whole conversation range; fading, never cut, with distance.
	voice.max_distance = 560
	voice.attenuation = 2.0
	add_child(voice)
	thought_voice = AudioStreamPlayer.new()
	thought_voice.bus = "Thought" if AudioServer.get_bus_index("Thought") >= 0 else "Voice"
	thought_voice.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(thought_voice)
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
	remote_bubble = Control.new()
	remote_bubble.set_script(preload("res://scripts/character_bubble.gd"))
	remote_bubble.actor = level.player
	level.hud.add_child(remote_bubble)
	remote_bubble.visible = false
	thoughts = JSON.parse_string(FileAccess.get_file_as_string("res://data/inner_dialogue.json"))
	roster = JSON.parse_string(FileAccess.get_file_as_string("res://data/guard_roster.json"))
	var keepers: Array[Node] = level.guards()
	for index in range(keepers.size()):
		name_keeper(keepers[index], number, index)
		if number > 1 and not keepers[index].has_method("begin_recovery"):
			keepers[index].weapon_kind = ["pistol", "smg"][index % 2]
	var authored: Dictionary = level.definition.get("features", {}) if level.get("definition") != null else {}
	if config.conversations.has(str(number)) and not keepers.is_empty():
		var first = keepers[0]
		var spot = authored.get("conversation")
		if spot != null:
			for keeper in keepers:
				if keeper.name == spot.guard:
					first = keeper
			first.position = Vector2(spot.position[0], spot.position[1])
		elif number == 3:
			first.position = Vector2(330, 236)
		var partner = load("res://scenes/guard.tscn").instantiate()
		partner.name = "ConversationKeeper"
		partner.position = first.position + Vector2(50, 0)
		partner.patrol_left = partner.position.x
		partner.patrol_right = partner.position.x + 100
		partner.level = level
		partner.illness_started = true
		var cast: Array = roster.conversation_cast[str(number)]
		assert(first.guard_name == cast[0], "Keeper conversation cast must match the authored scene")
		assign_keeper(partner, cast[1])
		level.get_node("Guards").add_child(partner)
		actors = [first, partner]
		conversation = config.conversations[str(number)]
		first.facing = 1
		partner.facing = -1
		# Hold a conversation-ready pose; detection and damage still work.
		first.conversation_hold = true
		partner.conversation_hold = true
	for huddle in authored.get("huddles", []):
		spawn_huddle(huddle)
	setup_trapdoors()
	place_props_after_physics()
	build_password_panel()
	var checkpoint_terminal = level.areas.get_node_or_null("RemoteTerminal")
	if checkpoint_terminal != null:
		spawn_terminal_guard(checkpoint_terminal.global_position)
	if not authored.get("ports", []).is_empty():
		var port: Array = authored.ports[0]
		access_point = Vector2(port[0], port[1])
		spawn_prop(access_point, "access", "SERVICE PORT")
		spawn_terminal_guard(access_point)
	elif number in [1, 2]:
		access_point = Vector2(500, 432) if number == 1 else Vector2(440, 432)
		spawn_prop(access_point, "access", "SERVICE PORT")
		spawn_terminal_guard(access_point)
		if number == 2:
			practice_camera = load("res://scenes/security_camera.tscn").instantiate()
			practice_camera.level = level
			practice_camera.position = Vector2(720, 370)
			level.add_child(practice_camera)

## One Keeper posted beside each terminal (service ports, the checkpoint and the records
## terminals), named from the roster's `terminal_guards` list for this floor, in the order the
## terminals are set up. He keeps to a few steps around his post.
var terminal_guard_index := 0

func spawn_terminal_guard(terminal_point: Vector2) -> void:
	var names: Array = roster.get("terminal_guards", {}).get(str(floor_number), [])
	if terminal_guard_index >= names.size():
		return
	var guard_name: String = names[terminal_guard_index]
	var slot := terminal_guard_index + 1
	terminal_guard_index += 1  # reserved now, so names follow terminal order even though we wait below
	# Floors register their collision a frame or two after _ready; the floor ray needs it.
	for wait in range(3):
		await get_tree().physics_frame
	var query := PhysicsRayQueryParameters2D.create(terminal_point + Vector2(0, -6), terminal_point + Vector2(0, 90), 1)
	var hit := level.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var x := INF
	var y := float(hit.position.y) - 16.0
	for offset: float in [48.0, -48.0, 96.0, -96.0, 144.0, -144.0]:
		var candidate := Vector2(terminal_point.x + offset, y)
		if not placement_clear(candidate) or not level.has_floor_below(candidate + Vector2(0, 13)):
			continue
		if level.guards().any(func(g): return g.global_position.distance_to(candidate) < 40.0):
			continue
		x = candidate.x
		break
	if x == INF:
		return
	var keeper = load("res://scenes/guard.tscn").instantiate()
	keeper.set_script(preload("res://scripts/terminal_guard.gd"))
	keeper.name = "TerminalGuard%d" % slot
	keeper.position = Vector2(x, hit.position.y - 16.0)
	keeper.post_at(x)
	keeper.level = level
	keeper.illness_started = true
	keeper.weapon_kind = "pistol"
	assign_keeper(keeper, guard_name)
	level.get_node("Guards").add_child(keeper)

func place_props_after_physics() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	add_props()
	vent_network = preload("res://scripts/vent_network.gd").new()
	add_child(vent_network)
	vent_network.call_deferred("setup",self)

func add_props() -> void:
	call_deferred("convert_cover_zones")
	add_authored_props()

## The old shadow zones become hiding spots in exactly the same places: vents, cabinets and
## lockers (never beside another hide or crate, never on a ladder landing).
func convert_cover_zones() -> void:
	spawn_easter_eggs()
	# The red flask on each science table is the collectible itself.
	for piece in level.definition.get("props", []) if level.get("definition") != null else []:
		if piece.kind != "ward_chamber":continue
		var table_at := Vector2(piece.position[0], piece.position[1])
		if floor_number == 5:
			# Match the drawn tabletop. Only Miro collides with layer 6;
			# guards and Niro can walk through the dressing.
			var tabletop := StaticBody2D.new()
			tabletop.position = table_at
			tabletop.collision_layer = 1 << 5
			tabletop.collision_mask = 0
			var surface := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size = Vector2(70, 4)
			surface.shape = shape
			surface.position.y = -3
			surface.one_way_collision = true
			tabletop.add_child(surface)
			add_child(tabletop)
		spawn_red_flask(table_at + Vector2(10, -25))
		var bottle: Node2D = spawn_prop(table_at+Vector2(-10,-25),"potion","TONIC")
		bottle.set_meta("lab_bottle",true)
		bottle.set_meta("heal_amount",1)
		for decoration in level.find_children("*", "", true, false):
			if decoration.get_script() == preload("res://scripts/story_prop.gd") and decoration.position.distance_to(table_at) < 1.0:
				decoration.set_meta("collectible_flask", true)
				decoration.set_meta("collectible_bottle", true)
				decoration.queue_redraw()
	if floor_number == 4:
		var carts: Array = preload("res://scripts/scaffold_art.gd").CART_X
		for row in range(carts.size()):
			for cart_x: float in carts[row]:
				spawn_red_flask(Vector2(cart_x + 10, float(level.definition.storeys[row]) - 39))
	if floor_number == 5:
		# The Foundation is three open rows: a few tonics along each, since the waves are relentless.
		for row in [236.0, 432.0, 656.0]:
			for x in [180.0, 520.0, 880.0]:
				var drop := PhysicsRayQueryParameters2D.create(Vector2(x, row - 24.0), Vector2(x, row + 120.0), 1)
				var hit_row := get_world_2d().direct_space_state.intersect_ray(drop)
				if hit_row.is_empty():
					continue
				var tonic_spot := Vector2(x, hit_row.position.y - 16.0)
				if placement_clear(tonic_spot) and not spot_taken(tonic_spot, "potion"):
					spawn_prop(tonic_spot, "potion", "TONIC")
	var titles := ["VENT", "CABINET", "LOCKER"]
	var made := 0
	for area in level.areas.get_children():
		if str(area.get("kind")) != "cover":
			continue
		var from: Vector2 = area.global_position
		var query := PhysicsRayQueryParameters2D.create(from + Vector2(0, -12), from + Vector2(0, 160), 1)
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		var point := Vector2(from.x, hit.position.y - 16.0)
		var crowded := false
		for prop in props:
			if is_instance_valid(prop) and prop.kind in ["hide", "crate"] and absf(prop.global_position.y - point.y) < 60.0 and absf(prop.global_position.x - point.x) < 220.0:
				crowded = true
		if crowded or spot_taken(point, "hide") or not placement_clear(point):
			continue
		spawn_prop(point, "hide", titles[made % titles.size()])
		made += 1

func spawn_red_flask(point: Vector2) -> void:
	var flask: Node2D = spawn_prop(point, "potion", "RED TONIC")
	flask.set_meta("heal_amount", 2)
	flask.set_meta("lab_flask", true)

func add_authored_props() -> void:
	level.player.set_collision_mask_value(6, true)  # crates and window sills
	var authored: Dictionary = level.definition.get("features", {}) if level.get("definition") != null else {}
	# Tonics: the little bottles beside the cots (drawn where scaffold_art once stamped them).
	if floor_number >= 2:
		var storey_list: Array = level.definition.get("storeys", [])
		for index in range(mini(6, storey_list.size())):
			for step in range(5 if floor_number == 2 else 4):
				var bottle_x := 220.0 + step * 330 + index * 37 + 70
				var tonic_point := Vector2(bottle_x, float(storey_list[index]) - 16.0)
				if bottle_x <= float(level.definition.world_size[0]) - 120.0 and placement_clear(tonic_point):
					spawn_prop(tonic_point, "potion", "TONIC")
	if authored.has("cases"):
		# Authored layouts place every case and hiding spot by hand (tools/level_layouts.py).
		for point in authored.cases:
			spawn_prop(Vector2(point[0], point[1]), "case", "Ammunition case")
		for hide in authored.hides:
			if hide.title == "CRATE":
				spawn_crate(Vector2(hide.position[0], hide.position[1] + 16))
			else:
				spawn_prop(Vector2(hide.position[0], hide.position[1]), "hide", hide.title)
		return
	if floor_number == 1:
		for point in LEVEL_ONE_CRATES:
			spawn_crate(point)
		# One reachable tonic per storey, clear of walls, patrols and ladder landings.
		for row in [236.0, 432.0, 656.0]:
			for bottle_x in range(356, 1060, 32):
				var tonic_point := Vector2(float(bottle_x), row)
				if level.has_floor_below(tonic_point + Vector2(0, 13)) and placement_clear(tonic_point) and not spot_taken(tonic_point, "potion") and not level.areas.get_children().any(func(area): return area.global_position.distance_to(tonic_point) < 70):
					spawn_prop(tonic_point, "potion", "TONIC")
					break
	# Authored flat-floor anchors only: no random world-coordinate placements.
	var anchors := [Vector2(910, 236), Vector2(750, 432), Vector2(550, 656)]
	if floor_number == 1:
		anchors = [Vector2(580, 236), Vector2(900, 432), Vector2(780, 656)]
	var valid: Array[Vector2] = []
	# Supply case: a small ammunition cache (suppressors were cut on 7 Nov).
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
			campaign.case_anchors[floor_number] = 0
		case_anchor_index = int(campaign.case_anchors[floor_number]) % valid.size()
		spawn_prop(valid[case_anchor_index], "case", "Ammunition case")
	# Enclosed wall recesses; no platform or collision geometry is removed.
	for entry in [[Vector2(900, 432), "VENT"], [Vector2(420, 656), "CRAWLSPACE"]]:
		var point: Vector2 = entry[0]
		var clear: bool = not level.areas.get_children().any(func(area): return area.global_position.distance_to(point) < 70) and not props.any(func(prop): return prop.global_position.distance_to(point) < 70)
		if clear and placement_clear(point) and level.has_floor_below(point + Vector2(0, 13)):
			spawn_prop(point, "hide", entry[1])

## Crates: stand on top (one-way, so they never block a walk or a patrol), or press E beside
## one to hide inside. `point` is on the floor; it is lifted onto any tile it would overlap.
const LEVEL_ONE_CRATES := [Vector2(477, 252), Vector2(968, 448), Vector2(530, 672)]

func spawn_crate(point: Vector2) -> void:
	# `point` is on the floor; check clearance from where the crate's prop marker sits.
	point = free_spot(point - Vector2(0, 16), "crate") + Vector2(0, 16)
	var tiles := level.get_node_or_null("StoneFloors") as TileMapLayer
	if tiles:
		for step in range(8):
			var blocked := false
			for offset in [-12.0, 0.0, 12.0]:
				blocked = blocked or tiles.get_cell_source_id(tiles.local_to_map(tiles.to_local(point + Vector2(offset, -1)))) >= 0
			if not blocked:
				break
			point.y -= tiles.tile_set.tile_size.y
	var center := point - Vector2(0, 13.5)
	# The prop sits where every other hiding spot does (16 px above the floor).
	spawn_prop(point - Vector2(0, 16), "crate", "CRATE")
	var body := StaticBody2D.new()
	body.name = "Crate%d" % props.size()
	body.position = center
	# Own physics layer (6): Miro lands on it, but sight lines and Keepers ignore it.
	body.collision_layer = 0
	body.set_collision_layer_value(6, true)
	body.collision_mask = 0
	level.player.set_collision_mask_value(6, true)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(28, 27)
	shape.shape = box
	shape.one_way_collision = true
	body.add_child(shape)
	add_child(body)

func spawn_prop(point: Vector2, kind: String, title: String) -> Node2D:
	# The starting cell is a prison, not a shortcut into the duct network.
	if kind == "hide" and floor_number == 1 and point.y < 280 and point.x < 300:return null
	if kind == "hide" and floor_number == 1 and absf(point.y-432.0)<24.0:point.x=384.0
	if kind == "hide":title = "VENT"
	if kind in ["case", "hide", "crate"]:
		point = free_spot(point, kind)
	if kind == "hide" and not vent_wall_clear(point):return null
	var prop := Node2D.new()
	prop.set_script(load("res://scripts/review_prop.gd"))
	prop.position = point
	prop.kind = kind
	# Interactive props must sit above the floor tile.  A negative z-index made
	# crates usable but invisible, leaving Miro apparently hiding in open air.
	# Characters render on their own higher layers, so this still keeps props
	# behind them.
	prop.z_index = 1
	prop.title = title
	add_child(prop)
	props.append(prop)
	return prop

func reachable(point: Vector2, distance := 36.0) -> bool:
	return level.player.global_position.distance_to(point) <= distance and level.clear_sight(level.player.global_position + Vector2(0, -8), point + Vector2(0, -8))

func security_terminal(radius := 48.0) -> Node2D:
	var nearest: Node2D
	var distance := radius
	var terminals := get_tree().get_nodes_in_group("security_terminals")
	var checkpoint: Node2D = level.areas.get_node_or_null("RemoteTerminal")
	if checkpoint != null:
		terminals.append(checkpoint)
	for terminal in terminals:
		if not level.is_ancestor_of(terminal):
			continue
		var gap: float = level.player.global_position.distance_to(terminal.global_position)
		if gap <= distance and reachable(terminal.global_position, distance):
			nearest = terminal
			distance = gap
	return nearest

## A wireless connection can reach an adjacent storey; the connected terminal
## determines which devices are wired to the command.
func security_storey(y: float) -> int:
	var definition = level.get("definition")
	if definition == null:
		return 0
	var storeys: Array = definition.get("storeys", [252, 448, 672, 868] if floor_number == 5 else [])
	for index in range(storeys.size()):
		if y <= float(storeys[index]):
			return index
	return maxi(0, storeys.size() - 1)

func disable_cameras(terminal: Node2D) -> int:
	if not is_instance_valid(terminal):
		return 0
	var storey := security_storey(terminal.global_position.y)
	var count := 0
	for node in level.find_children("*", "", true, false):
		if node.get_script() == preload("res://scripts/security_camera.gd") and node.is_active and security_storey(node.global_position.y) == storey:
			node.disable()
			count += 1
	return count

func disable_turrets(terminal: Node2D) -> int:
	if not is_instance_valid(terminal):
		return 0
	var storey := security_storey(terminal.global_position.y)
	var count := 0
	for turret in get_tree().get_nodes_in_group("tower_turrets"):
		if level.is_ancestor_of(turret) and not turret.disabled and not turret.is_in_group("security_cameras") and security_storey(turret.global_position.y) == storey:
			turret.disable()
			count += 1
	return count

func story_distance() -> float:
	var closest := 48.0
	if level.has_method("station_nearby"):
		var station: Dictionary = level.station_nearby()
		if not station.is_empty():
			var marker = level.areas.get_node_or_null(NodePath(station.id))
			if marker != null:closest=minf(closest,level.player.global_position.distance_to(marker.global_position))
	for area in level.areas.get_children():
		if area.kind in ["bed", "door", "sigil", "station", "exit", "brother", "note"]:
			closest = minf(closest, level.player.global_position.distance_to(area.global_position))
	return closest

## Wall-note easter eggs (data/easter_eggs.json): one picture each, an achievement, and for
## the Foreva note a beat that goes onto Miro's MP3.
func spawn_easter_eggs() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/easter_eggs.json"))
	for entry in data.eggs:
		if int(entry.floor) != floor_number:
			continue
		var from := Vector2(float(entry.position[0]), float(entry.position[1]) - 20.0)
		var drop := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 200), 1)
		var found := get_world_2d().direct_space_state.intersect_ray(drop)
		if found.is_empty():
			continue
		var spot := Vector2(from.x, found.position.y - 16.0)
		var prop := Node2D.new()
		prop.set_script(load("res://scripts/review_prop.gd"))
		prop.position = spot
		prop.kind = "egg"
		prop.title = str(entry.title)
		prop.egg = entry
		prop.egg_texture = load(str(entry.image))
		add_child(prop)
		props.append(prop)

var egg_view: Control

func show_egg(entry: Dictionary) -> void:
	hide_egg()
	egg_view = Control.new()
	egg_view.size = Vector2(640, 360)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.78)
	shade.size = Vector2(640, 360)
	egg_view.add_child(shade)
	var picture := TextureRect.new()
	picture.texture = load(str(entry.image))
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.size = Vector2(230, 230)
	picture.position = Vector2(30, 60)
	egg_view.add_child(picture)
	var words := Label.new()
	words.text = "%s\n\n[E] Close" % str(entry.caption)
	words.position = Vector2(290, 90)
	words.size = Vector2(320, 200)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	egg_view.add_child(words)
	level.hud.add_child(egg_view)
	# The achievement, and the secret beat if there is one.
	var campaign = get_node("/root/Campaign")
	var first: bool = campaign.unlock_achievement(str(entry.id))
	if entry.id == "foreva":
		campaign.add_track_unlock("spanish_guitarhall")
		if campaign.total("kills") == 0 and level.player.casualty_count == 0:
			campaign.unlock_achievement("foreva_peaceful")
			campaign.add_track_unlock("foreva")
	elif entry.has("unlock_track"):
		campaign.add_track_unlock(str(entry.unlock_track))
	if first:
		level.notify("ACHIEVEMENT UNLOCKED: %s · %s" % [entry.achievement, entry.achievement_text], 6.0)
		get_node("/root/SoundFX").play_sound("sigil", -8, 1.5)

func hide_egg() -> void:
	if is_instance_valid(egg_view):
		egg_view.queue_free()
	egg_view = null

func nearby_prop():
	var best = null
	var story_range := story_distance()
	var distance := minf(36, story_range)
	for prop in props:
		# A bottle must never consume E beside a story interaction.
		var candidate: float = level.player.global_position.distance_to(prop.global_position)
		# Let Miro stand beside the bottle to select it, even near a station.
		# The station wins when it is at least as close as the bottle.
		if prop.kind == "potion" and (story_range < 48.0 or story_range <= candidate):
			continue
		if candidate < distance and reachable(prop.global_position) and not (prop.kind in ["case", "potion", "note"] and prop.used):
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
		# Authored layouts never put a hatch where it could drop you past a locked gate.
		if level.get("definition") != null and level.definition.has("features"):
			gates = null
		if gates != null:
			for gate in gates.get_children():
				if point.x < gate.global_position.x:
					trap.route_gate = gate
		trap.position = level.to_local(point)
		level.add_child(trap)
		trapdoors.append(trap)
		floor.erase_cell(cell)

## A live Keeper right behind Miro who has not noticed him: E strangles him (never from the front).
func strangle_target():
	if level.player.is_dead or level.player.in_hiding_spot:
		return null
	var best = null
	var distance := 40.0
	for guard in level.guards():
		if guard.is_dead or guard.asleep or guard.has_method("begin_recovery"):
			continue
		if floor_number == 1 and guard.get("sick_guard") and not guard.get("key_taken"):
			continue  # Judas keeps his own pickpocket
		var gap: Vector2 = level.player.global_position - guard.global_position
		var behind: bool = gap.x * guard.facing < -4.0 or (absf(gap.x) <= 6.0 and level.player.facing == guard.facing)
		var above: bool = gap.y < -8.0 and gap.y >= -38.0 and absf(gap.x) <= 16.0
		var in_reach: bool = ((behind and absf(gap.y) < 26.0 and absf(gap.x) <= 36.0) or above) and gap.length() <= distance
		if in_reach and guard.alert_state != IntroGuard.State.ALERT and level.can_melee_reach(level.player.global_position, guard.global_position):
			best = guard
			distance = gap.length()
	return best

func nearest_loot():
	var best = null
	var distance := 45.0
	for guard in level.guards():
		var candidate: float = guard.global_position.distance_to(level.player.global_position)
		if (guard.is_dead or guard.asleep) and not guard.gun_taken and candidate < distance and level.can_melee_reach(level.player.global_position, guard.global_position):
			best = guard
			distance = candidate
	return best

func loot_takes_priority() -> bool:
	var guard = nearest_loot()
	if guard == null:
		return false
	var distance: float = guard.global_position.distance_to(level.player.global_position)
	var prop = nearby_prop()
	return not (prop != null and prop.kind == "access") and distance <= story_distance() and (prop == null or (prop.kind == "hide" and distance <= 24.0) or distance <= prop.global_position.distance_to(level.player.global_position))

func hint() -> String:
	if level.controls_locked():
		return ""
	if level.player.controls.nearest_charge() != null:
		return "[E] Recover C4"
	if level.player.in_hiding_spot:
		return "[E] Leave hiding spot • movement and attacks disabled inside"
	if loot_takes_priority():
		return ""
	if strangle_target() != null:
		return "[E] Pickpocket ammo · hold [E] Strangle" if not strangle_target().ammo_pickpocketed and strangle_target().remaining_ammo()>0 else "Hold [E] Strangle (from behind)"
	var trap = nearby_trapdoor()
	if trap != null:
		if not trap.available():
			return "Trapdoor locked · open checkpoint / ward seal first"
		return "Trapdoor open · closes when clear" if trap.is_open else "[E] Open trapdoor · 5 seconds"
	var prop = nearby_prop()
	if prop and prop.kind == "access":
		return "[E] Service port · [X] Wireless MP3"
	if prop:
		if prop.kind == "egg":
			return "[E] Read the note"
		if prop.kind == "note":
			return "[E] Read the note"
		if prop.kind == "potion":
			return ("[E] Drink red tonic (+one heart)" if int(prop.get_meta("heal_amount", 1)) == 2 else "[E] Drink tonic (+half a heart)") if level.player.health < level.player.max_health else "Tonic (you're not hurt)"
		return "[E] Take ammunition" if prop.kind == "case" else "[E] Hide in " + prop.title.to_lower()
	return ""

func try_interact() -> bool:
	if is_instance_valid(egg_view):
		hide_egg()
		return true
	if level.player.in_hiding_spot:
		level.player.in_hiding_spot = false
		if is_instance_valid(vent_network):vent_network.current=null
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
		level.player.controls.open_remote(true)
		return true
	if prop.kind == "egg":
		show_egg(prop.egg)
		return true
	if prop.kind == "note":
		password_known = true
		prop.used = true
		prop.queue_free()
		props.erase(prop)
		level.start_dialogue([["NOTE", "Checkpoint terminal login
user: keeper    password: root
(all lowercase. Burn this after reading.)"]])
		return true
	if prop.kind == "potion":
		if level.player.health >= level.player.max_health:
			level.notify("You're not hurt. Save it for later.")
		else:
			level.player.health = mini(level.player.max_health, level.player.health + int(prop.get_meta("heal_amount", 1)))
			prop.used = true
			prop.queue_redraw()
			get_node("/root/SoundFX").play_sound("sigil", -14, 1.7)
			level.notify("You drink the red tonic. A heart comes back." if int(prop.get_meta("heal_amount", 1)) == 2 else "You drink the tonic. Half a heart comes back.")
	elif prop.kind == "case":
		if level.player.controls.collect_ammo_case():
			prop.used = true
			prop.queue_redraw()
	else:
		level.player.end_stealth()
		level.player.in_hiding_spot = true
		if is_instance_valid(vent_network):
			vent_network.current=null
			if prop.kind == "hide":vent_network.enter(prop)
		level.player.velocity = Vector2.ZERO
		level.notify("Hidden in " + prop.title.to_lower() + ". [E] Leave")
	return true

func _process(delta: float) -> void:
	queue_redraw()
	update_bubbles(delta)
	if not is_instance_valid(level) or level.paused:
		return
	update_strangle(delta)
	if is_instance_valid(vent_network):vent_network.tick()
	update_turret_hint()
	thought_voice.stream_paused = level.controls_locked() or level.player.is_dead or voice_audible()
	if is_instance_valid(voice_speaker):
		voice.global_position = voice_speaker.global_position
		var voice_target_db := -7.0 if (level.player.is_concealed or level.player.in_hiding_spot) else 0.0
		if absf(voice_speaker.global_position.y - level.player.global_position.y) >= 96.0:voice_target_db -= 8.0
		voice.volume_db = move_toward(voice.volume_db, voice_target_db, delta * 32.0)
		if voice_speaker.is_dead or voice_speaker.asleep:
			voice.stop()
			subtitle.text = ""
			line_left = 0.0
			last_line = {}
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
		if not voice.playing and not pending_search_speakers.is_empty():
			play_next_search_bark()
	if conversation_done or actors.is_empty() or not conversation_started:
		update_casual(delta)
	if conversation_done or actors.is_empty():
		return
	if actors.any(func(actor): return actor.is_dead or actor.asleep or actor.alert_state != IntroGuard.State.PATROL):
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

## The floor roster is in authored spawn order. Level 5 uses a running reinforcement index.
func name_keeper(keeper: Node, number: int, index: int) -> void:
	var entries: Array = roster.floors.get(str(number), [])
	if index < entries.size():
		assign_keeper(keeper, entries[index])

func assign_keeper(keeper: Node, keeper_name: String) -> void:
	keeper.guard_name = keeper_name
	keeper.personality = roster.keepers[keeper_name].personality

## Off-duty Keepers in a tight group (features.huddles): they stand still, face in, and play
## their scene when Miro comes near. Too absorbed to see him unless he walks into them.
func spawn_huddle(huddle: Dictionary) -> void:
	var scene: Dictionary = roster.get("huddles", {}).get(huddle.scene, {})
	if scene.is_empty():
		return
	var members: Array = []
	var origin := Vector2(huddle.position[0], huddle.position[1])
	var count: int = scene.keepers.size()
	for index in range(count):
		var keeper = load("res://scenes/guard.tscn").instantiate()
		keeper.name = "Huddle%s%d" % [str(huddle.scene).capitalize().replace(" ", ""), index]
		keeper.position = origin + Vector2((index - (count - 1) / 2.0) * 30.0, 0)
		keeper.patrol_left = keeper.position.x
		keeper.patrol_right = keeper.position.x
		keeper.level = level
		keeper.illness_started = true
		keeper.weapon_kind = "pistol"
		assign_keeper(keeper, scene.keepers[index])
		level.get_node("Guards").add_child(keeper)
		keeper.facing = 1.0 if index == 0 else -1.0
		keeper.conversation_hold = true
		keeper.distracted = true
		members.append(keeper)
	var lines: Array = []
	for index in range(scene.lines.size()):
		var line: Dictionary = scene.lines[index].duplicate()
		line["id"] = "%s_%d" % [huddle.scene, index + 1]
		lines.append(line)
	add_casual_lines(lines, members, true)

## Adds an overheard scene that plays after (never over) the main conversation.
## `lines` are {speaker, text[, id]}; speaker indexes `actors` (default: the first two patrol Keepers).
func add_casual_lines(lines: Array, scene_actors: Array = [], hold := false) -> void:
	if scene_actors.is_empty():
		for keeper in level.guards():
			if not actors.has(keeper) and scene_actors.size() < 2:
				scene_actors.append(keeper)
	if scene_actors.is_empty():
		return
	casual_scenes.append({"actors": scene_actors, "lines": lines, "index": -1, "started": false, "done": false, "hold": hold})

func main_conversation_busy() -> bool:
	return conversation_started and not conversation_done

## One casual scene or patrol mutter at a time, only while no one else is speaking.
func update_casual(delta: float) -> void:
	if line_left > 0 or voice.playing:
		return
	# A half-heard main conversation elsewhere on the floor doesn't hold up a scene Miro is
	# standing beside (the huddle used to wait on it forever).
	if main_conversation_busy() and not actors.is_empty() and level.player.global_position.distance_to(actors[0].global_position) < 320:
		return
	for scene in casual_scenes:
		if scene.done:
			continue
		var cast: Array = scene.actors
		if cast.any(func(actor): return not is_instance_valid(actor) or actor.is_dead or actor.asleep or actor.alert_state != IntroGuard.State.PATROL):
			scene.done = true
			for actor in cast:
				if is_instance_valid(actor):
					actor.conversation_hold = false
					actor.distracted = false
			continue
		if not scene.started:
			if level.player.global_position.distance_to(cast[0].global_position) > 260:
				continue
			scene.started = true
			for actor in cast:
				actor.conversation_hold = true
		scene.index += 1
		if scene.index >= scene.lines.size():
			scene.done = true
			if not scene.hold:
				for actor in cast:
					actor.conversation_hold = false
			continue
		var line: Dictionary = scene.lines[scene.index]
		var speaker: Node2D = cast[int(line.speaker) % cast.size()]
		speak(speaker, str(line.get("id", "casual_%d" % scene.index)), str(line.text), line)
		return
	update_mutters(delta)

## A patrolling Keeper close to Miro mutters something mundane, once each, never near an
## unfinished overheard scene (so it can't talk over a clue).
func update_mutters(delta: float) -> void:
	mutter_wait = maxf(0, mutter_wait - delta)
	if mutter_wait > 0:
		return
	if not conversation_done and not actors.is_empty() and level.player.global_position.distance_to(actors[0].global_position) < 320:
		return
	for scene in casual_scenes:
		if not scene.done and level.player.global_position.distance_to(scene.actors[0].global_position) < 320:
			return
	var profiles: Dictionary = roster.keepers
	for keeper in level.guards():
		if keeper.get("personality") == null:
			continue
		if keeper.is_dead or keeper.asleep or keeper.alert_state != IntroGuard.State.PATROL or muttered.has(keeper.get_instance_id()) or actors.has(keeper):
			continue
		if keeper.distracted or not profiles.has(keeper.guard_name):
			continue
		var gap: Vector2 = keeper.global_position - level.player.global_position
		if gap.length() > MUTTER_RANGE or absf(gap.y) > 40:
			continue
		var idle: Array = profiles[keeper.guard_name].idle
		var choice := muttered.size() % idle.size()
		muttered[keeper.get_instance_id()] = true
		mutter_wait = MUTTER_GAP
		speak(keeper, "idle_%d" % (choice + 1), idle[choice])
		return

var recent_guard_lines: Dictionary = {}
# A shared spatial voice plays one Keeper at a time. Store IDs so changing scenes
# or removing a guard cannot leave us holding a dead speaker.
var pending_search_speakers: Array[int] = []

func queue_search_bark(actor: IntroGuard) -> void:
	if actor.global_position.distance_to(level.player.global_position) >= 340.0:
		return
	var speaker_id := actor.get_instance_id()
	if not pending_search_speakers.has(speaker_id):
		pending_search_speakers.append(speaker_id)

func play_next_search_bark() -> void:
	while not pending_search_speakers.is_empty():
		var speaker_id: int = pending_search_speakers.pop_front()
		var actor := instance_from_id(speaker_id) as IntroGuard
		if not is_instance_valid(actor) or actor.asleep or actor.is_dead or actor.sees_player:
			continue
		if actor.global_position.distance_to(level.player.global_position) >= 340.0:
			continue
		var profile: Dictionary = roster.keepers.get(actor.guard_name, {})
		if not profile.has("lost"):
			continue
		abort_conversation()
		speak(actor, "lost", str(profile.lost))
		if line_left > 0.0:
			break

func speak(actor: Node2D, id: String, text: String, extra: Dictionary = {}) -> void:
	if not is_instance_valid(actor) or actor.is_dead or actor.asleep:
		return
	var repeat_key := "%s:%s" % [actor.get_instance_id(), id]
	var now := Time.get_ticks_msec()
	if now - int(recent_guard_lines.get(repeat_key, -12000)) < 12000:
		return
	recent_guard_lines[repeat_key] = now
	voice.stop()
	voice_speaker = actor
	speech_bubble.actor = actor
	voice.global_position = actor.global_position
	# Still audible while Miro is cloaked or hiding, only softer.
	voice.volume_db = -7.0 if (level.player.is_concealed or level.player.in_hiding_spot) else 0.0
	var path := keeper_clip_path(actor.guard_name, id)
	var duration := maxf(2.5, text.length() * 0.055)
	voice.stream = load(path) if ResourceLoader.exists(path) else null
	if voice.stream:
		duration = voice.stream.get_length()
		if DisplayServer.get_name() != "headless":
			voice.play()
	line_left = duration + 0.35
	subtitle.text = "%s: %s" % [actor.display_name, text]
	last_line = extra.duplicate()
	if last_line.is_empty():
		last_line = {"bark": true}

## All spatial dialogue uses the actor's own voice, even when several floors share a line.
func keeper_clip_path(keeper_name: String, line_id: String) -> String:
	return "res://assets/audio/voice/%s_%s.mp3" % [keeper_name.to_lower(), line_id]

func bark(actor: Node2D, kind: String, force := false) -> void:
	if not is_instance_valid(actor) or actor.is_dead or actor.asleep:
		return
	if Time.get_ticks_msec() - int(recent_guard_lines.get("%s:%s" % [actor.get_instance_id(), kind], -12000)) < 12000:
		return
	# A Keeper far from Miro and from the talkers must not cut an overheard conversation short.
	var near_player: bool = actor.global_position.distance_to(level.player.global_position) < 340.0
	var is_talker: bool = actors.has(actor)
	if voice.playing and not force and not (near_player or is_talker):
		return
	if near_player or is_talker or force:
		abort_conversation()
	if voice.playing:
		if not force:
			return
		voice.stop()
		line_left = 0.0
	var profile: Dictionary = roster.keepers.get(actor.guard_name, {})
	var text: String = profile.get(kind, config.barks.get(kind, {"text": "Sleeping on the job."}).text)
	speak(actor, kind, text)

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
	return line_left > 0 and is_instance_valid(voice_speaker) and not voice_speaker.is_dead and not voice_speaker.asleep and voice_speaker.global_position.distance_to(level.player.global_position) < 230

func update_bubbles(delta: float) -> void:
	if not is_instance_valid(level):
		return
	speech_bubble.visible = voice_audible() and not level.controls_locked() and not level.player.is_dead
	speech_bubble.follow_actor()
	thought_bubble.visible = false
	remote_bubble.visible = false
	if level.controls_locked() or level.player.is_dead:
		return
	if remote_left > 0:
		remote_left = maxf(0, remote_left - delta)
		remote_bubble.visible = remote_left > 0
		remote_bubble.follow_actor()
		return
	if speech_bubble.visible:
		return
	if thought_left > 0:
		thought_left = maxf(0, thought_left - delta)
		thought_bubble.visible = thought_left > 0
		thought_bubble.follow_actor()
		if thought_left <= 0 and not pending_thoughts.is_empty():
			var next_thought: Array = pending_thoughts.pop_front()
			think(str(next_thought[0]), str(next_thought[1]))
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
			think(entry.text, "thought_%d_%s" % [floor_number, entry.id])
			break

## Turrets retain their first encounter tutorial; camera advice stays on demand.
func update_turret_hint() -> void:
	if turret_hinted or thought_seen.has("turret_hint") or level.controls_locked() or level.player.is_dead:
		return
	for turret in get_tree().get_nodes_in_group("tower_turrets"):
		if not level.is_ancestor_of(turret) or turret.is_in_group("security_cameras") or turret.health <= 0 or turret.disabled:
			continue
		if turret.target_point().distance_to(level.player.global_position) < 230.0:
			thought_seen["turret_hint"] = true
			turret_hinted = true
			think(TURRET_HINT)
			return

## Called when Miro asks for a hint [Z]. Prefer a nearby turret to camera advice.
func security_hint() -> String:
	var connected := level.player.controls.connection_target() != null
	if not turret_hinted and not thought_seen.has("turret_hint"):
		for turret in get_tree().get_nodes_in_group("tower_turrets"):
			if not level.is_ancestor_of(turret) or turret.is_in_group("security_cameras") or turret.health <= 0 or turret.disabled:continue
			if turret.target_point().distance_to(level.player.global_position) < 230.0:
				thought_seen["turret_hint"] = true
				turret_hinted = true
				return TURRET_HINT
	if not thought_seen.has("camera_hack_hint"):
		for camera in get_tree().get_nodes_in_group("security_cameras"):
			if not level.is_ancestor_of(camera) or not camera.is_active:continue
			var nearby: bool = camera.global_position.distance_to(level.player.global_position) < 230.0
			if nearby or connected:
				thought_seen["camera_hack_hint"] = true
				return CAMERA_HACK_HINT
	return ""

## Thoughts queue: a new one waits for the one on screen to finish (and be heard in full)
## unless it is Miro's own Z hint, which cuts in.
var pending_thoughts: Array = []

func think(text: String, clip := "", cut_in := false) -> void:
	if text.is_empty():
		return
	if thought_left > 0 and not cut_in:
		pending_thoughts.append([text, clip])
		return
	thought_voice.stop()
	thought_bubble.text_label.text = text
	thought_left = maxf(4, text.length() * 0.07)
	var path := "res://assets/audio/voice/%s.mp3" % clip
	# Thoughts without their own clip (floor openings, MISSING/HUNTED thoughts) use Miro's
	# text-hashed clip, like his dialogue.
	if clip.is_empty() or not ResourceLoader.exists(path):
		path = preload("res://scripts/remote_radio.gd").clip_path(text, "miro")
	if ResourceLoader.exists(path) and DisplayServer.get_name() != "headless":
		thought_voice.stream = load(path)
		thought_voice.play()
		thought_left = maxf(thought_left, thought_voice.stream.get_length() + 0.7)

## A line over the remote: shown above Miro, heard through the bitcrushed radio bus.
## With an actor (Niro in the room) the line hangs over him instead and is not radioed.
func remote_say(text: String, speaker := "NIRO", actor: Node2D = null) -> void:
	if text.is_empty():
		return
	remote_bubble.actor = actor if is_instance_valid(actor) else level.player
	remote_bubble.tag = speaker if is_instance_valid(actor) else speaker + " · remote"
	remote_bubble.text_label.text = text
	if is_instance_valid(actor):
		remote_left = maxf(2.5, text.length() * 0.06) + 0.8
	else:
		remote_left = get_node("/root/RemoteRadio").say(text) + 0.8

func remote_busy() -> bool:
	return remote_left > 0

func build_password_panel() -> void:
	password_panel = level.panel_at(Vector2(110, 95), Vector2(420, 190))
	var box := VBoxContainer.new()
	password_panel.add_child(box)
	var title := Label.new()
	title.text = "CHECKPOINT LOGIN"
	box.add_child(title)
	password_input = LineEdit.new()
	password_input.secret = true
	password_input.secret_character = "*"
	password_input.keep_editing_on_text_submit = true
	password_input.placeholder_text = "Password (case-sensitive)"
	box.add_child(password_input)
	password_input.text_submitted.connect(submit_password)
	var login := Button.new()
	login.text = "Log in"
	login.pressed.connect(func(): submit_password(password_input.text))
	box.add_child(login)
	password_use = Button.new()
	password_use.text = "Enter the known password"
	password_use.pressed.connect(func(): submit_password("root"))
	box.add_child(password_use)
	var slip := Button.new()
	password_slip = slip
	slip.text = "Inspect maintenance slip"
	slip.pressed.connect(func():
		password_known = true)
	box.add_child(slip)
	password_status = Label.new()
	password_status.text = ""
	box.add_child(password_status)
	var cancel := Button.new()
	cancel.text = "Close"
	cancel.pressed.connect(func(): password_panel.hide())
	box.add_child(cancel)
	password_panel.hide()

func open_terminal() -> void:
	password_panel.show()
	password_input.text = ""
	# No hints here: the player works the password out (the Keepers' talk, a dropped note).
	password_status.text = ""
	password_use.visible = false
	password_slip.visible = false
	password_input.grab_focus()

func submit_password(text: String) -> void:
	if text != "root":
		password_status.text = "Access denied. Password is case-sensitive."
		password_input.call_deferred("grab_focus")
		return
	terminal_authenticated = true
	password_panel.hide()
	level.hack_remaining = 1.0

func _unhandled_input(event: InputEvent) -> void:
	if modal_open() and event.is_action_pressed("ui_cancel"):
		password_panel.hide()
		get_viewport().set_input_as_handled()

func modal_open() -> bool:
	return is_instance_valid(password_panel) and password_panel.visible

func _exit_tree() -> void:
	if is_instance_valid(voice):
		voice.stop()
		voice.stream = null
	actors.clear()
	voice_speaker = null

## Level items never spawn on top of a Keeper, a story station, a ladder or another item.
## `point` is a prop position (16 px above the floor). Slides along the same floor in 16 px
## steps, alternating sides, up to 192 px; keeps the authored spot if nothing nearby is free.
func free_spot(point: Vector2, kind := "") -> Vector2:
	for step in range(0, 13):
		for direction in [1, -1]:
			if step == 0 and direction == -1:
				continue
			var candidate := point + Vector2(direction * step * 16.0, 0)
			if spot_taken(candidate, kind) or not placement_clear(candidate) or (kind == "hide" and not vent_wall_clear(candidate)):
				continue
			if step > 0 and not level.has_floor_below(candidate + Vector2(0, 13)):
				continue
			return candidate
	return point

func spot_taken(point: Vector2, kind := "") -> bool:
	for guard in level.guards():
		if not is_instance_valid(guard) or absf(guard.global_position.y - point.y) >= 40:
			continue
		# Clear of where the Keeper stands and of the stretch he patrols on this floor.
		var left := minf(guard.global_position.x, float(guard.get("patrol_left") if guard.get("patrol_left") != null else guard.global_position.x))
		var right := maxf(guard.global_position.x, float(guard.get("patrol_right") if guard.get("patrol_right") != null else guard.global_position.x))
		# Crates and wall hides may sit along a patrol (that's the point: hide near Keepers);
		# they only keep off the spot a Keeper is standing on.
		if kind in ["hide", "crate"]:
			left = guard.global_position.x - 20.0
			right = guard.global_position.x + 20.0
		if point.x > left - 30 and point.x < right + 30:
			return true
	for prop in props:
		# Crates and the wall hides (vents, lockers, crawlspaces) don't sit side by side; those
		# hides are drawn taller than their marker, so compare them over a taller band.
		var pair: bool = (kind == "crate" and prop.kind == "hide") or (kind == "hide" and prop.kind == "crate")
		if not is_instance_valid(prop) or absf(prop.global_position.y - point.y) >= (70.0 if pair else 24.0):
			continue
		var apart := 140.0 if pair else 32.0
		if absf(prop.global_position.x - point.x) < apart:
			return true
	for area in level.areas.get_children():
		if area.kind == "ladder":
			if Rect2(area.global_position - area.area_size / 2, area.area_size).grow(16).has_point(point):
				return true
		elif area.global_position.distance_to(point) < 34:
			return true
	return false

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

func pickpocket_ammo(guard: IntroGuard) -> int:
	if guard != strangle_target() or guard.ammo_pickpocketed: return 0
	var amount := mini(guard.remaining_ammo(), get_node("/root/Campaign").ammo_amount(3 if guard.weapon_kind == "pistol" else 6))
	if amount <= 0: return 0
	guard.ammunition -= amount
	guard.stolen_ammo += amount
	guard.ammo_pickpocketed = true
	var c = level.player.controls
	c.reserves[guard.weapon_kind] = int(c.reserves.get(guard.weapon_kind,0)) + amount
	level.notify("Pickpocketed %d %s rounds. [R] Reload · hold [E] to strangle." % [amount,guard.weapon_kind],4)
	if level.has_method("record_guard_ammo_checkpoint"):level.record_guard_ammo_checkpoint()
	return amount

func strangle_active() -> bool:
	return is_instance_valid(strangle_victim) and strangle_left > 0.0

func begin_strangle(victim: IntroGuard) -> void:
	strangle_requires_hold = next_strangle_requires_hold
	if strangle_active(): return
	strangle_victim=victim
	strangle_left=STRANGLE_TIME
	strangle_health=level.player.health
	previous_hold=victim.conversation_hold
	victim.conversation_hold=true
	victim.velocity.x=0
	level.player.velocity=Vector2.ZERO
	queue_redraw()

func cancel_strangle() -> void:
	if is_instance_valid(strangle_victim): strangle_victim.conversation_hold=previous_hold
	strangle_victim=null
	strangle_left=0
	queue_redraw()

func update_strangle(delta: float) -> void:
	if not strangle_active(): return
	var victim := strangle_victim
	if level.player.is_dead or level.player.health < strangle_health or victim.is_dead or victim.asleep or level.player.global_position.distance_to(victim.global_position)>44.0 or not level.can_melee_reach(level.player.global_position,victim.global_position):
		cancel_strangle()
		return
	if strangle_requires_hold:
		var c = level.player.controls
		var held: bool = Input.is_action_pressed("interact") or (c.pad_device >= 0 and Input.is_joy_button_pressed(c.pad_device,get_node("/root/InputBindings").pad_button(JOY_BUTTON_A)))
		if level.paused or not (DisplayServer.get_name()=="headless" or DisplayServer.window_is_focused()):
			cancel_strangle()
			return
		if not held:
			cancel_strangle()
			pickpocket_ammo(victim)
			return
	strangle_left=maxf(0,strangle_left-delta)
	if strangle_left<=0:
		cancel_strangle()
		level.finish_strangle(victim)

func _draw() -> void:
	if not strangle_active(): return
	var center := to_local(strangle_victim.global_position+Vector2(22,-24))
	draw_circle(center,6,Color("272744"))
	draw_arc(center,0,TAU,5,24,Color("494d7e"),1.5,true)
	draw_arc(center,-PI/2,-PI/2+TAU*(1.0-strangle_left/STRANGLE_TIME),5,24,Color("f2d3ab"),1.5,true)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_PAUSED] and strangle_requires_hold and strangle_active():
		cancel_strangle()

func vent_wall_clear(point: Vector2) -> bool:
	var rect := Rect2(point-Vector2(30,48),Vector2(60,68))
	for piece in level.definition.get("props",[]) if level.get("definition") != null else []:
		if rect.intersects(Rect2(Vector2(piece.position[0],piece.position[1])-Vector2(68,72),Vector2(136,96))):return false
	for decoration in level.get_children():
		if decoration.get_script() == preload("res://scripts/inner_conflict.gd") and is_instance_valid(decoration.frame):
			if rect.intersects(Rect2(decoration.frame.global_position-Vector2(36,74),Vector2(72,68))):return false
	var shape := RectangleShape2D.new()
	shape.size = Vector2(52,60)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape=shape
	query.transform=Transform2D(0,point+Vector2(0,-16))
	query.collision_mask=1
	return get_world_2d().direct_space_state.intersect_shape(query).is_empty()
