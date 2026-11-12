@tool
extends "res://scripts/environment_props.gd"
## Background art for Levels 2-5, drawn behind the tiles. No collision.
## Each authored level has its own look, built from the Kenney library sprites plus drawn set pieces:
##   2 The Symptoms: infirmary corridor (A) and the Keepers' barracks (B), worn and crowded
##   3 The Order: offices and surveillance, cold screens and pipes
##   4 The Ward: clinical white ward (A), green-lit containment (B)
## What stays the same on every floor so it reads as one tower: the masonry shell, the narrow
## barred windows onto the woods (closer each floor), the tower's emblem and the lights.
## Level 5 keeps its original blockout look (legacy_draw).
const ART = preload("res://scripts/visual_assets.gd")
var chapter := 2
var world := Vector2(1120, 756)
var storeys: Array = []
var authored := false
var blueprint: Dictionary = {}
var furniture_cache: Dictionary = {}
var furniture_rects: Dictionary = {}
var fixture_cache: Dictionary = {}
var dressing_lights: Array[Vector2] = []

# Only shift low furniture; ceiling art, platforms and story stations keep their anchors.
const BARRACKS_X := {220:188, 1210:1220, 587:674, 917:851, 1247:1292, 1284:1210, 405:378}
const CABINET_X := {370:332, 1223:1194, 476:492, 929:960, 635:594}
# Left edge of each existing lab cart. Pickups and cart art share these positions.
const CART_X := [[338, 760, 1170, 1580], [452, 801, 1176, 1602], [432, 842, 1252]]
const THEMES := {
	2: {"wall": Color("3a3354"), "mortar": Color("272744"), "light": Color(0.95, 0.78, 0.55), "accent": Color("c69fa5"), "deep": Color("4a3b4f")},
	3: {"wall": Color("2f3a56"), "mortar": Color("1f2640"), "light": Color(0.62, 0.86, 0.95), "accent": Color("8bb5c9"), "deep": Color("2b2f4f")},
	4: {"wall": Color("4f5873"), "mortar": Color("383f5a"), "light": Color(0.92, 0.96, 1.0), "accent": Color("d8e3ea"), "deep": Color("2f4a48")},
}

func _ready() -> void:
	super._ready()
	var path := str(get_parent().get_meta("blueprint", ""))
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary:
		blueprint = data
		chapter = int(data.get("number", 2))
		world = Vector2(data.world_size[0], data.world_size[1])
		storeys = data.get("storeys", [])
		authored = data.has("tiles") and THEMES.has(chapter)
	if authored:
		# Each storey's window has a sill Miro can stand on (same placement as dress_storey).
		var previous := 0.0
		for index in range(storeys.size()):
			var floor_y := float(storeys[index])
			var height := floor_y - previous
			var window_x := 300.0 + float((index * 520) % int(world.x - 400))
			var top := previous + height * 0.22
			if fixture_clear(Rect2(window_x-6,top-3,38,64)):
				add_ledge(Rect2(window_x - 6, top + 54 + 3, 38, 4))
			# Torches and lamps (same placement as dress_storey) light the blanket's no-go zones.
			for step in range(3):
				var lx := lamp_x(140.0 + step * 560 + (index % 2) * 240, previous, previous + minf(60.0,height*0.35))
				if lx <= world.x - 60 and get_parent().get("light_points") != null:
					var point := Vector2(lx, previous + minf(60.0, height * 0.35) + 8)
					get_parent().light_points.append(point)
					dressing_lights.append(point)
			previous = floor_y + 28.0
	prepare_furniture()
	queue_redraw()

func _process(_delta: float) -> void:
	if chapter in [2, 5]:
		tick_torches()

func _draw() -> void:
	if not authored:
		legacy_draw()
		return
	var look: Dictionary = THEMES[chapter]
	draw_rect(Rect2(Vector2.ZERO, world), look.mortar)
	# Masonry shell, shared by every floor of the tower. The second sub-floor is a shade deeper.
	var half := world.y * 0.5
	for row in range(int(world.y / 28) + 1):
		for column in range(int(world.x / 48) + 2):
			var x := column * 48 - (24 if row % 2 else 0)
			var shade: Color = look.wall.darkened(0.3 + ((column * 7 + row * 3) % 4) * 0.035)
			if row * 28 > half:
				shade = shade.lerp(look.deep, 0.45)
			draw_rect(Rect2(x + 1, row * 28 + 1, 46, 26), shade)
	var previous := 0.0
	var index := 0
	draw_crawlspaces()
	for floor_y in storeys:
		dress_storey(index, previous, float(floor_y), look)
		previous = float(floor_y) + 28.0
		index += 1

