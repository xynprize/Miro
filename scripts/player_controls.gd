extends Node
## Unified item selection, reload and inventory modal.
var player: IntroPlayer
var slots: Array[String] = ["shank", "c4", "", "", "remote"]
var layout: Array[String] = []
var active := "blanket"
var inventory_open := false
var remote_open := false
var local_console := false
## Records terminals Miro has logged into on this floor: one login per terminal, kept after closing it.
var logged_in: Dictionary = {}
var console_title: Label
var console_icon: TextureRect
var console_echo: Label
var has_remote := false
var remote_unlocked := false
var focus := false
var pad_aim := false
var pad_device := -1
var pad_prompts := false
var controller_settings: Node
var reserves: Dictionary = {}
var reload_left := 0.0
var panel: PanelContainer
var remote_panel: PanelContainer
var output: Label
var command: LineEdit
var buttons: Array[Button] = []
var swap_from := -1
var planted: Array[Node2D] = []
var progress := 0.0
## Level 5 guitar. Key 6 (or G) selects it; left click strums. Existing bindings are unchanged.
var has_guitar := false
var strum_cooldown := 0.0
var strum_flash := 0.0
var strum_visual_reach := 120.0
const STRUM_RADIUS := 120.0
const STRUM_RADIUS_ON_BEAT := 170.0

func _ready() -> void:
	player = get_parent()
	controller_settings = get_node("/root/ControllerSettings")
	Input.joy_connection_changed.connect(on_pad_connection)
	layout.assign(get_node("/root/Campaign").inventory_layout)

func on_pad_connection(device: int, connected: bool) -> void:
	if not connected and device == pad_device:
		pad_device = -1
		pad_aim = false
		pad_prompts = false
		player.pad_crouch = false

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
	if active in ["pistol", "smg"] and not player.guns.has(active):
		active = "blanket"

func capacity(gun: String) -> int:
	return 8 if gun == "pistol" else 24

func select_item(item: String) -> void:
	if item.is_empty():
		return
	reload_left = 0
	focus = false
	active = item
	if player.guns.has(item):
		player.select_gun(player.guns.find(item))

func _input(event: InputEvent) -> void:
	if not is_instance_valid(player.level):
		return
	if event is InputEventJoypadMotion and absf(event.axis_value) > float(controller_settings.preferences.deadzone):
		pad_device = event.device
		pad_prompts = true
	if event is InputEventJoypadButton and event.pressed:
		pad_device = event.device
		pad_prompts = true
		player.mouse_aim = false
		if handle_pad_button(event.button_index):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and not event.echo:
		if not event.pressed:
			return
		pad_prompts = false
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
		elif key == KEY_Q:
			select_item("blanket")
		elif (key == KEY_6 or key == KEY_G) and has_guitar:
			select_item("guitar")
		elif key == KEY_N:
			show_inventory()
		elif key == KEY_R:
			start_reload()
		elif key == KEY_B:
			next_beat()
		elif key == KEY_T:
			open_local_console()
		else:
			return
		get_viewport().set_input_as_handled()

func handle_pad_button(button: int) -> bool:
	if locked():
		if button == JOY_BUTTON_B or (inventory_open and button in [JOY_BUTTON_TOUCHPAD, JOY_BUTTON_BACK]):
			close_panels()
			return true
		return false
	if player.level.controls_locked() or player.is_dead:
		return false
	match button:
		JOY_BUTTON_A:
			var director := player.level.get_node_or_null("InnerConflict")
			var lore = director.usable_prop() if director != null and player.is_on_floor() else null
			if lore != null:
				director.open_prop(lore)
			elif player.in_hiding_spot or (player.is_on_floor() and "[E]" in player.level.context_hint()):
				player.level.interact()
			else:
				player.pad_jump_queued = true
		JOY_BUTTON_X:
			start_reload()
		JOY_BUTTON_Y:
			select_item("blanket")
		JOY_BUTTON_LEFT_STICK:
			if not controller_settings.preferences.hold_crouch:
				player.pad_crouch = not player.pad_crouch
		JOY_BUTTON_DPAD_LEFT:
			next_beat(-1)
		JOY_BUTTON_DPAD_RIGHT:
			next_beat()
		JOY_BUTTON_DPAD_UP:
			player.level.world_features.think(player.level.z_hint(), "", true)
		JOY_BUTTON_LEFT_SHOULDER:
			cycle_item(-1)
		JOY_BUTTON_RIGHT_SHOULDER:
			cycle_item(1)
		JOY_BUTTON_TOUCHPAD, JOY_BUTTON_BACK:
			show_inventory()
			buttons[0].grab_focus()
		_:
			return false
	return true

