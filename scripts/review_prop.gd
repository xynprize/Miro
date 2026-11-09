extends Node2D
const ART = preload("res://scripts/visual_assets.gd")
var kind := "case"
var used := false
var title := ""

func _draw() -> void:
	var ink := Color("272744")
	var pale := Color("c69fa5")
	if kind == "access":
		draw_texture_rect(preload("res://assets/weapons/remote.svg"), Rect2(-12, -15, 24, 30), false)
		draw_string(ThemeDB.fallback_font, Vector2(-30, -25), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, pale)
	elif kind == "case":
		draw_texture_rect(preload("res://assets/environment/crate.png"), Rect2(-14, -12, 28, 27), false, Color("8b6d9c") if used else Color.WHITE)
		draw_line(Vector2(-5, -2), Vector2(7, -2), pale if not used else Color("494d7e"), 3)
	else:
		draw_rect(Rect2(-20, -29, 40, 40), ink)
		draw_rect(Rect2(-20, -29, 40, 40), pale, false, 2)
		draw_texture_rect(ART.texture("vent"), Rect2(-18, -27, 36, 36), false, pale)
		draw_string(ThemeDB.fallback_font, Vector2(-20, -35), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, pale)
