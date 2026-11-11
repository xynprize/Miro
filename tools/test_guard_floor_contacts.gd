extends SceneTree
var overlaps: Array=[]
var samples := 0
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func run() -> void:
	for number in range(1,6):
		root.get_node("Campaign").checkpoint.clear()
		var path := "res://scenes/intro.tscn" if number==1 else "res://scenes/levels/level_%02d.tscn" % number
		var level=load(path).instantiate()
		root.add_child(level)
		current_scene=level
		await frames(3)
		level.finish_dialogue()
		var queries: Dictionary={}
		for guard in level.guards():
			var body=guard.get_node_or_null("CollisionShape2D")
			if body==null or body.disabled or body.shape==null: continue
			var inner=body.shape.duplicate()
			if inner is RectangleShape2D: inner.size-=Vector2(2,2)
			elif inner is CapsuleShape2D:
				inner.radius=maxf(0.5,inner.radius-1.0)
				inner.height=maxf(inner.radius*2.0,inner.height-2.0)
			var query:=PhysicsShapeQueryParameters2D.new()
			query.shape=inner
			query.collision_mask=1
			query.exclude=[guard.get_rid()]
			queries[guard]=query
		for tick in range(600):
			if not level.dialogue.is_empty(): level.finish_dialogue()
			level.player.health=10000
			level.player.is_dead=false
			if tick==180:
				for guard in level.guards(): guard.investigate(level.player.global_position)
			await frames(1)
			for guard in queries:
				if not is_instance_valid(guard) or guard.is_dead: continue
				var query=queries[guard]
				query.transform=guard.get_node("CollisionShape2D").global_transform
				var hits: Array=guard.get_world_2d().direct_space_state.intersect_shape(query,4)
				samples+=1
				if not hits.is_empty() and overlaps.size()<100:
					overlaps.append({"floor":number,"tick":tick,"guard":guard.name,"position":str(guard.global_position),"collider":str(hits[0].collider.get_path())})
		queries.clear()
		level.queue_free()
		current_scene=null
		await frames(4)
	var file:=FileAccess.open("user://guard-floor-contacts.json",FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"samples":samples,"overlaps":overlaps},"\t"))
	print("GUARD_FLOOR_CONTACT_RESULT: samples=",samples," solid_penetrations_over_1px=",overlaps.size())
	if not overlaps.is_empty(): push_error("FAIL: "+JSON.stringify(overlaps.slice(0,10)))
	quit(0 if overlaps.is_empty() else 1)
