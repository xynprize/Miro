extends Node
## Unified item selection, reload and inventory modal.
var player: IntroPlayer
var slots: Array[String] = ["", "", "c4", "shank"]
var layout: Array[String] = []
var active := "shank"
var inventory_open := false
var remote_open := false
var local_console := false
var security_session: Node

func security() -> Node:
	if security_session == null:
		security_session = preload("res://scripts/security_session.gd").new()
		add_child(security_session)
		security_session.setup(self)
	return security_session

func watching_cameras() -> bool:
	return is_instance_valid(security_session) and security_session.viewing
## Records terminals Miro has logged into on this floor: one login per terminal, kept after closing it.
var logged_in: Dictionary = {}
var console_title: Label
var console_icon: TextureRect
var console_echo: Label
var has_remote := false
var smg_achievement_checked := false
var remote_unlocked := false
var focus := false
var block_feedback_left := 0.0
var pad_aim := false
var pad_device := -1
var _pad_prompts := false
var pad_prompts: bool:
	get:
		return controller_settings.using_controller if is_instance_valid(controller_settings) else _pad_prompts
	set(value):
		_pad_prompts = value
		if is_instance_valid(controller_settings):
			controller_settings.using_controller = value
var controller_settings: Node
var reserves: Dictionary = {}
var reload_left := 0.0
var guitar_button: Button
var inventory_title: Label
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
var melee_left := 0.0
var held_buttons: Dictionary = {}
const HOLD_SECONDS := 0.35
var strum_cooldown := 0.0
var strum_flash := 0.0
var strum_direction := Vector2.RIGHT
var strum_visual_reach := 120.0
const STRUM_RADIUS := 120.0
const STRUM_RADIUS_ON_BEAT := 170.0

func _ready() -> void:
	player = get_parent()
	camera_base_zoom = player.get_node("Camera2D").zoom
	controller_settings = get_node("/root/ControllerSettings")
	Input.joy_connection_changed.connect(on_pad_connection)
	layout.assign(get_node("/root/Campaign").inventory_layout)

func on_pad_connection(device: int, connected: bool) -> void:
	if not connected and device == pad_device:
		var pads := Input.get_connected_joypads()
		pad_device = pads[0] if not pads.is_empty() else -1
		pad_aim = false
		pad_prompts = not pads.is_empty()
		player.pad_crouch = false

func locked() -> bool:
	return inventory_open or remote_open

func normalize_layout() -> void:
	var result: Array[String] = []
	for token in layout:
		if layout.size() == 5 and token == "shank": continue
		var item: String = str(token)
		if item in ["gun_1", "gun_2"]:
			var index := 0 if item == "gun_1" else 1
			item = player.guns[index] if player.guns.size() > index else ("pistol" if index == 0 else "smg")
		if item == "guitar": item = "pistol"
		if item in ["pistol", "smg", "c4", "shank"] and item not in result: result.append(item)
	for item in ["pistol", "smg", "c4", "shank"]:
		if item not in result: result.append(item)
	layout.assign(result)
	get_node("/root/Campaign").inventory_layout.assign(layout)

func sync_slots() -> void:
	normalize_layout()
	for i in range(4):
		var item: String = layout[i]
		slots[i] = "guitar" if item == "pistol" and has_guitar else (item if item in ["c4","shank"] or item in player.guns else "")
	for gun in player.guns:
		if gun == "smg" and not smg_achievement_checked:
			smg_achievement_checked = true
			get_node("/root/Campaign").unlock_achievement("acquire_smg")
		if not reserves.has(gun): reserves[gun] = capacity(gun) if gun == "smg" else capacity(gun) * 2
	if active not in slots and active not in ["shank", "blanket", "remote"]: active = "c4"

func capacity(gun: String) -> int:
	return 8 if gun == "pistol" else 24

## The last floor takes the blanket away: Q is the guitar there.
func blanket_removed() -> bool:
	return false

func select_slot(index: int) -> void:
	if slots[index].is_empty():
		player.level.notify("No loaded weapon. A fallen Keeper may carry one.")
		return
	select_item(slots[index])

