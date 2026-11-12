@tool
class_name IntroArea
extends Area2D
const LIBRARY = preload("res://scripts/visual_assets.gd")

@export_enum("bed", "door", "cover", "ladder", "sigil", "exit", "brother", "note") var kind: String = "cover"
@export var area_size := Vector2(60, 60):
	set(value):
		area_size = Vector2(maxf(1, value.x), maxf(1, value.y))
		sync_shape()
		queue_redraw()
var activated: bool = false

func _ready() -> void:
	sync_shape()

func sync_shape() -> void:
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision:
		var rectangle := RectangleShape2D.new()
		rectangle.size = area_size
		collision.shape = rectangle

func contains(point: Vector2) -> bool:
	return Rect2(global_position - area_size / 2, area_size).has_point(point)

func _draw() -> void:
	var pale := Color("f2d3ab")
	var pink := Color("c69fa5")
	var purple := Color("8b6d9c")
	var dark := Color("272744")
	match kind:
		"bed":
			draw_rect(Rect2(-25, -8, 50, 8), purple)
			draw_rect(Rect2(-22, -14, 12, 6), pale)
			draw_rect(Rect2(-9, -13, 31, 7), Color("494d7e"))
			for x in [-24, 20]:
				draw_rect(Rect2(x, -4, 4, 17), pink)
			if not activated:
				draw_rect(Rect2(-9, 3, 16, 7), dark)
				draw_line(Vector2(-5, 5), Vector2(3, 5), pale, 1)
		"door":
			if not activated:
				for x in [-5, 4]:
					draw_rect(Rect2(x, -area_size.y / 2, 3, area_size.y), purple)
				draw_rect(Rect2(-7, -2, 15, 9), pale)
				draw_circle(Vector2(1, 2), 2, dark)
				draw_texture_rect(LIBRARY.texture("hazard"), Rect2(-10, -8, 20, 20), false)
		"cover":
			# Shadow zones are gone: a vent or cabinet stands where each one was (world_features.convert_cover_zones).
			pass
		"ladder":
			for x in [-9, 9]:
				draw_rect(Rect2(x, -area_size.y / 2, 2, area_size.y), purple)
			for y in range(int(-area_size.y / 2), int(area_size.y / 2), 10):
				draw_line(Vector2(-8, y), Vector2(9, y), pink, 2)
		"sigil":
			draw_rect(Rect2(-13, -20, 26, 42), dark)
			draw_rect(Rect2(-11, -18, 22, 38), purple, false, 2)
			var color := pale if activated else pink
			draw_polyline(PackedVector2Array([Vector2(-7, 6), Vector2(0, -9), Vector2(7, 6), Vector2(-7, 6)]), color, 2)
			draw_line(Vector2(0, -12), Vector2(0, 13), color, 2)
		"brother":
			pass # The voice is a remote trigger, not a physical door.
		"exit":
			draw_rect(Rect2(-22, -50, 44, 76), dark)
			draw_rect(Rect2(-25, -53, 50, 79), purple, false, 3)
			draw_texture_rect(LIBRARY.texture("bars"), Rect2(-22, -49, 44, 72), false, pink)
			if kind == "exit":
				draw_polyline(PackedVector2Array([Vector2(-8, -12), Vector2(0, -4), Vector2(8, -12)]), pale, 2)
		"note":
			if name == "Guitar":
				draw_line(Vector2(0, -8), Vector2(0, 12), purple, 2)
				draw_line(Vector2(-10, 14), Vector2(10, 14), purple, 2)
				if not activated:
					draw_texture_rect(preload("res://scripts/weapon_art.gd").TEXTURES.guitar, Rect2(-17, -30, 34, 34), false)
			elif name == "RemoteTerminal":
				draw_texture_rect(LIBRARY.texture("terminal"), Rect2(-24, -34, 48, 48), false)
				draw_circle(Vector2(0, -21), 2, pale if activated else pink)
			elif name == "WardRelease":
				draw_texture_rect(LIBRARY.texture("lever"), Rect2(-16, -20, 32, 32), false)
			else:
				draw_texture_rect(LIBRARY.texture("record"), Rect2(-9, -12, 18, 24), false)
