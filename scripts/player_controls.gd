extends Node
## Unified item selection, reload/attachments and inventory modal.
var player: IntroPlayer
var slots: Array[String] = ["shank", "c4", "", "", "remote"]
var layout: Array[String] = []
var active := "blanket"
var inventory_open := false
var remote_open := false
var has_remote := false
var remote_unlocked := false
var focus := false
var reserves: Dictionary = {}
var attachments: Dictionary = {}
var spares := 0
var reload_left := 0.0
var attach_left := 0.0
var hold_key := 0
var panel: PanelContainer
var remote_panel: PanelContainer
var output: Label
var command: LineEdit
var buttons: Array[Button] = []
var swap_from := -1
var planted: Array[Node2D] = []
var progress := 0.0

func _ready() -> void:
	player = get_parent()
	layout.assign(get_node("/root/Campaign").inventory_layout)

func locked() -> bool:
	return inventory_open or remote_open

func sync_slots() -> void:
	for i in range(layout.size()):
		var token := layout[i]
		if token in ["gun_1", "gun_2"]:
			var gun_index := 0 if token == "gun_1" else 1
			slots[i] = player.guns[gun_index] if player.guns.size() > gun_index else ""
		else:
			slots[i] = token
	for gun in player.guns:
		if not reserves.has(gun):
			reserves[gun] = capacity(gun) * 2
	if active in ["pistol", "smg", "flamethrower"] and not player.guns.has(active):
		active = "blanket"

func capacity(gun: String) -> int:
	return 8 if gun == "pistol" else (24 if gun == "smg" else 30)

func select_item(item: String) -> void:
	if item.is_empty():
		return
	reload_left = 0
	attach_left = 0
	focus = false
	active = item
	if player.guns.has(item):
		attachments[player.equipped_gun] = player.suppressor_uses
		player.select_gun(player.guns.find(item))
		player.suppressor_uses = attachments.get(item, 0)

func _input(event: InputEvent) -> void:
	if not is_instance_valid(player.level):
		return
	if event is InputEventKey and not event.echo:
		if not event.pressed:
			if event.physical_keycode == hold_key:
				attach_left = 0
				hold_key = 0
			return
		var key: int = event.physical_keycode
		if locked():
			if key == KEY_ESCAPE or (key == KEY_N and inventory_open):
				close_panels()
				get_viewport().set_input_as_handled()
			return
		if player.level.controls_locked() or player.is_dead:
			return
		if key >= KEY_1 and key <= KEY_5:
			select_item(slots[key - KEY_1])
			hold_key = key
			if active in ["pistol", "smg"] and player.suppressor_uses == 0 and spares > 0:
				attach_left = 1.0
		elif key == KEY_Q:
			select_item("blanket")
		elif key == KEY_N:
			show_inventory()
		elif key == KEY_R:
			start_reload()
		else:
			return
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(player.level) or player.level.controls_locked() or player.is_dead or player.in_hiding_spot:
		return
	if event is InputEventMouseMotion:
		player.mouse_aim = true
	if event is InputEventMouseButton:
		player.mouse_aim = true
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			use_item()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			focus = event.pressed and active != "c4"
			if event.pressed and active == "c4":
				drop_charge()
		else:
			return
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player.level):
		return
	sync_slots()
	if panel == null and is_instance_valid(player.level.hud):
		build_panels()
	if player.level.controls_locked() or player.is_dead or player.in_hiding_spot:
		focus = false
		reload_left = 0
		attach_left = 0
		return
	focus = focus and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if reload_left > 0:
		reload_left = maxf(0, reload_left - delta)
		if reload_left == 0:
			var amount := mini(capacity(active) - player.ammunition, int(reserves.get(active, 0)))
			player.ammunition += amount
			reserves[active] -= amount
			player.gun_ammo[active] = player.ammunition
	if attach_left > 0:
		if hold_key == 0 or not Input.is_physical_key_pressed(hold_key):
			attach_left = 0
		else:
			attach_left = maxf(0, attach_left - delta)
			if attach_left == 0:
				spares -= 1
				player.suppressor_uses = 3
				attachments[active] = 3
	progress = 1.0 - (reload_left / 1.0 if reload_left > 0 else attach_left)
	if active in ["smg", "flamethrower"] and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		use_item()

