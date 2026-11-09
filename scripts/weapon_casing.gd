extends Node2D
var level: Node2D
var velocity := Vector2.ZERO
var lifetime := 0.45
func _physics_process(delta: float) -> void:
	if not is_instance_valid(level) or level.controls_locked():
		return
	lifetime -= delta
	velocity.y += 380 * delta
	var next := position + velocity * delta
	var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, level.to_global(next), 1))
	if hit.is_empty():
		position = next
		rotation += delta * 12
	else:
		velocity = Vector2.ZERO
	modulate.a = minf(1, lifetime * 3)
	if lifetime <= 0:
		queue_free()
func _draw() -> void:
	draw_texture_rect(preload("res://assets/weapons/casing.svg"), Rect2(-3, -2, 6, 4), false)
