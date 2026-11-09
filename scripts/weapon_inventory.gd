extends Control
var player: IntroPlayer
const ART = preload("res://scripts/weapon_art.gd")
func _process(_delta: float) -> void:
	queue_redraw()
func _draw() -> void:
	if not is_instance_valid(player) or not is_instance_valid(player.controls):
		return
	var controls = player.controls
	for i in range(5):
		var item: String = controls.slots[i]
		var x := i * 53.0
		draw_style_box(panel_style(controls.active == item and item != ""), Rect2(x, 0, 50, 38))
		draw_string(ThemeDB.fallback_font, Vector2(x + 4, 11), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		if item != "":
			var available: bool = controls.has_remote if item == "remote" else (player.has_supplies if item in ["shank", "c4"] else true)
			draw_texture_rect(ART.TEXTURES[item], Rect2(x + 17, 2, 27, 27), false, Color.WHITE if available else Color(1, 1, 1, 0.25))
			var count := ""
			if item == "c4":
				count = "×%d" % player.c4_count
			elif item in player.guns:
				count = "%d / %d" % [player.ammunition if item == player.equipped_gun else player.gun_ammo.get(item, 0), controls.reserves.get(item, 0)]
			draw_string(ThemeDB.fallback_font, Vector2(x + 12, 35), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
	draw_style_box(panel_style(controls.active == "blanket"), Rect2(274, 0, 50, 38))
	draw_string(ThemeDB.fallback_font, Vector2(278, 11), "Q", HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
	draw_texture_rect(ART.TEXTURES.blanket, Rect2(291, 3, 27, 27), false)
	draw_string(ThemeDB.fallback_font, Vector2(335, 14), "[N] Inventory", HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	var hint := "Left click: use"
	if controls.active == "c4":
		hint = "Right click: place · Left click: detonate · E: recover"
	elif controls.active in player.guns:
		hint = "Left click: fire · Right click: focus · R: reload"
	elif controls.active == "remote":
		hint = "Left click: open remote / MP3"
	draw_string(ThemeDB.fallback_font, Vector2(0, 51), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
	# Attachment state beside the health/header, never a selectable inventory item.
	if player.suppressor_uses > 0 or controls.spares > 0:
		draw_string(ThemeDB.fallback_font, Vector2(215, -32), "SUP %d/3 · spare %d" % [player.suppressor_uses, controls.spares], HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
	if controls.reload_left > 0 or controls.attach_left > 0:
		var center := Vector2(340, 32)
		draw_arc(center, 9, -PI / 2, -PI / 2 + TAU * controls.progress, 24, Color(1, 1, 1, 0.75), 2)
		draw_string(ThemeDB.fallback_font, Vector2(355, 35), "Reloading" if controls.reload_left > 0 else "Attaching", HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
	if is_instance_valid(player.pending_guard):
		draw_style_box(panel_style(true), Rect2(120, 75, 372, 86))
		draw_string(ThemeDB.fallback_font, Vector2(136, 96), "Take %s? Carry limit: two guns." % player.pending_guard.weapon_kind.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		draw_string(ThemeDB.fallback_font, Vector2(136, 119), "[Z] Replace %s   [X] Replace %s" % [player.guns[0], player.guns[1]], HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		draw_string(ThemeDB.fallback_font, Vector2(136, 145), "[Esc] Keep current guns", HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
func panel_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.26, 0.92)
	style.border_color = Color("f2d3ab") if selected else Color("52566b")
	style.set_border_width_all(1)
	return style
