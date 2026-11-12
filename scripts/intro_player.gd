class_name IntroPlayer
extends BaseCharacter

const GRAVITY := 850.0
var controls: Node
var jumps_used := 0
const DOUBLE_JUMP_COOLDOWN := 3.0
var double_jump_cooldown_left := 0.0
const WALL_JUMP_WINDOW := 0.18
const WALL_JUMP_PUSH_TIME := 0.16
const WALL_JUMP_SPEED := 210.0
const WALL_SLIDE_SPEED := 72.0
var wall_sliding := false
var wall_slide_dust_left := 0.0
var wall_jump_window_left := 0.0
var wall_jump_side := 0.0
var last_wall_jump_side := 0.0
var wall_jump_push_left := 0.0
var crouching := false
var pad_crouch := false
var pad_jump_queued := false
var level: Node2D
var facing: float = 1.0
var is_concealed: bool = false
# Authored at 60 Hz. Jump impulses preserve that apex at other fixed rates.
@export var jump_velocity := -242.37
@export var stealth_duration := 5.0
@export var stealth_cooldown := 8.0
@export_range(0.1, 1.0) var stealth_speed_multiplier := 0.55
var stealth_remaining := 0.0
var stealth_cooldown_left := 0.0
var casualty_count: int = 0
var detection_state: String = "unseen"
## Full health in half hearts (set from the difficulty); potions restore up to this.
var max_health := 6
## Free cloak on arriving at a checkpoint: hidden for a few seconds with no cooldown spent.
var respawn_cloak_left := 0.0
var has_supplies: bool = false
var has_key: bool = false
var has_gun: bool = false
var guns: Array[String] = []
var gun_ammo: Dictionary = {}
var equipped_gun := "pistol"
var pending_guard: IntroGuard
var in_hiding_spot := false
var ammunition: int = 0
var c4_count: int = 0:
	set(value):
		c4_count = maxi(0, value)
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
const ATTACK = preload("res://assets/characters/miro_attack.png")
## Julia's two-frame knife swing: wind-up, then the slash.
const MELEE_ANIM_TIME := 0.24
var melee_anim: float = 0.0
var melee_direction := Vector2.RIGHT
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("player")
	movement_speed = 115.0
	controls = preload("res://scripts/player_controls.gd").new()
	add_child(controls)
	$CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()
	
	var campaign = get_node_or_null("/root/Campaign")
	if campaign != null:
		var tuning: Dictionary = campaign.tuning()
		health = int(tuning.health)
		stealth_duration = float(tuning.stealth_duration)
		stealth_cooldown = float(tuning.stealth_cooldown)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(level):
		return
	invulnerability_left = maxf(0.0, invulnerability_left - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if attack_cooldown < 0.000001: attack_cooldown = 0.0
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	dodge_left = maxf(0.0, dodge_left - delta)
	if dodge_left < 0.000001: dodge_left = 0.0
	attack_flash = maxf(0.0, attack_flash - delta)
	melee_anim = maxf(0.0, melee_anim - delta)
	if level.controls_locked() or is_dead or (is_instance_valid(level.world_features) and level.world_features.strangle_active()):
		pad_jump_queued = false
		wall_sliding = false
		velocity = Vector2.ZERO
		update_visual(delta)
		return
	double_jump_cooldown_left = maxf(0.0, double_jump_cooldown_left - delta)
	if in_hiding_spot:
		wall_sliding = false
		velocity = Vector2.ZERO
		update_visual(delta)
		return
	stealth_cooldown_left = maxf(0, stealth_cooldown_left - delta)
	if respawn_cloak_left > 0.0:
		respawn_cloak_left = maxf(0.0, respawn_cloak_left - delta)
		is_concealed = respawn_cloak_left > 0.0
		stealth_remaining = respawn_cloak_left
	elif is_concealed:
		stealth_remaining = maxf(0, stealth_remaining - delta)
		if not level.in_cover(global_position):
			end_stealth()
			level.notify("Stepped into the light — cover ended.")
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
	wall_jump_window_left = maxf(0.0, wall_jump_window_left - delta)
	wall_jump_push_left = maxf(0.0, wall_jump_push_left - delta)
	if is_on_floor() or climbing:
		wall_jump_window_left = 0.0
		wall_jump_push_left = 0.0
		last_wall_jump_side = 0.0
	update_crouch()
	var jump_pressed := Input.is_action_just_pressed("jump") or pad_jump_queued
	pad_jump_queued = false
	if jump_pressed and not crouching:
		if not try_mantle() and not try_wall_jump():
			if jumps_used == 0 or (jumps_used == 1 and double_jump_cooldown_left <= 0.0):
				if jumps_used == 1:
					double_jump_cooldown_left = DOUBLE_JUMP_COOLDOWN
				velocity.y = jump_impulse()
				jumps_used += 1
				climbing = false
	if direction != 0.0:
		facing = signf(direction)
	if Input.is_action_just_pressed("dodge") and dodge_cooldown <= 0.0:
		dodge_left = 14.0 / 60.0
		dodge_cooldown = 0.85
		end_stealth()
	var blanket_fast: bool = is_concealed and controls.wants_quiet_modifier()
	var speed_multiplier := (0.8 if blanket_fast else stealth_speed_multiplier) if is_concealed else 1.0
	var walk_multiplier := 0.55 if controls.wants_quiet_modifier() and not is_concealed else 1.0
	velocity.x = direction * movement_speed * speed_multiplier * walk_multiplier * (0.45 if crouching else (0.6 if controls.focus else 1.0))
	if dodge_left > 0.0:
		velocity.x = facing * 245.0
	if wall_jump_push_left > 0.0:
		velocity.x = last_wall_jump_side * WALL_JUMP_SPEED
		facing = last_wall_jump_side
	if climbing:
		velocity.y = vertical * 85.0 * speed_multiplier
		if direction == 0.0:
			global_position.x = move_toward(global_position.x, ladder.global_position.x, delta * 120.0)
	else:
		velocity.y += GRAVITY * delta
	var was_grounded := is_on_floor()
	var previous_wall_side := signf(get_wall_normal().x) if is_on_wall() else 0.0
	var was_sliding := wall_sliding
	wall_sliding = not was_grounded and not climbing and velocity.y > 0.0 and direction * previous_wall_side < 0.0 and wall_jump_push_left <= 0.0 and dodge_left <= 0.0
	if wall_sliding:
		velocity.y = minf(velocity.y, WALL_SLIDE_SPEED)
		if not was_sliding and previous_wall_side != last_wall_jump_side:
			wall_jump_side = previous_wall_side
			wall_jump_window_left = WALL_JUMP_WINDOW
		wall_slide_dust_left -= delta
		if wall_slide_dust_left <= 0:
			level.emit_effect("dust", global_position + Vector2(-previous_wall_side * 7.0, 10.0))
			wall_slide_dust_left = 0.16
	else:
		wall_slide_dust_left = 0.0
	var fall_speed := velocity.y
	move_and_slide()
	wall_sliding = wall_sliding and is_on_wall() and not is_on_floor()
	if is_on_wall() and not is_on_floor() and not climbing:
		var wall_side := signf(get_wall_normal().x)
		if wall_side != previous_wall_side and wall_side != last_wall_jump_side:
			wall_jump_side = wall_side
			wall_jump_window_left = WALL_JUMP_WINDOW
	if not was_grounded and is_on_floor() and fall_speed > 100:
		level.emit_effect("dust", global_position + Vector2(0, 14))
	footstep_left = maxf(0, footstep_left - delta)
	if is_on_floor() and absf(velocity.x) > 20 and footstep_left <= 0:
		var quiet_footsteps: bool = is_concealed or crouching or controls.wants_quiet_modifier()
		get_node("/root/SoundFX").play_sound("step", -25 if quiet_footsteps else -19)
		footstep_left = 0.32 if blanket_fast else (0.5 if quiet_footsteps else 0.32)
	if Input.is_action_just_pressed("cloak"):
		toggle_stealth()
	check_guard_contact()
	if Input.is_action_just_pressed("attack"):
		shank()
	if Input.is_action_just_pressed("explosive"):
		level.plant_c4()

	if Input.is_action_just_pressed("fire"):
		fire_gun()
	# Out of the world: below the level's own floor (Level 5 is deeper than the others).
	if global_position.y > $Camera2D.limit_bottom + 44:
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
		level.notify("Too bright: the blanket won't hide you in the light. Crouch under it, or step away.")
	else:
		is_concealed = true
		stealth_remaining = stealth_duration
		check_guard_contact()

func end_stealth() -> void:
	if respawn_cloak_left > 0.0:
		# The free cloak breaks without costing the blanket its recharge.
		respawn_cloak_left = 0.0
		is_concealed = false
		return
	if not is_concealed:
		return
	is_concealed = false
	stealth_remaining = 0
	stealth_cooldown_left = stealth_cooldown

func check_guard_contact() -> void:
	# A Keeper who walks right past a hidden Miro doesn't notice him.
	return
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
	if is_instance_valid(controls) and controls.blanket_removed():
		return ""
	if is_concealed:
		return "STEALTH %.1fs" % stealth_remaining
	if stealth_cooldown_left > 0:
		return "STEALTH %.1fs cooldown" % stealth_cooldown_left
	if not is_instance_valid(level) or not level.in_cover(global_position):
		return "BLANKET [Q] · too bright here"
	return "BLANKET READY [Q]"

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
	melee_anim = MELEE_ANIM_TIME
	melee_direction = weapon_aim_direction()
	if absf(melee_direction.x) > 0.1:facing = signf(melee_direction.x)
	get_node("/root/SoundFX").play_sound("swing", -18)
	var target: Node2D
	var reach := INF
	var target_priority := -1
	var targets: Array[Node] = level.guards()
	targets.append_array(get_tree().get_nodes_in_group("tower_turrets"))
	for candidate in targets:
		var turret := candidate.is_in_group("tower_turrets")
		if candidate.health <= 0 or (not turret and candidate.is_dead):
			continue
		var point: Vector2 = candidate.target_point() if turret else candidate.global_position
		var difference := point - global_position
		if absf(difference.cross(melee_direction)) < 24 and difference.dot(melee_direction) <= 46 and difference.dot(melee_direction) >= -5:
			var priority := 0 if candidate is IntroGuard and candidate.asleep else 1
			if (priority > target_priority or (priority == target_priority and difference.length_squared() < reach)) and level.can_melee_reach(global_position, point):
				target = candidate
				target_priority = priority
				reach = difference.length_squared()
	if target != null:
		if target.is_in_group("tower_turrets"):
			target.take_turret_hit(2)
		else:
			target.receive_shank()

func select_gun(index: int) -> void:
	if index < 0 or index >= guns.size():
		return
	gun_ammo[equipped_gun] = ammunition
	equipped_gun = guns[index]
	ammunition = gun_ammo.get(equipped_gun, 0)

func loot_weapon(guard: IntroGuard) -> void:
	if guard.gun_taken or is_instance_valid(pending_guard):
		return
	if has_gun and guns.is_empty():
		guns.append(equipped_gun)
	gun_ammo[equipped_gun] = ammunition
	if guns.has(guard.weapon_kind):
		controls.reserves[guard.weapon_kind] = controls.reserves.get(guard.weapon_kind, 0) + guard.dropped_ammo()
		ammunition = gun_ammo.get(equipped_gun, 0)
		guard.gun_taken = true
	elif guns.size() < 2:
		guns.append(guard.weapon_kind)
		gun_ammo[guard.weapon_kind] = guard.dropped_ammo()
		equipped_gun = guard.weapon_kind
		ammunition = gun_ammo[equipped_gun]
		has_gun = true
		guard.gun_taken = true
		# A newly picked-up gun goes straight into his hand, so what you see is what you fire.
		controls.sync_slots()
		controls.select_item(equipped_gun)
## Bullets a fallen Keeper drops: at least 3 for a pistol, a full magazine for an SMG.
func weapon_ammo(kind: String) -> int:
	return 3 if kind == "pistol" else 12

func resolve_weapon_choice(_slot: int) -> void:
	pending_guard = null

func fire_gun() -> void:
	if in_hiding_spot or level.controls_locked() or is_dead:
		return
	if not has_gun or ammunition <= 0:
		level.notify("Out of ammo. [R] Reload." if int(controls.reserves.get(equipped_gun,0))>0 else "Out of ammo. Find ammunition: tap [E] behind an unaware Keeper, or search a fallen Keeper.")
		return
	if attack_cooldown > 0 or controls.reload_left > 0:
		return
	ammunition -= 1
	attack_cooldown = 0.65 if equipped_gun == "pistol" else 8.0 / 60.0
	attack_flash = 0.2
	get_node("/root/SoundFX").play_sound("shot", -22, 1.25 if equipped_gun == "smg" else 1.0)
	end_stealth()
	# Gunfire is always loud: kills cost noise.
	level.make_noise(global_position, 600.0)
	aim_direction = weapon_aim_direction()
	var spread := (0.006 if controls.focus else 0.018) if equipped_gun == "pistol" else (0.022 if controls.focus else 0.075)
	if climbing and not is_on_floor():
		spread += 0.16 if controls.focus else 0.24
	var bullet_direction := aim_direction.rotated(randf_range(-spread, spread))
	if absf(aim_direction.x) > 0.01:
		facing = signf(aim_direction.x)
	var bullet := Node2D.new()
	bullet.set_script(load("res://scripts/weapon_projectile.gd"))
	bullet.level = level
	bullet.shooter = self
	bullet.direction = bullet_direction
	bullet.damage = 4 if equipped_gun == "pistol" else 3
	bullet.falloff = equipped_gun != "pistol"
	# Start at the body so a muzzle offset cannot spawn beyond a nearby wall.
	bullet.position = position + Vector2(0, 5 if crouching else -4)
	level.add_child(bullet)
	level.emit_effect("hit", global_position + aim_direction * 12)
	var casing := Node2D.new()
	casing.set_script(load("res://scripts/weapon_casing.gd"))
	casing.level = level
	casing.position = position + Vector2(0, -6)
	casing.velocity = Vector2(-facing * 65, -100)
	level.add_child(casing)

func take_damage(amount: int, ignore_recovery := false) -> void:
	if dodge_left > 0:
		return
	var previous_health := health
	super.take_damage(amount, ignore_recovery)
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
	if melee_anim > 0 and not climbing:
		sprite.texture = ATTACK
		sprite.hframes = 2
		sprite.frame = 0 if melee_anim > MELEE_ANIM_TIME * 0.5 else 1
	sprite.flip_h = facing < 0
	sprite.modulate = Color("8b6d9c") if is_concealed else Color.WHITE
	sprite.modulate.a = 0.15 if in_hiding_spot else (0.42 if is_concealed else (0.5 if invulnerability_left > 0 and int(animation_time * 20) % 2 == 0 else 1.0))
	sprite.rotation = PI / 2 if is_dead else 0.0
	sprite.visible = is_dead
	queue_redraw()

## The guitar's ray: a widening beam of notes along the aim while a strum rings out.
func draw_strum_ray() -> void:
	if not is_instance_valid(controls) or controls.strum_flash <= 0.0:
		return
	var direction: Vector2 = controls.strum_direction
	var strength: float = clampf(controls.strum_flash / 0.35, 0.0, 1.0)
	var reach: float = controls.strum_visual_reach
	var side := Vector2(-direction.y, direction.x)
	var origin := guitar_sound_origin()
	# A soft widening cone underneath, then the line-and-note burst on top of it.
	draw_colored_polygon(PackedVector2Array([origin, origin + direction * reach + side * (reach * 0.16), origin + direction * reach - side * (reach * 0.16)]), Color(0.95, 0.83, 0.67, 0.16 * strength))
	preload("res://scripts/guitar_music_fx.gd").draw_burst(self, origin, direction, strength, reach)

func _draw() -> void:
	draw_strum_ray()
	if not is_dead and is_instance_valid(sprite):
		var scale_y := 0.65 if crouching else 1.0
		var origin := Vector2(0, 5 if crouching else 0)
		var frame_x := sprite.frame * 32 if sprite.hframes == 2 else 0
		var pose_facing := -signf(get_wall_normal().x) if wall_sliding else facing
		var lean := pose_facing * 0.12 if wall_sliding else 0.0
		draw_set_transform(origin, lean, Vector2(pose_facing, scale_y))
		draw_texture_rect_region(sprite.texture, Rect2(-16, -3, 32, 19), Rect2(frame_x, 13, 32, 19), sprite.modulate)
		var head_facing := pose_facing
		if not wall_sliding and (mouse_aim or controls.pad_aim) and absf(aim_direction.x) > 0.01:
			head_facing = signf(aim_direction.x)
		var head_angle := clampf(atan2(aim_direction.y, absf(aim_direction.x)), -0.3, 0.3) * head_facing if (mouse_aim or controls.pad_aim) and not wall_sliding else lean
		draw_set_transform(origin + Vector2(0, -5 * scale_y), head_angle, Vector2(head_facing, scale_y))
		draw_texture_rect_region(sprite.texture, Rect2(-16, -11, 32, 13), Rect2(frame_x, 0, 32, 13), sprite.modulate)
		draw_set_transform(Vector2.ZERO)
	if has_supplies and controls.active == "shank" and not is_dead and not in_hiding_spot:
		var direction := knife_aim_direction()
		var flip := -1.0 if direction.x < 0 else 1.0
		var swing := sin(melee_anim / MELEE_ANIM_TIME * PI) * 0.7
		draw_set_transform(Vector2(0,-4) + direction * 8, direction.angle() + flip * (0.25 - swing), Vector2(1,flip))
		draw_texture_rect(preload("res://scripts/weapon_art.gd").TEXTURES.shank,Rect2(0,-13,18,18),false)
		draw_set_transform(Vector2.ZERO)
	if has_gun and controls.active in guns and not is_dead and not in_hiding_spot:
		var direction := weapon_aim_direction()
		draw_set_transform(Vector2(0, -4), direction.angle(), Vector2(1, -1 if direction.x < 0 else 1))
		draw_texture_rect(preload("res://scripts/weapon_art.gd").TEXTURES[equipped_gun], Rect2(0, -10, 24, 24), false)
		draw_set_transform(Vector2.ZERO)
	if controls.has_guitar and controls.active == "guitar" and not is_dead and not in_hiding_spot:
		var direction := weapon_aim_direction()
		var flip := -1.0 if direction.x < 0 else 1.0
		var strum_tilt := -flip * PI / 3 if controls.guitar_guarding() else sin(controls.strum_flash / 0.35 * PI) * 0.1
		draw_set_transform(guitar_sound_origin(), direction.angle() + flip * PI / 4 + strum_tilt, Vector2(1, flip))
		draw_texture_rect(preload("res://scripts/weapon_art.gd").TEXTURES.guitar, Rect2(-10, -20, 30, 30), false)
		draw_set_transform(Vector2.ZERO)
	if attack_flash > 0 and melee_anim <= 0:
		draw_line(Vector2(facing * 9, -2), Vector2(facing * 35, -7), Color("fbf5ef"), 2)
	if controls.focus and has_gun and controls.active in guns and not is_dead and not in_hiding_spot:
		var cursor := focus_reticle_position()
		draw_line(Vector2(0, -4), cursor, Color(1, 1, 1, 0.15), 1)
		draw_arc(cursor, 5, 0, TAU, 16, Color(1, 1, 1, 0.7), 1)
	if is_concealed:
		draw_arc(Vector2(0, -20), 5, 0, PI, 8, Color("c69fa5"), 1)

func update_crouch() -> void:
	var requested: bool = (Input.is_action_pressed("crouch") or controls.wants_pad_crouch()) and is_on_floor()
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

## Use the contact normal so facing and held input cannot send the bounce into the wall.
func try_wall_jump() -> bool:
	if is_on_floor() or climbing or wall_jump_window_left <= 0.0 or wall_jump_side == last_wall_jump_side:
		return false
	last_wall_jump_side = wall_jump_side
	wall_jump_window_left = 0.0
	wall_jump_push_left = ceilf(WALL_JUMP_PUSH_TIME * 60.0) / 60.0
	dodge_left = 0.0
	velocity.y = jump_impulse()
	return true

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
	# A vault, not a teleport: spring up and over the ledge so it reads as a movement.
	wall_jump_window_left = 0.0
	# The same forward shove a wall jump uses, so input doesn't cancel the sideways motion.
	last_wall_jump_side = facing
	wall_jump_push_left = 0.2
	velocity = Vector2(facing * 150.0, jump_impulse(1.1))
	jumps_used = 1
	return true

## One normalized direction for the gun artwork, projectile and controller ADS reticle.
func knife_aim_direction() -> Vector2:
	return melee_direction if melee_anim > 0.0 else weapon_aim_direction()

func weapon_aim_direction() -> Vector2:
	var direction := (get_global_mouse_position() - global_position) if mouse_aim else (aim_direction if controls.pad_aim else Vector2(facing, 0))
	return direction.normalized() if direction.length_squared() > 0.01 else Vector2(-1 if facing < 0 else 1, 0)

func focus_reticle_position() -> Vector2:
	return get_local_mouse_position() if mouse_aim else Vector2(0, -4) + weapon_aim_direction() * 96.0

func guitar_sound_origin() -> Vector2:
	return Vector2(-6 if weapon_aim_direction().x < 0 else 6, -2)

## Match the discrete 60 Hz apex while allowing more frequent collision/input updates.
## Computed only on a jump, rather than adding work to every physics tick.
func jump_impulse(multiplier := 1.0) -> float:
	var authored := -jump_velocity * multiplier
	var rate := float(Engine.physics_ticks_per_second)
	if rate == 60.0: return -authored
	var reference_ticks := floorf(authored * 60.0 / GRAVITY)
	var height := reference_ticks * authored / 60.0 - GRAVITY * reference_ticks * (reference_ticks + 1.0) / (2.0 * 60.0 * 60.0)
	var delta := 1.0 / rate
	var ticks := maxf(1.0, ceilf((sqrt(1.0 + 8.0 * height / (GRAVITY * delta * delta)) - 1.0) / 2.0))
	return -(height / (ticks * delta) + GRAVITY * delta * (ticks + 1.0) / 2.0)