func select_item(item: String) -> void:
	if item.is_empty() or (item == "guitar" and not has_guitar):
		return
	reload_left = 0
	focus = false
	active = item
	if player.guns.has(item):
		player.select_gun(player.guns.find(item))

func gameplay_ready() -> bool:
	return is_instance_valid(player.level) and not watching_cameras() and not get_tree().paused and (DisplayServer.get_name() == "headless" or DisplayServer.window_is_focused()) and not locked() and not player.level.controls_locked() and not player.is_dead and not player.in_hiding_spot and not player.level.world_features.strangle_active()

func direct_melee() -> void:
	if not gameplay_ready() or melee_left > 0: return
	reload_left = 0
	focus = false
	player.attack_cooldown = 0
	player.shank()
	melee_left = 0.5

func direct_blanket() -> void:
	if gameplay_ready(): player.toggle_stealth()

func _input(event: InputEvent) -> void:
	if not is_instance_valid(player.level): return
	if watching_cameras():
		security_session.handle_input(event)
		return
	if event is InputEventJoypadMotion and absf(event.axis_value) > float(controller_settings.preferences.deadzone):
		pad_device = event.device
		pad_prompts = true
	if event is InputEventJoypadButton:
		var button: int = get_node("/root/InputBindings").canonical_pad(event.button_index)
		pad_device = event.device
		pad_prompts = true
		if not event.pressed:
			if held_buttons.has(button):
				var held: float = held_buttons[button]
				held_buttons.erase(button)
				if held >= 0 and gameplay_ready():
					if button == JOY_BUTTON_Y: cycle_item(1)
					elif button == JOY_BUTTON_DPAD_DOWN: open_remote()
				get_viewport().set_input_as_handled()
			return
		player.mouse_aim = false
		if inventory_open and handle_inventory_button(event.button_index):
			get_viewport().set_input_as_handled()
			return
		if gameplay_ready() and button in [JOY_BUTTON_Y, JOY_BUTTON_DPAD_DOWN]:
			held_buttons[button] = 0.0
			get_viewport().set_input_as_handled()
		elif handle_pad_button(button): get_viewport().set_input_as_handled()
		return
	if (event is InputEventKey and not event.echo) or event is InputEventMouseButton:
		if not event.pressed: return
		pad_prompts = false
		var key: int = get_node("/root/InputBindings").canonical_key(event)
		if locked():
			if key == KEY_ESCAPE or (key == KEY_N and inventory_open): close_panels()
			return
		if not gameplay_ready(): return
		if key >= KEY_1 and key <= KEY_4: select_slot(key - KEY_1)
		elif key == KEY_Q: direct_blanket()
		elif key == KEY_F: direct_melee()
		elif key == KEY_X: open_remote()
		elif key == KEY_G and has_guitar: select_item("guitar")
		elif key == KEY_N: show_inventory()
		elif key == KEY_R: start_reload()
		elif key == KEY_B: next_beat()
		elif key == KEY_V: next_beat(-1)
		elif key == KEY_H: shuffle_beats()
		elif key == KEY_T: open_local_console()
		else: return
		get_viewport().set_input_as_handled()

