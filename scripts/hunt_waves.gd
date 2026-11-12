extends Node
## Level 4: the tower knows Miro is out of his cell. The start of the floor cloaks him while a
## first wave of Keepers runs past and through the door, searching other rooms; then the cloak
## fades and waves of hunting Keepers rush him (stealth routes: vents, crates, shadows).
const FIRST_WAVE_SIZE := 5
const WAVE_SIZE := 5
const WAVE_GAP := 32.0
const MAX_WAVES := 3
const CLOAK_TIME := 11.0
var level: Node
var runners: Array = []
var wave_guards: Array = []
var clock := 0.0
var waves_sent := 0
var next_wave_at := 0.0
var run_done := false
var thoughts_said := 0
var floor_waved := {}
var next_keeper := 0

var started := false
var world_width := 1680.0

func _ready() -> void:
	next_wave_at = CLOAK_TIME + 3.0
	world_width = float(level.definition.world_size[0])

func begin() -> void:
	started = true
	level.player.respawn_cloak_left = CLOAK_TIME
	level.notify("A cold quiet. The cloak holds you.", 4.0)
	send_runners()

func send_runners() -> void:
	var player = level.player
	var y: float = player.position.y
	for index in range(FIRST_WAVE_SIZE):
		var guard = load("res://scenes/guard.tscn").instantiate()
		guard.position = Vector2(player.position.x - 60 - index * 46, y)
		guard.level = level
		guard.illness_started = true
		guard.weapon_kind = "pistol"
		name_reinforcement(guard)
		level.get_node("Guards").add_child(guard)
		guard.set_physics_process(false)
		guard.collision_layer = 0
		guard.collision_mask = 0
		guard.facing = 1
		guard.velocity = Vector2(150.0, 0)
		runners.append(guard)

func _physics_process(delta: float) -> void:
	# Headless regression runs drive the other floors by hand; only the hunt test opts in.
	if DisplayServer.get_name() == "headless" and not level.has_meta("hunt_waves_test"):
		return
	if level.controls_locked() or level.player.is_dead or level.completed:
		return
	if not started:
		begin()
	clock += delta
	for guard in runners:
		if is_instance_valid(guard):
			# Scripted runners skip IntroGuard physics, so advance its animation
			# clock and publish the movement velocity used by its sprite selection.
			guard.velocity = Vector2(150.0, 0)
			guard.time += delta
			guard.position += guard.velocity * delta
			guard.queue_redraw()
			guard.facing = 1
			if guard.position.x > world_width - 220:
				guard.queue_free()
	if clock > 2.0 and thoughts_said == 0:
		thoughts_said = 1
		level.world_features.think(thought_line(0))
	elif clock > 7.5 and thoughts_said == 1:
		thoughts_said = 2
		level.world_features.think(thought_line(1))
	elif clock > CLOAK_TIME + 0.5 and thoughts_said == 2:
		thoughts_said = 3
		level.notify("The cloak fades. More Keepers are coming.", 4.0)
	# A fresh wave rushes the last floors (the sigil floors) the first time Miro steps onto each.
	var depth := 0
	for storey in level.definition.get("storeys", []):
		if float(storey) <= level.player.position.y + 24.0:
			depth += 1
	if depth >= 5 and not floor_waved.has(depth) and clock > CLOAK_TIME + 2.0:
		floor_waved[depth] = true
		send_wave()
	if clock >= next_wave_at and waves_sent < MAX_WAVES and wave_clear():
		send_wave()
		next_wave_at = clock + WAVE_GAP

## Miro's thoughts for the pass-by (data/interludes.json, voiced like his other thoughts).
func thought_line(index: int) -> String:
	var lines: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/interludes.json")).hunt_thoughts
	return str(lines[index])

## Keepers never stack: every new spawn point keeps 44 px from the others.
func spread(points: Array) -> Array:
	var placed: Array = []
	for point in points:
		var x: float = point
		var tries := 0
		while placed.any(func(other): return absf(other - x) < 44.0) and tries < 40:
			x += 44.0 if (tries % 2 == 0) else -88.0
			tries += 1
		placed.append(clampf(x, 120.0, world_width - 120.0))
	return placed

func wave_clear() -> bool:
	return wave_guards.all(func(guard): return not is_instance_valid(guard) or guard.is_dead or guard.asleep or guard.alert_state == 0)

func name_reinforcement(guard: Node) -> void:
	# Reinforcement identities are unique; a named Keeper cannot die and return in the next wave.
	var names: Array = level.world_features.roster.get("hunt_reinforcements",[])
	if next_keeper < names.size():level.world_features.assign_keeper(guard,str(names[next_keeper]))
	next_keeper += 1

func send_wave() -> void:
	var player_row: float = level.player.position.y
	var nearby: Array = level.guards().filter(func(g):return not runners.has(g) and not g.is_dead and not g.asleep and absf(g.position.y-player_row)<48 and absf(g.position.x-level.player.position.x)<220)
	if nearby.size() >= 4:return
	waves_sent += 1
	wave_guards.clear()
	var player = level.player
	var count := WAVE_SIZE + int(level.get_node("/root/Campaign").tuning().wave_extra)
	var xs: Array = []
	for index in range(maxi(1, count)):
		xs.append(clampf(player.position.x + (-1.0 if index % 2 == 0 else 1.0) * (520 + index * 40), 120, world_width - 120))
	xs = spread(xs)
	for index in range(maxi(1, count)):
		var guard = load("res://scenes/guard.tscn").instantiate()
		guard.position = Vector2(xs[index], player.position.y)
		guard.patrol_left = guard.position.x - 80
		guard.patrol_right = guard.position.x + 80
		guard.level = level
		guard.illness_started = true
		guard.wave_guard = true
		guard.weapon_kind = "smg" if index % 3 == 2 else "pistol"
		name_reinforcement(guard)
		level.get_node("Guards").add_child(guard)
		guard.alert_state = IntroGuard.State.SEARCH
		guard.pursuing = true
		guard.last_known_position = player.global_position
		guard.search_left = 30.0
		wave_guards.append(guard)
	level.notify("Keepers are sweeping the floor for you.", 4.0)
