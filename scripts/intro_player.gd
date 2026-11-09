class_name IntroPlayer
extends BaseCharacter

var controls: Node
var jumps_used := 0
var crouching := false
var level: Node2D
var facing: float = 1.0
var is_concealed: bool = false
# At 60 Hz with gravity 850, two apex-timed impulses reproduce Fran's
# approximately 65.17px total rise, including the floor contact margin.
@export var jump_velocity := -242.37
@export var stealth_duration := 5.0
@export var stealth_cooldown := 8.0
@export_range(0.1, 1.0) var stealth_speed_multiplier := 0.55
var stealth_remaining := 0.0
var stealth_cooldown_left := 0.0
var casualty_count: int = 0
var detection_state: String = "unseen"
var has_supplies: bool = false
var has_key: bool = false
var has_gun: bool = false
var guns: Array[String] = []
var gun_ammo: Dictionary = {}
var equipped_gun := "pistol"
var pending_guard: IntroGuard
var suppressor_uses := 0
var in_hiding_spot := false
var ammunition: int = 0
var c4_count: int = 0
var attack_cooldown: float = 0.0
var dodge_left: float = 0.0
var dodge_cooldown: float = 0.0
var animation_time: float = 0.0
var climbing: bool = false
var attack_flash: float = 0.0
var footstep_left := 0.0
var mouse_aim := false
var aim_direction := Vector2.RIGHT
const IDLE = preload("res://assets/characters/miro_idle.png")
const WALK = preload("res://assets/characters/miro_walk.png")
const JUMP = preload("res://assets/characters/miro_jump.png")
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("player")
	movement_speed = 115.0
	controls = preload("res://scripts/player_controls.gd").new()
	add_child(controls)
	$CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(level):
		return
	invulnerability_left = maxf(0.0, invulnerability_left - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	dodge_left = maxf(0.0, dodge_left - delta)
	attack_flash = maxf(0.0, attack_flash - delta)
	if level.controls_locked() or is_dead:
		velocity = Vector2.ZERO
		update_visual(delta)
		return
	if in_hiding_spot:
		velocity = Vector2.ZERO
		update_visual(delta)
		return
	stealth_cooldown_left = maxf(0, stealth_cooldown_left - delta)
	if is_concealed:
		stealth_remaining = maxf(0, stealth_remaining - delta)
		if not level.in_cover(global_position):
			end_stealth()
			level.notify("Left shadows — cover ended.")
		elif stealth_remaining == 0:
			end_stealth()
	var direction := Input.get_axis("move_left", "move_right")
	var vertical := Input.get_axis("climb_up", "climb_down")
	var ladder = level.ladder_at(global_position)
	if ladder == null:
		climbing = false
	elif vertical != 0.0:
		climbing = true
	if is_on_floor() or climbing:
		jumps_used = 0
	elif jumps_used == 0:
		jumps_used = 1
	update_crouch()
	if Input.is_action_just_pressed("jump") and not crouching:
		if not try_mantle() and jumps_used < 2:
			velocity.y = jump_velocity
			jumps_used += 1
			climbing = false
	if direction != 0.0:
		facing = direction
	if Input.is_action_just_pressed("dodge") and dodge_cooldown <= 0.0:
		dodge_left = 0.22
		dodge_cooldown = 0.85
		end_stealth()
	var speed_multiplier := stealth_speed_multiplier if is_concealed else 1.0
	velocity.x = direction * movement_speed * speed_multiplier * (0.45 if crouching else (0.6 if controls.focus else 1.0))
	if dodge_left > 0.0:
		velocity.x = facing * 245.0
	if climbing:
		velocity.y = vertical * 85.0 * speed_multiplier
		if direction == 0.0:
			global_position.x = move_toward(global_position.x, ladder.global_position.x, delta * 120.0)
	else:
		velocity.y += 850.0 * delta
	var was_grounded := is_on_floor()
	var fall_speed := velocity.y
	move_and_slide()
	if not was_grounded and is_on_floor() and fall_speed > 100:
		level.emit_effect("dust", global_position + Vector2(0, 14))
	footstep_left = maxf(0, footstep_left - delta)
	if is_on_floor() and absf(velocity.x) > 20 and footstep_left <= 0:
		get_node("/root/SoundFX").play_sound("step", -25 if is_concealed else -19)
		footstep_left = 0.5 if is_concealed else 0.32
	if Input.is_action_just_pressed("cloak"):
		toggle_stealth()
	check_guard_contact()
	if Input.is_action_just_pressed("attack"):
		shank()
	if Input.is_action_just_pressed("explosive"):
		level.plant_c4()

	if Input.is_action_just_pressed("fire"):
		fire_gun()
	if global_position.y > 800:
		die()
	update_visual(delta)

func toggle_stealth() -> void:
	if level.controls_locked() or is_dead:
		return
	if not has_supplies:
		level.notify("Your blanket is on the bed. Search it with E.")
	elif is_concealed:
		end_stealth()
	elif stealth_cooldown_left > 0:
		level.notify("Stealth recharging: %.1fs" % stealth_cooldown_left)
	elif not level.in_cover(global_position):
		level.notify("The blanket only conceals you in shadows.")
	else:
		is_concealed = true
		stealth_remaining = stealth_duration
		check_guard_contact()

func end_stealth() -> void:
	if not is_concealed:
		return
	is_concealed = false
	stealth_remaining = 0
	stealth_cooldown_left = stealth_cooldown

func check_guard_contact() -> void:
	if not is_concealed:
		return
	var bounds := Rect2(global_position + Vector2(-7, -9), Vector2(14, 24))
	for guard in level.guards():
		if not guard.is_dead and bounds.intersects(Rect2(guard.global_position + Vector2(-7, -9), Vector2(14, 24))):
			end_stealth()
			guard.alert_state = IntroGuard.State.ALERT
			guard.suspicion = 1.0
			guard.sees_player = true
			guard.last_known_position = global_position
			level.notify("Cover blown — you touched a Keeper!")
			return

func stealth_status() -> String:
	if is_concealed:
		return "STEALTH %.1fs" % stealth_remaining
	if stealth_cooldown_left > 0:
		return "STEALTH %.1fs cooldown" % stealth_cooldown_left
	if not is_instance_valid(level) or not level.in_cover(global_position):
		return "BLANKET [Q + click] · find shadow"
	return "BLANKET READY [Q + click]"

func shank() -> void:
	if in_hiding_spot or level.controls_locked() or is_dead:
		return
	if not has_supplies:
		level.notify("Search beneath the bed first. [E]")
		return
	if attack_cooldown > 0.0:
		return
	end_stealth()
	attack_cooldown = 0.5
	attack_flash = 0.16
	get_node("/root/SoundFX").play_sound("swing", -18)
	for guard in level.guards():
		var difference: Vector2 = guard.global_position - global_position
		if not guard.is_dead and absf(difference.y) < 24 and absf(difference.x) <= 46 and difference.x * facing >= -5:
			if level.can_melee_reach(global_position, guard.global_position):
				if level.player.is_concealed or not guard.detect_player():
					# Perform a strangle instead of a lethal shank if stealthy
					guard.strangle()
					return
				guard.receive_shank()
				break

func select_gun(index: int) -> void:
	if index < 0 or index >= guns.size():
		return
	gun_ammo[equipped_gun] = ammunition
	controls.attachments[equipped_gun] = suppressor_uses
	equipped_gun = guns[index]
	suppressor_uses = controls.attachments.get(equipped_gun, 0)
	ammunition = gun_ammo.get(equipped_gun, 0)

func loot_weapon(guard: IntroGuard) -> void:
	if guard.gun_taken or is_instance_valid(pending_guard):
		return
	if has_gun and guns.is_empty():
		guns.append(equipped_gun)
	gun_ammo[equipped_gun] = ammunition
	if guns.has(guard.weapon_kind):
		controls.reserves[guard.weapon_kind] = controls.reserves.get(guard.weapon_kind, 0) + weapon_ammo(guard.weapon_kind)
		ammunition = gun_ammo.get(equipped_gun, 0)
		guard.gun_taken = true
	elif guns.size() < 2:
		controls.attachments[equipped_gun] = suppressor_uses
		suppressor_uses = 0
		guns.append(guard.weapon_kind)
		gun_ammo[guard.weapon_kind] = weapon_ammo(guard.weapon_kind)
		equipped_gun = guard.weapon_kind
		ammunition = gun_ammo[equipped_gun]
		has_gun = true
		guard.gun_taken = true
	else:
		pending_guard = guard
		level.notify("Take %s? [Z] replace %s / [X] replace %s / [Esc] cancel" % [guard.weapon_kind, guns[0], guns[1]], 30)

func weapon_ammo(kind: String) -> int:
	return 2 if kind == "pistol" else (12 if kind == "smg" else 16)

func resolve_weapon_choice(slot: int) -> void:
	if not is_instance_valid(pending_guard):
		return
	if slot >= 0 and slot < guns.size():
		gun_ammo[equipped_gun] = ammunition
		controls.attachments[equipped_gun] = suppressor_uses
		controls.attachments.erase(guns[slot])
		controls.reserves.erase(guns[slot])
		suppressor_uses = 0
		gun_ammo.erase(guns[slot])
		guns[slot] = pending_guard.weapon_kind
		equipped_gun = guns[slot]
		gun_ammo[equipped_gun] = weapon_ammo(equipped_gun)
		ammunition = gun_ammo[equipped_gun]
		pending_guard.gun_taken = true
	pending_guard = null
	controls.sync_slots()
	level.notify("Weapon choice saved. Select a slot to equip.")

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if is_instance_valid(pending_guard):
		if event.physical_keycode in [KEY_Z, KEY_X, KEY_ESCAPE]:
			resolve_weapon_choice(0 if event.physical_keycode == KEY_Z else (1 if event.physical_keycode == KEY_X else -1))
			get_viewport().set_input_as_handled()


func fire_gun() -> void:
	if in_hiding_spot or level.controls_locked() or is_dead:
		return
	if not has_gun or ammunition <= 0:
		level.notify("No loaded weapon. A fallen Keeper may carry one.")
		return
	if attack_cooldown > 0 or controls.reload_left > 0 or controls.attach_left > 0:
		return
	ammunition -= 1
	attack_cooldown = 0.65 if equipped_gun == "pistol" else (0.13 if equipped_gun == "smg" else 0.12)
	attack_flash = 0.2
	var suppressed := suppressor_uses > 0 and equipped_gun in ["pistol", "smg"]
	if suppressed:
		suppressor_uses -= 1
		controls.attachments[equipped_gun] = suppressor_uses
	get_node("/root/SoundFX").play_sound("flame" if equipped_gun == "flamethrower" else "shot", -32 if suppressed else -22, 1.25 if equipped_gun == "smg" else 1.0)
	end_stealth()
	if not suppressed:
		level.make_noise(global_position, 600.0)
	aim_direction = (get_global_mouse_position() - global_position).normalized() if mouse_aim else Vector2(facing, 0)
	if aim_direction.length_squared() < 0.1:
		aim_direction = Vector2(facing, 0)
	if absf(aim_direction.x) > 0.01:
		facing = signf(aim_direction.x)
	var bullet := Node2D.new()
	bullet.set_script(load("res://scripts/weapon_projectile.gd"))
	bullet.level = level
	bullet.shooter = self
	bullet.direction = aim_direction
	bullet.flame = equipped_gun == "flamethrower"
	bullet.damage = 2 if equipped_gun == "pistol" else 1
	if bullet.flame:
		bullet.speed = 240.0
		bullet.remaining = 100.0
	# Start at the body so a muzzle offset cannot spawn beyond a nearby wall.
	bullet.position = position + Vector2(0, -4)
	level.add_child(bullet)
	level.emit_effect("hit", global_position + aim_direction * 12)
	if equipped_gun == "flamethrower":
		return
	var casing := Node2D.new()
	casing.set_script(load("res://scripts/weapon_casing.gd"))
	casing.level = level
	casing.position = position + Vector2(0, -6)
	casing.velocity = Vector2(-facing * 65, -100)
	level.add_child(casing)

func take_damage(amount: int) -> void:
	if dodge_left > 0:
		return
	var previous_health := health
	super.take_damage(amount)
	if health < previous_health:
		in_hiding_spot = false
		get_node("/root/SoundFX").play_sound("hit", -16)
		level.emit_effect("hit", global_position)
	end_stealth()

func die() -> void:
	if is_dead:
		return
	super.die()
	level.notify("The tower keeps its prisoners. Press Backspace to retry.", 20.0)

func update_visual(delta: float) -> void:
	if mouse_aim and not level.controls_locked():
		aim_direction = (get_global_mouse_position() - global_position).normalized()
	animation_time += delta
	sprite.hframes = 1
	sprite.texture = IDLE
	if dodge_left > 0 or (not is_on_floor() and not climbing):
		sprite.texture = JUMP
	elif absf(velocity.x) > 1:
		sprite.texture = WALK
		sprite.hframes = 2
		sprite.frame = int(animation_time * 8) % 2
	sprite.flip_h = facing < 0
	sprite.modulate = Color("8b6d9c") if is_concealed else Color.WHITE
	sprite.modulate.a = 0.15 if in_hiding_spot else (0.42 if is_concealed else (0.5 if invulnerability_left > 0 and int(animation_time * 20) % 2 == 0 else 1.0))
	sprite.rotation = PI / 2 if is_dead else 0.0
	sprite.visible = is_dead
	queue_redraw()

func _draw() -> void:
	if not is_dead and is_instance_valid(sprite):
		var scale_y := 0.65 if crouching else 1.0
		var origin := Vector2(0, 5 if crouching else 0)
		var frame_x := sprite.frame * 32 if sprite.hframes == 2 else 0
		draw_set_transform(origin, 0, Vector2(facing, scale_y))
		draw_texture_rect_region(sprite.texture, Rect2(-16, -3, 32, 19), Rect2(frame_x, 13, 32, 19), sprite.modulate)
		var head_facing := signf(aim_direction.x) if mouse_aim and absf(aim_direction.x) > 0.01 else facing
		var head_angle := clampf(atan2(aim_direction.y, absf(aim_direction.x)), -0.3, 0.3) * head_facing if mouse_aim else 0.0
		draw_set_transform(origin + Vector2(0, -5 * scale_y), head_angle, Vector2(head_facing, scale_y))
		draw_texture_rect_region(sprite.texture, Rect2(-16, -11, 32, 13), Rect2(frame_x, 0, 32, 13), sprite.modulate)
		draw_set_transform(Vector2.ZERO)
	if has_gun and controls.active in guns and not is_dead and not in_hiding_spot:
		var direction := aim_direction if mouse_aim else Vector2(facing, 0)
		draw_set_transform(Vector2(0, -4), direction.angle(), Vector2(1, -1 if direction.x < 0 else 1))
		draw_texture_rect(preload("res://scripts/weapon_art.gd").TEXTURES[equipped_gun], Rect2(0, -10, 24, 24), false)
		if suppressor_uses > 0 and equipped_gun in ["pistol", "smg"]:
			draw_rect(Rect2(20, -3, 9, 4), Color("777b98"))
		draw_set_transform(Vector2.ZERO)
	if attack_flash > 0:
		draw_line(Vector2(facing * 9, -2), Vector2(facing * 35, -7), Color("fbf5ef"), 2)
	if controls.focus:
		var cursor := get_local_mouse_position()
		draw_arc(cursor, 5, 0, TAU, 16, Color(1, 1, 1, 0.7), 1)
	if is_concealed:
		draw_arc(Vector2(0, -20), 5, 0, PI, 8, Color("c69fa5"), 1)

func update_crouch() -> void:
	var requested := Input.is_physical_key_pressed(KEY_CTRL) and is_on_floor()
	if crouching and not requested:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(12, 27)
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = shape
		query.transform = Transform2D(0, global_position + Vector2(0, 1.5))
		query.collision_mask = 1
		query.margin = 0.0
		query.exclude = [get_rid()]
		if not get_world_2d().direct_space_state.intersect_shape(query).is_empty():
			requested = true
	crouching = requested
	$CollisionShape2D.shape.size = Vector2(12, 16 if crouching else 27)
	$CollisionShape2D.position.y = 7 if crouching else 1.5
	sprite.scale.y = 0.65 if crouching else 1.0
	sprite.position.y = 5 if crouching else 0

func try_mantle() -> bool:
	if not is_on_wall() or is_on_floor() or climbing:
		return false
	var up := Vector2(0, -34)
	var across := Vector2(facing * 22, 0)
	if test_move(global_transform, up):
		return false
	var raised := global_transform
	raised.origin += up
	if test_move(raised, across):
		return false
	var destination := global_position + up + across
	if not level.has_floor_below(destination + Vector2(0, 13)):
		return false
	global_position = destination
	velocity = Vector2.ZERO
	jumps_used = 1
	return true