func wants_pad_crouch() -> bool:
	if controller_settings.preferences.hold_crouch:
		player.pad_crouch = false
		return pad_device >= 0 and Input.is_joy_button_pressed(pad_device, JOY_BUTTON_LEFT_STICK)
	return player.pad_crouch

func cycle_item(step: int) -> void:
	var items: Array[String] = []
	for item in slots:
		if not item.is_empty() and (item != "remote" or has_remote):
			items.append(item)
	items.append("blanket")
	if has_guitar:
		items.append("guitar")
	var index := items.find(active)
	if index < 0:
		index = -1 if step > 0 else 0
	select_item(items[posmod(index + step, items.size())])

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(player.level) or player.level.controls_locked() or player.is_dead or player.in_hiding_spot:
		return
	if event is InputEventMouseMotion:
		pad_aim = false
		pad_prompts = false
		player.mouse_aim = true
	if event is InputEventMouseButton:
		pad_aim = false
		pad_prompts = false
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
		return
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		if pad_device not in pads:
			pad_device = pads[0]
		var aim := Vector2(Input.get_joy_axis(pad_device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(pad_device, JOY_AXIS_RIGHT_Y))
		var deadzone: float = controller_settings.preferences.deadzone
		if aim.length_squared() > deadzone * deadzone:
			if controller_settings.preferences.invert_aim_y:
				aim.y = -aim.y
			pad_aim = true
			pad_prompts = true
			player.mouse_aim = false
			player.aim_direction = aim.normalized()
	else:
		pad_aim = false
	focus = (focus and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)) or (player.guns.has(active) and Input.is_action_pressed("pad_focus"))
	if active == "c4" and Input.is_action_just_pressed("pad_focus"):
		drop_charge()
	if reload_left > 0:
		reload_left = maxf(0, reload_left - delta)
		if reload_left == 0:
			var amount := mini(capacity(active) - player.ammunition, int(reserves.get(active, 0)))
			player.ammunition += amount
			reserves[active] -= amount
			player.gun_ammo[active] = player.ammunition
	strum_cooldown = maxf(0, strum_cooldown - delta)
	strum_flash = maxf(0, strum_flash - delta)
	progress = 1.0 - reload_left
	if Input.is_action_just_pressed("pad_use") or (active == "smg" and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_pressed("pad_use"))):
		use_item()

func use_item() -> void:
	if reload_left > 0:
		return
	if (player.mouse_aim or pad_aim) and absf(player.aim_direction.x) > 0.01:
		player.facing = signf(player.aim_direction.x)
	match active:
		"blanket": player.toggle_stealth()
		"shank": player.shank()
		"c4": detonate_charges()
		"remote": open_remote()
		"guitar": strum()
		"pistol", "smg": player.fire_gun()

func start_reload() -> void:
	if active not in player.guns or reload_left > 0 or player.ammunition >= capacity(active):
		return
	if reserves.get(active, 0) <= 0:
		player.level.notify("No reserve ammunition.")
		return
	reload_left = 1.0

func collect_guitar() -> void:
	has_guitar = true
	select_item("guitar")

