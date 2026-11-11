extends "res://scripts/intro_level.gd"
## Playable blockout controller. Milestones stand in for unfinished set pieces.
var definition: Dictionary
var milestones: Dictionary = {}
var pending_milestone: String = ""
var connected_cameras: Array[Node] = []
var hack_remaining := 0.0
var floor_alerts := 0
var watcher_reserves_called := false
const HAZARD_ROTATIONS := {"floor": 0.0, "ceiling": PI, "left": -PI / 2, "right": PI / 2}
var brother: Node
var cinematic: Control
## Level 5 only: guitar, waves and Niro's three retreats (scripts/foundation_flow.gd).
var flow: Node
## Branch reaction for this floor (Level 2 onward): MISSING or HUNTED, from committed floors.
var reputation := ""
var hunted := false
var disappointment_heard := false
var poster: Node2D

var beat_cue_wait := 0.0

func _ready() -> void:
	definition = JSON.parse_string(FileAccess.get_file_as_string(get_meta("blueprint")))
	get_node("/root/Campaign").enter_floor(int(definition.number))
	process_mode = Node.PROCESS_MODE_ALWAYS
	setup_inputs()
	player.level = self
	player.position = $LevelPlan/PlayerSpawn.position
	# Camera and out-of-world limits follow the blueprint (Level 5 is deeper than the others).
	player.get_node("Camera2D").limit_right = int(definition.world_size[0])
	player.get_node("Camera2D").limit_bottom = int(definition.world_size[1])
	player.has_supplies = true
	player.c4_count = int(definition.get("demolition_charges", 1)) + 3 # Three charges to use freely; story supports stay reserved.
	door_open = true
	brother_heard = true
	for guard in guards():
		guard.level = self
		guard.illness_started = true
	build_hud()
	apply_difficulty()
	setup_world_features(int(definition.number))
	call_deferred("apply_carried_kit")
	call_deferred("apply_checkpoint")
	player.controls.has_remote = get_node("/root/Campaign").remote_owned
	player.controls.remote_unlocked = get_node("/root/Campaign").remote_unlocked
	var authored: Dictionary = definition.get("features", {})
	if authored.has("cameras"):
		# Linked cameras go dark when the checkpoint terminal is reprogrammed; the rest keep sweeping.
		for entry in authored.cameras:
			var camera = load("res://scenes/security_camera.tscn").instantiate()
			camera.position = Vector2(entry.position[0], entry.position[1])
			camera.facing_angle = float(entry.get("facing", 1.57))
			camera.level = self
			add_child(camera)
			if entry.get("disabled", false):
				# Already dead when Miro arrives: the tower's earlier floors were reprogrammed, these stay dark as scenery.
				camera.set_meta("pre_disabled", true)
				camera.is_active = false
				camera.queue_redraw()
				continue
			if entry.get("linked", false):
				connected_cameras.append(camera)
			elif int(definition.number) == 2 and world_features.practice_camera == null:
				# Level 2's camera is the practice one: the service port's remote hack turns it off.
				world_features.practice_camera = camera
	elif int(definition.number) == 3:
		for point in [Vector2(450, 180), Vector2(820, 370)]:
			var camera = load("res://scenes/security_camera.tscn").instantiate()
			camera.position = point
			camera.level = self
			add_child(camera)
			connected_cameras.append(camera)
	for entry in authored.get("hazards", []):
		var hazard := Area2D.new()
		hazard.set_script(preload("res://scripts/tower_hazard.gd"))
		hazard.level = self
		hazard.kind = str(entry.kind)
		hazard.position = Vector2(entry.position[0], entry.position[1])
		hazard.rotation = HAZARD_ROTATIONS.get(entry.get("mount", "floor"), 0.0)
		hazard.disabled = bool(entry.get("disabled", false))
		add_child(hazard)
	if int(definition.number) == 5:
		flow = Node.new()
		flow.set_script(load("res://scripts/foundation_flow.gd"))
		flow.name = "FoundationFlow"
		add_child(flow)
		flow.setup(self)
	# Extra patrols the layout generator does not place (features.extra_guards).
	for spot in definition.get("features", {}).get("extra_guards", []):
		var extra = load("res://scenes/guard.tscn").instantiate()
		extra.name = str(spot.name)
		extra.position = Vector2(spot.position[0], spot.position[1])
		extra.patrol_left = float(spot.patrol[0])
		extra.patrol_right = float(spot.patrol[1])
		extra.level = self
		extra.illness_started = true
		extra.weapon_kind = "pistol"
		world_features.assign_keeper(extra, str(spot.keeper))
		$Guards.add_child(extra)
	if int(definition.number) == 4:
		var hunt := Node.new()
		hunt.set_script(load("res://scripts/hunt_waves.gd"))
		hunt.name = "HuntWaves"
		hunt.level = self
		add_child(hunt)
	# The floor's opening is Miro thinking it through: his thoughts are the game's cues.
	var opening: Array = [["MIRO", definition.opening, "thought"]]
	opening.append_array(setup_branch())
	start_dialogue(opening)
	var accents := {2: Color("c69fa5"), 3: Color("8bb5c9"), 4: Color("d8e3ea"), 5: Color("f2d3ab")}
	var report: String = get_node("/root/Campaign").branch()[reputation].report if int(definition.number) > 2 else ""
	show_card("floor", "%02d" % int(definition.number), str(definition.title).to_upper(), report, accents.get(int(definition.number), Color("c69fa5")))

