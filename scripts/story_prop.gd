@tool
extends Node2D
## Restrained symptom animation and ward set dressing; mirospec.md Art and floor progression.
@export_enum("sick_prisoner", "ward_chamber") var kind := "sick_prisoner"
var clock := 0.0

var cough_count := 0
var cough_was := false

func _process(delta: float) -> void:
	if not Engine.is_editor_hint() and get_parent().get_parent().has_method("controls_locked") and get_parent().get_parent().controls_locked():
		return
	clock += delta
	if kind == "sick_prisoner":
		var coughing := fmod(clock, 4.0) > 3.2
		var level = get_parent().get_parent()
		if coughing and not cough_was and level.get("player") != null:
			cough_count += 1
			get_node("/root/SoundFX").cough_near(global_position, level.player.global_position, cough_count + 1)
		cough_was = coughing
	queue_redraw()

func _draw() -> void:
	if kind == "sick_prisoner":
		draw_rect(Rect2(-30, -55, 60, 70), Color("272744"))
		var cough := fmod(clock, 4.0) > 3.2
		var shift := sin(clock * 35) * 2 if cough else sin(clock * 2) * 0.5
		draw_rect(Rect2(-7 + shift, -12, 14, 26), Color("8b6d9c"))
		draw_circle(Vector2(shift + (4 if cough else 0), -20 + (3 if cough else 0)), 6, Color("c69fa5"))
		draw_line(Vector2(shift, -7), Vector2(shift + 10, -17 if cough else 2), Color("c69fa5"), 3)
		if cough:
			for index in range(3):
				draw_circle(Vector2(12 + index * 5, -18 - index * 2), 1, Color("f2d3ab"))
		for x in range(-28, 30, 14):
			draw_line(Vector2(x, -55), Vector2(x, 15), Color("494d7e"), 2)
	else:
		draw_rect(Rect2(-60, -65, 120, 80), Color("272744"))
		draw_rect(Rect2(-60, -65, 120, 80), Color("8b6d9c"), false, 2)
		draw_rect(Rect2(-35, -5, 70, 9), Color("494d7e"))
		for x in [-25, 25]:
			draw_line(Vector2(x, 4), Vector2(x, 14), Color("8b6d9c"), 3)
			draw_line(Vector2(x, -8), Vector2(x, 4), Color("c69fa5"), 3)
		draw_rect(Rect2(40, -50, 10, 20), Color("c69fa5"))
		draw_line(Vector2(45, -30), Vector2(20, -7), Color("8b6d9c"), 1)
		var art = preload("res://scripts/visual_assets.gd")
		draw_texture_rect(art.texture("microscope"), Rect2(-14, -37, 28, 32), false)
		if not get_meta("collectible_bottle",false):
			draw_texture_rect(art.texture("bottle"), Rect2(-18, -25, 16, 20), false)
		if not get_meta("collectible_flask", false):
			draw_texture_rect(art.texture("flask"), Rect2(2, -25, 16, 20), false)