## Crawlspace ceilings are thin invisible solids; show them as a low brace with hazard stripes,
## so a player reads "crouch here" (Left Ctrl) before bumping into it.
func draw_crawlspaces() -> void:
	var path := str(get_parent().get_meta("blueprint", ""))
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	for solid in data.get("solids", []):
		if not str(solid.name).begins_with("Crawl"):
			continue
		var rect := Rect2(solid.position[0] - 14, solid.position[1] - 3, 28, 8)
		draw_rect(rect, Color("1b1b30"))
		for stripe in range(4):
			draw_rect(Rect2(rect.position.x + stripe * 7, rect.position.y + 1, 4, 6), Color("f2d3ab") if stripe % 2 == 0 else Color("8b6d9c"))

## The original blockout (The Foundation).
func legacy_draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, world), Color("272744"))
	for row in range(32):
		for column in range(24):
			var x := column * 48 - (24 if row % 2 else 0)
			draw_rect(Rect2(x + 1, row * 28 + 1, 46, 26), Color("494d7e").darkened(0.35 + (column % 3) * 0.04))
	for x in [28, 420, 812, 1092]:
		draw_rect(Rect2(x, 0, 20, 896), Color("494d7e"))
	for point in [Vector2(180, 155), Vector2(530, 155), Vector2(950, 155), Vector2(450, 350), Vector2(850, 350), Vector2(200, 575), Vector2(700, 575)]:
		draw_circle(point + Vector2(4, 2), 22, Color(0.95, 0.83, 0.67, 0.025))
		draw_torch(Rect2(point - Vector2(16, 14), Vector2(32, 32)))
	for point in [Vector2(980, 252), Vector2(980, 448), Vector2(530, 672)]:
		draw_grounded(CRATE, point)
	for point in [Vector2(1035, 252), Vector2(350, 448), Vector2(700, 672)]:
		draw_grounded(SHROOMS, point)

func vent_clear(rect: Rect2) -> bool:
	var features = get_parent().get("world_features")
	if is_instance_valid(features):
		for prop in features.props:
			if is_instance_valid(prop) and prop.kind == "hide" and rect.intersects(Rect2(prop.position-Vector2(30,48),Vector2(60,68))):return false
	for hide in blueprint.get("features",{}).get("hides",[]):
		if hide.title != "CRATE" and rect.intersects(Rect2(Vector2(hide.position[0],hide.position[1])-Vector2(30,48),Vector2(60,68))):return false
	return true

func refresh_fixture_clearance() -> void:
	fixture_cache.clear()
	if not authored:return
	for point in dressing_lights:get_parent().light_points.erase(point)
	dressing_lights.clear()
	var previous := 0.0
	for index in range(storeys.size()):
		var floor_y := float(storeys[index])
		var y := previous+minf(60.0,(floor_y-previous)*0.35)
		for step in range(3):
			var anchor := 140.0+step*560+(index%2)*240
			if anchor > world.x-60:continue
			var point := Vector2(lamp_x(anchor,previous,y),y+8)
			dressing_lights.append(point)
			get_parent().light_points.append(point)
		previous=floor_y+28.0

func fixture_clear(rect: Rect2) -> bool:
	if not fixture_cache.has(rect):fixture_cache[rect]=fixture_clear_uncached(rect)
	return fixture_cache[rect]

func fixture_clear_uncached(rect: Rect2) -> bool:
	if not vent_clear(rect):return false
	for tile in blueprint.get("tiles",[]):
		if rect.intersects(Rect2(float(tile[0])*28,float(tile[1])*28,28,28)):return false
	for gate in blueprint.get("gates",[]):
		if rect.intersects(Rect2(Vector2(gate.position[0],gate.position[1])-Vector2(gate.size[0],gate.size[1])/2,Vector2(gate.size[0],gate.size[1])).grow(8)):return false
	return true

func lamp_x(anchor: float, ceiling: float, y: float) -> float:
	for step in range(17):
		var x := anchor + step * 14.0
		var rect := Rect2(x-12,ceiling,24,y-ceiling+10)
		if x > world.x-32 or not fixture_clear(rect):continue
		var clear := true
		for area in blueprint.get("interactables",[]):
			if str(area.get("kind","")) in ["sigil","station"] and rect.intersects(Rect2(Vector2(area.position[0],area.position[1])-Vector2(30,55),Vector2(60,70))):clear=false
		for station in blueprint.get("stations",[]):
			if str(station.get("id","")) == "WardRelease" and rect.intersects(Rect2(300,305,168,32)):clear=false
			if rect.intersects(Rect2(Vector2(station.position[0],station.position[1])-Vector2(30,55),Vector2(60,70))):clear=false
		if clear:return x
	return anchor