func handle_inventory_button(button: int) -> bool:
	if not inventory_open:return false
	if button in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
		var step := -1 if button in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_UP] else 1
		var index := buttons.find(get_viewport().gui_get_focus_owner())
		if index < 0:index = -1 if step > 0 else 0
		buttons[posmod(index + step, buttons.size())].grab_focus()
		return true
	if button == JOY_BUTTON_A:
		var focused := get_viewport().gui_get_focus_owner()
		if focused in buttons:
			focused.pressed.emit()
			return true
	return false

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
			var terminal := connection_target(36.0, true)
			var checkpoint: Node2D = player.level.areas.get_node_or_null("RemoteTerminal")
			if player.is_on_floor() and terminal != null and terminal != checkpoint and terminal.global_position.distance_to(player.global_position) <= player.level.world_features.story_distance():
				open_local_console()
				return true
			var director := player.level.get_node_or_null("InnerConflict")
			var lore = director.usable_prop() if director != null and player.is_on_floor() else null
			if lore != null:
				director.open_prop(lore)
			elif player.in_hiding_spot or (player.is_on_floor() and "[E]" in player.level.context_hint()):
				player.level.world_features.next_strangle_requires_hold = true
				player.level.interact()
				player.level.world_features.next_strangle_requires_hold = false
			else:
				player.pad_jump_queued = true
		JOY_BUTTON_X:
			start_reload()
		JOY_BUTTON_Y:
			cycle_item(1)
		JOY_BUTTON_LEFT_STICK:
			if not controller_settings.preferences.hold_crouch:
				player.pad_crouch = not player.pad_crouch
		JOY_BUTTON_DPAD_LEFT:
			next_beat(-1)
		JOY_BUTTON_DPAD_RIGHT:
			next_beat()
		JOY_BUTTON_DPAD_DOWN:
			shuffle_beats()
		JOY_BUTTON_DPAD_UP:
			player.level.world_features.think(player.level.z_hint(), "", true)
		JOY_BUTTON_LEFT_SHOULDER:
			direct_blanket()
		JOY_BUTTON_RIGHT_SHOULDER:
			direct_melee()
		JOY_BUTTON_TOUCHPAD, JOY_BUTTON_BACK:
			show_inventory()
			buttons[0].grab_focus()
		_:
			return false
	return true

func wants_pad_crouch() -> bool:
	if controller_settings.preferences.hold_crouch:
		player.pad_crouch = false
		return pad_device >= 0 and Input.is_joy_button_pressed(pad_device, get_node("/root/InputBindings").pad_button(JOY_BUTTON_LEFT_STICK))
	return player.pad_crouch

func wants_quiet_modifier() -> bool:
	return Input.is_action_pressed("slow_walk") or (pad_device >= 0 and Input.is_joy_button_pressed(pad_device, get_node("/root/InputBindings").pad_button(JOY_BUTTON_RIGHT_STICK)))

func cycle_item(step: int) -> void:
	var items: Array[String] = []
	for item in slots:
		if item in ["pistol", "smg", "guitar", "shank"]: items.append(item)
	if items.is_empty(): return
	var index := items.find(active)
	if index < 0: index = -1 if step > 0 else 0
	select_item(items[posmod(index + step, items.size())])

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(player.level) or player.level.controls_locked() or player.is_dead or player.in_hiding_spot or player.level.world_features.strangle_active():
		return
	if event is InputEventMouseMotion and event.relative.length() > 3:
		pad_aim = false
		pad_prompts = false
		player.mouse_aim = true
	if (event is InputEventKey or event is InputEventMouseButton) and (get_node("/root/InputBindings").matches(event, "use_item") or get_node("/root/InputBindings").matches(event, "focus_item")):
		pad_aim = false
		pad_prompts = false
		player.mouse_aim = true
		if get_node("/root/InputBindings").matches(event, "use_item") and event.pressed:
			use_item()
		elif get_node("/root/InputBindings").matches(event, "focus_item"):
			focus = event.pressed and active != "c4"
			if event.pressed and active == "c4":
				drop_charge()
		else:
			return
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player.level):
		return
	var camera: Camera2D = player.get_node("Camera2D")
	var ads: bool = focus and player.guns.has(active) and gameplay_ready()
	if not is_instance_valid(player.level.card) or player.level.card.mode != "floor":
		camera.zoom = camera.zoom.lerp(camera_base_zoom * (1.08 if ads else 1.0), 1.0 - exp(-12.0 * delta))
	update_mouse_cursor()
	melee_left = maxf(0, melee_left - delta)
	if not gameplay_ready(): held_buttons.clear()
	else:
		for button in held_buttons.keys():
			if held_buttons[button] < 0: continue
			held_buttons[button] += delta
			if held_buttons[button] >= HOLD_SECONDS:
				held_buttons[button] = -1.0
				if button == JOY_BUTTON_Y: select_item("c4")
				elif button == JOY_BUTTON_DPAD_DOWN: shuffle_beats()
	sync_slots()
	if inventory_open:
		refresh_slots()
	if panel == null and is_instance_valid(player.level.hud):
		build_panels()
	if watching_cameras() or player.level.controls_locked() or player.is_dead or player.in_hiding_spot or player.level.world_features.strangle_active():
		focus = false
		reload_left = 0
		return
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		if pad_device not in pads:
			pad_device = pads[0]
		update_pad_aim(Vector2(Input.get_joy_axis(pad_device, (JOY_AXIS_LEFT_X if get_node("/root/InputBindings").preset == "Southpaw" else JOY_AXIS_RIGHT_X)), Input.get_joy_axis(pad_device, (JOY_AXIS_LEFT_Y if get_node("/root/InputBindings").preset == "Southpaw" else JOY_AXIS_RIGHT_Y))))
	else:
		pad_aim = false
	focus = (focus and Input.is_action_pressed("focus_item")) or ((player.guns.has(active) or active == "guitar") and Input.is_action_pressed("pad_focus"))
	update_mouse_cursor()
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
	if Input.is_action_just_pressed("pad_use") or (active == "smg" and (Input.is_action_pressed("use_item") or Input.is_action_pressed("pad_use"))):
		use_item()

