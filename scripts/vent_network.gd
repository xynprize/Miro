extends Node
## Offset openings link adjacent storeys. Closed milestone gates still divide the duct.
var features: Node
var current: Node2D
var previous_axis := 0

func setup(owner_features: Node) -> void:
	features = owner_features
	var level: Node = features.level
	var rows: Array = level.definition.get("storeys", []) if level.get("definition") != null else []
	if rows.is_empty():rows = [252.0,448.0,672.0,868.0]
	for floor_y in rows:
		var y := float(floor_y) - 16.0
		if features.props.any(func(p): return p.kind == "hide" and absf(p.position.y-y)<32):continue
		for x in range(180, int(level.definition.get("world_size", [1120,900])[0]) - 80, 28) if level.get("definition") != null else range(180,1040,28):
			var point := Vector2(float(x),y)
			if features.floor_number == 1 and y < 280 and point.x < 300:continue
			if features.placement_clear(point) and features.vent_wall_clear(point) and not features.spot_taken(point,"hide") and level.has_floor_below(point+Vector2(0,13)):
				features.spawn_prop(point,"hide","VENT")
				break
	for art in level.get_children():
		if art.has_method("prepare_furniture"):
			art.refresh_fixture_clearance()
			art.furniture_cache.clear()
			art.furniture_rects.clear()
			art.prepare_furniture()
		if art is CanvasItem:art.queue_redraw()

func enter(vent: Node2D) -> void:
	current = vent
	previous_axis = 0
	features.level.player.global_position = vent.global_position

func opening(direction: int) -> Node2D:
	if not is_instance_valid(current):return null
	var target: Node2D
	var nearest_y := INF
	var nearest_x := INF
	for prop in features.props:
		if not is_instance_valid(prop) or prop.kind != "hide":continue
		var dy: float = (prop.global_position.y-current.global_position.y)*direction
		if dy < 80:continue
		var dx: float = absf(prop.global_position.x-current.global_position.x)
		if dy < nearest_y-32 or (absf(dy-nearest_y)<32 and dx<nearest_x):
			target=prop
			nearest_y=dy
			nearest_x=dx
	return target

func passage_open(target: Node2D) -> bool:
	var level: Node = features.level
	if features.floor_number == 1 and not level.door_open:return false
	if level.get("definition") != null:
		var rows: Array = level.definition.get("storeys", [])
		var from_row: int = features.security_storey(current.global_position.y)
		var to_row: int = features.security_storey(target.global_position.y)
		if absi(to_row-from_row) != 1:return false
		if to_row > from_row:
			for station in level.definition.stations:
				if not level.milestones.has(station.id) and float(station.position[1]) < target.global_position.y-100.0:
					level.notify("Duct locked: %s first." % station.title)
					return false
	var gates := level.get_node_or_null("Gates")
	if gates != null:
		for gate in gates.get_children():
			if gate.is_open:continue
			var horizontal: bool = gate.gate_size.x > gate.gate_size.y
			var a: float = current.global_position.y if horizontal else current.global_position.x
			var b: float = target.global_position.y if horizontal else target.global_position.x
			var boundary: float = gate.global_position.y if horizontal else gate.global_position.x
			if (a-boundary)*(b-boundary)<=0:return false
	return true

func tick() -> void:
	if not features.level.player.in_hiding_spot:return
	var axis := int(signf(Input.get_axis("climb_up","climb_down")))
	if axis != 0 and previous_axis == 0:
		travel(axis)
	previous_axis = axis

func travel(direction: int) -> bool:
	var target := opening(direction)
	if target == null:return false
	if not passage_open(target):
		if features.level.message_left <= 0:features.level.notify("The duct is sealed beyond the checkpoint.")
		return false
	current=target
	features.level.player.global_position=target.global_position
	features.level.notify("Vent opening reached. [E] Exit · W/S travel")
	return true
