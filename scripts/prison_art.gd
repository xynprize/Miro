@tool
extends "res://scripts/environment_props.gd"
## Code-native pixel geometry for props pending Julia's final art. No generated bitmaps.
const INK = Color("272744")
const BLUE = Color("494d7e")
const VIOLET = Color("8b6d9c")
const PINK = Color("c69fa5")
const WARM = Color("f2d3ab")

const WINDOWS := [Vector2(350, 135), Vector2(900, 135), Vector2(560, 330), Vector2(180, 555), Vector2(890, 555)]

const TORCHES := [Vector2(300, 183), Vector2(615, 178), Vector2(1005, 175), Vector2(920, 380), Vector2(470, 374), Vector2(145, 608), Vector2(690, 604), Vector2(1000, 597)]

func _ready() -> void:
	super._ready()
	if get_parent().get("light_points") != null:
		# The first torch (outside the cell) stays out of the blanket's no-go zones, so the
		# tutorial's first refuge works.
		for point in TORCHES.slice(1):
			get_parent().light_points.append(point)
	for point in WINDOWS:
		add_ledge(Rect2(point + Vector2(-23, 23), Vector2(46, 4)))

func _process(_delta: float) -> void:
	tick_torches()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1120, 756), INK)
	# Staggered masonry, deterministic wear, buttresses and deep window recesses.
	for row in range(28):
		for column in range(25):
			var x := column * 48 - (24 if row % 2 else 0)
			var y := row * 28
			var color := BLUE.darkened(0.35 + float((row * 7 + column * 3) % 5) * 0.045)
			draw_rect(Rect2(x + 1, y + 1, 46, 26), color)
			if (row * 3 + column) % 11 == 0:
				draw_polyline(PackedVector2Array([Vector2(x + 20, y + 3), Vector2(x + 16, y + 10), Vector2(x + 23, y + 16)]), INK, 1)
	for x in [28, 420, 812, 1092]:
		for y in range(0, 740, 28):
			draw_rect(Rect2(x, y, 24, 27), BLUE.darkened(0.15))
			draw_line(Vector2(x + 2, y + 1), Vector2(x + 21, y + 1), VIOLET.darkened(0.4), 1)
	for point in WINDOWS:
		window(point)
	# Cell frame and bars end at the door, leaving the player readable.
	draw_rect(Rect2(54, 140, 202, 5), VIOLET)
	draw_rect(Rect2(54, 143, 5, 108), VIOLET)
	for x in range(72, 240, 24):
		draw_line(Vector2(x, 145), Vector2(x, 249), Color(0.55, 0.43, 0.61, 0.35), 2)
	draw_line(Vector2(55, 185), Vector2(251, 185), VIOLET.darkened(0.2), 2)
	draw_string(ThemeDB.fallback_font, Vector2(78, 132), "CELL 07", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, PINK)
	for point in TORCHES:
		torch(point)
	# Crates are real props now (world_features.spawn_crate): solid on top, hide inside with E.
	for point in [Vector2(450, 448), Vector2(700, 672), Vector2(1035, 252)]:
		draw_grounded(SHROOMS, point)
	for point in [Vector2(730, 206), Vector2(295, 402), Vector2(995, 619)]:
		draw_polyline(PackedVector2Array([point + Vector2(-5, 0), point + Vector2(0, 5), point + Vector2(5, 0)]), WARM, 1)
	# Chains and an empty hanging cage in the lower vault.
	for x in [104, 122]:
		draw_line(Vector2(x, 285), Vector2(x, 346), VIOLET, 1)
	draw_rect(Rect2(89, 345, 48, 59), INK)
	draw_rect(Rect2(89, 345, 48, 59), VIOLET, false, 2)
	for x in range(96, 136, 8):
		draw_line(Vector2(x, 348), Vector2(x, 402), PINK.darkened(0.3), 1)
	draw_string(ThemeDB.fallback_font, Vector2(570, 591), "LEAVE A MARK", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, VIOLET)

func window(point: Vector2) -> void:
	draw_rect(Rect2(point - Vector2(20, 40), Vector2(40, 64)), VIOLET.darkened(0.3))
	draw_rect(Rect2(point - Vector2(16, 36), Vector2(32, 58)), INK)
	draw_rect(Rect2(point - Vector2(12, 32), Vector2(5, 47)), BLUE)
	for x in [-7, 3, 13]:
		draw_line(point + Vector2(x, -35), point + Vector2(x, 20), VIOLET.darkened(0.25), 2)
	draw_rect(Rect2(point + Vector2(-23, 23), Vector2(46, 4)), VIOLET)

func torch(point: Vector2) -> void:
	for i in range(5, 0, -1):
		draw_circle(point, float(i * 10), Color(0.95, 0.83, 0.67, 0.012))
	draw_torch(Rect2(point - Vector2(16, 14), Vector2(32, 32)))

func crate(point: Vector2) -> void:
	draw_grounded(CRATE, point)