func stamp(id: String, rect: Rect2, tint := Color(1, 1, 1, 0.8)) -> void:
	if not vent_clear(rect):return
	# Warning fixtures must not cover a window on a short or crowded storey.
	if id in ["warning", "beacon"]:
		var previous := 0.0
		for index in range(storeys.size()):
			var floor_y := float(storeys[index])
			var wx := 300.0 + float((index * 520) % int(world.x - 400))
			var window := Rect2(wx - 6, previous + (floor_y - previous) * 0.22 - 3, 38, 64)
			if rect.grow(4).intersects(window):
				rect.position.x = window.end.x + 10
			previous = floor_y + 28.0
	draw_texture_rect(ART.texture(id), rect, false, tint)

## One storey: pillars, a window onto the woods, light pools, the emblem and themed set pieces.
## Every position comes from the storey index, so the art is identical on every run.
func dress_storey(index: int, ceiling: float, floor_y: float, look: Dictionary) -> void:
	var height := floor_y - ceiling
	var second_half := index >= 3
	for column in range(0, int(world.x / 28), 15):
		var x := column * 28.0 + 6
		if not vent_clear(Rect2(x,ceiling,16,height)):continue
		draw_rect(Rect2(x, ceiling, 16, height), look.wall.darkened(0.12))
		draw_rect(Rect2(x, ceiling, 3, height), look.wall.lightened(0.08))
	var window_x := 300.0 + float((index * 520) % int(world.x - 400))
	draw_window(Vector2(window_x, ceiling + height * 0.22), index)
	for step in range(3):
		var x := 140.0 + step * 560 + (index % 2) * 240
		if x > world.x - 60:
			continue
		var y := ceiling + minf(60.0, height * 0.35)
		x = lamp_x(x,ceiling,y)
		for ring in range(5):
			draw_circle(Vector2(x, y + 8), 70.0 - ring * 12, Color(look.light.r, look.light.g, look.light.b, 0.02))
		draw_rect(Rect2(x - 40, floor_y - 4, 80, 4), Color(look.light.r, look.light.g, look.light.b, 0.08))
		if chapter == 2 and not second_half:
			draw_torch(Rect2(x - 16, y - 14, 32, 32))
		else:
			draw_lamp(Vector2(x, ceiling), y, look)
	draw_emblem(Vector2(window_x + 120, ceiling + height * 0.38), look)
	match chapter:
		2:
			dress_barracks(index, ceiling, floor_y, second_half)
		3:
			dress_surveillance(index, ceiling, floor_y, second_half, look)
		4:
			dress_ward(index, ceiling, floor_y, second_half)

func draw_window(point: Vector2, depth: int) -> void:
	if not fixture_clear(Rect2(point-Vector2(6,3),Vector2(38,64))):return
	var size := Vector2(26, 54)
	draw_rect(Rect2(point - Vector2(3, 3), size + Vector2(6, 6)), Color("1b1b30"))
	draw_rect(Rect2(point, size), Color("2b3d5c"))
	draw_rect(Rect2(point + Vector2(0, size.y * 0.55), Vector2(size.x, size.y * 0.45)), Color("22314a"))
	# Pines: taller as Miro descends and the woods come closer.
	var tree_height := 10.0 + (chapter - 1) * 5 + depth * 1.5
	for tree in range(3):
		var base := point + Vector2(4 + tree * 9, size.y)
		var tip := base + Vector2(0, -minf(size.y - 4, tree_height + (tree % 2) * 6))
		draw_colored_polygon(PackedVector2Array([base + Vector2(-6, 0), base + Vector2(6, 0), tip]), Color("1d2a2a"))
	for bar in range(1, 4):
		draw_rect(Rect2(point.x + bar * size.x / 4 - 1, point.y, 2, size.y), Color("8b6d9c"))
	# The stone sill Miro can stand on.
	draw_rect(Rect2(point + Vector2(-6, size.y + 3), Vector2(38, 4)), Color("8b6d9c"))

func draw_emblem(center: Vector2, look: Dictionary) -> void:
	var color: Color = look.accent
	color.a = 0.32
	draw_arc(center, 11, 0, TAU, 24, color, 2)
	draw_polyline(PackedVector2Array([center + Vector2(0, -9), center + Vector2(8, 5), center + Vector2(-8, 5), center + Vector2(0, -9)]), color, 2)
	draw_circle(center + Vector2(0, 1), 2.5, color)

