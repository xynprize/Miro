extends Area2D
## docs/class.md: SecurityCamera; docs/mirospec.md: Level 3 checkpoint.
@export var detection_range := 210.0
@export var half_angle := 0.48
@export var facing_angle := 1.57
var is_active := true
var sweep_time := 0.0
var alert_cooldown := 0.0
var level: Node
var cone_points := PackedVector2Array()
const WATCHER := preload("res://assets/environment/watcher_animation.png")

const PROJECTILE := preload("res://scripts/weapon_projectile.gd")
## A moss watcher has 1 HP (two hit points of damage): two shots, one stab, or any C4.
var health := 2
var disabled := false:
	get:
		return not is_active

func _ready() -> void:
	add_to_group("security_cameras")
	add_to_group("tower_turrets")
	collision_layer = PROJECTILE.TURRET_LAYER
	collision_mask = 0
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(26, 25)
	collider.shape = shape
	add_child(collider)

func target_point() -> Vector2:
	return global_position

func take_turret_hit(amount := 1) -> void:
	if health <= 0:
		return
	level.make_noise(global_position, 600.0)
	health = maxi(0, health - amount)
	level.emit_effect("hit", global_position)
	if health <= 0:
		var campaign = get_node_or_null("/root/Campaign")
		if campaign != null:
			campaign.unlock_achievement("destroy_mosswatcher")
			campaign.add_track_unlock("relapse_3")
	if health <= 0:
		if level.has_method("record_security_checkpoint"): level.record_security_checkpoint(self, true)
		queue_free()

func stun() -> bool:
	return false

func _physics_process(delta: float) -> void:
	if not is_active or level.controls_locked():
		return
	sweep_time += delta
	cone_points = PackedVector2Array([Vector2.ZERO])
	for index in range(25):
		var tip := global_position + Vector2.from_angle(direction_angle() - half_angle + 2 * half_angle * index / 24.0) * detection_range
		var query := PhysicsRayQueryParameters2D.create(global_position, tip, 1)
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		cone_points.append(to_local(hit.position if not hit.is_empty() else tip))
	alert_cooldown = maxf(0, alert_cooldown - delta)
	if detects_player() and alert_cooldown <= 0:
		alert_cooldown = 2.0
		level.camera_alert(level.player.global_position)
	queue_redraw()

## With music playing, one full sweep takes four bars and turns on the downbeat.
func direction_angle() -> float:
	var clock = get_node_or_null("/root/MusicDirector")
	if clock != null and clock.bpm() > 0:
		return facing_angle + sin(clock.beat_position() / 16.0 * TAU) * 0.4
	return facing_angle + sin(sweep_time * 0.7) * 0.4

func detects_player() -> bool:
	if not is_active or level.player.is_dead or (level.player.is_concealed or level.player.in_hiding_spot):
		return false
	var offset: Vector2 = level.player.global_position - global_position
	return offset.length() <= detection_range and absf(wrapf(offset.angle() - direction_angle(), -PI, PI)) <= half_angle and level.clear_sight(global_position, level.player.global_position)

func disable() -> void:
	if level.has_method("record_security_checkpoint"): level.record_security_checkpoint(self, false)
	is_active = false
	queue_redraw()
	var campaign = get_node_or_null("/root/Campaign")
	if campaign == null:
		return
	campaign.on_security_disabled("camera", position)

func _draw() -> void:
	if is_active and cone_points.size() > 2:
		draw_colored_polygon(cone_points, Color(0.95, 0.83, 0.67, 0.12))
	var blink := fposmod(sweep_time + position.x / 180.0, 4.0)
	var frame := 2 if not is_active else (mini(4, int(blink / 0.1)) if blink < 0.5 else 0)
	draw_texture_rect_region(WATCHER, Rect2(-13, -12, 26, 25), Rect2(frame * 26, 0, 26, 25))
	if is_active and alert_cooldown > 1.3:
		draw_rect(Rect2(-1, -23, 2, 6), Color("f2d3ab"))
		draw_rect(Rect2(-1, -16, 2, 2), Color("f2d3ab"))
