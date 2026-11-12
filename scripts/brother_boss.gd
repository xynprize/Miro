extends IntroGuard
## Niro, the tower physician (docs/class.md Brother; Level 5 "The Foundation").
## Four meetings share one health pool: he retreats at each threshold, then is beaten
## but NOT killed on the deepest floor. Attacks are timed to the beat when music plays.
enum Phase { TELEGRAPH, RUSH, RELEASE, RECOVERY, REPOSITION, RETREAT, DEFEATED }
signal retreated(engagement: int)
var current_phase := Phase.TELEGRAPH
var is_vulnerable: bool:
	get: return current_phase == Phase.RECOVERY and not is_dead
var flank_target_x := 0.0
var phase_left := 1.1
var attack_number := 0
var projectile := Vector2.ZERO
var projectile_velocity := Vector2.ZERO
var projectile_live := false
var projectile_reflected := false
## 1–3: he retreats when health reaches retreat_at[engagement - 1]. 4: the final fight.
var engagement := 4
var retreat_at: Array = [9, 6, 3]
var max_health := 12
var start_health := 0
var calls_left := 0
var retreat_left := 0.0

func _ready() -> void:
	add_to_group("guards")
	sync_discoverable_group()
	health = start_health if start_health > 0 else max_health
	alert_state = State.ALERT
	sees_player = true
	calls_left = 2 if engagement >= 3 else 0
	phase_left = telegraph_time()
	planned_attack = next_attack()

func music() -> Node:
	return get_node("/root/MusicDirector")

## Telegraph resolves on a beat: at least 0.8 s of warning, landing on the following beat line.
func telegraph_time() -> float:
	var beat_length: float = music().seconds_per_beat()
	var position: float = music().beat_position()
	var warning := 0.8 if engagement < 4 else 0.6
	if position < 0:
		return 1.1
	var to_next := (1.0 - fmod(position, 1.0)) * beat_length
	while to_next < warning:
		to_next += beat_length
	return to_next

## The vulnerability window lasts one bar (three quarters of one in the final fight).
func recovery_time() -> float:
	if music().beat_position() < 0:
		return 1.6
	return music().seconds_per_bar() * (1.0 if engagement < 4 else 0.7)

func attacks() -> Array:
	match engagement:
		1: return ["rush"]
		2: return ["rush", "throw"]
		_: return ["rush", "throw", "call"]

var last_attack := ""
var combo := 0
## Test hook: the next attack, once.
var forced_attack := ""
var planned_attack := "rush"

## Not a fixed rotation: he picks at random, never the same attack three times running.
func next_attack() -> String:
	if forced_attack != "":
		var forced := forced_attack
		forced_attack = ""
		return forced
	var list := attacks()
	var attack: String = list[randi() % list.size()]
	if engagement >= 2 and is_instance_valid(level) and absf(level.player.position.x-position.x)>150 and randf()<0.65:
		attack = "throw"
	if attack == last_attack and list.size() > 1 and randf() < 0.6:
		attack = list[(list.find(attack) + 1) % list.size()]
	if attack == "call" and calls_left <= 0:
		attack = "rush"
	return attack

