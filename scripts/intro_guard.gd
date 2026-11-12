class_name IntroGuard
extends BaseCharacter

const KEEPER_IDLE = preload("res://assets/characters/standard_keeper_idle.png")
const KEEPER_WALK = preload("res://assets/characters/standard_keeper_walk.png")
const KEEPER_ATTACK = preload("res://assets/characters/standard_keeper_attack.png")
## Point blank, a Keeper swings his knife instead of firing (Julia's two-frame attack).
const STRIKE_REACH := 30.0
const STRIKE_SLASH := 0.2
var strike_left := 0.0
var strike_landed := false
const KEY_TEXTURE = preload("res://assets/environment/key.png")

enum State { PATROL, SUSPICIOUS, ALERT, SEARCH }
@export var patrol_left: float = 300.0
@export var patrol_right: float = 500.0
@export var sick_guard: bool = false
@export_enum("pistol", "smg") var weapon_kind := "pistol"
var ammunition := -1
var ammo_pickpocketed := false
var stolen_ammo := 0
var burst_left := 0
var burst_timer := 0.0
var shot_direction := Vector2.RIGHT
var level: Node2D
var alert_state: State = State.PATROL
var facing: float = 1.0
var suspicion: float = 0.0
var last_known_position := Vector2.ZERO
var search_left: float = 0.0
var sweep_origin := INF
var sweep_side := 1.0
var search_route: Array[Dictionary] = []
var route_goal := Vector2.INF
var route_attempt := Vector2.INF
var route_stall := 0.0
var route_previous := Vector2.INF
const GuardRoutes = preload("res://scripts/guard_navigation.gd")
var attack_timer: float = 0.0
var windup: float = 0.0
var turn_wait: float = 0.0
var time: float = 0.0
var illness_started: bool = false
var seen_bodies: Dictionary = {}
var seen_sleepers: Dictionary = {}
var key_taken: bool = false
var gun_taken: bool = false
var death_recorded: bool = false
var sees_player: bool = false
var body_reported: bool = false
var guard_name := "Keeper"
## The name shown to the player: no digits ("Wren2" shows as "Wren T."), clip lookups keep guard_name.
var display_name: String:
	get:
		var plain := guard_name
		var stripped := guard_name.rstrip("0123456789")
		if stripped != guard_name:
			plain = stripped + " T."
		return plain
## Individual character description from the Keeper roster.
var personality := ""
## Off duty in a huddle: absorbed in each other, they only notice Miro right on top of them.
var distracted := false
const DISTRACTED_SIGHT := 40.0
var conversation_hold := false
var turn_away_left := 0.0
var alert_barked := false
## Put to sleep by Miro's guitar (Level 5). Lootable, never counted as a kill, sleeps for the rest of the floor.
var asleep := false:
	set(value):
		if asleep == value: return
		asleep = value
		collision_layer = 0 if asleep else 4
		sync_discoverable_group()
## Spawned by a Level 5 wave or by Niro calling for help.
var wave_guard := false

## Difficulty (Settings): how far a Keeper sees, how fast he makes up his mind, and how hard he fights.
var sight := 165.0
var suspicion_rate := 1.0
var windup_time := 0.65
var attack_gap := 2.1
var chase_speed := 78.0
## True while a Keeper who lost sight of Miro is still running after him.
var pursuing := false
var lost_barked := false
## Keepers take 4 pistol shots, two face-to-face stabs, or one stab from behind.
const MAX_HEALTH := 16
const BODY_SIGHT := 260.0
const HEARING_RANGE := 85.0
const BODY_NEARBY := 190.0
const HOP_SPEED := 300.0

func _ready() -> void:
	if is_instance_valid(level) and level.get("checkpoint_grace_until") != null and Time.get_ticks_msec() < int(level.get("checkpoint_grace_until")):
		for body in level.guards():
			if body.is_dead:seen_bodies[body.get_instance_id()] = true
			elif body.asleep:seen_sleepers[body.get_instance_id()] = true
	add_to_group("guards")
	sync_discoverable_group()
	var campaign = get_node_or_null("/root/Campaign")
	if campaign != null:
		var tuning: Dictionary = campaign.tuning()
		health = MAX_HEALTH
		movement_speed = (33.0 if sick_guard else 43.0) * float(tuning.get("attack_speed", 1.0))
		sight = float(tuning.sight)
		suspicion_rate = float(tuning.suspicion)
		windup_time = float(tuning.windup)
		attack_gap = float(tuning.attack_gap)
		chase_speed = float(tuning.chase)
	else:
		health = MAX_HEALTH
		movement_speed = 33.0 if sick_guard else 43.0


func can_see_point(point: Vector2, distance_limit: float = 165.0) -> bool:
	var difference := point - global_position
	var vertical_limit := 80.0 if not is_on_floor() else (70.0 if absf(difference.x) < 40.0 else 45.0)
	if is_instance_valid(level) and is_instance_valid(level.player) and point == level.player.global_position and not level.player.crouching and difference.y < 0.0 and level.player.is_on_floor():
		vertical_limit = maxf(vertical_limit, 64.0)
	return difference.length() < distance_limit and absf(difference.y) < vertical_limit and difference.x * facing >= -8 and level.clear_sight(global_position + Vector2(0, -8), point + Vector2(0, -8))