## Each storey of a floor is a checkpoint: the first time Miro stands on a deeper one it is
## saved, and a retry puts him back there with the floor's progress, with every Keeper
## respawned (the scene reloads).
func current_storey() -> int:
	var storeys: Array = definition.get("storeys", [])
	for index in range(storeys.size()):
		if player.global_position.y < float(storeys[index]) + 20.0:
			return index
	return storeys.size() - 1

var checkpoint_refreshed := 0

func update_checkpoint() -> void:
	if flow != null or player.is_dead or not player.is_on_floor() or completed:
		return
	var campaign = get_node("/root/Campaign")
	var storey := current_storey()
	if storey <= int(campaign.checkpoint.get("storey", 0)) and not campaign.checkpoint.is_empty():
		# Same storey: keep the checkpoint's place and health, but keep its kit current so guns
		# and ammo picked up since are not lost on a retry (refreshed every couple of seconds).
		if int(campaign.checkpoint.get("floor", 0)) == int(definition.number) and Time.get_ticks_msec() - checkpoint_refreshed > 2000:
			checkpoint_refreshed = Time.get_ticks_msec()
			var kit := player_snapshot()
			kit["health"] = int(campaign.checkpoint.get("player", {}).get("health", player.health))
			campaign.checkpoint["player"] = kit
			campaign.checkpoint["dead"] = dead_guards()
			campaign.checkpoint["security"] = security_checkpoint.duplicate(true)
			campaign.checkpoint["milestones"] = milestones.duplicate()
			campaign.checkpoint["sigil"] = sigil_placed
			campaign.checkpoint["thoughts"] = world_features.thought_seen.keys()
			campaign.checkpoint["used_cases"] = used_ammo_cases()
			campaign.checkpoint["used_potions"] = used_potion_positions()
			campaign.checkpoint["looted_guards"] = looted_guard_names()
			campaign.checkpoint["guard_ammo"] = guard_ammo_snapshot()
			campaign.save_checkpoint()
		return
	if storey == 0 and campaign.checkpoint.is_empty():
		return
	campaign.checkpoint = {"floor": int(definition.number), "storey": storey, "position": player.global_position, "milestones": milestones.duplicate(), "sigil": sigil_placed, "player": player_snapshot(), "dead": dead_guards(), "thoughts": world_features.thought_seen.keys(), "used_cases": used_ammo_cases(), "used_potions": used_potion_positions(), "looted_guards": looted_guard_names(), "guard_ammo": guard_ammo_snapshot(), "security": security_checkpoint.duplicate(true)}
	get_node("/root/MusicDirector").checkpoint_music()
	campaign.save_checkpoint()
	notify("Checkpoint.")

## What Miro is carrying at a checkpoint, so a retry gives it all back.
func player_snapshot() -> Dictionary:
	var c = player.controls
	return {
		"health": player.health, "max_health": player.max_health, "has_supplies": player.has_supplies,
		"has_key": player.has_key, "has_gun": player.has_gun, "guns": Array(player.guns),
		"gun_ammo": player.gun_ammo.duplicate(), "equipped_gun": player.equipped_gun, "ammunition": player.ammunition,
		"c4_count": player.c4_count, "casualty_count": player.casualty_count,
		"reserves": c.reserves.duplicate(), "has_guitar": c.has_guitar, "layout": Array(c.layout),
		"has_remote": c.has_remote, "remote_unlocked": c.remote_unlocked, "active_item": c.active, "planted_charges": c.charge_snapshot(),
	}

func dead_guards() -> Array:
	var dead: Array = []
	for guard in guards():
		if guard.is_dead and guard.get_parent() == $Guards:
			dead.append({"name": str(guard.name), "position": guard.global_position, "looted": guard.gun_taken})
	return dead

## Loot already included in the saved kit cannot be collected a second time after a retry.
func used_ammo_cases() -> Array:
	var used: Array = []
	var index := 0
	for prop in world_features.props:
		if is_instance_valid(prop) and prop.kind == "case":
			if prop.used:
				used.append({"index": index, "position": prop.global_position})
			index += 1
	return used

