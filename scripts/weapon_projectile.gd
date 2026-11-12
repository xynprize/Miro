extends Node2D
const TURRET_LAYER := 1 << 6
## Swept collision prevents fast rounds from tunneling through thin walls.
var level: Node2D
var shooter: CollisionObject2D
var direction := Vector2.RIGHT
var speed := 700.0
var remaining := 420.0
var damage := 2
var enemy := false
var niro_round := false
var override_turret: Node2D
var crossfire := false
## SMG rounds lose punch over distance (down to 40% at long range); pistols don't.
var falloff := false
var travelled := 0.0
var sprite: Texture2D
var trail_start := Vector2.ZERO

func _ready() -> void:
	trail_start = position

func _physics_process(delta: float) -> void:
	if override_turret != null and (not is_instance_valid(override_turret) or override_turret.hack_left <= 0.0 or override_turret.disabled):
		queue_free()
		return
	if not is_instance_valid(level) or level.controls_locked():
		return
	var distance := minf(remaining, speed * delta)
	var destination := global_position + direction * distance
	var query := PhysicsRayQueryParameters2D.create(global_position, destination, 1 | (2 if enemy else 4 | TURRET_LAYER))
	query.hit_from_inside = true
	query.collide_with_areas = not enemy
	if is_instance_valid(shooter):
		query.exclude = [shooter.get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if enemy or crossfire:
		var player_hit := find_player_hit(level.player, global_position, hit.position if not hit.is_empty() else destination)
		if not player_hit.is_empty():
			hit = player_hit
	if not enemy and strike_guard(global_position, hit.position if not hit.is_empty() else destination):
		queue_free()
		return
	if not hit.is_empty():
		global_position = hit.position
		var target = hit.collider
		if target is IntroGuard and not target.is_dead:
			target.take_damage(1 if niro_round and target.has_method("begin_recovery") else guard_damage(target, hit.position), true)
		elif not enemy and target.is_in_group("tower_turrets"):
			target.take_turret_hit()
			queue_free()
			return
		elif (enemy or crossfire) and target is IntroPlayer and target.controls.guitar_guarding():
			# Holding guitar guard turns a shot back toward whoever fired it.
			enemy = false
			shooter = target
			direction = -direction
			remaining = 300.0
			position = hit.position + direction * 6.0
			level.emit_effect("hit", global_position)
			get_node("/root/SoundFX").play_near("hit", global_position, level.player.global_position, -10, 560.0, 1.6)
			return
		elif (enemy or crossfire) and target is IntroPlayer:
			# A pistol round or a turret bolt takes a heart; an SMG round takes half of one.
			var smg: bool = is_instance_valid(shooter) and shooter.get("weapon_kind") == "smg"
			target.take_damage(player_damage(target, hit.position, smg))
		level.emit_effect("hit", global_position)
		queue_free()
		return
	global_position = destination
	remaining -= distance
	travelled += distance
	queue_redraw()
	if remaining <= 0:
		queue_free()

func _draw() -> void:
	if sprite:
		draw_texture(sprite, -sprite.get_size() / 2.0)
	else:
		draw_line(-direction * 10, Vector2.ZERO, Color("f2d3ab"), 2)

## Guards are hit by where the round actually passes, not just their collision capsule:
## the head (a generous box) is an instant kill and the body box reaches out over the
## gun they hold, so a Keeper's weapon never blocks a shot at him. Walls and beds still do.
func shot_damage() -> int:
	if not falloff:
		return damage
	return maxi(1, roundi(float(damage) * (1.0 - 0.6 * clampf(travelled / 320.0, 0.0, 1.0))))

## Visual hit regions include the head above the physics capsule, for both postures.
static func player_zone(player: Node2D, point: Vector2) -> String:
	var local := point - player.global_position
	if player.get("crouching"):
		if Rect2(-8, -12, 16, 9).has_point(local):
			return "head"
		if Rect2(-8, -3, 16, 12).has_point(local):
			return "body"
		if Rect2(-7, 9, 14, 9).has_point(local):
			return "legs"
	else:
		if Rect2(-8, -26, 16, 14).has_point(local):
			return "head"
		if Rect2(-8, -12, 16, 18).has_point(local):
			return "body"
		if Rect2(-7, 6, 14, 12).has_point(local):
			return "legs"
	return ""

static func find_player_hit(player: Node2D, from: Vector2, to: Vector2) -> Dictionary:
	if not is_instance_valid(player) or player.get("is_dead"):
		return {}
	var steps := maxi(1, ceili(from.distance_to(to) / 2.0))
	for index in range(steps + 1):
		var point := from.lerp(to, float(index) / steps)
		if not player_zone(player, point).is_empty():
			return {"collider": player, "position": point}
	return {}

static func player_damage(player: Node2D, point: Vector2, smg := false) -> int:
	match player_zone(player, point):
		"head": return 3 if smg else 4
		"legs": return 1
		_: return 2

func guard_damage(guard: Node2D, point: Vector2) -> int:
	var local := point - guard.global_position
	var head := Rect2(-9, -30, 18, 14).has_point(local)
	if guard.has_method("begin_recovery"):
		return 3 if head else (1 if local.y >= 7 else 2)
	if head:
		return 99
	return maxi(1, floori(shot_damage() * 0.5)) if local.y >= 7 else shot_damage()

func strike_guard(from: Vector2, to: Vector2) -> bool:
	var length := from.distance_to(to)
	var steps := maxi(1, ceili(length / 2.0))
	# Build a conservative broad phase once; preserve legacy sample spacing and tree order.
	var candidates: Array[Node] = []
	var sweep := Rect2(from, to - from).abs().grow(0.01)
	for guard in level.guards():
		if not is_instance_valid(guard) or guard.is_dead or guard == shooter or not guard is IntroGuard: continue
		var bounds := Rect2(guard.global_position + Vector2(-24, -30), Vector2(48, 48))
		if sweep.intersects(bounds.grow(0.01)): candidates.append(guard)
	for step in range(steps + 1):
		var point := from.lerp(to, float(step) / steps)
		for guard in candidates:
			if not is_instance_valid(guard) or guard.is_dead or guard == shooter or not guard is IntroGuard:
				continue
			var local: Vector2 = point - guard.global_position
			var reach := 14.0
			var body := Rect2(-10.0 - (reach if guard.facing < 0 else 0.0), -22.0, 20.0 + reach, 40.0)
			var head := Rect2(-9.0, -30.0, 18.0, 14.0)
			if head.has_point(local) or body.has_point(local):
				guard.damage_origin = shooter.global_position if is_instance_valid(shooter) else from-direction*20.0
				# Regular Keeper headshots retain their existing lethal hit; Niro respects recovery.
				if head.has_point(local) and not guard.has_method("begin_recovery"):
					guard.invulnerability_left = 0.0
				guard.take_damage(guard_damage(guard, point), true)
				level.emit_effect("hit", point)
				return true
	return false