func detect_player() -> bool:
	if is_dead or asleep or not level or level.player.is_dead or (level.player.is_concealed or level.player.in_hiding_spot):
		return false
	# Prisoners inside the locked cell are not escapees yet.
	if not level.door_open and level.player.global_position.x < level.get_node("Interactables/CellLock").global_position.x:
		return false
	return can_see_point(level.player.global_position, DISTRACTED_SIGHT if distracted else sight) or hears_player()

## Footsteps at a run: a Keeper who hears Miro pounding along close by, for about half a second,
## turns on him even unseen. A quick last step in for a pickpocket is too brief to be heard.
var heard_time := 0.0
func hears_player() -> bool:
	if distracted or conversation_hold:
		return false  # absorbed in a huddle or conversation, they only notice Miro right on top of them
	var p = level.player
	var difference: Vector2 = p.global_position - global_position
	if p.crouching or p.is_concealed or p.in_hiding_spot or absf(p.velocity.x) < p.movement_speed * 0.9 or absf(difference.x) >= HEARING_RANGE or absf(difference.y) >= 40.0:
		heard_time = 0.0
		return false
	heard_time += get_physics_process_delta_time()
	return heard_time > 0.5

## The sick Keepers' cough: the animation and its sound share one clock.
func is_coughing() -> bool:
	return sick_guard and illness_started and fmod(time, 4.0) < 1.4

var cough_count := 0
var cough_was := false

func cough_sound() -> void:
	var now := is_coughing() and not is_dead and not asleep
	if now and not cough_was and is_instance_valid(level) and is_instance_valid(level.player):
		cough_count += 1
		get_node("/root/SoundFX").cough_near(global_position, level.player.global_position, cough_count + int(global_position.x))
	cough_was = now