func used_potion_positions() -> Array:
	var used: Array = []
	for prop in world_features.props:
		if is_instance_valid(prop) and prop.kind == "potion" and prop.used:used.append(prop.position)
	return used

func looted_guard_names() -> Array:
	var names: Array = []
	for guard in guards():
		if guard.gun_taken:
			names.append(str(guard.name))
	return names

func guard_ammo_snapshot() -> Dictionary:
	var saved: Dictionary = {}
	for guard in guards():
		if guard.get_parent() == $Guards: saved[str(guard.name)] = {"ammo":guard.remaining_ammo(), "picked":guard.ammo_pickpocketed, "stolen":guard.stolen_ammo}
	return saved

func record_guard_ammo_checkpoint() -> void:
	var campaign = get_node("/root/Campaign")
	if campaign.checkpoint.get("floor",0) != int(definition.number):return
	var kit := player_snapshot()
	kit["health"] = int(campaign.checkpoint.get("player",{}).get("health",player.health))
	campaign.checkpoint["player"] = kit
	campaign.checkpoint["guard_ammo"] = guard_ammo_snapshot()
	campaign.save_checkpoint()

func restore_checkpoint_loot(saved: Dictionary) -> void:
	# Cases and terminal posts are authored asynchronously after the first physics frames.
	for tick in range(4):
		await get_tree().physics_frame
	for guard_name in saved.get("guard_ammo", {}):
		var guard = $Guards.get_node_or_null(str(guard_name))
		if guard != null:
			var data: Dictionary = saved.guard_ammo[guard_name]
			guard.ammunition = int(data.ammo)
			guard.ammo_pickpocketed = bool(data.picked)
			guard.stolen_ammo = int(data.stolen)
	for entry in saved.get("dead", []):
		var fallen = $Guards.get_node_or_null(str(entry.name))
		if fallen != null and not fallen.is_dead:
			fallen.restore_dead(entry.position, bool(entry.get("looted", false)))
	for guard_name in saved.get("looted_guards", []):
		var guard = $Guards.get_node_or_null(str(guard_name))
		if guard != null:
			guard.gun_taken = true
	var cases: Array = world_features.props.filter(func(prop): return is_instance_valid(prop) and prop.kind == "case")
	for point in saved.get("used_potions", []):
		for prop in world_features.props:
			if is_instance_valid(prop) and prop.kind == "potion" and prop.position.distance_to(point) < 1.0:
				prop.used = true
				prop.queue_redraw()
	for entry in saved.get("used_cases", []):
		var index := int(entry.index)
		var found = null
		for prop in cases:
			if prop.global_position.distance_to(entry.position) < 1.0:
				found = prop
				break
		if found == null and index >= 0 and index < cases.size():
			found = cases[index]
		if found != null:
			found.used = true
			found.queue_redraw()

func apply_player_snapshot(data: Dictionary) -> void:
	var c = player.controls
	player.health = int(data.get("health", player.health))
	player.max_health = int(data.get("max_health", player.max_health))
	player.has_supplies = bool(data.get("has_supplies", player.has_supplies))
	player.has_key = bool(data.get("has_key", false))
	player.has_gun = bool(data.get("has_gun", false))
	player.guns.assign(data.get("guns", []))
	player.gun_ammo = Dictionary(data.get("gun_ammo", {})).duplicate()
	player.equipped_gun = str(data.get("equipped_gun", player.equipped_gun))
	player.ammunition = int(data.get("ammunition", 0))
	player.c4_count = int(data.get("c4_count", player.c4_count))
	player.casualty_count = int(data.get("casualty_count", 0))
	c.reserves = Dictionary(data.get("reserves", {})).duplicate()
	c.has_guitar = bool(data.get("has_guitar", false))
	c.has_remote = bool(data.get("has_remote", c.has_remote))
	c.remote_unlocked = bool(data.get("remote_unlocked", c.remote_unlocked))
	var campaign = get_node("/root/Campaign")
	campaign.remote_owned = c.has_remote
	campaign.remote_unlocked = c.remote_unlocked
	if data.has("layout"):
		c.layout.assign(data.layout)
		campaign.inventory_layout.assign(data.layout)
	c.sync_slots()
	var restored_item := str(data.get("active_item", player.equipped_gun if player.has_gun else "c4"))
	if restored_item in ["shank", "blanket", "remote"]:restored_item = player.equipped_gun if player.has_gun else "c4"
	if restored_item == "pistol" and c.has_guitar:restored_item = "guitar"
	c.select_item(restored_item)
	c.restore_charges(data.get("planted_charges", []))

