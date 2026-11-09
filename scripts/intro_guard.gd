class_name IntroGuard
extends BaseCharacter

const KEEPER_IDLE = preload("res://assets/characters/standard_keeper_idle.png")
const KEEPER_WALK = preload("res://assets/characters/standard_keeper_walk.png")
const KEY_TEXTURE = preload("res://assets/environment/key.png")

enum State { PATROL, SUSPICIOUS, ALERT, SEARCH }
@export var patrol_left: float = 300.0
@export var patrol_right: float = 500.0
@export var sick_guard: bool = false
@export_enum("pistol", "smg", "flamethrower") var weapon_kind := "pistol"
var burst_left := 0
var burst_timer := 0.0
var shot_direction := Vector2.RIGHT
var level: Node2D
var alert_state: State = State.PATROL
var facing: float = 1.0
var suspicion: float = 0.0
var last_known_position := Vector2.ZERO
var search_left: float = 0.0
var attack_timer: float = 0.0
var windup: float = 0.0
var turn_wait: float = 0.0
var time: float = 0.0
var illness_started: bool = false
var seen_bodies: Array[int] = []
var key_taken: bool = false
var gun_taken: bool = false
var death_recorded: bool = false
var sees_player: bool = false
var body_reported: bool = false
var guard_name := "Keeper"
var voice_index := 0
var conversation_hold := false
var turn_away_left := 0.0
var alert_barked := false

func _ready() -> void:
	add_to_group("guards")
	health = 2
	movement_speed = 33.0 if sick_guard else 43.0

func can_see_point(point: Vector2, distance_limit: float = 165.0) -> bool:
	var difference := point - global_position
	return difference.length() < distance_limit and absf(difference.y) < 45 and difference.x * facing >= -8 and level.clear_sight(global_position + Vector2(0, -8), point + Vector2(0, -8))

func detect_player() -> bool:
	if is_dead or not level or level.player.is_dead or (level.player.is_concealed or level.player.in_hiding_spot):
		return false
	# Prisoners inside the locked cell are not escapees yet.
	if not level.door_open and level.player.global_position.x < level.get_node("Interactables/CellLock").global_position.x:
		return false
	return can_see_point(level.player.global_position)

func _physics_process(delta: float) -> void:
	time += delta
	queue_redraw()
	if not level or level.controls_locked():
		return
	if is_dead:
		return
	invulnerability_left = maxf(0, invulnerability_left - delta)
	attack_timer = maxf(0.0, attack_timer - delta)
	turn_wait = maxf(0.0, turn_wait - delta)
	sees_player = detect_player()
	if sees_player:
		suspicion = minf(1.0, suspicion + delta * 2.5)
		last_known_position = level.player.global_position
		search_left = 5.0
		if suspicion >= 1.0:
			alert_state = State.ALERT
			if not alert_barked and level.world_features:
				alert_barked = true
				level.world_features.bark(self, "alert")
		else:
			alert_state = State.SUSPICIOUS
	elif alert_state == State.ALERT or alert_state == State.SUSPICIOUS:
		alert_state = State.SEARCH
		search_left = 5.0
		suspicion = maxf(0.0, suspicion - delta)
	for body in level.guards():
		if body != self and body.is_dead and not seen_bodies.has(body.get_instance_id()) and can_see_point(body.global_position):
			seen_bodies.append(body.get_instance_id())
			body_reported = true
			if not sees_player:
				investigate(body.global_position)
			level.notify("%s found %s. The Keepers are searching." % [guard_name, body.guard_name])
			if level.world_features:
				level.world_features.bark(self, "body")
	velocity.x = 0
	burst_timer -= delta
	if burst_left > 0 and burst_timer <= 0:
		if sees_player:
			shoot_weapon()
		else:
			burst_left = 0
	if windup > 0:
		windup -= delta
		if windup <= 0 and sees_player:
			burst_left = 1 if weapon_kind == "pistol" else (3 if weapon_kind == "smg" else 5)
			shoot_weapon()
	elif alert_state == State.ALERT and sees_player:
		facing = signf(last_known_position.x - global_position.x)
		if global_position.distance_to(last_known_position) < (90 if weapon_kind == "flamethrower" else 150):
			if attack_timer <= 0:
				windup = 0.65
				shot_direction = (level.player.global_position - global_position).normalized()
				attack_timer = 2.1
		else:
			velocity.x = facing * 78.0
	elif alert_state == State.SEARCH:
		search_left -= delta
		if absf(last_known_position.x - global_position.x) > 12:
			facing = signf(last_known_position.x - global_position.x)
			velocity.x = facing * 42.0
		else:
			facing = 1.0 if int(time) % 2 == 0 else -1.0
		if search_left <= 0:
			alert_state = State.PATROL
			suspicion = 0
	elif alert_state == State.PATROL:
		if conversation_hold or turn_away_left > 0:
			turn_away_left = maxf(0, turn_away_left - delta)
			velocity.y += 850.0 * delta
			move_and_slide()
			return
		if sick_guard and not illness_started:
			return
		if global_position.x <= patrol_left:
			if facing < 0:
				turn_wait = 1.8 if sick_guard else 0.8
			facing = 1
		elif global_position.x >= patrol_right:
			if facing > 0:
				turn_wait = 1.0
			facing = -1
		if turn_wait <= 0:
			velocity.x = facing * movement_speed
	# Do not walk off a floor or chase between tiers. Guards cannot climb.
	var foot := global_position + Vector2(signf(velocity.x) * 15, 12)
	if velocity.x != 0 and not level.has_floor_below(foot):
		velocity.x = 0
		facing *= -1
		if alert_state == State.SEARCH:
			last_known_position.x = global_position.x
	velocity.y += 850.0 * delta
	move_and_slide()
	if is_on_wall():
		facing *= -1

