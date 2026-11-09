extends Node2D
## Isolated art preview; does not alter saves or start gameplay.
const GUITAR = preload("res://assets/weapons/guitar_red_v2.png")
const FX = preload("res://scripts/guitar_music_fx.gd")
var capture := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	get_viewport().get_window().size = Vector2i(1280, 720)
	get_viewport().get_window().content_scale_size = Vector2i(640, 360)
	var label := Label.new()
	label.text = "MIRO / RED ELECTRIC GUITAR\nSprite + pixel rays and music notes"
	label.position = Vector2(24, 18)
	label.add_theme_color_override("font_color", Color("f2d3ab"))
	add_child(label)
	capture = "--capture-guitar" in OS.get_cmdline_user_args()
	if capture:
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://tmp/guitar")
		get_viewport().get_texture().get_image().save_png("res://tmp/guitar/guitar-preview.png")
		get_tree().quit()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color("272744"))
	for x in range(0, 640, 16):
		for y in range(80, 336, 16):
			if (x / 16 + y / 16) % 2 == 0:
				draw_rect(Rect2(x, y, 16, 16), Color("2d2e4c"))
	draw_texture_rect(GUITAR, Rect2(35, 100, 208, 208), false)
	draw_texture_rect(GUITAR, Rect2(295, 183, 32, 32), false)
	var strength := 0.72 if capture else 1.0 - fposmod(Time.get_ticks_msec() / 1000.0, 1.0)
	FX.draw_burst(self, Vector2(323, 194), Vector2(1, -0.18), strength, 170)
	draw_string(ThemeDB.fallback_font, Vector2(26, 344), "Transparent PNG / nearest filter / game size 27-32 px / original art retained", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f2d3ab"))