func use_item() -> void:
	if reload_left > 0 or melee_left > 0:
		return
	if (player.mouse_aim or pad_aim) and absf(player.aim_direction.x) > 0.01:
		player.facing = signf(player.aim_direction.x)
	match active:
		"blanket":
			if not blanket_removed():
				player.toggle_stealth()
		"shank": direct_melee()
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
	if get_node("/root/Campaign").unlock_achievement("guitar_acquired"):
		get_node("/root/Campaign").add_track_unlock("shit_crashed")
	sync_slots()
	select_item("guitar")

## A strum puts ordinary Keepers in range to sleep for the rest of the floor and can hurt an
## exposed Niro. Strumming on the beat reaches further; missing the beat is never punished.
func guitar_guarding() -> bool:
	return has_guitar and active == "guitar" and focus and gameplay_ready()

func block_melee(attacker: Vector2) -> bool:
	var direction := player.weapon_aim_direction()
	if not guitar_guarding() or (attacker - player.global_position).dot(direction) < -4.0:
		return false
	if block_feedback_left <= 0.0:
		block_feedback_left = 0.2
		get_node("/root/SoundFX").play_sound("swing", -18, 0.7)
		player.level.emit_effect("hit", player.global_position + direction * 12 + Vector2(0,-8))
	return true

func strum() -> int:
	if not has_guitar or strum_cooldown > 0:
		return -1
	strum_cooldown = 0.55
	strum_flash = 0.35
	strum_direction = player.weapon_aim_direction()
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
	var amount: int = get_node("/root/Campaign").ammo_amount(12 if gun == "smg" else capacity(gun))
	reserves[gun] = reserves.get(gun, 0) + amount
	# The case also holds a field dressing: one full heart.
	player.health = mini(player.max_health, player.health + 2)
	player.level.notify("Ammunition case: +%d %s rounds, and a full heart" % [amount, gun])
	return true

## [B] or "next" on the remote: skip to the next unlocked beat on Miro's MP3, then back to the floor.
func next_beat(step := 1) -> String:
	var campaign = get_node("/root/Campaign")
	var music = get_node("/root/MusicDirector")
	var text := ""
	music.cancel_shuffle()
	if not has_remote:
		text = "No player on me."
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
			text = "MP3 · %d/%d %s" % [index + 1, unlocked.size(), campaign.track_title(str(unlocked[index]))]
	if is_instance_valid(player.level):
		player.level.notify(text, 3)
	return text

func shuffle_beats() -> String:
	var music = get_node("/root/MusicDirector")
	var text: String = "No player on me." if not has_remote else music.toggle_shuffle()
	if is_instance_valid(player.level):player.level.notify(text, 4.0)
	return text

func collect_remote() -> void:
	if has_remote:
		return
	has_remote = true
	get_node("/root/Campaign").remote_owned = true
	if player.level.get("hud"):
		player.level.hud.add_child(preload("res://scripts/remote_pickup_card.gd").new())
	player.level.notify("Taken: Keeper MP3 player. [X] opens wireless hacking.", 8)

