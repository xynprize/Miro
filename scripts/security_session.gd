extends Node
## Authenticated, storey-local security control shared by both console surfaces.
var controls: Node
var camera: Camera2D
var terminal: Node2D
var cameras: Array[Node2D] = []
var index := 0
var wireless := true
var viewing := false
var cooldown := 0.0
var caption: Label
var overlay: CanvasLayer
var hud_was_visible := true

func setup(owner_controls: Node) -> void:
	controls = owner_controls

func authenticated(target: Node2D) -> bool:
	if not is_instance_valid(target):return false
	var features = controls.player.level.world_features
	return controls.logged_in.has(target.get_instance_id()) or (controls.connection_name(target) == "checkpoint.local" and features.terminal_authenticated) or (controls.connection_name(target) == "service.local" and features.early_authenticated)

func storey() -> int:
	return controls.player.level.world_features.security_storey(controls.player.global_position.y)

func devices(group: String) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var level = controls.player.level
	for device in get_tree().get_nodes_in_group(group):
		if group == "tower_turrets" and device.is_in_group("security_cameras"):continue
		if is_instance_valid(device) and level.is_ancestor_of(device) and device.health > 0 and level.world_features.security_storey(device.global_position.y) == storey():
			result.append(device)
	return result

func execute(command: String) -> String:
	if command in ["cameras hack", "turrets hack"] and controls.local_console:
		return "Unknown command. Type help."
	if not controls.local_console and (not controls.has_remote or not controls.remote_unlocked):
		return "Unlock the MP3 service console first."
	var target: Node2D = controls.connection_target()
	if target == null:return "Out of terminal range. Move closer to a service port or terminal."
	if not authenticated(target):return "Authenticate first: login <password>"
	if command in ["cameras hack", "cameras watch"]:
		return start_view(target, not controls.local_console)
	var cameras_command := command.begins_with("cameras")
	var targets := devices("security_cameras" if cameras_command else "tower_turrets")
	if command == "turrets hack":
		if cooldown > 0.0:return "Turret override cooling down: %.1fs" % cooldown
		var count := 0
		for device in targets:
			if not device.disabled:
				device.hack_left = 1.5
				device.charge = 0.0
				count += 1
		if count == 0:return "No powered turrets on this storey."
		cooldown = 10.0
		controls.record_mp3_hack()
		controls.close_panels()
		controls.player.level.notify("Turret override: 1.5s. Keep clear of their fire.")
		return "Turret override: 1.5s. Cooldown: 10s."
	var enabled := command.ends_with(" on")
	var changed := 0
	for device in targets:
		var active: bool = device.is_active if cameras_command else not device.disabled
		if active == enabled:continue
		if enabled:
			if cameras_command:device.is_active = true
			else:
				device.disabled = false
				device.hack_left = 0.0
				device.charge = 0.0
			var level = controls.player.level
			if level.has_method("record_security_enabled"):level.record_security_enabled(device)
			device.queue_redraw()
		else:device.disable()
		changed += 1
	if not enabled and changed > 0:controls.record_mp3_hack()
	# Only the authenticated checkpoint transaction can satisfy its objective.
	if command == "cameras off" and controls.connection_name(target) == "checkpoint.local":
		controls.player.level.complete_security_hack()
	if targets.is_empty():return "No surviving %s on this storey." % ("cameras" if cameras_command else "turrets")
	return "%s %s on this storey: %d" % ["Cameras" if cameras_command else "Turrets", "enabled" if enabled else "disabled", changed]

func start_view(target: Node2D, remote: bool) -> String:
	cameras = devices("security_cameras").filter(func(device): return device.is_active)
	if cameras.is_empty():return "No powered Mosswatchers on this storey. Try cameras on."
	cameras.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	terminal = target
	wireless = remote
	index = 0
	controls.close_panels()
	controls.player.end_stealth()
	viewing = true
	camera = Camera2D.new()
	camera.zoom = controls.player.get_node("Camera2D").zoom
	var original: Camera2D = controls.player.get_node("Camera2D")
	camera.limit_left = original.limit_left
	camera.limit_top = original.limit_top
	camera.limit_right = original.limit_right
	camera.limit_bottom = original.limit_bottom
	var level = controls.player.level
	if level.get("definition") != null:
		var rows: Array = level.definition.storeys
		var row := storey()
		camera.limit_top = 0 if row==0 else int(rows[row-1])+28
		camera.limit_bottom = int(rows[row])+28
		var required_zoom: float = controls.get_viewport().get_visible_rect().size.y / float(camera.limit_bottom-camera.limit_top)
		camera.zoom = Vector2.ONE*maxf(camera.zoom.y,required_zoom)
	controls.player.level.add_child(camera)
	camera.make_current()
	hud_was_visible = level.hud.visible
	level.hud.visible = false
	overlay = CanvasLayer.new()
	overlay.layer = 50
	add_child(overlay)
	caption = Label.new()
	caption.position = Vector2(16, 315)
	caption.add_theme_font_size_override("font_size",14)
	caption.add_theme_color_override("font_shadow_color",Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_x",2)
	caption.add_theme_constant_override("shadow_offset_y",2)
	overlay.add_child(caption)
	update_view()
	return "Mosswatcher feed open."

func update_view() -> void:
	if not viewing:return
	if cameras.is_empty() or not is_instance_valid(cameras[index]):
		stop_view()
		return
	var device = cameras[index]
	# Look into the watcher's cone, rather than exposing the whole map.
	camera.global_position = device.global_position + Vector2.from_angle(device.direction_angle()) * 90.0
	caption.text = "MOSSWATCHER %d/%d · W/S switch · E/Esc exit" % [index + 1, cameras.size()]

func _process(delta: float) -> void:
	if not is_instance_valid(controls) or not is_instance_valid(controls.player.level):return
	if get_tree().paused:return
	cooldown = maxf(0.0, cooldown - delta)
	if not viewing:return
	var player = controls.player
	var in_range: bool = is_instance_valid(terminal) and player.global_position.distance_to(terminal.global_position) <= (controls.MP3_CONNECTION_RADIUS if wireless else 48.0) and absf(player.global_position.y-terminal.global_position.y) <= controls.MP3_FLOOR_TOLERANCE
	if player.is_dead or not in_range or not authenticated(terminal):
		stop_view()
		if not player.is_dead:player.level.notify("Camera connection lost: out of terminal range.")
		return
	var selected = cameras[index] if not cameras.is_empty() else null
	cameras = devices("security_cameras").filter(func(device): return device.is_active)
	cameras.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	index = maxi(0, cameras.find(selected))
	update_view()

func handle_input(event: InputEvent) -> void:
	if not viewing:return
	if event.is_action_pressed("interact") or event.is_action_pressed("pause_game") or event.is_action_pressed("ui_cancel"):
		stop_view()
	elif event.is_action_pressed("climb_up") or event.is_action_pressed("climb_down"):
		index = posmod(index + (-1 if event.is_action_pressed("climb_up") else 1), cameras.size())
		update_view()
	get_viewport().set_input_as_handled()

func stop_view() -> void:
	viewing = false
	if is_instance_valid(camera):camera.queue_free()
	if is_instance_valid(overlay):overlay.queue_free()
	if is_instance_valid(controls.player):
		if is_instance_valid(controls.player.level):controls.player.level.hud.visible = hud_was_visible
		var original: Camera2D = controls.player.get_node("Camera2D")
		original.make_current()
		original.reset_smoothing()
	cameras.clear()