## Guns, ammo, C4 and health come with Miro from the floor above (not on a retry: the checkpoint has its own kit).
func apply_carried_kit() -> void:
	var campaign = get_node("/root/Campaign")
	var kit: Dictionary = campaign.carried_kit
	if kit.is_empty() or int(campaign.carried_from) != int(definition.number) - 1:
		return
	var checkpoint: Dictionary = campaign.checkpoint
	if int(checkpoint.get("floor", 0)) == int(definition.number) and checkpoint.get("retry", false):
		return
	var c = player.controls
	player.has_supplies = bool(kit.get("has_supplies", player.has_supplies))
	player.has_gun = bool(kit.get("has_gun", false))
	player.guns.assign(kit.get("guns", []))
	player.gun_ammo = Dictionary(kit.get("gun_ammo", {})).duplicate()
	player.equipped_gun = str(kit.get("equipped_gun", player.equipped_gun))
	player.ammunition = int(kit.get("ammunition", 0))
	if kit.has("c4_count"):
		player.c4_count = maxi(int(definition.get("demolition_charges", 1)), int(kit.get("c4_count", 0)))
	c.reserves = Dictionary(kit.get("reserves", {})).duplicate()
	player.health = clampi(int(kit.get("health", player.health)), 1, player.max_health)
	c.sync_slots()
	if player.has_gun:
		c.select_item(player.equipped_gun)

func apply_checkpoint() -> void:
	var saved: Dictionary = get_node("/root/Campaign").checkpoint
	if saved.is_empty() or int(saved.get("floor", 0)) != int(definition.number) or flow != null or not saved.get("retry", false):
		return
	saved.erase("retry")
	player.global_position = saved.position
	# Resuming past the point where the floor's second song starts: that song, not the first.
	if definition.has("music_region"):
		var entry: Dictionary = definition.music_region.entry
		if saved.position.y >= float(entry.get("minimum_y", INF)) and (not entry.has("requires_milestone") or saved.milestones.has(entry.requires_milestone)):
			get_node("/root/MusicDirector").second_section(int(definition.number))
	player.velocity = Vector2.ZERO
	if saved.has("player"):
		apply_player_snapshot(saved.player)
	# Keepers killed before the checkpoint stay dead; everyone else is back on their feet.
	for guard_name in saved.get("guard_ammo", {}):
		var guard = $Guards.get_node_or_null(str(guard_name))
		if guard != null:
			var data: Dictionary = saved.guard_ammo[guard_name]
			guard.ammunition = int(data.ammo)
			guard.ammo_pickpocketed = bool(data.picked)
			guard.stolen_ammo = int(data.stolen)
	for entry in saved.get("dead", []):
		var fallen = $Guards.get_node_or_null(str(entry.name))
		if fallen != null:
			fallen.restore_dead(entry.position, bool(entry.get("looted", false)))
	restore_checkpoint_loot(saved)
	restore_checkpoint_security(saved)
	checkpoint_grace_until = Time.get_ticks_msec() + 4000
	for guard in guards():
		if guard.is_dead or guard.asleep:continue
		guard.alert_state = IntroGuard.State.PATROL
		guard.suspicion = 0.0
		guard.pursuing = false
		guard.sees_player = false
		guard.search_left = 0.0
		guard.windup = 0.0
		guard.burst_left = 0
		guard.ladder_exit_left = 0.0
		guard.ladder_stall_time = 0.0
		for body in guards():
			if body.is_dead:guard.seen_bodies[body.get_instance_id()] = true
			elif body.asleep:guard.seen_sleepers[body.get_instance_id()] = true
	# A moment of grace so the respawned Keepers can't strip health the instant he appears.
	player.invulnerability_left = 3.5
	player.respawn_cloak_left = 4.0
	player.is_concealed = true
	sigil_placed = bool(saved.get("sigil", false)) and definition.stations.any(func(station): return station.kind == "sigil" and saved.get("milestones", {}).has(station.id))
	for id in saved.milestones:
		milestones[id] = true
		var node = areas.get_node_or_null(NodePath(str(id)))
		if node != null:
			node.activated = true
			node.queue_redraw()
		if has_node("Gates"):
			for gate in $Gates.get_children():
				if gate.unlock_milestone == str(id):
					gate.unlock()
	# Thoughts Miro already had on this floor are not repeated after a retry; the floor's
	# opening-line thoughts always count as heard once a checkpoint exists.
	for id in saved.get("thoughts", []):
		world_features.thought_seen[id] = true
	for entry in world_features.thoughts.get(str(int(definition.number)), []):
		if not entry.has("milestone") and not entry.has("minimum_y"):
			world_features.thought_seen[entry.id] = true
	# Straight back into play: skip the floor's opening scene.
	dialogue = []
	dialogue_index = 0
	dialogue_event = ""
	notify("Back at your checkpoint. The Keepers are back too.")