func build_panels() -> void:
	panel = player.level.panel_at(Vector2(70, 115), Vector2(500, 150))
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	inventory_title = title
	title.text = "INVENTORY · Drag or click two weapon slots to swap"
	title.add_theme_font_size_override("font_size", 12)
	box.add_child(title)
	var row := HBoxContainer.new()
	box.add_child(row)
	for i in range(4):
		var button := Button.new()
		button.custom_minimum_size = Vector2(72, 45)
		button.add_theme_font_size_override("font_size", 11)
		button.set_script(preload("res://scripts/inventory_slot.gd"))
		button.controls = self
		button.slot_index = i
		row.add_child(button)
		buttons.append(button)
	guitar_button = Button.new()
	guitar_button.name = "GuitarItem"
	guitar_button.text = "Guitar"
	guitar_button.icon = preload("res://scripts/weapon_art.gd").TEXTURES.guitar
	guitar_button.expand_icon = true
	guitar_button.add_theme_constant_override("icon_max_width", 20)
	guitar_button.custom_minimum_size = Vector2(72, 45)
	guitar_button.pressed.connect(func(): select_item("guitar"); close_panels())
	row.add_child(guitar_button)
	guitar_button.visible = false
	var close := Button.new()
	controller_settings.bind_prompt(close, "Done [N / Esc]")
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
	# Enter must not drop the cursor: keep editing after each command (no re-clicking the box).
	command.keep_editing_on_text_submit = true
	command.text_changed.connect(func(value: String):
		command.secret = not value.is_empty() and (command.secret or value.strip_edges().begins_with("login ")))
	command.text_submitted.connect(run_command)
	remote_box.add_child(command)
	var done := Button.new()
	controller_settings.bind_prompt(done, "Close terminal [Esc]")
	done.pressed.connect(close_panels)
	remote_box.add_child(done)
	remote_panel.hide()

func show_inventory() -> void:
	held_buttons.clear()
	inventory_open = true
	panel.show()
	refresh_slots()

func refresh_slots() -> void:
	if is_instance_valid(guitar_button):
		guitar_button.visible = false
	if is_instance_valid(inventory_title):
		var item := "blanket"
		inventory_title.text = controller_settings.controller_text("INVENTORY · R1/D-pad navigate · Cross pick/swap · L1 " + item, controller_settings.playstation()) if pad_prompts else ("INVENTORY · Drag or click to swap · " + get_node("/root/InputBindings").label("blanket") + " " + item)
	for i in range(4):
		buttons[i].text = "%s\n%s%s" % [get_node("/root/InputBindings").label("slot_%d" % (i + 1)), slots[i] if not slots[i].is_empty() else "empty", " *" if swap_from == i else ""]

func swap_slot(index: int) -> void:
	if swap_from < 0:
		swap_from = index
	else:
		var item := layout[index]
		layout[index] = layout[swap_from]
		layout[swap_from] = item
		var campaign = get_node("/root/Campaign")
		campaign.inventory_layout.assign(layout)
		if campaign.checkpoint.get("floor",0)==campaign.current_floor and campaign.checkpoint.has("player"):
			campaign.checkpoint.player["layout"] = Array(layout)
			campaign.save_checkpoint()
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
	held_buttons.clear()
	if at_port:
		show_console(true, true)
		return
	if not has_remote:
		player.level.notify("Judas, the first Keeper, carries an MP3 player. Loot or pickpocket him.")
		return
	show_console(false, at_port)

func open_local_console() -> void:
	if connection_target(48.0, true) == null:
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
	if not local:
		var target := connection_target()
		output.text += "\nNearby signal: " + connection_name(target) + ". Type scan." if target != null else "\nNo terminal signal nearby."

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

## Reading the same archive via the console counts just like reading its physical terminal.
func record_terminal_read(contents: String) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/terminal_logs.json"))
	for entry in data.get("terminals", []):
		if int(entry.get("floor",0)) != get_node("/root/Campaign").current_floor:continue
		if "\n\n".join(PackedStringArray(entry.get("pages",[]))) != contents:continue
		get_node("/root/PlayerBehavior").record("lore_"+str(entry.id), "seeker", 2, "lore", 2)
		for terminal in get_tree().get_nodes_in_group("security_terminals"):
			if terminal.get_script()==preload("res://scripts/lore_terminal.gd") and terminal.log_entry.id==entry.id:terminal.read=true

