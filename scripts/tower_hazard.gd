extends Area2D
## Local up points away from the mounting surface. Aim is stored in world space.
const SPIKES := preload("res://assets/environment/spike_trap.png")
const BASE := preload("res://assets/environment/turret_body.png")
const HEAD := preload("res://assets/environment/turret_head.png")
const ROUND := preload("res://assets/misc/turret_projectile.png")
const PROJECTILE := preload("res://scripts/weapon_projectile.gd")
const PIVOT := Vector2(0, -17)
const RANGE := 185.0
const HACK_GUARD_RANGE := 360.0
const STUN_TIME := 5.0

var level: Node2D
var kind := "spikes"
var aim := PI
var charge := 0.0
## 5 HP: ten shots, five stabs, or any C4.
var health := 10
var disabled := false
var stun_left := 0.0
var hack_left := 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	if kind == "spikes":
		add_to_group("lethal_spikes")
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		# Long enough that wall spikes above a crawl gap catch a standing Miro's head;
		# crouching slips under.
		shape.size = Vector2(32, 9)
		collider.shape = shape
		collider.position.y = -4.5
		add_child(collider)
	else:
		aim = global_rotation + PI
		add_to_group("tower_turrets")
		collision_layer = PROJECTILE.TURRET_LAYER
		collision_mask = 0
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(24, 23)
		collider.shape = shape
		collider.position.y = -12
		add_child(collider)

func _physics_process(delta: float) -> void:
	if level.controls_locked() or level.player.is_dead:
		return
	if kind == "spikes":
		if overlaps_body(level.player):
			level.player.health = 0
			level.player.die()
		return
	stun_left = maxf(0.0, stun_left - delta)
	hack_left = maxf(0.0, hack_left - delta)
	if health <= 0 or disabled or stun_left > 0.0:
		queue_redraw()
		return
	var muzzle := target_point()
	if hack_left > 0.0:
		var victim: Node2D
		var nearest := HACK_GUARD_RANGE
		for guard in level.guards():
			if guard.is_dead or guard.asleep:continue
			var gap: float = muzzle.distance_to(guard.global_position)
			if gap < nearest and level.clear_sight(muzzle, guard.global_position):
				victim = guard
				nearest = gap
		var player_gap: float = muzzle.distance_to(level.player.global_position)
		if player_gap < RANGE and player_gap < nearest and not level.player.is_concealed and not level.player.in_hiding_spot and level.clear_sight(muzzle, level.player.global_position):
			victim = level.player
		if victim != null:
			aim = rotate_toward(aim, (victim.global_position-muzzle).angle(), delta * 4.0)
			if absf(angle_difference(aim, (victim.global_position-muzzle).angle())) < 0.08:
				charge += delta
				if charge >= 0.4:
					charge = 0.0
					var shot := Node2D.new()
					shot.set_script(PROJECTILE)
					shot.level = level
					shot.shooter = self
					shot.override_turret = self
					shot.crossfire = true
					shot.niro_round = true
					shot.damage = 1
					shot.position = level.to_local(muzzle)
					shot.direction = Vector2.from_angle(aim)
					shot.remaining = HACK_GUARD_RANGE
					shot.sprite = ROUND
					level.add_child(shot)
		else:charge = 0.0
		queue_redraw()
		return
	var offset: Vector2 = level.player.global_position - muzzle
	# Turrets read heat and motion in the open: the blanket, a hiding spot or a patch of
	# shadow hides Miro from them.
	if offset.length() > RANGE or level.player.is_concealed or level.player.in_hiding_spot or not level.clear_sight(muzzle, level.player.global_position):
		charge = 0.0
	else:
		aim = rotate_toward(aim, offset.angle(), delta * 4.0)
		if absf(angle_difference(aim, offset.angle())) < 0.08:
			charge += delta
			if charge >= 0.8:
				charge = 0.0
				var shot := Node2D.new()
				shot.set_script(PROJECTILE)
				shot.level = level
				shot.position = level.to_local(muzzle)
				shot.direction = Vector2.from_angle(aim)
				shot.enemy = true
				shot.remaining = RANGE
				shot.sprite = ROUND
				level.add_child(shot)
	queue_redraw()

func target_point() -> Vector2:
	return to_global(PIVOT)

func take_turret_hit(amount := 1) -> void:
	if health <= 0:
		return
	health = maxi(0, health - amount)
	level.emit_effect("hit", target_point())
	if health <= 0:
		# Achievement wiring for destruction, including C4 overkill.
		var campaign = get_node_or_null("/root/Campaign")
		if campaign != null:
			if kind == "turret":
				campaign.unlock_achievement("destroy_turret")
				campaign.add_track_unlock("qwella1")
	if health <= 0:
		if level.has_method("record_security_checkpoint"): level.record_security_checkpoint(self, true)
		queue_free()

func disable() -> void:
	if level.has_method("record_security_checkpoint"): level.record_security_checkpoint(self, false)
	disabled = true
	charge = 0.0
	queue_redraw()
	var campaign = get_node_or_null("/root/Campaign")
	if campaign == null:
		return
	campaign.on_security_disabled(kind, get_meta("security_origin", position))

func stun() -> bool:
	if disabled or health <= 0:
		return false
	stun_left = STUN_TIME
	charge = 0.0
	queue_redraw()
	return true

func _draw() -> void:
	if kind == "spikes":
		draw_texture(SPIKES, Vector2(-16, -32))
		return
	draw_texture(BASE, Vector2(-16, -30))
	draw_set_transform(PIVOT, aim - global_rotation - PI)
	var head_color := Color("f2d3ab") if charge > 0.5 else Color.WHITE
	if disabled:
		head_color = Color("656879")
	elif stun_left > 0.0:
		head_color = Color("8bb5c9")
	draw_texture(HEAD, Vector2(-25, -14), head_color)
	draw_set_transform(Vector2.ZERO)
	if health < 3:
		for pip in range(3):
			draw_rect(Rect2(-8 + pip * 6, -33, 4, 2), Color("f2d3ab") if pip < health else Color("494d7e"))