func use_item() -> void:
	if reload_left > 0 or attach_left > 0:
		return
	if player.mouse_aim and absf(player.aim_direction.x) > 0.01:
		player.facing = signf(player.aim_direction.x)
	match active:
		"blanket": player.toggle_stealth()
		"shank": player.shank()
		"c4": detonate_charges()
		"remote": open_remote()
		"pistol", "smg", "flamethrower": player.fire_gun()

func start_reload() -> void:
	if active not in player.guns or reload_left > 0 or player.ammunition >= capacity(active):
		return
	if reserves.get(active, 0) <= 0:
		player.level.notify("No reserve ammunition.")
		return
	attach_left = 0
	reload_left = 1.0

func collect_suppressor() -> void:
	if active in ["pistol", "smg"] and player.suppressor_uses == 0:
		player.suppressor_uses = 3
		attachments[active] = 3
		player.level.notify("Suppressor attached · 3 shots")
	else:
		spares += 1
		player.level.notify("Spare suppressor stored. Hold a gun's slot key for 1 second to attach.")

func collect_remote() -> void:
	if has_remote:
		return
	has_remote = true
	get_node("/root/Campaign").remote_owned = true
	player.level.notify("Taken: Keeper MP3 player. Select its slot, then click to inspect.", 8)

func build_panels() -> void:
	panel = player.level.panel_at(Vector2(70, 115), Vector2(500, 150))
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "INVENTORY · Click two slots to swap · Q always selects blanket"
	title.add_theme_font_size_override("font_size", 12)
	box.add_child(title)
	var row := HBoxContainer.new()
	box.add_child(row)
	for i in range(5):
		var button := Button.new()
		button.custom_minimum_size = Vector2(88, 45)
		button.add_theme_font_size_override("font_size", 11)
		button.pressed.connect(swap_slot.bind(i))
		row.add_child(button)
		buttons.append(button)
	var close := Button.new()
	close.text = "Done [N / Esc]"
	close.pressed.connect(close_panels)
	box.add_child(close)
	panel.hide()
	remote_panel = player.level.panel_at(Vector2(70, 95), Vector2(500, 220))
	var remote_box := VBoxContainer.new()
	remote_panel.add_child(remote_box)
	output = Label.new()
	output.custom_minimum_size = Vector2(460, 125)
	output.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	output.add_theme_font_size_override("font_size", 12)
	remote_box.add_child(output)
	command = LineEdit.new()
	command.placeholder_text = "miro@player:~$ help"
	command.text_submitted.connect(run_command)
	remote_box.add_child(command)
	var done := Button.new()
	done.text = "Close terminal [Esc]"
	done.pressed.connect(close_panels)
	remote_box.add_child(done)
	remote_panel.hide()

func show_inventory() -> void:
	inventory_open = true
	panel.show()
	refresh_slots()

func refresh_slots() -> void:
	for i in range(5):
		buttons[i].text = "%d\n%s%s" % [i + 1, slots[i] if not slots[i].is_empty() else "empty", " *" if swap_from == i else ""]

func swap_slot(index: int) -> void:
	if swap_from < 0:
		swap_from = index
	else:
		var item := layout[index]
		layout[index] = layout[swap_from]
		layout[swap_from] = item
		get_node("/root/Campaign").inventory_layout.assign(layout)
		sync_slots()
		swap_from = -1
	refresh_slots()

func close_panels() -> void:
	inventory_open = false
	remote_open = false
	panel.hide()
	remote_panel.hide()
	swap_from = -1

func open_remote() -> void:
	if not has_remote:
		player.level.notify("The first Keeper carries an MP3 player. Loot or pickpocket him.")
		return
	remote_open = true
	remote_panel.show()
	output.text = "KEEPER MP3 · service port locked\nA script in your handwriting: unlock.sh\nType: hack" if not remote_unlocked else "miro@player:~$\nType help for commands. Nearby access points only."
	command.text = ""
	command.grab_focus()