func _physics_process(delta: float) -> void:
	time += delta
	glance_left = maxf(0.0, glance_left - delta)
	search_turn_left = maxf(0.0, search_turn_left - delta)
	obstacle_replan_left = maxf(0.0, obstacle_replan_left - delta)
	hop_retry_left = maxf(0.0, hop_retry_left - delta)
	cough_sound()
	queue_redraw()
	if not level or level.controls_locked():
		return
	if is_dead or asleep:
		release_crossing()
	if is_dead:
		return
	if is_on_floor():
		hop_landing = Vector2.INF
	if asleep:
		sees_player = false
		velocity = Vector2(0, velocity.y + 850.0 * delta)
		move_and_slide()
		return
	# A secured victim cannot turn, attack or walk away during the held takedown.
	var world = level.world_features
	if is_instance_valid(world) and world.strangle_active() and world.strangle_victim == self:
		velocity = Vector2(0, velocity.y + 850.0 * delta)
		windup = 0.0
		burst_left = 0
		strike_left = 0.0
		move_and_slide()
		return
	invulnerability_left = maxf(0, invulnerability_left - delta)
	attack_timer = maxf(0.0, attack_timer - delta)
	turn_wait = maxf(0.0, turn_wait - delta)
	sees_player = detect_player()
	if sees_player:
		sweep_origin = INF
		search_route.clear()
		route_goal = Vector2.INF
		suspicion = minf(1.0, suspicion + delta * (3.0 if level.get("hunted") else 2.5) * suspicion_rate)
		last_known_position = level.player.global_position
		search_left = 5.0
		if suspicion >= 1.0:
			distracted = false
			alert_state = State.ALERT
			if not alert_barked and level.world_features:
				alert_barked = true
				level.world_features.bark(self, "alert")
		else:
			alert_state = State.SUSPICIOUS
	elif alert_state == State.ALERT or alert_state == State.SUSPICIOUS:
		# Losing sight of Miro mid-chase doesn't stop a Keeper: he runs on to where Miro was
		# heading, then searches. A suspicious Keeper just goes to look.
		pursuing = alert_state == State.ALERT
		# Miro vanished into the dark, a vent or a crate: say so.
		if (level.player.is_concealed or level.player.in_hiding_spot) and level.world_features and not lost_barked:
			lost_barked = true
			level.world_features.queue_search_bark(self)
		if pursuing:
			var heading := signf(level.player.velocity.x)
			if heading == 0:
				heading = signf(last_known_position.x - global_position.x)
			last_known_position.x += heading * 140.0
		alert_state = State.SEARCH
		search_left = 8.0 if pursuing else 5.0
		suspicion = maxf(0.0, suspicion - delta)
	for body in get_tree().get_nodes_in_group("discoverable_guards"):
		if body != self and body.asleep and not body.is_dead and not seen_sleepers.has(body.get_instance_id()) and notices_body(body.global_position):
			seen_sleepers[body.get_instance_id()] = true
			# A live sleeper merits a local check; a corpse below still triggers the full alarm.
			if not sees_player and alert_state != State.ALERT and not pursuing:
				var profile: Dictionary = level.world_features.roster.keepers.get(guard_name,{})
				var concerned: bool = profile.get("sleep_reaction","dry") == "concerned"
				investigate(body.global_position)
				alert_state = State.SEARCH
				pursuing = false
				search_left = 7.0 if concerned else 4.0
				suspicion = maxf(suspicion, 0.65 if concerned else 0.35)
			level.notify("%s found %s unconscious. A local search begins." % [display_name, body.display_name])
			if level.world_features:
				level.world_features.bark(self, "sleeping")
		elif body != self and body.is_dead and not seen_bodies.has(body.get_instance_id()) and notices_body(body.global_position):
			seen_bodies[body.get_instance_id()] = true
			body_reported = true
			if not sees_player:
				investigate(body.global_position)
			level.notify("%s found %s. The Keepers are searching." % [display_name, body.display_name])
			# High alert: grieve out loud (over anything else being said), turn on the area at
			# a run, and rouse every Keeper within earshot.
			if alert_state != State.ALERT:
				alert_state = State.SEARCH
			pursuing = true
			lost_barked = false
			search_left = 12.0
			suspicion = 1.0
			for other in level.guards():
				if other != self and not other.is_dead and not other.asleep and other.global_position.distance_to(global_position) < 380.0 and absf(other.global_position.y - global_position.y) < 90.0:
					other.investigate(body.global_position)
					other.pursuing = true
			if level.world_features:
				level.world_features.bark(self, "body", true)
	velocity.x = 0
	burst_timer -= delta
	if burst_left > 0 and burst_timer <= 0:
		if sees_player:
			shoot_weapon()
		else:
			burst_left = 0
	if strike_left > 0:
		strike_left -= delta
		if not strike_landed and strike_left <= STRIKE_SLASH:
			strike_landed = true
			get_node("/root/SoundFX").play_near("swing", global_position, level.player.global_position, -20)
			var reach: Vector2 = level.player.global_position - global_position
			if not level.player.is_dead and absf(reach.y) < 22 and absf(reach.x) <= STRIKE_REACH + 4 and reach.x * facing >= -4:
				if not level.player.controls.block_melee(global_position):
					level.player.take_damage(1)
	elif windup > 0:
		windup -= delta
		if windup <= 0 and sees_player:
			burst_left = 1 if weapon_kind == "pistol" else 3
			shoot_weapon()
	elif alert_state == State.ALERT and sees_player:
		face_toward(last_known_position.x)
		if global_position.distance_to(last_known_position) < 150:
			if attack_timer <= 0:
				var gap: Vector2 = level.player.global_position - global_position
				if absf(gap.x) < STRIKE_REACH and absf(gap.y) < 20:
					strike_left = windup_time * 0.5 + STRIKE_SLASH
					strike_landed = false
				elif remaining_ammo() <= 0:
					velocity.x = facing * chase_speed
				else:
					windup = windup_time
					shot_direction = (level.player.get_node("CollisionShape2D").global_position - (global_position + Vector2(0, -4))).normalized()
				attack_timer = attack_gap
		else:
			velocity.x = facing * chase_speed
	elif alert_state == State.SEARCH:
		search_left -= delta
		if crossing == null and is_on_floor() and level.ladder_at(global_position) == null and sweep_origin == INF and last_known_position.distance_to(route_attempt)>28:
			route_attempt = last_known_position
			plan_search_route(last_known_position)
		if crossing == null and not waiting_at_ladder:
			update_search_route(delta)
		var goal := movement_goal()
		var distance := goal.x - global_position.x
		if sweep_origin == INF and search_route.is_empty() and absf(distance) <= 12 and absf(goal.y - global_position.y) < 40 and is_on_floor():
			begin_sweep(facing)
		if not search_route.is_empty():
			goal = movement_goal()
			face_toward(goal.x)
			velocity.x = facing * (chase_speed if pursuing else 42.0)
		elif sweep_origin != INF:
			# No usable route in this direction: look, then try the other side.
			if (global_position.x-sweep_origin)*sweep_side>196:
				sweep_side *= -1
			face_toward(global_position.x + sweep_side * 70)
			velocity.x = facing * 42.0
		else:
			if absf(distance) > 12:
				face_toward(goal.x)
				velocity.x = facing * (chase_speed if pursuing else 42.0)
		if search_left <= 0:
			pursuing = false
			search_route.clear()
			sweep_origin = INF
			alert_state = State.PATROL
			suspicion = 0
	elif alert_state == State.PATROL:
		if conversation_hold or turn_away_left > 0:
			turn_away_left = maxf(0, turn_away_left - delta)
			velocity.y += 850.0 * delta
			move_and_slide()
			return
		if sick_guard and not illness_started:
			return
		if global_position.x <= patrol_left:
			if facing < 0:
				turn_wait = beat_wait(1.8 if sick_guard else 0.8)
			facing = 1
		elif global_position.x >= patrol_right:
			if facing > 0:
				turn_wait = beat_wait(1.0)
			facing = -1
		if turn_wait <= 0:
			velocity.x = facing * movement_speed * stride()
	waiting_at_ladder = false
	if crossing == null and ladder_follow(delta) or ladder_search(delta):
		return
	var requested := velocity.x
	velocity.x = spaced_speed(requested)
	if alert_state == State.PATROL and turn_wait <= 0.0 and requested * facing > 0 and velocity.x * facing < 1.0:
		facing *= -1
		turn_wait = beat_wait(0.8)
	# Do not walk off a floor or chase between tiers (ladders are followed above).
	var foot := global_position + Vector2(signf(velocity.x) * 15, 12)
	var chasing := velocity.x != 0 and (alert_state == State.ALERT or pursuing)
	var hop_down := chasing and solid_between(foot, foot + Vector2(0, 48))
	if velocity.x != 0 and is_on_floor() and not level.has_floor_below(foot) and not hop_down:
		velocity.x = 0
		if alert_state == State.SEARCH:
			if obstacle_replan_left <= 0.0:
				obstacle_replan_left = 0.6
				face_toward(global_position.x - facing * 70)
				begin_sweep(facing)
		elif requested != 0 and turn_wait <= 0.0:
			facing *= -1
	# A chasing Keeper hops over anything one tile high instead of giving up at it.
	var searching := alert_state == State.SEARCH or alert_state == State.ALERT
	var hopping := searching and velocity.x * facing > 0 and is_on_floor() and can_hop()
	if hopping:
		hop_retry_left = 0.85
		velocity.y = -HOP_SPEED
	velocity.y += 850.0 * delta
	move_and_slide()
	if is_on_wall() and not hopping and is_on_floor():
		if searching:
			# A crouch passage or tall wall is impassable to this guard.
			alert_state = State.SEARCH
			if obstacle_replan_left <= 0.0:
				obstacle_replan_left = 0.6
				if not plan_search_route(last_known_position):
					begin_sweep(-facing)
		else:
			turn_patrol_from_obstacle()

