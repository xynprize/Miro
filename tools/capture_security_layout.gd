extends SceneTree
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in range(n):await process_frame
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://tmp/security-layout")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for number in range(1,6):
		root.get_node("Campaign").checkpoint.clear()
		var level = load("res://scenes/intro.tscn" if number==1 else "res://scenes/levels/level_%02d.tscn" % number).instantiate()
		root.add_child(level)
		current_scene = level
		await frames(12)
		level.finish_dialogue()
		level.player.set_physics_process(false)
		for guard in level.guards():guard.set_physics_process(false)
		level.hud.visible = false
		var size := Vector2i(1120,756) if number==1 else Vector2i(level.definition.world_size[0],level.definition.world_size[1])
		root.size = size
		var camera := Camera2D.new()
		camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
		level.add_child(camera)
		camera.make_current()
		await frames(12)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/security-layout/level-%d.png" % number)
		if number == 3:
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
			root.size = Vector2i(1280,720)
			level.player.position = level.areas.get_node("RemoteTerminal").position-Vector2(200,0)
			var c = level.player.controls
			c.has_remote = true
			c.remote_unlocked = true
			level.world_features.terminal_authenticated = true
			level.hud.visible = true
			c.security().execute("cameras hack")
			await frames(12)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tmp/security-layout/camera-feed.png")
			c.security().stop_view()
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		level.queue_free()
		await frames(3)
	print("SECURITY_LAYOUT_CAPTURE_RESULT: 5/5")
	quit()