func _process(delta: float) -> void:
	super._process(delta)
	# A beat earned on the last floor is announced once, a few seconds in.
	beat_cue_wait += delta
	var campaign = get_node("/root/Campaign")
	if beat_cue_wait > 4.0 and not campaign.fresh_unlocks.is_empty() and dialogue.is_empty() and not controls_locked():
		var names: Array = []
		for track in campaign.fresh_unlocks:
			names.append(campaign.track_title(str(track)))
		campaign.fresh_unlocks = []
		notify("New beat unlocked: %s. Press B to change beat." % ", ".join(names), 7.0)
	# Level 2: his brother's offer comes through the remote on its own as Miro reaches that
	# point in the floor, whether or not he has looked at the sick prisoner first.
	# Floor 3's familiar voice speaks the same way, once the personnel record has been read.
	if flow == null and dialogue.is_empty() and not controls_locked() and not player.is_dead and player.is_on_floor() and not milestones.has("BrotherReveal") and milestones.has("RankRecord"):
		var reveal = areas.get_node_or_null("BrotherReveal")
		if reveal != null and reveal.global_position.distance_to(player.global_position) < 90.0:
			for station in definition.stations:
				if station.id == "BrotherReveal":
					pending_milestone = "BrotherReveal"
					start_dialogue(station.lines, "milestone")
	if int(definition.number) == 4 and flow == null and dialogue.is_empty() and not controls_locked() and not player.is_dead and player.is_on_floor() and not milestones.has("BrotherWarning") and milestones.has("ExperimentRecords") and milestones.has("ContainmentEvidence"):
		var warning = areas.get_node_or_null("BrotherWarning")
		if warning != null and warning.global_position.distance_to(player.global_position) < 90.0:
			for station in definition.stations:
				if station.id == "BrotherWarning":
					pending_milestone = "BrotherWarning"
					start_dialogue(station.lines, "milestone")
	if flow == null and dialogue.is_empty() and not controls_locked() and not player.is_dead and player.is_on_floor() and not milestones.has("BrotherOffer"):
		var offer = areas.get_node_or_null("BrotherOffer")
		if offer != null and offer.global_position.distance_to(player.global_position) < 90.0:
			for station in definition.stations:
				if station.id == "BrotherOffer":
					pending_milestone = "BrotherOffer"
					start_dialogue(station.lines, "milestone")
	update_checkpoint()
	if not controls_locked() and definition.has("music_region"):
		var entry: Dictionary = definition.music_region.entry
		var in_region := player.position.x >= float(entry.get("minimum_x", -INF)) and player.position.y >= float(entry.get("minimum_y", -INF)) and player.position.y <= float(entry.get("maximum_y", INF))
		var ready_milestone := not entry.has("requires_milestone") or milestones.has(entry.requires_milestone)
		if in_region and ready_milestone and (not entry.get("requires_landing", true) or player.is_on_floor()):
			get_node("/root/MusicDirector").second_section(int(definition.number))
	# A gate always matches the milestones: whatever opened the milestone, the gate follows.
	if has_node("Gates") and int(Engine.get_physics_frames()) % 30 == 0:
		for gate in $Gates.get_children():
			if gate.unlock_milestone != "" and milestones.has(gate.unlock_milestone) and not gate.is_open:
				gate.unlock()
	if hack_remaining > 0 and not controls_locked():
		if player.is_dead or player.global_position.distance_to(areas.get_node("RemoteTerminal").global_position) >= 90:
			hack_remaining = 0
			notify("Reprogramming interrupted. Stay beside the terminal for one second.")
		else:
			hack_remaining = maxf(0, hack_remaining - delta)
			if hack_remaining == 0:
				for camera in connected_cameras:
					# A watcher Miro already destroyed is simply gone: skip it.
					if is_instance_valid(camera):
						camera.disable()
				# The hack counts the moment it completes, so no other scene starting at the same
				# time (a remote threat, a Keeper's bark) can swallow it and leave the gate locked.
				milestones["RemoteTerminal"] = true
				if has_node("Gates"):
					for gate in $Gates.get_children():
						if gate.unlock_milestone == "RemoteTerminal":
							gate.unlock()
				var terminal_area = areas.get_node_or_null("RemoteTerminal")
				if terminal_area != null:
					terminal_area.activated = true
					terminal_area.queue_redraw()
				notify("Checkpoint linked cameras disabled. Gate open. Other systems use their service terminals.", 6.0)
				if dialogue.is_empty():
					start_dialogue([["MIRO", "I hacked the system and nobody has even realized.", "thought"]])
	if completed:
		overlay_label.text = get_node("/root/ControllerSettings").prompt("%s\n\n%s\n\n%s\n\n[Backspace] Retry   [Enter] Descend" % [definition.title.to_upper(), definition.closing, floor_report()])
		if int(definition.number) == 5:
			overlay_label.text = get_node("/root/ControllerSettings").prompt("MIRO\n\nThe end.\n\n[Backspace] Replay final floor   [Enter] New run")