func run_command(raw: String) -> void:
	var text := raw.strip_edges()
	command.clear()
	if text == "hack" or text == "./unlock.sh":
		remote_unlocked = true
		get_node("/root/Campaign").remote_unlocked = true
		output.text = "Service mode unlocked. Your scripts survived.\nMP3 playback active. Type help."
	elif not remote_unlocked:
		output.text = "Service port locked. Type hack to run your unlock script."
	elif text == "help":
		output.text = "help · scan · login <password> · cameras off · music\n1. Stand near an access point and scan.\n2. Find its password, then login <password>.\n3. Run cameras off (or lights test on floor 1). Esc closes."
	elif text == "music":
		output.text = "MP3 mode: the current floor's soundtrack is playing.\nYour player doubles as a local tower terminal."
	elif text == "scan":
		if at_early_port():
			output.text = "service.local · maintenance account\nSticker: user root · password root\n" + ("Practice lamp available. login root, then lights test" if get_node("/root/Campaign").current_floor == 1 else "Optional corridor camera. login root, then cameras off")
			return
		output.text = "checkpoint.local · 2 cameras · login required\nPassword clue: listen to the Keepers or inspect the terminal." if at_checkpoint() else "No writable access point in range.\nThe security checkpoint on floor 3 has a local terminal."
	elif text.begins_with("login "):
		if not at_checkpoint() and not at_early_port():
			output.text = "No local connection. Move to the checkpoint terminal."
		elif text != "login root":
			output.text = "Access denied. Listen for the password near the terminal."
		else:
			if at_early_port():
				player.level.world_features.early_authenticated = true
			else:
				player.level.world_features.terminal_authenticated = true
			output.text = "root@checkpoint: authenticated\nYour script: cameras off"
	elif text == "lights test":
		if at_early_port() and player.level.world_features.early_authenticated:
			player.level.emit_effect("hit", player.level.world_features.access_point)
			output.text = "Service lamp blinked. Your script works.\nOn the next floor, try cameras off at a service port."
		else:
			output.text = "Connect at the service port and login root first."
	elif text == "cameras off":
		if at_early_port() and player.level.world_features.early_authenticated and is_instance_valid(player.level.world_features.practice_camera):
			player.level.world_features.practice_camera.disable()
			output.text = "Corridor camera disabled. This route is optional."
			return
		if at_checkpoint() and player.level.world_features.terminal_authenticated:
			close_panels()
			player.level.hack_remaining = 1.0
		else:
			output.text = "Connect locally and authenticate first: login <password>"
	else:
		output.text = "Unknown command. Type help. No real network commands are executed."

func at_early_port() -> bool:
	return get_node("/root/Campaign").current_floor in [1, 2] and player.level.world_features.reachable(player.level.world_features.access_point, 48)

func at_checkpoint() -> bool:
	return get_node("/root/Campaign").current_floor == 3 and player.level.world_features.reachable(player.level.areas.get_node("RemoteTerminal").global_position, 48)

func drop_charge() -> void:
	# Reserve authored charges so optional explosives cannot soft-lock the story.
	var reserve := 1
	if get_node("/root/Campaign").current_floor == 4:
		reserve = 0
		for station in player.level.definition.stations:
			if station.kind == "sigil" and not player.level.milestones.has(station.id):
				reserve += int(station.get("charge_count", 1))
	elif player.level.sigil_placed:
		reserve = 0
	if player.c4_count <= reserve:
		player.level.notify("Remaining C4 is reserved for the marked supports. [E] at a support.")
		return
	var charge := Node2D.new()
	charge.set_script(preload("res://scripts/dropped_charge.gd"))
	charge.position = player.position
	player.level.add_child(charge)
	planted.append(charge)
	player.c4_count -= 1
	player.end_stealth()

func nearest_charge():
	var best = null
	var distance: float = minf(36, player.level.world_features.story_distance())
	var prop = player.level.world_features.nearby_prop()
	if prop != null:
		distance = minf(distance, prop.global_position.distance_to(player.global_position))
	for charge in planted:
		if not is_instance_valid(charge):
			continue
		var candidate := charge.global_position.distance_to(player.global_position)
		if candidate < distance and player.level.clear_sight(player.global_position, charge.global_position):
			best = charge
			distance = candidate
	return best

func recover_charge() -> bool:
	var charge = nearest_charge()
	if charge == null:
		return false
	planted.erase(charge)
	charge.queue_free()
	player.c4_count += 1
	player.level.notify("C4 recovered.")
	return true

func detonate_charges() -> void:
	for charge in planted:
		if not is_instance_valid(charge):
			continue
		var point := charge.global_position
		player.level.emit_effect("breach", point)
		player.level.make_noise(point, 700)
		get_node("/root/SoundFX").play_sound("collapse", -20)
		if get_node("/root/Campaign").current_floor == 1 and not player.level.door_open and point.distance_to(player.level.get_node("Interactables/CellLock").global_position) < 65:
			player.level.route = "C4 breach"
			player.level.open_door()
		for guard in player.level.guards():
			if guard.global_position.distance_to(point) < 90 and player.level.clear_sight(point, guard.global_position):
				guard.take_damage(3)
		charge.queue_free()
	planted.clear()
