extends Control
## Between-level cinematics (C6-C9): a split-screen call over the MP3. Miro, inside the tower,
## on the left; his brother on the right. Every line plays in full (the scene waits for each
## clip). Until Level 3 reveals his name Niro is only a voice, a dark shape at his desk.
## Lines: data/interludes.json. Tab / Enter / Space / Esc skips.
signal finished
const C = preload("res://scripts/cinema.gd")
const GAP := 0.45
const TAIL := 2.2
var floor_done := 1
var elapsed := 0.0
var done := false
var audio: Node
var data: Dictionary = {}
var starts: Array[float] = []
var lengths: Array[float] = []
var played := -1
var total := 0.0
var kael: Texture2D = preload("res://assets/characters/kael_idle.png")
var miro_idle: Texture2D = preload("res://assets/characters/miro_idle.png")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	audio = preload("res://scripts/cine_audio.gd").new()
	add_child(audio)
	var scenes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/interludes.json")).scenes
	data = scenes.get(str(floor_done), scenes["1"]).duplicate(true)
	# Branching: a HUNTED run (kills over stealth) hears Niro's opening line change; nothing else does.
	if data.has("hunted_first") and get_node("/root/Campaign").reputation() == "HUNTED" and get_node("/root/Campaign").total("kills") > 0:
		data.lines[0][1] = data.hunted_first
	audio.loop("wind_loop", -26.0, 1.0)
	audio.loop("rain_loop", -24.0, 1.5)
	var radio = get_node("/root/RemoteRadio")
	var cursor := 1.0
	for line in data.lines:
		var prefix := "miro" if str(line[0]) == "MIRO" else "niro"
		var length := maxf(2.2, str(line[1]).length() * 0.06)
		if radio.has_clip(str(line[1]), prefix):
			length = load(radio.clip_path(str(line[1]), prefix)).get_length()
		starts.append(cursor)
		lengths.append(length)
		cursor += length + GAP
	total = cursor + TAIL

func _process(delta: float) -> void:
	if done:
		return
	elapsed += delta
	audio.tick(elapsed)
	var index := current_line()
	if index != played and index >= 0:
		played = index
		var line: Array = data.lines[index]
		var radio = get_node("/root/RemoteRadio")
		if str(line[0]) == "MIRO":
			radio.say_in_room(str(line[1]), "miro", "Voice")
		else:
			radio.say(str(line[1]))
	queue_redraw()
	if elapsed >= total:
		finish()

## The line being spoken right now (-1 in the gaps and at the ends).
func current_line() -> int:
	for index in range(starts.size()):
		if elapsed >= starts[index] and elapsed < starts[index] + lengths[index]:
			return index
	return -1

func _input(event: InputEvent) -> void:
	var pad_skip: bool = event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_START]
	if not done and (pad_skip or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_TAB, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE])):
		get_viewport().set_input_as_handled()
		finish()

func finish() -> void:
	if done:
		return
	done = true
	get_node("/root/RemoteRadio").stop()
	finished.emit()
	queue_free()

func _draw() -> void:
	var unit := size / C.FRAME
	draw_set_transform(Vector2.ZERO, 0.0, unit)
	var t := elapsed
	var index := current_line()
	var speaker := ""
	if index >= 0:
		speaker = str(data.lines[index][0])
	var miro_talks := speaker == "MIRO"
	var niro_talks := speaker != "" and not miro_talks
	panel_miro(t, 1.0 if miro_talks else (0.55 if niro_talks else 0.8))
	panel_niro(t, 1.0 if niro_talks else (0.55 if miro_talks else 0.8))
	# The MP3 link between them.
	draw_rect(Rect2(317, 0, 6, 360), Color("0b0c14"))
	draw_rect(Rect2(311, 160, 18, 30), Color("1b1d2e"))
	draw_rect(Rect2(314, 164, 12, 8), Color(0.6, 0.95, 0.8, 0.5 + 0.4 * sin(t * 6.0)))
	if index >= 0:
		var line: Array = data.lines[index]
		var label := "MIRO" if miro_talks else ("NIRO" if data.named else "THE VOICE")
		C.subtitle(self, "%s:  %s" % [label, str(line[1])], 1.0)
	elif t > total - TAIL:
		C.title(self, Vector2(320, 190), str(data.title), 30, Color("e6d9c3"), 6.0, true)
	C.vignette(self, 0.55)
	C.grain(self, int(t * 24.0), 0.05)
	C.fade(self, 1.0 - C.phase(t, 0.0, 0.8) + C.phase(t, total - 0.8, 0.8))