func draw_lamp(anchor: Vector2, y: float, look: Dictionary) -> void:
	draw_line(anchor, Vector2(anchor.x, y - 4), Color("1b1b30"), 2)
	draw_colored_polygon(PackedVector2Array([Vector2(anchor.x - 9, y + 4), Vector2(anchor.x + 9, y + 4), Vector2(anchor.x + 4, y - 4), Vector2(anchor.x - 4, y - 4)]), Color("1b1b30"))
	draw_rect(Rect2(anchor.x - 6, y + 3, 12, 2), look.light)

## Level 2: cots and bottles in the sick corridor; lockers and laundry in the barracks.
func prepare_furniture() -> void:
	if not authored or chapter not in [2,3]:return
	for row in range(storeys.size()):
		for step in range(5 if chapter == 2 else 4):
			var x: float = 220.0 + step * 330 + row * 37 if chapter == 2 else 260.0 + step * 400 + row * 53
			if x > world.x - (120 if chapter == 2 else 140):continue
			if chapter == 2:
				furniture_x(float(BARRACKS_X.get(int(x), x)),52 if row >= 3 else 54,52 if row >= 3 else 23,float(storeys[row]))
			else:
				furniture_x(float(CABINET_X.get(int(x+110), x+110)),26,44,float(storeys[row]))

func furniture_x(anchor: float, width: float, height: float, floor_y: float) -> float:
	var key := Vector3(anchor, floor_y, width)
	if furniture_cache.has(key):
		return furniture_cache[key]
	var blockers: Array[Rect2] = []
	for tile in blueprint.get("tiles", []):
		var top := float(tile[1]) * 28.0
		if top < floor_y and top + 28.0 > floor_y - height - 4.0:
			blockers.append(Rect2(float(tile[0])*28, top, 28, 28))
	for step in range(17):
		for side in [1.0, -1.0]:
			var x: float = anchor + step * side * 14.0
			if x < 32 or x + width > world.x - 32:
				continue
			var rect := Rect2(x - 4, floor_y - height - 4, width + 8, height + 3)
			var clear := vent_clear(rect)
			for tile: Rect2 in blockers:
				if rect.intersects(tile):
					clear = false
			if not clear:continue
			for area in blueprint.get("interactables", []):
				var at := Vector2(area.position[0], area.position[1])
				if rect.intersects(Rect2(at - Vector2(36,56), Vector2(72,78))):clear = false
			for station in blueprint.get("stations", []):
				var at := Vector2(station.position[0], station.position[1])
				if rect.intersects(Rect2(at - Vector2(40,56), Vector2(80,78))):clear = false
			for port in blueprint.get("features", {}).get("ports", []):
				var at := Vector2(port[0],port[1])
				if rect.intersects(Rect2(at - Vector2(34,28), Vector2(68,48))):clear = false
			for other: Rect2 in furniture_rects.values():
				if rect.intersects(other):clear = false
			if clear:
				furniture_rects[key] = rect
				furniture_cache[key] = x
				return x
	furniture_cache[key] = INF
	return INF

func dress_barracks(index: int, ceiling: float, floor_y: float, second_half: bool) -> void:
	var frame := Color("5a4a5e")
	for step in range(5):
		var x := 220.0 + step * 330 + index * 37
		if x > world.x - 120:
			continue
		x = furniture_x(float(BARRACKS_X.get(int(x), x)), 52 if second_half else 54, 52 if second_half else 23, floor_y)
		if x == INF:continue
		if second_half:
			for locker in range(3):
				var rect := Rect2(x + locker * 18, floor_y - 52, 16, 52)
				draw_rect(rect, Color("47506b"))
				draw_rect(Rect2(rect.position + Vector2(3, 6), Vector2(10, 2)), Color("2b2f4f"))
				draw_rect(Rect2(rect.position + Vector2(3, 10), Vector2(10, 2)), Color("2b2f4f"))
			draw_line(Vector2(x + 70, ceiling + 34), Vector2(x + 170, ceiling + 40), Color("8b6d9c"), 1)
			for sheet in range(3):
				draw_rect(Rect2(x + 78 + sheet * 30, ceiling + 36 + sheet * 2, 22, 30), Color(0.85, 0.82, 0.86, 0.22))
		else:
			draw_rect(Rect2(x, floor_y - 18, 54, 6), frame)
			draw_rect(Rect2(x + 2, floor_y - 12, 3, 12), frame)
			draw_rect(Rect2(x + 49, floor_y - 12, 3, 12), frame)
			draw_rect(Rect2(x + 4, floor_y - 23, 46, 5), Color(0.85, 0.82, 0.86, 0.25))

