extends Node2D
const SINGLE_NOTE = preload("res://assets/weapons/music_note.svg")
const DOUBLE_NOTE = preload("res://assets/weapons/music_double_note.svg")
## Cosmetic-only, pixel-drawn rays and notes; no font dependency or gameplay RNG.
## Call strum(aim, radius) from a weapon, or use draw_burst from an existing _draw.
@export_range(0.1, 2.0) var duration := 0.35
@export var reach := 120.0
var remaining := 0.0
var direction := Vector2.RIGHT

func strum(aim := Vector2.RIGHT, radius := 120.0) -> void:
	direction = aim.normalized() if aim.length_squared() > 0.01 else Vector2.RIGHT
	reach = maxf(0, radius)
	remaining = duration
	queue_redraw()

func _process(delta: float) -> void:
	if remaining > 0:
		remaining = maxf(0, remaining - delta)
		queue_redraw()

func _draw() -> void:
	if remaining > 0:
		draw_burst(self, Vector2.ZERO, direction, remaining / duration, reach)

static func draw_burst(canvas: CanvasItem, origin: Vector2, aim: Vector2, strength: float, radius: float) -> void:
	var fade := clampf(strength, 0, 1)
	if fade <= 0 or radius <= 0:
		return
	var forward := aim.normalized() if aim.length_squared() > 0.01 else Vector2.RIGHT
	var side := forward.orthogonal()
	var age := 1.0 - fade
	# Short segmented rays stay crisp under nearest filtering. Notes stay upright
	# when aiming left/up, rather than becoming mirrored or rotated glyphs.
	for lane in range(-2, 3):
		var color := Color("d32632") if absi(lane) == 2 else Color("f2d3ab")
		color.a = fade * 0.7
		for segment in range(3):
			var t := fposmod(age * 0.8 + segment * 0.3, 1.0)
			var start := origin + forward * (10 + t * radius * 0.8) + side * float(lane) * (2 + t * 7)
			canvas.draw_line(start.round(), (start + forward * (5 + t * 8)).round(), color, 1, false)
	for index in range(8):
		var t := fposmod(float(index) / 8.0 + age * 0.65, 1.0)
		var wobble := sin(t * 12 + index * 1.7) * (5 + t * 12)
		var point := (origin + forward * (10 + t * radius * 0.88) + side * wobble).round()
		var color := Color("f2d3ab") if index % 2 == 0 else Color("c69fa5")
		color.a = fade * (1 - t * 0.55)
		draw_note(canvas, point, color, index % 3 == 0)

static func draw_note(canvas: CanvasItem, point: Vector2, color: Color, paired := false) -> void:
	canvas.draw_texture(DOUBLE_NOTE if paired else SINGLE_NOTE, point + Vector2(-4, -6), color)

