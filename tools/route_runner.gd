extends RefCounted
## Plays a level's authored route (data/levels/level_0N.json "route", written by
## tools/level_layouts.py) with real inputs: walking, auto-jumping steps, crouching through
## crawlspaces, climbing ladders and using each objective. Used by the level tests and the
## exported playthrough, so every authored floor is proven completable.
var host
var level
var fight := true

func _init(owner) -> void:
	host = owner

func frames(count: int) -> void:
	await host.frames(count)

func crouch(down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_CTRL
	event.keycode = KEY_CTRL
	event.pressed = down
	Input.parse_input_event(event)

func release_all() -> void:
	for action in ["move_left", "move_right", "jump", "climb_up", "climb_down"]:
		Input.action_release(action)

func walk(x: float, crouched := false, limit := 2400) -> bool:
	var p = level.player
	var count := 0
	var best := absf(p.position.x - x)
	var stalled := 0
	if crouched:
		crouch(true)
		await frames(2)
	while absf(p.position.x - x) > 4 and count < limit and not p.is_dead:
		if level.controls_locked():
			level.finish_dialogue()
		var right: bool = x > p.position.x
		Input.action_press("move_right" if right else "move_left")
		Input.action_release("move_left" if right else "move_right")
		var blocked: bool = p.is_on_wall() or stalled > 20
		var spike_ahead := false
		if not crouched and p.is_on_floor():
			for hazard in level.get_tree().get_nodes_in_group("lethal_spikes"):
				if not is_zero_approx(hazard.rotation):
					continue
				var gap: Vector2 = hazard.global_position - p.global_position
				var ahead := gap.x * (1.0 if right else -1.0)
				if ahead > 0 and ahead < 30 and absf(gap.y - 15.0) < 12:
					spike_ahead = true
					break
		if spike_ahead or (not crouched and blocked and (p.is_on_floor() or (p.jumps_used == 1 and p.velocity.y > -20 and p.double_jump_cooldown_left <= 0.0))):
			Input.action_press("jump")
		else:
			Input.action_release("jump")
		if fight:
			for guard in level.guards():
				if not guard.is_dead and not guard.asleep and p.position.distance_to(guard.position) < 44:
					p.facing = signf(guard.position.x - p.position.x)
					p.shank()
		await frames(1)
		count += 1
		var distance := absf(p.position.x - x)
		if distance < best - 0.5:
			best = distance
			stalled = 0
		else:
			stalled += 1
	release_all()
	if crouched:
		crouch(false)
	for i in range(60):
		if p.is_on_floor() or p.climbing:
			break
		await frames(1)
	await frames(2)
	print("ROUTE walk target=", x, " actual=", p.position, " hp=", p.health)
	return absf(p.position.x - x) <= 8 and not p.is_dead

func climb(ladder_name: String, floor_y: float) -> bool:
	var ladder = level.areas.get_node(ladder_name)
	if not await walk(ladder.global_position.x):
		return false
	var p = level.player
	var down: bool = floor_y > p.position.y
	Input.action_press("climb_down" if down else "climb_up")
	for tick in range(900):
		await frames(1)
		if down and p.position.y > floor_y - 30 and p.is_on_floor():
			break
		if p.is_dead:
			break
	release_all()
	await frames(4)
	print("ROUTE climb ", ladder_name, " -> ", p.position)
	return absf(p.position.y - (floor_y - 14)) < 10 and not p.is_dead

func fall(floor_y: float) -> bool:
	var p = level.player
	for tick in range(240):
		if p.is_on_floor() and p.position.y > floor_y - 30:
			break
		await frames(1)
	return absf(p.position.y - (floor_y - 14)) < 10

func use_station(id: String) -> bool:
	var station: Dictionary = {}
	for entry in level.definition.stations:
		if entry.id == id:
			station = entry
	if not await walk(float(station.position[0])):
		return false
	await frames(6)
	# A guard who followed this combat route can intercept E with a takedown
	# or loot action. Finish that real interaction before trying the station.
	for attempt in range(20):
		if attempt==19:
			var prop = level.world_features.nearby_prop()
			print("ROUTE_INTERACTION_DIAGNOSTIC id=",id," hint=",level.context_hint()," hidden=",level.player.in_hiding_spot," locked=",level.controls_locked()," prop=",prop.kind if prop!=null else "none", " message=",level.message," milestones=",level.milestones)
		level.interact()
		if id == "RemoteTerminal":
			level.world_features.submit_password("root")
			await frames(70)
		if not level.dialogue.is_empty(): level.finish_dialogue()
		if level.milestones.has(id): break
		await frames(30)
	await frames(2)
	print("ROUTE station ", id, " done=", level.milestones.has(id))
	return level.milestones.has(id)

## Returns the list of failed step descriptions (empty when the whole route worked).
func follow(owner_level) -> Array[String]:
	level = owner_level
	var failed: Array[String] = []
	for step in level.definition.get("route", []):
		var ok := true
		var label := JSON.stringify(step)
		if step.has("station"):
			ok = await use_station(step.station)
		elif step.has("climb"):
			ok = await climb(step.climb, float(step.to))
		elif step.has("fall"):
			ok = await fall(float(step.fall))
		elif step.has("x"):
			ok = await walk(float(step.x), step.get("crouch", false))
		elif step.has("exit"):
			level.interact()
			await frames(2)
			ok = level.completed
		if not ok:
			failed.append(label)
			push_error("ROUTE FAILED: " + label + " at " + str(level.player.position))
			break
	return failed