## Left half: a stone corridor inside the tower, torchlight, Miro with the MP3 glowing.
func panel_miro(t: float, light: float) -> void:
	var rect := Rect2(0, 0, 317, 360)
	C.gradient(self, rect, Color("0c0d18").lerp(Color.BLACK, 1.0 - light), Color("1c1b2b").lerp(Color.BLACK, 1.0 - light))
	for x in range(0, 317, 38):
		draw_rect(Rect2(x, 40, 2, 220), Color(0.05, 0.05, 0.09, 0.9))   # cell bars
	draw_rect(Rect2(0, 262, 317, 98), Color("12121c"))
	# A barred window high in the wall: the storm outside, in the start menu's natural rain.
	var window := Rect2(206, 36, 96, 84)
	C.gradient(self, window, Color("141a2e").lerp(Color.BLACK, 1.0 - light), Color("232a45").lerp(Color.BLACK, 1.0 - light))
	C.natural_rain(self, t, 0.0, -1.0, window, 0.55)
	for bar in range(1, 4):
		draw_rect(Rect2(window.position.x + bar * window.size.x / 4.0 - 1.5, window.position.y, 3, window.size.y), Color("07080f"))
	draw_rect(Rect2(window.position.x - 3, window.position.y - 3, window.size.x + 6, 3), Color("07080f"))
	draw_rect(Rect2(window.position.x - 3, window.position.y + window.size.y, window.size.x + 6, 3), Color("07080f"))
	var flicker := 0.85 + 0.15 * sin(t * 9.0) * sin(t * 5.3)
	draw_circle(Vector2(52, 110), 46.0, Color(1.0, 0.62, 0.25, 0.10 * light * flicker))
	draw_rect(Rect2(50, 104, 4, 12), Color(1.0, 0.7, 0.3, light))
	# Miro's own sprite, facing the MP3 in his hand.
	var sprite := miro_idle
	var tint_miro := Color(1, 1, 1, 1).lerp(Color(0.35, 0.35, 0.4, 1), 1.0 - light)
	draw_set_transform(Vector2(150, 300) * (size / C.FRAME), 0.0, size / C.FRAME * Vector2(4.2, 4.2))
	draw_texture(sprite, Vector2(-sprite.get_width() / 2.0, -sprite.get_height()), tint_miro)
	draw_set_transform(Vector2.ZERO, 0.0, size / C.FRAME)
	draw_circle(Vector2(188, 262), 34.0, Color(0.55, 0.95, 0.8, 0.10 * light))
	draw_rect(Rect2(182, 254, 12, 18), Color(0.6, 0.95, 0.8, 0.55 * light))
	draw_rect(Rect2(0, 0, 317, 360), Color(0, 0, 0, 0.0))

## Right half: his brother's office; once named he is Kael's sprite, before that a silhouette.
func panel_niro(t: float, light: float) -> void:
	var rect := Rect2(323, 0, 317, 360)
	C.gradient(self, rect, Color("10202a").lerp(Color.BLACK, 1.0 - light), Color("1d3039").lerp(Color.BLACK, 1.0 - light))
	draw_rect(Rect2(323, 270, 317, 90), Color("101a20"))
	draw_circle(Vector2(560, 120), 58.0, Color(0.85, 0.95, 0.9, 0.08 * light))   # the desk lamp
	draw_rect(Rect2(556, 118, 8, 4), Color(0.9, 0.98, 0.92, light))
	draw_rect(Rect2(380, 240, 90, 40), Color("0b1318"))   # a cot: a ward bed behind him
	var tint := Color(1, 1, 1, 1) if data.named else Color(0.02, 0.03, 0.04, 1)
	tint = tint.lerp(Color.BLACK, (1.0 - light) * 0.6) if data.named else tint
	draw_set_transform(Vector2(480, 300) * (size / C.FRAME), 0.0, size / C.FRAME * Vector2(-4.2, 4.2))
	draw_texture(kael, Vector2(-kael.get_width() / 2.0, -kael.get_height()), tint)
	draw_set_transform(Vector2.ZERO, 0.0, size / C.FRAME)
	if not data.named:
		draw_string(C.Type.body(), Vector2(420, 120), "UNKNOWN CALLER", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(C.ROSE.r, C.ROSE.g, C.ROSE.b, 0.85))