func turn_patrol_from_obstacle() -> void:
	# A chase can leave a guard on the opposite side of an impassable wall
	# from his old patrol. Keep his replacement patrol on the reachable side.
	var span := clampf(patrol_right-patrol_left,56.0,196.0)
	if facing > 0:
		patrol_right = minf(patrol_right,global_position.x)
		patrol_left = minf(patrol_left,patrol_right-span)
	else:
		patrol_left = maxf(patrol_left,global_position.x)
		patrol_right = maxf(patrol_right,patrol_left+span)
	facing *= -1
	turn_wait = beat_wait(0.8)

func navigation() -> RefCounted:
	if not level.has_meta("guard_navigation") or level.get_meta("guard_navigation").geometry_state != GuardRoutes.signature(level):
		level.set_meta("guard_navigation", GuardRoutes.new(level))
	return level.get_meta("guard_navigation")

func movement_goal() -> Vector2:
	return search_route[0].point if not search_route.is_empty() else last_known_position

func plan_search_route(target: Vector2) -> bool:
	var path: Array[Dictionary] = navigation().route(global_position, target)
	if path.is_empty() or path[-1].point.distance_to(target) > 28:
		return false
	if sweep_origin == INF:
		var length := 0.0
		var previous := global_position
		for step in path:
			length += previous.distance_to(step.point)
			previous = step.point
		search_left = maxf(search_left,minf(30.0,length/42.0+3.0))
	search_route = path
	route_goal = target
	route_stall = 0
	route_previous = global_position
	return true

func begin_sweep(direction: float) -> void:
	pursuing = false
	if sweep_origin == INF:
		sweep_origin = global_position.x
	last_known_position = global_position
	sweep_side = 1.0 if direction >= 0 else -1.0
	var goal: Vector2 = navigation().search_goal(global_position,sweep_side,get_instance_id())
	if not plan_search_route(goal):
		goal = navigation().search_goal(global_position,-sweep_side,get_instance_id())
		if plan_search_route(goal): sweep_side *= -1

func update_search_route(delta: float) -> void:
	while not search_route.is_empty() and global_position.distance_to(search_route[0].point)<18:
		search_route.pop_front()
	if search_route.is_empty():
		if route_goal != Vector2.INF:
			route_goal = Vector2.INF
			begin_sweep(-sweep_side)
		return
	# Bound a jam by elapsed time rather than tick count; don't replan every frame.
	if route_previous != Vector2.INF and global_position.distance_to(route_previous)<1:
		route_stall += delta
	else:
		route_stall = 0
		route_previous = global_position
	if route_stall>1.5:
		search_route.clear()
		route_goal = Vector2.INF
		begin_sweep(-sweep_side)

## Ladders: a hunting Keeper climbs after Miro; an unaware one near the ladder glances up (or down).
var glance_left := 0.0
var search_turn_left := 0.0
var obstacle_replan_left := 0.0
var hop_retry_left := 0.0
var ladder_exit_side := 0.0
var ladder_exit_left := 0.0
var ladder_stall_time := 0.0
var crossing: IntroArea
var crossing_goal := Vector2.INF
var waiting_at_ladder := false
var hop_landing := Vector2.INF
const SHAFT_OWNER := &"guard_crossing"

func face_toward(x: float) -> void:
	# An exactly vertical sightline must not collapse the sprite to zero width.
	if absf(x - global_position.x) > 3.0:
		var direction := signf(x - global_position.x)
		if alert_state == State.SEARCH and not sees_player and not pursuing and direction != facing:
			if search_turn_left > 0.0:return
			search_turn_left = 0.35
		facing = direction

func _exit_tree() -> void:
	release_crossing()

func release_crossing() -> void:
	if is_instance_valid(crossing) and crossing.get_meta(SHAFT_OWNER, 0) == get_instance_id():
		crossing.remove_meta(SHAFT_OWNER)
	crossing = null
	crossing_goal = Vector2.INF

