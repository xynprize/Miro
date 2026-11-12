extends Node2D
const ART = preload("res://scripts/visual_assets.gd")
var kind := "case"
var used := false
var title := ""
var egg_texture: Texture2D
var egg: Dictionary = {}

func _draw() -> void:
	var ink := Color("272744")
	var pale := Color("c69fa5")
	if kind == "access":
		# A service port is a terminal like the others: a desk with a cathode screen.
		var blue := Color("494d7e")
		var glow := Color("8bb5c9")
		draw_rect(Rect2(-14, 2, 28, 14), blue.darkened(0.25))
		draw_rect(Rect2(-14, 2, 28, 2), blue.lightened(0.1))
		draw_rect(Rect2(-12, 4, 3, 12), ink)
		draw_rect(Rect2(9, 4, 3, 12), ink)
		for ring in range(3, 0, -1):
			draw_circle(Vector2(0, -9), 8.0 + ring * 5, Color(glow.r, glow.g, glow.b, 0.025))
		draw_rect(Rect2(-11, -20, 22, 20), ink)
		draw_texture_rect(preload("res://assets/library/terminal.png"), Rect2(-9, -18, 18, 18), false, glow)
		draw_string(ThemeDB.fallback_font, Vector2(-30, -25), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, pale)
	elif kind == "egg":
		# A paper pinned to the wall with a thumbnail of what it shows.
		draw_rect(Rect2(-10, -22, 20, 25), Color("e8e0d0"))
		draw_rect(Rect2(-8, -20, 16, 16), Color("272744"))
		if egg_texture != null:
			draw_texture_rect(egg_texture, Rect2(-8, -20, 16, 16), false)
		draw_circle(Vector2(0, -23), 1.6, Color("c0392b"))
	elif kind == "note":
		draw_rect(Rect2(-6, 2, 12, 14), Color("e8e0d0"))
		draw_line(Vector2(-4, 6), Vector2(4, 6), Color("8b6d9c"), 1)
		draw_line(Vector2(-4, 10), Vector2(3, 10), Color("8b6d9c"), 1)
		draw_string(ThemeDB.fallback_font, Vector2(-14, -4), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, pale)
	elif kind == "potion":
		if not used:
			draw_texture_rect(ART.texture("flask" if get_meta("lab_flask", false) else "bottle"), Rect2(-8, 0, 16, 20) if (get_meta("lab_flask", false) or get_meta("lab_bottle",false)) else Rect2(-6, 0, 12, 16), false, Color(1, 1, 1, 0.95))
	elif kind == "crate":
		# A crate Miro can stand on, or climb inside to hide [E]. Position is 16 px above the floor.
		draw_texture_rect(preload("res://assets/environment/crate.png"), Rect2(-14, -11, 28, 27), false)
	elif kind == "case":
		draw_texture_rect(preload("res://assets/environment/crate.png"), Rect2(-14, -12, 28, 27), false, Color("8b6d9c") if used else Color.WHITE)
		draw_line(Vector2(-5, -2), Vector2(7, -2), pale if not used else Color("494d7e"), 3)
	else:
		draw_rect(Rect2(-20, -29, 40, 40), ink)
		draw_rect(Rect2(-20, -29, 40, 40), pale, false, 2)
		draw_texture_rect(ART.texture("vent"), Rect2(-18, -27, 36, 36), false, pale)
		draw_string(ThemeDB.fallback_font, Vector2(-20, -35), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, pale)