## Level 3: banks of monitors, filing cabinets, pipes, warning lights.
func dress_surveillance(index: int, ceiling: float, floor_y: float, second_half: bool, look: Dictionary) -> void:
	for column in range(2, int(world.x / 28) - 2, 9):
		stamp("pipe", Rect2(column * 28.0, ceiling + 2, 28, 28), Color(1, 1, 1, 0.55))
	for step in range(4):
		var x := 260.0 + step * 400 + index * 53
		if x > world.x - 140:
			continue
		var bank := Rect2(x, ceiling + 30, 84, 34)
		if not vent_clear(bank.grow(3)):continue
		draw_rect(bank.grow(3), Color("1b1b30"))
		for screen in range(3):
			var glow: Color = look.light.darkened(0.35 + 0.15 * ((screen + index + step) % 3))
			draw_rect(Rect2(bank.position + Vector2(2 + screen * 28, 2), Vector2(24, 30)), Color(glow.r, glow.g, glow.b, 0.55))
		# Background furniture is tinted down so it never reads as something to pick up.
		var cabinet_x := furniture_x(float(CABINET_X.get(int(x + 110), x + 110)), 26, 44, floor_y)
		if cabinet_x != INF:
			stamp("cabinet", Rect2(cabinet_x, floor_y - 44, 26, 44), Color(0.45, 0.45, 0.6, 0.7))
		if second_half:
			stamp("warning", Rect2(x + 150, ceiling + 44, 22, 22), Color(1, 1, 1, 0.7))
			stamp("beacon", Rect2(x + 180, ceiling + 6, 22, 22), Color(1, 1, 1, 0.8))
		elif vent_clear(Rect2(x+150,floor_y-30,34,30)):
			draw_rect(Rect2(x + 150, floor_y - 30, 34, 30), Color("1b1b30"))
			draw_rect(Rect2(x + 153, floor_y - 27, 28, 3), look.light.darkened(0.5))

func draw_hazard(center: Vector2) -> void:
	var points := PackedVector2Array([center + Vector2(0, -11), center + Vector2(12, 9), center + Vector2(-12, 9)])
	draw_colored_polygon(points, Color(0.55, 0.62, 0.35, 0.55))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), Color("1b1b30"), 1.5)
	draw_rect(Rect2(center.x - 1, center.y - 4, 2, 7), Color("1b1b30"))

## Level 4: observation glass, carts and flasks; containment tanks and hazard signs.
func dress_ward(index: int, ceiling: float, floor_y: float, second_half: bool) -> void:
	for step in range(4):
		var x := 240.0 + step * 410 + index * 41
		if x > world.x - 150:
			continue
		if second_half:
			var tank := Rect2(x, floor_y - 78, 40, 74)
			if not vent_clear(tank.grow(3)):continue
			draw_rect(tank.grow(3), Color("1b1b30"))
			draw_rect(tank, Color(0.36, 0.72, 0.58, 0.32))
			for bubble in range(4):
				draw_circle(tank.position + Vector2(10 + (bubble * 9) % 22, 12 + bubble * 15), 2.0, Color(0.8, 1, 0.9, 0.35))
			draw_hazard(Vector2(x + 66, ceiling + 52))
			stamp("smoke", Rect2(x - 10, floor_y - 30, 60, 30), Color(1, 1, 1, 0.08))
		else:
			var glass := Rect2(x, ceiling + 26, 92, 40)
			if not vent_clear(glass.grow(3)) or not vent_clear(Rect2(CART_X[index][step],floor_y-38,40,38)):continue
			draw_rect(glass.grow(3), Color("8b9bb4"))
			draw_rect(glass, Color(0.75, 0.86, 0.95, 0.18))
			draw_line(glass.position + Vector2(12, 34), glass.position + Vector2(34, 6), Color(1, 1, 1, 0.25), 2)
			var cart_x: float = CART_X[index][step]
			draw_rect(Rect2(cart_x, floor_y - 20, 40, 4), Color("8b9bb4"))
			stamp("microscope", Rect2(cart_x + 20, floor_y - 38, 18, 18), Color(1, 1, 1, 0.8))
			draw_rect(Rect2(cart_x + 2, floor_y - 16, 3, 16), Color("8b9bb4"))
			draw_rect(Rect2(cart_x + 35, floor_y - 16, 3, 16), Color("8b9bb4"))