func _unhandled_input(event: InputEvent) -> void:
	if completed and event.is_action_pressed("advance") and not event.is_echo():
		get_node("/root/Campaign").complete_floor(int(definition.number), sigil_placed, milestones, floor_raw_stats())
		get_node("/root/Campaign").update_unlocks()
		get_viewport().set_input_as_handled()
		if definition.number < 5:
			play_interlude(int(definition.number), "res://scenes/levels/level_%02d.tscn" % (int(definition.number) + 1))
		else:
			get_tree().change_scene_to_file("res://scenes/intro.tscn")
		return
	super._unhandled_input(event)

## World reacts to how Miro has played so far; never changes objectives or the plot.
func setup_branch() -> Array:
	var campaign = get_node("/root/Campaign")
	var number := int(definition.number)
	reputation = campaign.reputation()
	hunted = reputation == "HUNTED"
	var data: Dictionary = campaign.branch()[reputation]
	world_features.thoughts[str(number)].insert(0, {"id": "branch", "text": str(data.get("thoughts", {}).get(str(number), data.thought))})
	poster = Node2D.new()
	poster.set_script(load("res://scripts/wanted_poster.gd"))
	poster.wanted = hunted
	poster.position = $LevelPlan/PlayerSpawn.position + Vector2(70, -46)
	add_child(poster)
	if not world_features.conversation.is_empty():
		world_features.conversation = world_features.conversation.duplicate(true)
		for index in range(data.guard_line.size()):
			world_features.conversation.append({"id": "branch_%s_%d" % [reputation.to_lower(), index], "speaker": index % 2, "text": data.guard_line[index]})
	if hunted and number < 5:
		# More armed Keepers: one extra patrol by the stair gate, clear of the ladder landings.
		var extra = load("res://scenes/guard.tscn").instantiate()
		extra.name = "HuntedKeeper"
		var spot = definition.get("features", {}).get("hunted_guard")
		extra.position = Vector2(spot.position[0], spot.position[1]) if spot != null else Vector2(700, 656)
		extra.patrol_left = spot.patrol[0] if spot != null else 640.0
		extra.patrol_right = spot.patrol[1] if spot != null else 760.0
		extra.level = self
		extra.illness_started = true
		extra.weapon_kind = "pistol"
		world_features.assign_keeper(extra, world_features.roster.hunted[str(number)])
		$Guards.add_child(extra)
	var lines: Array = [["TOWER PA", data.pa]]
	if number < 5:
		# Each floor has its own line here, so the same threat is never heard twice.
		lines.append(["THE VOICE" if number < 4 else "NIRO", str(data.get("remote_calls", {}).get(str(number), data.remote_call))])
	return lines

## Kills cost: Niro's disappointment over the remote (once per floor) on top of noise and bodies.
## Floor 3: if the guards' password talk is missed, the first Keeper to fall drops a note with it.
var password_note_dropped := false

func drop_password_note(at: Vector2) -> void:
	if password_note_dropped or int(definition.number) != 3 or world_features.password_known:
		return
	password_note_dropped = true
	world_features.spawn_prop(at + Vector2(0, -4), "note", "NOTE")

func on_keeper_killed(guard) -> void:
	drop_password_note(guard.global_position)
	var campaign = get_node("/root/Campaign")
	var is_named: bool = not str(guard.get("guard_name")).is_empty()
	campaign.on_keeper_killed(str(guard.get("guard_name")), is_named)
	if disappointment_heard or int(definition.number) >= 5:
		return
	disappointment_heard = true
	var lines: Array = campaign.branch().kill_disappointment
	world_features.remote_say(lines[(int(definition.number) + player.casualty_count) % lines.size()], "NIRO" if int(definition.number) >= 3 else "THE VOICE")

func floor_report() -> String:
	var campaign = get_node("/root/Campaign")
	var raw := floor_raw_stats()
	var scored: Dictionary = campaign.score_floor(raw)
	var text := "%s   ·   Kills %d   ·   Seen %d" % [campaign.style_word(raw), raw.kills, raw.detections]
	var unlocks: Array = campaign.preview_unlocks(int(scored.stealth), int(raw.kills))
	if not unlocks.is_empty():
		text += "\nMP3 unlocked: " + ", ".join(unlocks)
	return text