func wait_for_crossing(ladder: IntroArea, goal: Vector2, delta: float) -> bool:
	if crossing == ladder:
		return false
	var gap := absf(ladder.global_position.x - global_position.x)
	if gap > 68.0:
		return false
	var owner := instance_from_id(int(ladder.get_meta(SHAFT_OWNER, 0))) as IntroGuard if ladder.has_meta(SHAFT_OWNER) else null
	if is_instance_valid(owner) and owner.is_inside_tree() and not owner.is_dead and not owner.asleep and owner.crossing == ladder:
		waiting_at_ladder = true
		search_left = maxf(search_left, 2.0)
		ladder_stall_time = 0.0
		route_stall = 0.0
		face_toward(ladder.global_position.x)
		# Leave a full body width of clearance for the climber stepping off.
		var side := -1.0 if global_position.x < ladder.global_position.x else 1.0
		velocity.x = spaced_speed(side * clampf((52.0 - gap) * 4.0, -42.0, 78.0))
		velocity.y += 850.0 * delta
		move_and_slide()
		return true
	if not sees_player and goal.y < global_position.y - 70.0:
		var upstairs := 0
		for other: IntroGuard in level.guards():
			if other != self and not other.is_dead and not other.asleep and absf(other.global_position.y - goal.y) < 42.0 and absf(other.global_position.x - goal.x) < 180.0:
				upstairs += 1
		if upstairs >= 2:
			# Searchers cover the lower floor instead of all piling onto one landing.
			pursuing = false
			search_route.clear()
			route_goal = Vector2.INF
			last_known_position = global_position + Vector2(facing * 70.0, 0)
			search_left = minf(search_left, 4.0)
			velocity = Vector2(0, velocity.y + 850.0 * delta)
			move_and_slide()
			return true
	if gap <= 48.0:
		crossing = ladder
		crossing_goal = goal
		ladder.set_meta(SHAFT_OWNER, get_instance_id())
	return false

func ladder_follow(delta: float) -> bool:
	if ladder_exit_left > 0.0:
		return false
	var player = level.player
	if not is_instance_valid(player) or player.is_dead or not player.climbing:
		return false
	var ladder = level.ladder_at(player.global_position)
	if ladder == null:
		return false
	var hunting := alert_state == State.ALERT or pursuing
	if not hunting or not sees_player:
		if alert_state == State.PATROL and absf(player.global_position.x - global_position.x) < 160.0 and absf(player.global_position.y - global_position.y) < 140.0 and not conversation_hold:
			glance_left = 0.6
			facing = signf(player.global_position.x - global_position.x) if absf(player.global_position.x - global_position.x) > 4.0 else facing
		return false
	var here = level.ladder_at(global_position)
	if here != ladder and absf(global_position.x - ladder.global_position.x) > 28.0:
		return false
	var dy: float = player.global_position.y - global_position.y
	if absf(dy) < 14.0:
		velocity = Vector2.ZERO
		move_and_slide()
		return true
	if wait_for_crossing(ladder, player.global_position, delta):
		return true
	climb_toward(ladder.global_position.x, dy, delta)
	return true

## Bound the requested speed by the room on each side. A faster follower slows
## before contact; exactly coincident guards choose a stable order and spread out.
func spaced_speed(requested: float) -> float:
	if not is_on_floor():
		return requested
	var left := -chase_speed
	var right := chase_speed
	for other in level.guards():
		if other == self or other.is_dead or other.asleep or absf(other.position.y - position.y) > 20.0:
			continue
		var gap: float = other.position.x - position.x
		var clearance := 52.0 if facing != other.facing else 36.0
		var limit := (absf(gap) - clearance) * 4.0
		if gap > 0 or (gap == 0 and other.get_instance_id() > get_instance_id()):
			right = minf(right, limit)
		else:
			left = maxf(left, -limit)
	if left > right:
		return clampf((left + right) * 0.5, -chase_speed, chase_speed)
	return clampf(requested, left, right)