func shoot_weapon() -> void:
	burst_left -= 1
	burst_timer = 0.14
	var bullet := Node2D.new()
	bullet.set_script(load("res://scripts/weapon_projectile.gd"))
	bullet.level = level
	bullet.shooter = self
	bullet.enemy = true
	bullet.direction = shot_direction
	bullet.flame = weapon_kind == "flamethrower"
	bullet.speed = 210.0 if bullet.flame else 280.0
	bullet.remaining = 100.0 if bullet.flame else 260.0
	bullet.position = position + Vector2(0, -4)
	level.add_child(bullet)
	get_node("/root/SoundFX").play_sound("flame" if bullet.flame else "shot", -25, 1.25 if weapon_kind == "smg" else 1.0)
	level.make_noise(global_position, 600)
	if not bullet.flame:
		var casing := Node2D.new()
		casing.set_script(load("res://scripts/weapon_casing.gd"))
		casing.level = level
		casing.position = position
		casing.velocity = Vector2(-facing * 65, -100)
		level.add_child(casing)

func investigate(point: Vector2) -> void:
	if is_dead or sees_player:
		return
	last_known_position = point
	search_left = 6.0
	alert_state = State.SEARCH
	suspicion = 0.3

func receive_shank() -> void:
	level.emit_effect("hit", global_position)
	conversation_hold = false
	turn_away_left = 0
	var unaware := alert_state != State.ALERT and not detect_player()
	health -= 2 if unaware else 1
	if health <= 0:
		die()
	else:
		alert_state = State.ALERT
		suspicion = 1.0
		last_known_position = level.player.global_position
		facing = signf(last_known_position.x - global_position.x)
		level.notify("The Keeper turns. One more hit; dodge his wind-up with C.")

func strangle() -> void:
	if is_dead:
		return
	# Non-lethal takedown
	is_dead = true
	death_recorded = true
	sees_player = false
	velocity = Vector2.ZERO
	# No casualty count increase for strangles
	# No blood effect
	get_node("/root/Campaign").record_event("strangle")
	level.notify("Guard neutralized quietly.")
	queue_redraw()

func die() -> void:
	if death_recorded:
		return
	death_recorded = true
	super.die()
	sees_player = false
	velocity = Vector2.ZERO
	level.player.casualty_count += 1

	# Record the kill event in Campaign
	var method := "gun" # Default
	if level.player.active == "shank":
		method = "shank"
	elif level.player.active == "c4":
		method = "c4"
	
	# Handle strangling as a non-lethal leave-on-floor state
	# This is a separate action from the lethal 'die()' call
	
	get_node("/root/Campaign").record_event("keeper_killed", {
		"method": method,
		"named": guard_name != "Keeper"
	})

	level.emit_effect("blood", global_position + Vector2(0, 12))
	level.notify("A body remains. Other Keepers may discover it. [E] Loot")
	queue_redraw()

func _draw() -> void:
	var pale := Color("f2d3ab")
	draw_string(ThemeDB.fallback_font, Vector2(-18, -36), guard_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, pale)
	if is_dead:
		# No dedicated death sheet yet: retain Julia's idle silhouette as a body.
		draw_set_transform(Vector2(0, 3), PI / 2)
		draw_texture(KEEPER_IDLE, Vector2(-16, -16))
		draw_set_transform(Vector2.ZERO)
		draw_carried_key()
		return
	if alert_state != State.PATROL or not sick_guard:
		var cone := PackedVector2Array([Vector2(0, -8), Vector2(facing * 150, -43), Vector2(facing * 150, 23)])
		draw_colored_polygon(cone, Color(0.78, 0.62, 0.65, 0.07 if alert_state != State.ALERT else 0.16))
	var coughing := sick_guard and illness_started and fmod(time, 4.0) < 1.4
	var moving: bool = absf(velocity.x) > 1 and level != null and not level.controls_locked()
	var texture: Texture2D = KEEPER_WALK if moving else KEEPER_IDLE
	var frame := int(time * 8) % 2 if moving else 0
	# Mirror the art, not the guard's collision, FOV or attached indicators.
	draw_set_transform(Vector2(0, 15), -facing * 0.12 if coughing else 0.0, Vector2(facing, 0.9 if coughing else 1.0))
	draw_texture_rect_region(texture, Rect2(-16, -31, 32, 32), Rect2(frame * 32, 0, 32, 32))
	draw_set_transform(Vector2.ZERO)
	draw_set_transform(Vector2(0, -4), 0, Vector2(facing, 1))
	draw_texture_rect(preload("res://scripts/weapon_art.gd").TEXTURES[weapon_kind], Rect2(0, -10, 24, 24), false)
	draw_set_transform(Vector2.ZERO)
	if windup > 0:
		draw_line(Vector2(facing * 9, 0), Vector2(facing * 27, -9), pale, 2)
	if coughing:
		draw_line(Vector2(facing * 8, 2), Vector2(facing * 6, -4), pale, 3)
		draw_circle(Vector2(facing * 14, -5 - fmod(time * 9, 12)), 1.5, Color("c69fa5"))
	if alert_state != State.PATROL:
		var reaction: Texture2D = preload("res://assets/library/alert.png") if alert_state == State.ALERT else preload("res://assets/library/question.png")
		draw_texture_rect(reaction, Rect2(-8, -35, 16, 16), false, pale)
	draw_carried_key()

func draw_carried_key() -> void:
	if sick_guard and not key_taken:
		draw_texture(KEY_TEXTURE, Vector2(-facing * 10 - 14, -12))