func _physics_process(delta: float) -> void:
	time += delta
	if is_dead or level.controls_locked() or level.player.is_dead:
		queue_redraw()
		return
	invulnerability_left = maxf(0, invulnerability_left - delta)
	phase_left -= delta
	velocity.y += 850 * delta
	velocity.x = 0
	if current_phase == Phase.RETREAT:
		retreat_left -= delta
		modulate.a = clampf(retreat_left / 0.8, 0, 1)
		if retreat_left <= 0:
			retreated.emit(engagement)
			queue_free()
		move_and_slide()
		queue_redraw()
		return
	if current_phase == Phase.TELEGRAPH:
		facing = 1 if level.player.position.x > position.x else -1
		if engagement >= 3:
			var gap := absf(level.player.position.x-position.x)
			var step_direction := facing if gap>170 else -facing if gap<70 else 0.0
			if step_direction != 0:
				move_across(step_direction, 75.0 if engagement >= 4 else 30.0)
		if phase_left <= 0:
			var chosen := next_attack() if not forced_attack.is_empty() else planned_attack
			last_attack = chosen
			match chosen:
				"rush":
					current_phase = Phase.RUSH
					phase_left = 0.95
				"throw":
					projectile = global_position + Vector2(facing * 15, -5)
					projectile_velocity = (level.player.global_position - projectile).normalized() * (330.0 if engagement >= 4 else 260.0)
					projectile_reflected = false
					projectile_live = true
					fire_volley()
					begin_release()
				"call":
					calls_left -= 1
					if level.has_method("niro_calls_guard"):
						level.niro_calls_guard(global_position)
					begin_release()
	elif current_phase == Phase.RUSH:
		if not move_across(facing, 265.0 if engagement >= 4 else 250.0) and phase_left > 0.3:
			# No floor to rush along: throw instead of standing there.
			projectile = global_position + Vector2(facing * 15, -5)
			projectile_velocity = (level.player.global_position - projectile).normalized() * (330.0 if engagement >= 4 else 260.0)
			projectile_reflected = false
			projectile_live = true
			begin_release()
		if global_position.distance_to(level.player.global_position) < 28:
			if not level.player.controls.block_melee(global_position):
				level.player.take_damage(2)
		if phase_left <= 0 or (is_on_wall() and phase_left < 0.4):
			# Sometimes he comes straight back for a second rush before he gives Miro an opening.
			if engagement >= 2 and combo < 1 and randf() < (0.35 if engagement < 4 else 0.55):
				combo += 1
				facing = 1 if level.player.position.x > position.x else -1
				phase_left = 0.7
			else:
				combo = 0
				begin_recovery()
	elif current_phase == Phase.RELEASE and phase_left <= 0:
		begin_recovery()
	elif current_phase == Phase.REPOSITION:
		var distance := flank_target_x - global_position.x
		facing = signf(distance)
		if absf(distance) < 12.0 or phase_left <= 0 or not move_across(facing, 250.0):
			begin_telegraph()
	elif current_phase == Phase.RECOVERY and phase_left <= 0:
		attack_number += 1
		if engagement == 4 and attack_number % 2 == 0:
			# The deepest row is a continuous runway. Commit to a flank instead of
			# following every small player movement and camping one half forever.
			flank_target_x = 910.0 if global_position.x < 560.0 else 210.0
			current_phase = Phase.REPOSITION
			phase_left = 3.65
		else:
			begin_telegraph()
	move_and_slide()
	if projectile_live:
		var next := projectile + projectile_velocity * delta
		if not level.clear_sight(projectile, next):
			projectile_live = false
		else:
			var zones = load("res://scripts/weapon_projectile.gd")
			var hit: Dictionary = zones.find_player_hit(level.player, projectile, next)
			if projectile_reflected:
				if Geometry2D.get_closest_point_to_segment(global_position,projectile,next).distance_to(global_position)<18:
					take_damage(1)
					projectile_live = false
			elif not hit.is_empty():
				if level.player.controls.guitar_guarding():
					projectile_velocity = -projectile_velocity
					projectile_reflected = true
				else:
					level.player.take_damage(zones.player_damage(level.player, hit.position))
					projectile_live = false
		projectile = next
		if projectile.distance_to(global_position) > 600:
			projectile_live = false
	queue_redraw()

func fire_volley() -> void:
	var count := 2 if engagement >= 4 else 1
	for index in range(count):
		var shot := preload("res://scripts/weapon_projectile.gd").new()
		shot.level = level
		shot.shooter = self
		shot.enemy = true
		shot.niro_round = true
		shot.damage = 1
		shot.speed = 330.0 if engagement >= 4 else 260.0
		shot.remaining = 600
		var spread := (float(index)-float(count-1)/2.0)*0.11
		# Keep the central throw, with extra readable lanes on both sides.
		if absf(spread)<0.01: spread = 0.11
		shot.direction = projectile_velocity.normalized().rotated(spread)
		shot.position = projectile
		level.add_child(shot)

func begin_recovery() -> void:
	current_phase = Phase.RECOVERY
	phase_left = recovery_time()

func begin_release() -> void:
	# A throw remains guarded through the release animation. Reflected shots are
	# judged on impact, so a shot can connect when the subsequent opening begins.
	current_phase = Phase.RELEASE
	phase_left = 0.65 if engagement >= 4 else 0.8

func begin_telegraph() -> void:
	current_phase = Phase.TELEGRAPH
	phase_left = telegraph_time()
	planned_attack = next_attack()