func ladder_search(delta: float) -> bool:
	if ladder_exit_left > 0.0:
		ladder_exit_left = maxf(0.0, ladder_exit_left - delta)
		velocity.x = ladder_exit_side * 120.0
		velocity.y += 850.0 * delta
		move_and_slide()
		if is_on_floor() or ladder_exit_left <= 0.0:
			ladder_exit_left = 0.0
			release_crossing()
		return true
	if crossing == null and alert_state == State.PATROL and not pursuing:
		return false
	var target := movement_goal()
	# A hunting Keeper tracks Miro himself, so he follows him up and down a ladder without stopping.
	if (alert_state == State.ALERT or pursuing) and sees_player and is_instance_valid(level.player) and not level.player.is_dead:
		target = level.player.global_position
		last_known_position = target
	if crossing != null:
		if sees_player and level.player.climbing and crossing.contains(level.player.global_position):
			crossing_goal = level.player.global_position
			if global_position.distance_to(crossing_goal) < 14.0:
				velocity = Vector2.ZERO
				move_and_slide()
				return true
		target = crossing_goal
	var dy := target.y - global_position.y
	var current_ladder: IntroArea = level.ladder_at(global_position)
	if current_ladder != null:ladder_stall_time = 0.0
	if current_ladder != null:
		var edge: float = current_ladder.global_position.y + (-1.0 if dy < 0.0 else 1.0) * current_ladder.area_size.y / 2.0
		if (dy < 0.0 and target.y < edge) or (dy > 0.0 and target.y > edge):
			var landing := ladder_landing(current_ladder, dy < 0.0, target)
			if landing != Vector2.INF:
				target = landing
				dy = target.y - global_position.y
	# Once on a ladder he keeps going until he is level with the target floor.
	var on_ladder := level.ladder_at(global_position) != null
	if not on_ladder:
		ladder_exit_side = 0.0
	if absf(dy) < (16.0 if on_ladder else 35.0 if not search_route.is_empty() and search_route[0].ladder != null else 70.0):
		if on_ladder:
			# At the top: hop up and over the lip onto the floor, toward whoever he is after.
			if ladder_exit_side == 0.0:
				ladder_exit_side = signf(target.x - global_position.x)
				if ladder_exit_side == 0.0:
					ladder_exit_side = facing
				var landing := Vector2(global_position.x + ladder_exit_side * 36.0, target.y + 12.0)
				var opposite := Vector2(global_position.x - ladder_exit_side * 36.0, target.y + 12.0)
				if not level.has_floor_below(landing) and level.has_floor_below(opposite):
					ladder_exit_side *= -1.0
			# Commit to one side of the lip; re-aiming every substep oscillates around Miro.
			facing = ladder_exit_side
			ladder_exit_left = 0.35
			var near_bottom := global_position.y > current_ladder.global_position.y + current_ladder.area_size.y * 0.5 - 48.0
			velocity = Vector2(ladder_exit_side * 120.0, 0.0 if near_bottom else -190.0)
			move_and_slide()
			return true
		if search_route.is_empty() or search_route[0].ladder == null:
			return false
	var best = null
	var best_gap := INF
	var route_ladder: IntroArea = crossing if crossing != null else search_route[0].ladder if not search_route.is_empty() else null
	for area in level.areas.get_children():
		if route_ladder != null and area != route_ladder:
			continue
		if area.kind != "ladder":
			continue
		var rect := Rect2(area.global_position - area.area_size / 2.0, area.area_size)
		var near_here := global_position.y >= rect.position.y - 40.0 and global_position.y <= rect.end.y + 40.0
		var goes_toward: bool = area == route_ladder or (rect.position.y < global_position.y - 32.0 if dy < 0.0 else rect.end.y > global_position.y + 32.0)
		if near_here and goes_toward:
			var gap := absf(area.global_position.x - global_position.x)
			if gap < best_gap:
				best_gap = gap
				best = area
	if best == null:
		return false
	search_left = maxf(search_left, 2.0)
	if wait_for_crossing(best, target, delta):
		return true
	var ladder_x: float = best.global_position.x
	if absf(global_position.x - ladder_x) > 14.0 and level.ladder_at(global_position) == null:
		# Walk to the foot (or top) of the ladder on this floor.
		var before_x := global_position.x
		facing = signf(ladder_x - global_position.x)
		velocity.x = spaced_speed(facing * chase_speed)
		if velocity.x * facing > 0 and is_on_floor() and can_hop():velocity.y = -HOP_SPEED
		velocity.y += 850.0 * delta
		move_and_slide()
		ladder_stall_time = ladder_stall_time + delta if absf(global_position.x-before_x)<0.01 else 0.0
		if ladder_stall_time > 1.5:
			release_crossing()
			# An impassable vault or another Keeper cannot hold a chase forever.
			pursuing = false
			alert_state = State.SEARCH
			begin_sweep(-facing)
			search_left = 3.0
			ladder_stall_time = 0.0
		return true
	climb_toward(ladder_x, dy, delta)
	return true

func climb_toward(ladder_x: float, dy: float, delta: float) -> void:
	var direction := signf(dy)
	var speed := 92.0
	for other in level.guards():
		if other == self or other.is_dead or other.asleep or absf(other.position.x - ladder_x) > 14 or other.is_on_floor():
			continue
		# Opposing climbers must be able to pass instead of waiting on each other.
		if (other.last_known_position.y - other.position.y) * direction <= 0:
			continue
		var gap: float = (other.position.y - position.y) * direction
		if gap > 0 or (gap == 0 and other.get_instance_id() < get_instance_id()):
			speed = minf(speed, maxf(0, (gap - 28.0) * 4.0))
	velocity = Vector2(clampf((ladder_x - position.x) / delta, -120, 120), direction * speed)
	move_and_slide()

func ladder_landing(ladder: Node2D, upward: bool, goal: Vector2) -> Vector2:
	var edge: float = ladder.global_position.y + (-1.0 if upward else 1.0) * ladder.area_size.y / 2.0
	var best := Vector2.INF
	for side in [-1.0, 1.0]:
		var x: float = ladder.global_position.x + side * (ladder.area_size.x / 2.0 + 20.0)
		var from := Vector2(x, edge - (28.0 if upward else 72.0))
		var to := Vector2(x, edge + (80.0 if upward else 24.0))
		var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(from, to, 1))
		if hit.is_empty():continue
		var point := Vector2(x, hit.position.y - 16.0)
		if best == Vector2.INF or absf(point.x - goal.x) < absf(best.x - goal.x):best = point
	return best

