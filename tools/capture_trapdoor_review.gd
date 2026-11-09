extends "res://tools/capture_controls_review.gd"
func capture() -> void:
	var level = load("res://scenes/intro.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(5)
	level.finish_dialogue()
	level.interact()
	level.finish_dialogue()
	for guard in level.guards():
		guard.set_physics_process(false)
	var hatch = level.world_features.trapdoors[1]
	level.player.position = hatch.position + Vector2(0, -28)
	await frames(35)
	level.interact()
	await frames(5)
	await save("res://tmp/trapdoor-open.png")
	level.queue_free()
	await frames(3)
	root.get_node("MusicDirector").silence()
	quit()