## A strum puts ordinary Keepers in range to sleep for the rest of the floor and can hurt an
## exposed Niro. Strumming on the beat reaches further; missing the beat is never punished.
func strum() -> int:
	if not has_guitar or strum_cooldown > 0:
		return -1
	strum_cooldown = 0.55
	strum_flash = 0.35
	var on_beat: bool = get_node("/root/MusicDirector").is_on_beat(0.12)
	var radius := STRUM_RADIUS_ON_BEAT if on_beat else STRUM_RADIUS
	strum_visual_reach = radius
	var affected := 0
	get_node("/root/SoundFX").play_sound("sigil", -14, 1.6 if on_beat else 1.3)
	player.level.emit_effect("hit", player.global_position + Vector2(0, -8))
	for guard in player.level.guards():
		if guard.is_dead or guard.global_position.distance_to(player.global_position) > radius:
			continue
		if not player.level.clear_sight(player.global_position + Vector2(0, -8), guard.global_position + Vector2(0, -8)):
			continue
		if guard.has_method("begin_recovery"):
			if guard.is_vulnerable:
				guard.take_damage(1)
				affected += 1
		elif not guard.asleep:
			guard.fall_asleep()
			affected += 1
	for turret in get_tree().get_nodes_in_group("tower_turrets"):
		var point: Vector2 = turret.target_point()
		var origin := player.global_position + Vector2(0, -8)
		if point.distance_to(origin) <= radius and player.level.clear_sight(origin, point):
			turret.stun()
	if on_beat:
		player.level.notify("On the beat. The song carries further.", 1.5)
	return affected

func collect_ammo_case() -> bool:
	if player.guns.is_empty() and not player.has_gun:
		player.level.notify("Ammunition. Useless without a gun; leave it for now.")
		return false
	var gun: String = player.equipped_gun
	reserves[gun] = reserves.get(gun, 0) + capacity(gun)
	# The case also holds a field dressing: one full heart.
	player.health = mini(player.max_health, player.health + 2)
	player.level.notify("Ammunition case: +%d %s rounds, and a full heart" % [capacity(gun), gun])
	return true

## [B] or "next" on the remote: skip to the next unlocked beat on Miro's MP3, then back to the floor.
func next_beat(step := 1) -> String:
	var campaign = get_node("/root/Campaign")
	var music = get_node("/root/MusicDirector")
	var text := ""
	if not has_remote:
		text = "No player on me."
	elif not remote_unlocked and not local_console:
		text = "The MP3 is locked. Open the remote [5] and type hack."
	else:
		var unlocked: Array = campaign.unlocked_tracks()
		var position: int = unlocked.find(music.track_id) if music.review_override else -1
		if unlocked.is_empty():
			text = "Only the floor's beat on here. Quiet floors and fights unlock more."
		elif posmod(position + 1 + step, unlocked.size() + 1) == 0:
			music.resume_floor()
			text = "MP3 · back to the floor's beat."
		else:
			var index := posmod(position + 1 + step, unlocked.size() + 1) - 1
			music.review_override = true
			music.play_track(unlocked[index])
			text = "MP3 · %d/%d %s" % [index + 1, unlocked.size(), music.catalog[unlocked[index]].title]
	if is_instance_valid(player.level):
		player.level.notify(text, 3)
	return text

func collect_remote() -> void:
	if has_remote:
		return
	has_remote = true
	get_node("/root/Campaign").remote_owned = true
	if player.level.get("hud"):
		player.level.hud.add_child(preload("res://scripts/remote_pickup_card.gd").new())
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
	var header := HBoxContainer.new()
	remote_box.add_child(header)
	console_icon = TextureRect.new()
	console_icon.custom_minimum_size = Vector2(24, 24)
	console_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	console_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(console_icon)
	console_title = Label.new()
	header.add_child(console_title)
	console_echo = Label.new()
	var console_font := SystemFont.new()
	console_font.font_names = PackedStringArray(["Menlo", "Consolas", "DejaVu Sans Mono"])
	console_echo.add_theme_font_override("font", console_font)
	console_echo.add_theme_font_size_override("font_size", 11)
	console_echo.add_theme_color_override("font_color", Color("a4d6bc"))
	console_echo.clip_text = true
	remote_box.add_child(console_echo)
	output = Label.new()
	output.custom_minimum_size = Vector2(460, 100)
	output.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	output.add_theme_font_size_override("font_size", 12)
	remote_box.add_child(output)
	command = LineEdit.new()
	command.placeholder_text = "miro@player:~$ help"
	command.add_theme_font_override("font", console_font)
	command.add_theme_font_size_override("font_size", 12)
	command.max_length = 120
	command.secret_character = "*"
	command.text_changed.connect(func(value: String):
		command.secret = not value.is_empty() and (command.secret or value.strip_edges().begins_with("login ")))
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
	local_console = false
	panel.hide()
	remote_panel.hide()
	swap_from = -1