func solid_between(from: Vector2, to: Vector2, mask := 1) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, mask)
	query.exclude = [get_rid()]
	query.hit_from_inside = true
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()

## Something knee-high directly ahead, with clear space above it to land on.
func can_hop() -> bool:
	if hop_retry_left > 0.0:return false
	var ahead := Vector2(facing * 20, 0)
	var knee := global_position + Vector2(0, 8)
	var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(knee, knee + ahead, 1))
	if hit.is_empty():
		return false
	# Sweep the standing body up and across one tile. A knee ray alone can
	# mistake a step under a low ceiling for a usable landing.
	var lift := Vector2.UP * 30.0
	if test_move(global_transform, lift) or test_move(global_transform.translated(lift), ahead):
		return false
	# Reserve the first 28px of landing, not an entire wide platform.
	var landing := Vector2(float(hit.position.x) + facing * 14.0, global_position.y - 28.0)
	for other: IntroGuard in level.guards():
		if other == self:
			continue
		if absf(other.global_position.x - landing.x) < 25.0 and absf(other.global_position.y - landing.y) < 19.0:
			return false
		if not other.asleep and not other.is_dead and other.hop_landing.distance_squared_to(landing) < 25.0 * 25.0:
			return false
	hop_landing = landing
	return true

## Patrols keep time with the music: a Keeper turns at the end of his beat on a beat line
## (sick Keepers on every other beat) and leans into each step on the beat.
func music() -> Node:
	return get_node_or_null("/root/MusicDirector")

func beat_wait(minimum: float) -> float:
	var clock := music()
	if clock == null or clock.bpm() <= 0:
		return minimum
	var spb: float = clock.seconds_per_beat()
	var position: float = clock.beat_position()
	var every := 2.0 if sick_guard else 1.0
	var target := ceilf((position + minimum / spb) / every) * every
	return (target - position) * spb

## Averages 1.0 over a beat, so patrol timings are unchanged; the peak lands on the beat.
func stride() -> float:
	var clock := music()
	if clock == null or clock.bpm() <= 0:
		return 1.0
	var offset := fmod(clock.beat_position(), 1.0)
	return 0.7 + 0.6 * (1.0 - offset)

func remaining_ammo() -> int:
	if ammunition < 0: ammunition = 8 if weapon_kind == "pistol" else 24
	return ammunition

func dropped_ammo() -> int:
	return mini(remaining_ammo(), maxi(0, get_node("/root/Campaign").ammo_amount(3 if weapon_kind == "pistol" else 12) - stolen_ammo))

func shoot_weapon() -> void:
	if remaining_ammo() <= 0:
		burst_left = 0
		return
	ammunition -= 1
	burst_left -= 1
	burst_timer = 0.14
	var bullet := Node2D.new()
	bullet.set_script(load("res://scripts/weapon_projectile.gd"))
	bullet.level = level
	bullet.shooter = self
	bullet.enemy = true
	bullet.direction = shot_direction
	bullet.speed = 280.0
	bullet.remaining = 260.0
	bullet.position = position + Vector2(0, -4)
	level.add_child(bullet)
	get_node("/root/SoundFX").play_near("shot", global_position, level.player.global_position, -25, 600.0, 1.25 if weapon_kind == "smg" else 1.0)
	level.make_noise(global_position, 600)
	var casing := Node2D.new()
	casing.set_script(load("res://scripts/weapon_casing.gd"))
	casing.level = level
	casing.position = position
	casing.velocity = Vector2(-facing * 65, -100)
	level.add_child(casing)

## Strangled from behind: out cold, no blood, not a casualty. Other Keepers who find him are
## alarmed, but nobody cries out that he is dead.
var strangled := false

func strangle() -> void:
	strangled = true
	fall_asleep()

func fall_asleep() -> void:
	if is_dead or asleep:
		return
	asleep = true
	alert_state = State.PATROL
	sees_player = false
	windup = 0
	burst_left = 0
	suspicion = 0

## A fallen Keeper is hard to miss: seen from further off than a sneaking prisoner, and
## noticed nearby even with his back turned.
func sync_discoverable_group() -> void:
	# Setters cover checkpoint restores, sleeping, death, and test/dev state changes immediately.
	if not is_inside_tree() or not is_in_group("guards"): return
	if is_dead or asleep:
		if not is_in_group("discoverable_guards"): add_to_group("discoverable_guards")
	elif is_in_group("discoverable_guards"):
		remove_from_group("discoverable_guards")

func notices_body(point: Vector2) -> bool:
	var difference := point - global_position
	if absf(difference.y) >= 45: return false
	var distance := difference.length()
	if distance >= BODY_SIGHT or (difference.x * facing < -8 and distance >= BODY_NEARBY): return false
	return level.clear_sight(global_position + Vector2(0, -8), point + Vector2(0, -8))

func investigate(point: Vector2) -> void:
	if is_dead or asleep or sees_player:
		return
	distracted = false
	sweep_origin = INF
	route_attempt = Vector2.INF
	search_route.clear()
	route_goal = Vector2.INF
	last_known_position = point
	search_left = 6.0
	alert_state = State.SEARCH
	suspicion = 0.3