func counts_detection() -> bool:
	# In The Foundation discovery is forced after the guitar; only earlier sightings count.
	return flow == null or flow.step == flow.Step.OFFICE

func objective() -> String:
	if flow != null and not flow.objective().is_empty():
		var text: String = flow.objective()
		if not milestones.has("FinalSigil"):
			text += " · final sigil not yet placed"
		return text
	for station in definition.stations:
		if flow != null and station.id in ["FinalOffer", "BrotherEncounter"] and not milestones.has(station.id):
			continue
		if not milestones.has(station.id) and station.requires.all(func(required): return milestones.has(required)):
			return "%02d / %s\n%s" % [int(definition.number), definition.title.to_upper(), station.objective]
	return "%s\nReach the stair gate. [E]" % definition.title

## Z hints come from the blueprint ("hints", keyed by station id, "exit", or L5's flow step).
func hint_key() -> String:
	if flow != null and not flow.objective().is_empty():
		return "flow_" + flow.hint_step()
	for station in definition.stations:
		if flow != null and station.id in ["FinalOffer", "BrotherEncounter"] and not milestones.has(station.id):
			continue
		if not milestones.has(station.id):
			return station.id
	return "exit"

func hint_lines(key: String) -> Array:
	return definition.get("hints", {}).get(key, [])

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
	if int(definition.number) == 4 and not milestones.has("WardRelease") and has_node("Gates/WardSeal") and player.global_position.distance_to($Gates/WardSeal.global_position + Vector2(0, 68)) < 80.0:
		return "Ward sealed. Manual release: upper floor, far left, on the raised gantry. Double jump up, then interact."
	if world_features and not world_features.hint().is_empty():
		return world_features.hint()
	if is_instance_valid(brother) and not brother.is_dead:
		return flow.niro_fight_hint() if flow != null else "[F] Melee during RECOVER • [C] Dodge • Space Jump"
	if hack_remaining > 0:
		return "Reprogramming… %d%% • stay within reach" % int((1 - hack_remaining) * 100)
	if controls_locked() or player.is_dead:
		return ""
	var station := station_nearby()
	if not station.is_empty():
		return "Completed: " + station.title if milestones.has(station.id) else "[E] " + station.title
	var guard = closest_guard()
	if guard and (guard.is_dead or guard.asleep) and not guard.gun_taken:
		return "[E] Search sleeping Keeper" if guard.asleep else "[E] Search fallen Keeper"
	if nearby("exit", 65):
		return "[E] Descend once this floor's objectives are complete"
	if player.is_concealed:
		return "Move carefully • touching a Keeper breaks stealth"
	if ladder_at(player.global_position):
		return "[W / S] Climb"
	if stuck():
		return "Not sure where to go? [Z] Think it through"
	return "A/D Move   Space Jump   C Dash   1–3 Weapons   4 Knife   F Melee   Q Blanket   X MP3   Esc Controls"

func interact() -> void:
	if controls_locked() or player.is_dead:
		return
	if player.controls.recover_charge():
		return
	if try_strangle():
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
				notify("First: " + station_title(str(required)))
				return
		if flow != null and station.id in ["FinalOffer", "BrotherEncounter", "DefeatExchange"]:
			notify("Niro will come to you.")
			return
		if station.kind == "sigil":
			var needed: int = int(station.get("charge_count", 1))
			if player.c4_count < needed:
				notify("Not enough C4. Recover placed charges first.")
				return
		pending_milestone = station.id
		if station.id == "ForestViewpoint":
			pending_milestone = ""
			get_node("/root/Campaign").add_track_unlock("set_me_free")
			cinematic = load("res://scenes/ending_cinematic.tscn").instantiate()
			cinematic.level = self
			cinematic.finished.connect(finish_ending)
			hud.add_child(cinematic)
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
	if guard and (guard.is_dead or guard.asleep) and not guard.gun_taken:
		player.loot_weapon(guard)
		return
	if nearby("exit", 65):
		if definition.stations.all(func(entry): return milestones.has(entry.id)) and sigil_placed:
			completed = true
			player.velocity = Vector2.ZERO
		else:
			notify("Follow the remaining objective before descending.")

## A station id as the player reads it ("FinalSigil" -> "Place the final sigil").
func station_title(id: String) -> String:
	for entry in definition.stations:
		if entry.id == id:
			return str(entry.title)
	return id.replace("_", " ")

func finish_dialogue() -> void:
	var event := dialogue_event
	var finished_milestone := pending_milestone if event == "milestone" else ""
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
	if flow != null:
		if finished_milestone == "Guitar":
			flow.on_guitar()
		elif event.begins_with("niro_"):
			flow.on_dialogue_finished(event)

func can_melee_reach(from: Vector2, to: Vector2) -> bool:
	return clear_sight(from, to)