func open_remote(at_port := false) -> void:
	if not has_remote:
		player.level.notify("Judas, the first Keeper, carries an MP3 player. Loot or pickpocket him.")
		return
	show_console(false, at_port)

func open_local_console() -> void:
	if player.level.world_features.security_terminal() == null:
		player.level.notify("Get within reach of a records or checkpoint terminal. [T]")
		return
	show_console(true)

## `terminal_look`: a service port presents as a plain tower terminal, like the records ones.
func show_console(local: bool, terminal_look := false) -> void:
	local_console = local
	var as_terminal := local or terminal_look
	remote_open = true
	remote_panel.show()
	console_title.text = "TOWER SECURITY TERMINAL" if as_terminal else "KEEPER MP3 · SERVICE CONSOLE"
	console_icon.texture = preload("res://assets/library/terminal.png") if as_terminal else preload("res://assets/weapons/remote.svg")
	console_echo.text = ""
	output.text = "Type help for commands." if local or remote_unlocked else "A script in your handwriting: unlock.sh. Type hack."
	command.placeholder_text = "tower@local:~$ help" if as_terminal else "miro@player:~$ help"
	command.clear()
	command.secret = false
	command.grab_focus()

## A tiny pretend file system: each floor's records are readable text files (ls, cat).
var above_floor := false
var pager: Array = []
var pager_index := 0

func floor_files() -> Dictionary:
	var files := {}
	var floor_number: int = get_node("/root/Campaign").current_floor
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/terminal_logs.json"))
	for entry in data.get("terminals", []):
		if int(entry.get("floor", 0)) != floor_number:
			continue
		var name := str(entry.file).to_lower().replace(" ", "_")
		var clean := ""
		for character in name:
			if character.is_valid_identifier() or character == "_" or (character >= "0" and character <= "9"):
				clean += character
		files[clean + ".txt"] = "

".join(PackedStringArray(entry.get("pages", [])))
	files["readme.txt"] = "TOWER RECORDS TERMINAL
Floor %02d archive. Access is logged. Type ls to list files, cat <file> to read one." % floor_number
	return files

func show_page() -> void:
	output.text = str(pager[pager_index])
	if pager_index < pager.size() - 1:
		output.text += "
-- more (press Enter) --"
	pager_index += 1

