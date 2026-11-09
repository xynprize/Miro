extends Control
## Screen-space text anchored to a world-space speaker; never intercepts gameplay input.
var actor: Node2D
var thought := false
var text_label: Label
const SPEECH = preload("res://assets/library/speech.png")
const THOUGHT = preload("res://assets/library/thought.png")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(252, 88)
	text_label = Label.new()
	text_label.position = Vector2(12, 7)
	text_label.size = Vector2(228, 72)
	text_label.add_theme_font_size_override("font_size", 11)
	text_label.add_theme_color_override("font_color", Color("272744"))
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(text_label)

func follow_actor() -> void:
	if not is_instance_valid(actor):
		visible = false
		return
	size.y = maxf(42, text_label.get_line_count() * text_label.get_line_height() + 14)
	text_label.size.y = size.y - 14
	var point := actor.get_global_transform_with_canvas().origin
	var viewport := get_viewport_rect().size
	position = Vector2(clampf(point.x - size.x / 2, 8, viewport.x - size.x - 8), clampf(point.y - size.y - 52, 124, viewport.y - size.y - 40))
	queue_redraw()

func _draw() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fbf5ef")
	style.border_color = Color("8b6d9c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12 if thought else 5)
	draw_style_box(style, Rect2(Vector2.ZERO, size))
	var tail_x := size.x / 2
	if is_instance_valid(actor):
		tail_x = clampf(actor.get_global_transform_with_canvas().origin.x - position.x, 20, size.x - 20)
	# Reuse the licensed bubble assets as the speaker/thought tail badge.
	draw_texture_rect(THOUGHT if thought else SPEECH, Rect2(tail_x - 12, size.y - 2, 24, 24), false, Color("fbf5ef"))