func plant_c4() -> void:
	notify("This floor's charge is reserved for its sigil support. [E]")

func camera_alert(point: Vector2) -> void:
	floor_alerts += 1
	var called := spawn_watcher_reserves(point)
	for guard in guards():
		if not guard.is_dead:
			guard.investigate(point)
			guard.pursuing = true
	notify("WATCHER ALERT • Reinforcements incoming." if called else "WATCHER ALERT • Every Keeper is closing in on your last seen position.")

## One reserve squad per floor. Repeated sweeps redirect the squad without spawning endlessly.
func spawn_watcher_reserves(point: Vector2) -> bool:
	var reserves: Array = world_features.roster.watcher_reserves.get(str(int(definition.number)), [])
	if reserves.is_empty():
		return false
	# The squad comes once and is redirected while it lives; if it is wiped out, the next
	# alert calls another two.
	for guard in guards():
		if guard.name.begins_with("WatcherReserve") and not guard.is_dead:
			return false
	watcher_reserves_called = true
	var slots: Array[Vector2] = []
	for offset in [-156, 156, -100, 100]:
		var above := point + Vector2(offset, -24)
		if not clear_sight(point, above):
			continue
		var query := PhysicsRayQueryParameters2D.create(above, above + Vector2(0, 82), 1)
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.normal.y < -0.9:
			slots.append(hit.position - Vector2(0, 16))
	var entry: Vector2 = $LevelPlan/PlayerSpawn.global_position
	for index in range(reserves.size()):
		var location := slots[index] if index < slots.size() else entry + Vector2(index * 18, 0)
		var guard = preload("res://scenes/guard.tscn").instantiate()
		guard.name = "WatcherReserve%d" % (index + 1)
		world_features.assign_keeper(guard, reserves[index])
		guard.position = $Guards.to_local(location)
		guard.patrol_left = guard.position.x - 60.0
		guard.patrol_right = guard.position.x + 60.0
		guard.level = self
		guard.illness_started = true
		guard.weapon_kind = "pistol"
		$Guards.add_child(guard)

	return true

func niro_retreating(engagement: int) -> void:
	if flow != null:
		flow.niro_retreating(engagement)

func niro_calls_guard(point: Vector2) -> void:
	if flow != null:
		flow.niro_calls_guard(point)

func brother_defeated() -> void:
	if flow != null:
		flow.step = flow.Step.DONE
	get_node("/root/MusicDirector").silence()
	milestones["BrotherEncounter"] = true
	areas.get_node("BrotherEncounter").activated = true
	areas.get_node("BrotherEncounter").queue_redraw()
	var campaign = get_node("/root/Campaign")
	campaign.unlock_achievement("defeat_niro")
	campaign.add_track_unlock("hot_shit")
	for station in definition.stations:
		if station.id == "DefeatExchange":
			pending_milestone = "DefeatExchange"
			start_dialogue(station.lines, "milestone")

func controls_locked() -> bool:
	return is_instance_valid(cinematic) or super.controls_locked()

func finish_ending() -> void:
	milestones["ForestViewpoint"] = true
	completed = true
	get_node("/root/Campaign").complete_floor(5, sigil_placed, milestones, floor_raw_stats())

var security_checkpoint: Dictionary = {}
var checkpoint_grace_until := 0

func record_security_checkpoint(device: Node2D, destroyed: bool) -> void:
	var kind := "camera" if device.get_script() == preload("res://scripts/security_camera.gd") else "turret"
	var campaign = get_node("/root/Campaign")
	var id: String = campaign.security_device_id(int(definition.number), kind, device.position)
	security_checkpoint[id] = {"destroyed": destroyed, "kind": kind, "position": device.position}
	if int(campaign.checkpoint.get("floor", 0)) == int(definition.number):
		campaign.checkpoint["security"] = security_checkpoint.duplicate(true)
		campaign.save_checkpoint()

func restore_checkpoint_security(saved: Dictionary) -> void:
	security_checkpoint = Dictionary(saved.get("security", {})).duplicate(true)
	var campaign = get_node("/root/Campaign")
	for device in get_tree().get_nodes_in_group("tower_turrets"):
		if not is_ancestor_of(device):continue
		var camera: bool = device.get_script() == preload("res://scripts/security_camera.gd")
		var kind := "camera" if camera else "turret"
		var id: String = campaign.security_device_id(int(definition.number), kind, device.position)
		if not security_checkpoint.has(id):continue
		if bool(security_checkpoint[id].get("destroyed", false)):
			device.queue_free()
		elif camera:
			device.is_active = false
			device.cone_points = PackedVector2Array()
			device.queue_redraw()
		else:
			device.disabled = true
			device.charge = 0.0
			device.queue_redraw()