func show_page() -> void:
	output.text = str(pager[pager_index])
	if pager_index < pager.size() - 1:
		output.text += controller_settings.prompt("\n-- more (press Enter) --")
	pager_index += 1

func run_command(raw: String) -> void:
	var text := raw.strip_edges()
	if text in ["cameras hack", "cameras watch", "cameras on", "turrets on", "turrets hack", "cameras off", "turrets off"]:
		output.text = security().execute(text)
		command.clear()
		return
	if text.is_empty() and pager_index > 0 and pager_index < pager.size():
		command.clear()
		show_page()
		return
	pager.clear()
	pager_index = 0
	# Whatever the command, the text box keeps (or regains) focus once it has run.
	command.call_deferred("grab_focus")
	var is_login := text.begins_with("login ")
	var echo := "login " + "*".repeat(text.trim_prefix("login ").length()) if is_login else ("***" if command.secret else text)
	console_echo.text = "> " + echo
	command.clear()
	command.secret = false
	# Track terminal commands for achievements (non-empty, non-paging commands)
	if not text.is_empty():
		var campaign_node = get_node("/root/Campaign")
		campaign_node.on_terminal_command(text)
	if local_console and (text in ["hack", "./unlock.sh", "lights test", "music"] or text.begins_with("play ")):
		output.text = "Unknown command. Type help."
		return
	if text == "whoami":
		var terminal: Node2D = connected_terminal()
		output.text = "root" if (terminal != null and logged_in.has(terminal.get_instance_id())) or (at_early_port() and player.level.world_features.early_authenticated) or (at_checkpoint() and player.level.world_features.terminal_authenticated) else "guest"
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
		record_terminal_read(str(files[name]))
		# Long files page through the console one screen at a time.
		pager = str(files[name]).split("

")
		pager_index = 0
		show_page()
		return
	if text == "hack" or text == "./unlock.sh":
		remote_unlocked = true
		get_node("/root/Campaign").remote_unlocked = true
		output.text = "Service mode unlocked. Your scripts survived.\nMP3 playback active. Type scan to find a nearby terminal."
	elif not remote_unlocked and not local_console:
		output.text = "Service port locked. Type hack to run your unlock script."
	elif text == "help":
		output.text = "scan · login <password> · ls · cat <file> · cameras off/on/watch · turrets off/on · next" + ("\nMP3: cameras hack · turrets hack (1.5s, cooldown 10s)" if not local_console else "")
	elif text == "next":
		output.text = next_beat()
	elif text == "music":
		var unlocked: Array = get_node("/root/Campaign").unlocked_tracks()
		var listing := "MP3 · [V] Previous · [B] Next · [H] Shuffle\n0. floor soundtrack"
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
			output.text = "Now playing: " + get_node("/root/Campaign").track_title(str(unlocked[index - 1]))
		else:
			output.text = "No track %d. Type music to list them." % index
	elif text == "scan":
		var terminal: Node2D = connected_terminal()
		if at_checkpoint():
			output.text = "checkpoint.local · floor %d · login required\nCameras on this floor: cameras off\nTurrets on this floor: turrets off" % (player.level.world_features.security_storey(terminal.global_position.y) + 1)
		elif terminal != null:
			output.text = "records.local · floor %d · login required\nCameras on this floor: cameras off\nTurrets on this floor: turrets off" % (player.level.world_features.security_storey(terminal.global_position.y) + 1)
		elif at_early_port():
			output.text = "service.local · floor %d · maintenance account\nSticker: user root · password root\n" % (player.level.world_features.security_storey(connection_target().global_position.y) + 1) + ("Practice lamp: lights test" if get_node("/root/Campaign").current_floor == 1 else "Cameras on this floor: cameras off")
		else:
			output.text = "No writable access point in range."
	elif is_login:
		var terminal: Node2D = connected_terminal()
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
		var terminal: Node2D = connected_terminal()
		if not ((terminal != null and logged_in.has(terminal.get_instance_id())) or (at_checkpoint() and player.level.world_features.terminal_authenticated) or (at_early_port() and player.level.world_features.early_authenticated)):
			output.text = "Stay at an authenticated terminal: login <password>"
			return
		var count: int = player.level.world_features.disable_turrets(connection_target())
		if count > 0:
			record_mp3_hack()
		output.text = "Turrets disabled on this floor: %d" % count if count > 0 else "No active turrets on this floor."
	elif text == "lights test":
		if at_early_port() and player.level.world_features.early_authenticated:
			player.level.emit_effect("hit", player.level.world_features.access_point)
			output.text = "Service lamp blinked. Your script works.\nOn the next floor, try cameras off at a service port."
		else:
			output.text = "Connect at the service port and login root first."
	elif text == "cameras off":
		if at_checkpoint() and player.level.world_features.terminal_authenticated:
			record_mp3_hack()
			close_panels()
			player.level.hack_remaining = 1.0
			return
		if at_early_port() and player.level.world_features.early_authenticated:
			var count: int = player.level.world_features.disable_cameras(connection_target())
			if count > 0:
				record_mp3_hack()
			output.text = "Cameras disabled on this floor: %d" % count if count > 0 else "No active cameras on this floor."
			return
		# Any records terminal you've logged into controls this floor's cameras too.
		var terminal: Node2D = connected_terminal()
		if terminal != null and logged_in.has(terminal.get_instance_id()):
			var count: int = player.level.world_features.disable_cameras(connection_target())
			if count > 0:
				record_mp3_hack()
			output.text = "Cameras disabled on this floor: %d" % count if count > 0 else "No active cameras on this floor."
		else:
			output.text = "Connect locally and authenticate first: login <password>"
	else:
		output.text = "Unknown command. Type help."

func record_mp3_hack() -> void:
	if has_remote and not local_console:
		get_node("/root/Campaign").on_mp3_hack()

const MP3_CONNECTION_RADIUS := 640.0
const MP3_FLOOR_TOLERANCE := 256.0

func connection_radius() -> float:
	return 48.0 if local_console else MP3_CONNECTION_RADIUS

## The MP3 sees terminals in the current corridor, even beyond the camera or behind cover.
## Physical interaction still needs a clear path and arm's reach.
func connection_target(radius := -1.0, physical := false) -> Node2D:
	if radius < 0.0:radius = connection_radius()
	physical = physical or local_console
	var candidates: Array[Node] = get_tree().get_nodes_in_group("security_terminals")
	var checkpoint: Node2D = player.level.areas.get_node_or_null("RemoteTerminal")
	if checkpoint != null:candidates.append(checkpoint)
	for prop in player.level.world_features.props:
		if is_instance_valid(prop) and prop.kind == "access":candidates.append(prop)
	var nearest: Node2D
	var best := radius
	for terminal in candidates:
		if not is_instance_valid(terminal) or not player.level.is_ancestor_of(terminal):continue
		var delta: Vector2 = terminal.global_position - player.global_position
		var gap := delta.length()
		if absf(delta.y) > MP3_FLOOR_TOLERANCE or gap > best:continue
		if physical and not player.level.world_features.reachable(terminal.global_position, radius):continue
		nearest = terminal
		best = gap
	return nearest

func connection_name(target: Node2D) -> String:
	if target == null:return "none"
	if target == player.level.areas.get_node_or_null("RemoteTerminal"):return "checkpoint.local"
	return "service.local" if target.get_script() == preload("res://scripts/review_prop.gd") else "records.local"

func connected_terminal() -> Node2D:
	var target := connection_target()
	return target if target != null and connection_name(target) != "service.local" else null

func at_early_port(radius := -1.0) -> bool:
	var target := connection_target(radius)
	return target != null and connection_name(target) == "service.local"

func at_checkpoint() -> bool:
	var target := connection_target()
	return target != null and target == player.level.areas.get_node_or_null("RemoteTerminal")

const THROW_SPEED := 190.0
const BLAST_RADIUS := 130.0

func drop_charge() -> void:
	if not player.has_supplies or player.c4_count <= 0:
		player.level.notify("Out of C4.")
		return
	# Three optional carried charges. Story supports have a separate reserve.
	var charge := Node2D.new()
	charge.set_script(preload("res://scripts/dropped_charge.gd"))
	charge.set_meta("inventory_charge", true)
	charge.position = player.position + Vector2(0, -6)
	# A short lunge toward the aim (mouse or right stick), or forward and a little up.
	var direction: Vector2 = player.aim_direction if (player.mouse_aim or pad_aim) else Vector2(player.facing, 0)
	charge.velocity = (direction.normalized() + Vector2(0, -0.35)).normalized() * THROW_SPEED
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
	if charge == null or not is_instance_valid(charge):
		return false
	planted.erase(charge)
	var was_inventory := bool(charge.get_meta("inventory_charge", true))
	charge.queue_free()
	if was_inventory:
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
		get_node("/root/SoundFX").play_near("collapse", point, player.global_position, -20, 900.0)
		if get_node("/root/Campaign").current_floor == 1 and not player.level.door_open and point.distance_to(player.level.get_node("Interactables/CellLock").global_position) < 100:
			player.level.route = "C4 breach"
			player.level.open_door()
		for guard in player.level.guards():
			if guard.global_position.distance_to(point) < BLAST_RADIUS and player.level.clear_sight(point, guard.global_position):
				var was_dead: bool = guard.is_dead
				guard.take_damage(16, true)
				if not was_dead and guard.is_dead:
					get_node("/root/Campaign").on_c4_kill()
		# One charge is enough for a turret: stuck to it, or anywhere in the blast.
		for turret in get_tree().get_nodes_in_group("tower_turrets"):
			if not is_instance_valid(turret) or turret.health <= 0:
				continue
			if charge.attached == turret or (turret.target_point().distance_to(point) < BLAST_RADIUS and player.level.clear_sight(point, turret.target_point())):
				turret.health = 1
				turret.take_turret_hit()
		charge.queue_free()
	planted.clear()

## Shared by the live right stick and input regression checks; remember the last aim at rest.
func update_pad_aim(stick: Vector2) -> void:
	var deadzone: float = controller_settings.preferences.deadzone
	if stick.length_squared() <= deadzone * deadzone:
		return
	if controller_settings.preferences.invert_aim_y:
		stick.y = -stick.y
	pad_aim = true
	pad_prompts = true
	player.mouse_aim = false
	player.aim_direction = stick.normalized()

func charge_snapshot() -> Array:
	var saved: Array = []
	for charge in planted:
		if is_instance_valid(charge):
			saved.append({"position": charge.position, "velocity": charge.velocity, "stuck": charge.stuck, "inventory_charge": bool(charge.get_meta("inventory_charge", true))})
	return saved

func restore_charges(saved: Array) -> void:
	for charge in planted:
		if is_instance_valid(charge):charge.queue_free()
	planted.clear()
	for entry in saved:
		var charge := Node2D.new()
		charge.set_script(preload("res://scripts/dropped_charge.gd"))
		charge.position = entry.position
		charge.velocity = entry.get("velocity", Vector2.ZERO)
		charge.stuck = bool(entry.get("stuck", true))
		charge.set_meta("inventory_charge", bool(entry.get("inventory_charge", true)))
		player.level.add_child(charge)
		planted.append(charge)

var cursor_hidden := false
var camera_base_zoom := Vector2.ONE

func update_mouse_cursor() -> void:
	# Spoken dialogue and stationary hiding remain part of the game, not cursor UI.
	var bindings = get_node("/root/InputBindings")
	var menu_open: bool = get_tree().paused or player.level.paused or player.level.completed or player.is_dead or locked() or is_instance_valid(bindings.panel) or player.level.world_features.modal_open()
	var focused: bool = DisplayServer.get_name() == "headless" or DisplayServer.window_is_focused()
	var hide: bool = not menu_open and focused and DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_MINIMIZED
	var mode: int = Input.MOUSE_MODE_HIDDEN if hide else Input.MOUSE_MODE_VISIBLE
	if hide != cursor_hidden or Input.mouse_mode != mode:
		cursor_hidden = hide
		Input.mouse_mode = mode

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_PAUSED]:
		held_buttons.clear()
		focus = false
		if is_instance_valid(player): player.get_node("Camera2D").zoom = camera_base_zoom
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_PAUSED] and cursor_hidden:
		cursor_hidden = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _exit_tree() -> void:
	if cursor_hidden:Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
