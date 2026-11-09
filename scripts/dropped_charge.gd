extends Node2D
var velocity := Vector2.ZERO
func _physics_process(delta: float) -> void:
	if get_parent().controls_locked():
		return
	velocity.y += 500 * delta
	var target := global_position + velocity * delta
	var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, target + Vector2(0, 4), 1))
	if hit.is_empty():
		global_position = target
	else:
		global_position = hit.position - Vector2(0, 4)
		velocity = Vector2.ZERO
func _draw() -> void:
	draw_texture_rect(preload("res://assets/weapons/c4.svg"), Rect2(-7, -7, 14, 14), false)