func receive_shank() -> void:
	level.emit_effect("hit", global_position)
	conversation_hold = false
	turn_away_left = 0
	var unaware := alert_state != State.ALERT and not detect_player()
	# From behind (or unseen) a stab kills outright; face to face it takes two.
	var behind: bool = (level.player.global_position.x - global_position.x) * facing < 0.0
	health -= MAX_HEALTH if (unaware or behind) else 8
	if health <= 0:
		die()
	else:
		alert_state = State.ALERT
		suspicion = 1.0
		last_known_position = level.player.global_position
		face_toward(last_known_position.x)
		level.notify("The Keeper turns. One more hit; dodge his wind-up with C.")

## A Keeper who was already dead at the checkpoint stays dead (no new casualty, no new alarm).
func restore_dead(point: Vector2, looted: bool) -> void:
	collision_layer = 0
	global_position = point
	death_recorded = true
	health = 0
	is_dead = true
	gun_taken = looted
	sees_player = false
	velocity = Vector2.ZERO
	queue_redraw()

func die() -> void:
	collision_layer = 0
	if death_recorded:
		return
	death_recorded = true
	super.die()
	sees_player = false
	velocity = Vector2.ZERO
	level.player.casualty_count += 1
	level.emit_effect("blood", global_position + Vector2(0, 12))
	level.notify("A body remains. Other Keepers may discover it. [E] Loot")
	if level.has_method("on_keeper_killed"):
		level.on_keeper_killed(self)
	queue_redraw()

func _draw() -> void:
	var pale := Color("f2d3ab")
	draw_string(ThemeDB.fallback_font, Vector2(-18, -36), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, pale)
	# A hurt Keeper shows a small health bar over his head.
	if not is_dead and health < MAX_HEALTH and health > 0 and not has_method("begin_recovery"):
		draw_rect(Rect2(-11, -30, 22, 3), Color(0.1, 0.05, 0.1, 0.8))
		draw_rect(Rect2(-11, -30, 22.0 * float(health) / MAX_HEALTH, 3), Color("c0392b").lerp(Color("e8c07a"), float(health) / MAX_HEALTH))
	if asleep:
		draw_set_transform(Vector2(0, 6), PI / 2 * facing)
		draw_texture(KEEPER_IDLE, Vector2(-16, -16))
		draw_set_transform(Vector2.ZERO)
		draw_string(ThemeDB.fallback_font, Vector2(6, -14 - fmod(time * 6, 8)), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, pale)
		return
	if is_dead:
		# No dedicated death sheet yet: retain Julia's idle silhouette as a body.
		draw_set_transform(Vector2(0, 3), PI / 2)
		draw_texture(KEEPER_IDLE, Vector2(-16, -16))
		draw_set_transform(Vector2.ZERO)
		draw_carried_key()
		return
	if alert_state != State.PATROL or not sick_guard:
		var cone := PackedVector2Array([Vector2(0, -8), Vector2(facing * 150, -43), Vector2(facing * 150, 23)])
		draw_colored_polygon(cone, Color(0.78, 0.62, 0.65, 0.07 if alert_state != State.ALERT else 0.16))
	var coughing := is_coughing()
	var moving: bool = absf(velocity.x) > 1 and level != null and not level.controls_locked()
	var texture: Texture2D = KEEPER_WALK if moving else KEEPER_IDLE
	var frame := int(time * 8) % 2 if moving else 0
	if strike_left > 0:
		texture = KEEPER_ATTACK
		frame = 0 if strike_left > STRIKE_SLASH else 1
	# Mirror the art, not the guard's collision, FOV or attached indicators.
	draw_set_transform(Vector2(0, 15), -facing * 0.12 if coughing else 0.0, Vector2(facing, 0.9 if coughing else 1.0))
	draw_texture_rect_region(texture, Rect2(-16, -31, 32, 32), Rect2(frame * 32, 0, 32, 32))
	draw_set_transform(Vector2.ZERO)
	if strike_left <= 0:
		draw_set_transform(Vector2(0, -4), 0, Vector2(facing, 1))
		draw_texture_rect(preload("res://scripts/weapon_art.gd").TEXTURES[weapon_kind], Rect2(0, -10, 24, 24), false)
		draw_set_transform(Vector2.ZERO)
	if glance_left > 0.0:
		# Looking up the ladder: a chevron over his head.
		draw_polyline(PackedVector2Array([Vector2(-4, -33), Vector2(0, -38), Vector2(4, -33)]), pale, 2.0)
	if windup > 0:
		draw_line(Vector2(facing * 9, 0), Vector2(facing * 27, -9), pale, 2)
	if coughing:
		draw_line(Vector2(facing * 8, 2), Vector2(facing * 6, -4), pale, 3)
		draw_circle(Vector2(facing * 14, -5 - fmod(time * 9, 12)), 1.5, Color("c69fa5"))
	if alert_state != State.PATROL:
		var reaction: Texture2D = preload("res://assets/library/alert.png") if alert_state == State.ALERT else preload("res://assets/library/question.png")
		draw_texture_rect(reaction, Rect2(-8, -35, 16, 16), false, pale)
	draw_carried_key()

func draw_carried_key() -> void:
	if sick_guard and not key_taken:
		draw_texture(KEY_TEXTURE, Vector2(-facing * 10 - 14, -12))