func run_command(raw: String) -> void:
	var text := raw.strip_edges()
	if text.is_empty() and pager_index > 0 and pager_index < pager.size():
		command.clear()
		show_page()
		return
	pager.clear()
	pager_index = 0
	var is_login := text.begins_with("login ")
	var echo := "login " + "*".repeat(text.trim_prefix("login ").length()) if is_login else ("***" if command.secret else text)
	console_echo.text = "> " + echo
	command.clear()
	command.secret = false
	if local_console and (text in ["hack", "./unlock.sh", "lights test", "music"] or text.begins_with("play ")):
		output.text = "Unknown command. Type help."
		return
	if text == "whoami":
		var terminal: Node2D = player.level.world_features.security_terminal()
		output.text = "root" if terminal != null and logged_in.has(terminal.get_instance_id()) else "guest"
		return
	var floor_dir := "floor%02d" % int(get_node("/root/Campaign").current_floor)
	if text == "pwd":
		output.text = "/var/tower" if above_floor else "/var/tower/" + floor_dir
		return
	if text == "cd .." or text == "cd ../" or text == "cd /":
		above_floor = true
		return
	if text == "cd" or text == "cd ~" or text == "cd " + floor_dir or text == "cd " + floor_dir + "/" or text == "cd ./" + floor_dir:
		above_floor = false
		return
	if text.begins_with("cd "):
		output.text = "cd: %s: No such file or directory" % text.trim_prefix("cd ").strip_edges()
		return
	if text == "ls":
		output.text = (floor_dir + "/") if above_floor else "  ".join(PackedStringArray(floor_files().keys()))
		return
	if text.begins_with("cat ") and above_floor:
		output.text = "cat: %s: No such file or directory" % text.trim_prefix("cat ").strip_edges()
		return
	if text.begins_with("cat "):
		var name := text.trim_prefix("cat ").strip_edges()
		var files := floor_files()
		if not files.has(name):
			output.text = "cat: %s: No such file or directory" % name
			return
		# Long files page through the console one screen at a time.
		pager = str(files[name]).split("

")
		pager_index = 0
		show_page()
		return
	if text == "hack" or text == "./unlock.sh":
		remote_unlocked = true
		get_node("/root/Campaign").remote_unlocked = true
		output.text = "Service mode unlocked. Your scripts survived.\nMP3 playback active. Type help."
	elif not remote_unlocked and not local_console:
		output.text = "Service port locked. Type hack to run your unlock script."
	elif text == "help":
		output.text = "scan · login <password> · ls · cat <file> · pwd · whoami · cameras off · turrets off · next"
	elif text == "next":
		output.text = next_beat()
	elif text == "music":
		var unlocked: Array = get_node("/root/Campaign").unlocked_tracks()
		var listing := "MP3 · 0. floor soundtrack"
		for index in range(unlocked.size()):
			listing += "\n%d. %s" % [index + 1, get_node("/root/MusicDirector").catalog[unlocked[index]].title]
		output.text = listing + ("\nType play <number>." if not unlocked.is_empty() else "\nUnseen floors unlock more tracks.")
	elif text.begins_with("play "):
		var unlocked: Array = get_node("/root/Campaign").unlocked_tracks()
		var index := text.trim_prefix("play ").to_int()
		var music = get_node("/root/MusicDirector")
		if index == 0:
			music.resume_floor()
			output.text = "Back to the floor soundtrack."
		elif index >= 1 and index <= unlocked.size():
			music.review_override = true
			music.play_track(unlocked[index - 1])
			output.text = "Now playing: " + music.catalog[unlocked[index - 1]].title
		else:
			output.text = "No track %d. Type music to list them." % index
	elif text == "scan":
		var terminal: Node2D = player.level.world_features.security_terminal()
		if at_checkpoint():
			output.text = "checkpoint.local · linked cameras and floor turrets · login required"
		elif terminal != null:
			output.text = "records.local · floor turret controls · login required"
		elif at_early_port():
			output.text = "service.local · maintenance account\nSticker: user root · password root\n" + ("Practice lamp: lights test" if get_node("/root/Campaign").current_floor == 1 else "Optional corridor camera: cameras off")
		else:
			output.text = "No writable access point in range."
	elif is_login:
		var terminal: Node2D = player.level.world_features.security_terminal()
		if terminal == null and not at_checkpoint() and not at_early_port():
			output.text = "No local connection. Move beside an access point."
		elif text != "login root":
			output.text = "Access denied. Password is case-sensitive."
		else:
			if at_early_port():
				player.level.world_features.early_authenticated = true
			if at_checkpoint():
				player.level.world_features.terminal_authenticated = true
			if terminal != null:
				logged_in[terminal.get_instance_id()] = true
			output.text = "Authenticated."
	elif text == "turrets off":
		var terminal: Node2D = player.level.world_features.security_terminal()
		if terminal == null or (not logged_in.has(terminal.get_instance_id()) and not (at_checkpoint() and player.level.world_features.terminal_authenticated)):
			output.text = "Stay at an authenticated terminal: login <password>"
			return
		var count: int = player.level.world_features.disable_turrets()
		output.text = "Turrets disabled on this floor: %d" % count if count > 0 else "No active turrets on this floor."
	elif text == "lights test":
		if at_early_port() and player.level.world_features.early_authenticated:
			player.level.emit_effect("hit", player.level.world_features.access_point)
			output.text = "Service lamp blinked. Your script works.\nOn the next floor, try cameras off at a service port."
		else:
			output.text = "Connect at the service port and login root first."
	elif text == "cameras off":
		if at_early_port() and player.level.world_features.early_authenticated and is_instance_valid(player.level.world_features.practice_camera):
			player.level.world_features.practice_camera.disable()
			output.text = "Corridor camera disabled."
			return
		if at_checkpoint() and player.level.world_features.terminal_authenticated:
			close_panels()
			player.level.hack_remaining = 1.0
			return
		# Any records terminal you've logged into controls this floor's cameras too.
		var terminal: Node2D = player.level.world_features.security_terminal()
		if terminal != null and logged_in.has(terminal.get_instance_id()):
			var count: int = player.level.world_features.disable_cameras()
			output.text = "Cameras disabled on this floor: %d" % count if count > 0 else "No active cameras on this floor."
		else:
			output.text = "Connect locally and authenticate first: login <password>"
	else:
		output.text = "Unknown command. Type help."

func at_early_port() -> bool:
	return get_node("/root/Campaign").current_floor in [1, 2] and player.level.world_features.reachable(player.level.world_features.access_point, 48)

func at_checkpoint() -> bool:
	return get_node("/root/Campaign").current_floor == 3 and player.level.world_features.reachable(player.level.areas.get_node("RemoteTerminal").global_position, 48)

const THROW_SPEED := 190.0
const BLAST_RADIUS := 130.0

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
	# Every floor gives three charges to use freely (story supports keep their own). Out of
	# them, the floor hands over a spare, one at a time, so a stuck player always has one.
	var spare := player.c4_count <= reserve
	if spare:
		if planted.any(func(placed): return is_instance_valid(placed)):
			player.level.notify("Out of C4. Detonate or recover the charge you placed first.")
			return
		player.level.notify("Out of C4. A spare charge turns up in your pack.")
	var charge := Node2D.new()
	charge.set_script(preload("res://scripts/dropped_charge.gd"))
	charge.position = player.position + Vector2(0, -6)
	# A short lunge toward the aim (mouse or right stick), or forward and a little up.
	var direction: Vector2 = player.aim_direction if (player.mouse_aim or pad_aim) else Vector2(player.facing, 0)
	charge.velocity = (direction.normalized() + Vector2(0, -0.35)).normalized() * THROW_SPEED
	player.level.add_child(charge)
	planted.append(charge)
	if not spare:
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
	if planted.any(func(charge): return is_instance_valid(charge)):
		# No control change: left click detonates, and the remote shows the signal going out.
		var popup := Control.new()
		popup.set_script(preload("res://scripts/remote_screen.gd"))
		player.level.hud.add_child(popup)
	for charge in planted:
		if not is_instance_valid(charge):
			continue
		var point := charge.global_position
		player.level.emit_effect("breach", point)
		player.level.make_noise(point, 700)
		get_node("/root/SoundFX").play_sound("collapse", -20)
		if get_node("/root/Campaign").current_floor == 1 and not player.level.door_open and point.distance_to(player.level.get_node("Interactables/CellLock").global_position) < 100:
			player.level.route = "C4 breach"
			player.level.open_door()
		for guard in player.level.guards():
			if guard.global_position.distance_to(point) < BLAST_RADIUS and player.level.clear_sight(point, guard.global_position):
				guard.take_damage(16, true)
		# One charge is enough for a turret: stuck to it, or anywhere in the blast.
		for turret in get_tree().get_nodes_in_group("tower_turrets"):
			if not is_instance_valid(turret) or turret.health <= 0:
				continue
			if charge.attached == turret or (turret.target_point().distance_to(point) < BLAST_RADIUS and player.level.clear_sight(point, turret.target_point())):
				turret.health = 1
				turret.take_turret_hit()
		charge.queue_free()
	planted.clear()
