extends Node
## Offline soundtrack playback. Two voices crossfade; no API calls at runtime.
var catalog: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var active := 0
var track_id := ""
var section_id := ""
var fade_progress := 1.0
var duck_db := 0.0
var review_override := false
var unlocked_beats: Array[String] = []
const FIRST := {1: "yz33", 2: "bobblehead", 3: "swag", 4: "plane_drums", 5: "shit_crashed"}
const SECOND := {2: "dope2", 3: "sumcrazy", 4: "cyberpunk", 5: "robot_attack"}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "Effects", "Voice"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	for bus in ["Music", "Effects", "Voice"]:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), config.get_value("audio", bus, -6.0 if bus == "Music" else 0.0))
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/music/runtime_catalog.json")).tracks
	for index in range(2):
		var voice := AudioStreamPlayer.new()
		voice.bus = "Music"
		voice.volume_db = -80
		voice.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(voice)
		voices.append(voice)

func set_volume(bus: String, db: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), db)
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value("audio", bus, db)
	config.save("user://settings.cfg")

func start_floor(number: int) -> void:
	review_override = false
	section_id = "floor_%d_entry" % number
	play_track(FIRST[number])

func second_section(number: int) -> void:
	if review_override or section_id == "floor_%d_second" % number or not SECOND.has(number):
		return
	section_id = "floor_%d_second" % number
	play_track(SECOND[number])

func play_track(id: String) -> void:
	if id == track_id:
		return
	if not catalog.has(id):
		return
	track_id = id
	active = 1 - active
	voices[active].stop()
	var stream = load(catalog[id].stream).duplicate()
	stream.loop = true
	voices[active].stream = stream
	voices[active].volume_db = -80
	if DisplayServer.get_name() != "headless":
		voices[active].play()
	fade_progress = 0

func silence() -> void:
	track_id = ""
	fade_progress = 0

func unlock_achievement_beat(beat_id: String) -> void:
	if beat_id == "": return
	if not unlocked_beats.has(beat_id):
		unlocked_beats.append(beat_id)
		print("BEAT_UNLOCKED: ", beat_id)
		# In a real implementation, this would add the track to the MP3 player's accessible list.

func _process(delta: float) -> void:
	if voices.is_empty() or get_tree().paused:
		return
	var scene = get_tree().current_scene
	var spoken := false
	if is_instance_valid(scene) and scene.has_method("controls_locked"):
		spoken = not scene.dialogue.is_empty()
		if scene.get("world_features") != null:
			spoken = spoken or scene.world_features.voice_audible()
	duck_db = move_toward(duck_db, -8.0 if spoken else 0.0, delta * (24 if spoken else 6))
	fade_progress = minf(1, fade_progress + delta / 1.5)
	for index in range(2):
		var gain := fade_progress if index == active and not track_id.is_empty() else 1 - fade_progress
		voices[index].volume_db = linear_to_db(maxf(0.0001, gain)) + duck_db
		if gain <= 0 and voices[index].playing:
			voices[index].stop()

func _exit_tree() -> void:
	for voice in voices:
		voice.stop()
		voice.stream = null
	voices.clear()
