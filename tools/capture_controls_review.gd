extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func save(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func capture() -> void:
	var level = load("res://scenes/levels/level_02.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(5)
	level.finish_dialogue()
	# Review fixture uses real loot, inventory and terminal paths.
	var guards = level.guards()
	for guard in guards:
		guard.set_physics_process(false)
	guards[0].die()
	guards[1].die()
	level.player.loot_weapon(guards[0])
	level.player.loot_weapon(guards[1])
	var controls = level.player.controls
	controls.collect_remote()
	controls.sync_slots()
	controls.select_item("pistol")
	controls.collect_suppressor()
	await frames(4)
	await save("res://tmp/final-hotbar.png")
	controls.show_inventory()
	await frames(3)
	await save("res://tmp/final-inventory.png")
	controls.close_panels()
	level.player.position = level.world_features.access_point
	controls.open_remote()
	controls.run_command("hack")
	controls.run_command("scan")
	await frames(3)
	await save("res://tmp/final-remote.png")
	controls.close_panels()
	level.paused = true
	await frames(3)
	await save("res://tmp/final-pause.png")
	level.queue_free()
	await frames(3)
	root.get_node("MusicDirector").silence()
	quit()