func move_across(direction: float, speed: float) -> bool:
	if is_zero_approx(direction):
		return false
	if is_on_floor():
		var ahead := Vector2(direction * 20.0, 0)
		if solid_between(global_position + Vector2(0, 8), global_position + ahead + Vector2(0, 8)):
			var lift := Vector2.UP * 30.0
			if test_move(global_transform, lift) or test_move(global_transform.translated(lift), ahead):
				return false
			velocity.y = -HOP_SPEED
		elif not solid_between(global_position + ahead, global_position + ahead + Vector2(0, 48)):
			return false
	velocity.x = direction * speed
	return true

func receive_shank() -> void:
	take_damage(1)

func take_damage(amount: int, _ignore_recovery := false) -> void:
	if not is_vulnerable:
		return
	if invulnerability_left > 0:
		return
	invulnerability_left = 0.35
	var minimum_health := int(retreat_at[engagement - 1]) if engagement < 4 else 0
	health = maxi(minimum_health, health - amount)
	level.emit_effect("hit", global_position)
	if engagement < 4 and health <= int(retreat_at[engagement - 1]):
		begin_retreat()
	elif health <= 0:
		die()

func begin_retreat() -> void:
	current_phase = Phase.RETREAT
	projectile_live = false
	retreat_left = 0.8
	if level.has_method("niro_retreating"):
		level.niro_retreating(engagement)

## Defeated, not killed: he kneels and stays inside the tower.
func die() -> void:
	if is_dead:
		return
	is_dead = true
	current_phase = Phase.DEFEATED
	projectile_live = false
	velocity = Vector2.ZERO
	level.brother_defeated()
	queue_redraw()

const KAEL_IDLE = preload("res://assets/characters/kael_idle.png")
const KAEL_WALK = preload("res://assets/characters/kael_walk.png")
const KAEL_ATTACK = preload("res://assets/characters/kael_attack.png")

## Julia's Kael sheets: idle 24 px, walk 2 x 24 px, attack 2 x 32 px.
func draw_kael(texture: Texture2D, frames: int, frame: int, tint: Color, squash := 1.0) -> void:
	var frame_size := Vector2(float(texture.get_width()) / frames, texture.get_height())
	var height := frame_size.y * squash
	draw_set_transform(Vector2.ZERO, 0, Vector2(facing, 1))
	draw_texture_rect_region(texture, Rect2(-frame_size.x / 2, 6 - height, frame_size.x, height), Rect2(frame * frame_size.x, 0, frame_size.x, frame_size.y), tint)
	draw_set_transform(Vector2.ZERO)

## Drawing the tell must not reroll or consume the upcoming attack.
func telegraph_attack() -> String:
	return forced_attack if not forced_attack.is_empty() else planned_attack

func _draw() -> void:
	if is_dead:
		# Kneeling, alive: Kael's idle pressed down.
		draw_kael(KAEL_IDLE, 1, 0, Color("c9b6d1"), 0.7)
		return
	var tint := Color("f2d3ab") if is_vulnerable else Color.WHITE
	var winding_up := current_phase == Phase.TELEGRAPH and phase_left < 0.3 and telegraph_attack() != "call"
	if current_phase in [Phase.RUSH, Phase.RELEASE]:
		draw_kael(KAEL_ATTACK, 2, 1, tint)
	elif winding_up:
		draw_kael(KAEL_ATTACK, 2, 0, tint)
	elif current_phase in [Phase.RETREAT, Phase.REPOSITION]:
		draw_kael(KAEL_WALK, 2, int(time * 8) % 2, tint)
	else:
		draw_kael(KAEL_IDLE, 1, 0, tint)
	var cue := "RECOVER" if is_vulnerable else ("RETREATING" if current_phase == Phase.RETREAT else ("FLANK" if current_phase == Phase.REPOSITION else telegraph_attack().to_upper()))
	draw_string(ThemeDB.fallback_font, Vector2(-30, -43), "NIRO · " + cue, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("fbf5ef"))
	for index in range(health):
		draw_rect(Rect2(-36 + index * 6, -36, 4, 3), Color("f2d3ab"))
	if current_phase == Phase.TELEGRAPH:
		draw_line(Vector2(0, 8), Vector2(facing * 90, 8), Color("c69fa5"), 2)
	if projectile_live:
		draw_circle(to_local(projectile), 4, Color("fbf5ef"))
