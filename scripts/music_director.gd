extends Node
## Offline soundtrack playback. Two voices crossfade; no API calls at runtime.
## Also the game's beat clock: emits beat/bar from the playing track so patrols,
## waves and boss telegraphs can land on the music (docs/STORY_AND_SYSTEMS_IMPLEMENTATION.md).
signal beat(index: int)
signal bar(index: int)
signal track_changed(id: String)
var catalog: Dictionary = {}
# At most one background request and one prepared, immutable stream.
const PREPARED_STREAM_LIMIT := 48 * 1024 * 1024
var warming_path := ""
var desired_path := ""
var prepared_path := ""
var prepared_stream: AudioStream
func prefetch_track(id: String) -> void:
	desired_path = str(catalog[id].stream) if catalog.has(id) and id != track_id else ""
	if prepared_path != desired_path:
		prepared_path = ""
		prepared_stream = null
	poll_prefetch()
func poll_prefetch() -> void:
	if not warming_path.is_empty():
		var status := ResourceLoader.load_threaded_get_status(warming_path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS: return
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var loaded: AudioStream = ResourceLoader.load_threaded_get(warming_path)
			var bytes: int = loaded.data.size() if loaded is AudioStreamMP3 or loaded is AudioStreamWAV else PREPARED_STREAM_LIMIT + 1
			if warming_path == desired_path and bytes <= PREPARED_STREAM_LIMIT:
				prepared_stream = loaded
				prepared_path = warming_path
		var completed_path := warming_path
		warming_path = ""
		# A failed/oversized track must not be requested every frame.
		if completed_path == desired_path and prepared_path != desired_path: desired_path = ""
	if not desired_path.is_empty() and prepared_path != desired_path:
		if ResourceLoader.load_threaded_request(desired_path) == OK:
			warming_path = desired_path
		else: desired_path = ""

var voices: Array[AudioStreamPlayer] = []
var active := 0
var track_id := ""
var section_id := ""
var fade_progress := 1.0
var duck_db := 0.0
var review_override := false
var shuffle_enabled := false
var shuffle_bag: Array[String] = []
var shuffle_rng := RandomNumberGenerator.new()
var pending_track := ""
var pending_wait := 0.0
var track_time := 0.0
var last_beat := -1
var lowpass: AudioEffectLowPassFilter
var stealth_db := 0.0
# Approved order (Ethan, 7 Nov 2026). Level 5 is near-silent until the guitar pickup.
const FIRST := {1: "yz33", 2: "dope2", 3: "bobblehead", 4: "plane_drums", 5: ""}
const SECOND := {2: "swag", 3: "cyberpunk", 4: "sumcrazy", 5: "hot_shit"}
const GUITAR_TRACK := "shit_crashed"
const OUTRO_TRACK := "set_me_free"
const MENU_TRACK := "drill_shxt"
const MENU_COMPLETED_TRACK := "lil_uzi2"
const BEATS_PER_BAR := 4
const OPEN_CUTOFF := 20500.0
const DEFAULT_BUS_DB := {"Music": -4.0, "Effects": -1.0, "Voice": -2.0}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	shuffle_rng.randomize()
	var has_peak_limiter := false
	for index in range(AudioServer.get_bus_effect_count(0)):
		if AudioServer.get_bus_effect(0,index) is AudioEffectHardLimiter: has_peak_limiter = true
	if not has_peak_limiter:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -2.0
		limiter.pre_gain_db = 0.0
		limiter.release = 0.05
		AudioServer.add_bus_effect(0,limiter)
	for bus in ["Music", "Effects", "Voice"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	for bus in ["Music", "Effects", "Voice"]:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), config.get_value("audio", bus, DEFAULT_BUS_DB[bus]))
	# Miro's thoughts: a far, spacey reverb on its own bus that feeds the Voice bus.
	if AudioServer.get_bus_index("Thought") < 0:
		AudioServer.add_bus()
		var thought_bus := AudioServer.bus_count - 1
		AudioServer.set_bus_name(thought_bus, "Thought")
		AudioServer.set_bus_send(thought_bus, "Voice")
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.75
		reverb.damping = 0.2
		reverb.spread = 1.0
		reverb.predelay_msec = 90
		reverb.wet = 0.2
		reverb.dry = 0.9
		AudioServer.add_bus_effect(thought_bus, reverb)
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/music/runtime_catalog.json")).tracks
	lowpass = AudioEffectLowPassFilter.new()
	lowpass.cutoff_hz = OPEN_CUTOFF
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Music"), lowpass)
	for index in range(2):
		var voice := AudioStreamPlayer.new()
		voice.bus = "Music"
		voice.volume_db = -80
		voice.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(voice)
		voices.append(voice)
		voice.finished.connect(shuffle_finished.bind(index))

func set_volume(bus: String, db: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), db)
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value("audio", bus, db)
	config.save("user://settings.cfg")

## The floor's own beat right now (entry, second half or guitar), so the MP3 can hand back to it.
var floor_track := ""

func resume_floor() -> void:
	cancel_shuffle()
	review_override = false
	if floor_track.is_empty():
		silence()
	else:
		play_track(floor_track)

func start_floor(number: int) -> void:
	cancel_shuffle()
	review_override = false
	pending_track = ""
	# Re-entering the same floor from its second section (a retry) resumes that second track;
	# a new floor never inherits the last floor's second track.
	var was_second := section_id == "floor_%d_second" % number
	var was_guitar := number == 5 and section_id == "floor_5_guitar"
	section_id = "floor_%d_entry" % number

	floor_track = FIRST[number]
	if was_guitar:
		section_id = "floor_5_guitar"
		floor_track = GUITAR_TRACK
	if was_second and SECOND.has(number):
		floor_track = SECOND[number]
		section_id = "floor_%d_second" % number

	if floor_track.is_empty():
		silence()
	else:
		track_id = "" # A retry restarts the floor cue rather than retaining its old playhead.
		play_track(floor_track)
	prefetch_track(GUITAR_TRACK if number == 5 and not was_second else str(SECOND.get(number,"")))

func second_section(number: int) -> void:
	if section_id == "floor_%d_second" % number or not SECOND.has(number):
		return
	section_id = "floor_%d_second" % number
	floor_track = SECOND[number]
	if shuffle_enabled:
		cancel_shuffle()
		review_override = false
	# A beat Miro picked on the MP3 keeps playing; the floor's beat comes back on "next".
	if not review_override:
		queue_track(SECOND[number])

## Level 5: picking up the guitar starts Shit Crashed at once (the pickup is the downbeat).
func guitar_section() -> void:
	if section_id == "floor_5_guitar":
		return
	if shuffle_enabled:
		cancel_shuffle()
		review_override = false
	section_id = "floor_5_guitar"
	floor_track = GUITAR_TRACK
	if review_override:
		return
	pending_track = ""
	play_track(GUITAR_TRACK)

func play_outro() -> void:
	cancel_shuffle()
	review_override = false
	pending_track = ""
	section_id = "outro"
	play_track(OUTRO_TRACK, false)

## Switch on the next bar line of the current track (at most one bar of wait).
func queue_track(id: String) -> void:
	if id == track_id or not catalog.has(id):
		return
	if track_id.is_empty() or bpm() <= 0:
		play_track(id)
		return
	prefetch_track(id)
	pending_track = id
	pending_wait = seconds_to_next_bar()

func play_track(id: String, loop := true, shuffle_play := false) -> void:
	if not shuffle_play:cancel_shuffle()
	if id == track_id and not shuffle_play:
		return
	if not catalog.has(id):
		return
	pending_track = ""
	track_id = id
	active = 1 - active
	voices[active].stop()
	poll_prefetch()
	var path: String = catalog[id].stream
	var base: AudioStream = prepared_stream if prepared_path == path and prepared_stream != null else load(path)
	var stream = base.duplicate()
	if prepared_path == path:
		prepared_stream = null
		prepared_path = ""
		desired_path = ""
	if stream is AudioStreamWAV:
		# A WAV track (Sum Crazy) loops through its sample range instead of a loop flag.
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	else:
		stream.loop = loop
	voices[active].stream = stream
	voices[active].volume_db = -80
	if DisplayServer.get_name() != "headless":
		voices[active].play()
	fade_progress = 0
	track_time = 0.0
	last_beat = -1
	track_changed.emit(id)

func silence() -> void:
	cancel_shuffle()
	track_id = ""
	pending_track = ""
	fade_progress = 0

func bpm() -> float:
	return float(catalog.get(track_id, {}).get("bpm", 0.0))

func seconds_per_beat() -> float:
	return 60.0 / bpm() if bpm() > 0 else 0.5

func seconds_per_bar() -> float:
	return seconds_per_beat() * BEATS_PER_BAR

## Position in beats. Uses the audio clock when the track is audible, else a pause-aware game clock.
func beat_position() -> float:
	if track_id.is_empty() or bpm() <= 0:
		return -1.0
	var seconds := track_time
	var voice: AudioStreamPlayer = voices[active] if not voices.is_empty() else null
	if voice and voice.playing:
		seconds = voice.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	return maxf(0.0, seconds) / seconds_per_beat()

func seconds_to_next_bar() -> float:
	var position := beat_position()
	if position < 0:
		return 0.0
	var into_bar := fmod(position, BEATS_PER_BAR)
	return (BEATS_PER_BAR - into_bar) * seconds_per_beat() if into_bar > 0.001 else 0.0

func is_on_beat(window := 0.12) -> bool:
	var position := beat_position()
	if position < 0:
		return false
	var offset := fmod(position, 1.0)
	return minf(offset, 1.0 - offset) * seconds_per_beat() <= window

func _process(delta: float) -> void:
	if not warming_path.is_empty(): poll_prefetch()
	if voices.is_empty() or get_tree().paused:
		return
	if not track_id.is_empty():
		track_time += delta
		var whole := int(floor(beat_position()))
		if whole != last_beat and whole >= 0:
			last_beat = whole
			beat.emit(whole)
			if whole % BEATS_PER_BAR == 0:
				bar.emit(whole / BEATS_PER_BAR)
	if not pending_track.is_empty():
		pending_wait -= delta
		if pending_wait <= 0:
			play_track(pending_track)
	var scene = get_tree().current_scene
	var spoken := false
	var hidden := false
	var uneasy := false
	if is_instance_valid(scene) and scene.has_method("controls_locked"):
		spoken = not scene.dialogue.is_empty()
		if scene.get("world_features") != null:
			spoken = spoken or scene.world_features.voice_audible()
		var player = scene.get("player")
		if is_instance_valid(player):
			hidden = player.is_concealed or player.in_hiding_spot
			uneasy = str(player.detection_state).begins_with("SEARCHING")
	duck_db = move_toward(duck_db, -8.0 if spoken else 0.0, delta * (24 if spoken else 6))
	# Under the blanket the music is under it too: low-pass and -3 dB. Suspicion opens it a little.
	var cutoff := 800.0 if hidden else (2600.0 if uneasy else OPEN_CUTOFF)
	lowpass.cutoff_hz = lerpf(lowpass.cutoff_hz, cutoff, minf(1.0, delta * 6.0))
	stealth_db = move_toward(stealth_db, -3.0 if hidden else 0.0, delta * 9)
	fade_progress = minf(1, fade_progress + delta / 1.5)
	for index in range(2):
		var gain := fade_progress if index == active and not track_id.is_empty() else 1 - fade_progress
		voices[index].volume_db = linear_to_db(maxf(0.0001, gain)) + duck_db + stealth_db
		if gain <= 0 and voices[index].playing:
			voices[index].stop()

func _exit_tree() -> void:
	for voice in voices:
		voice.stop()
		voice.stream = null
	# A request owns a native loader token until get() consumes it. Drain at shutdown
	# only; doing this during gameplay would defeat asynchronous preparation.
	if not warming_path.is_empty():
		var status := ResourceLoader.load_threaded_get_status(warming_path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS or status == ResourceLoader.THREAD_LOAD_LOADED:
			ResourceLoader.load_threaded_get(warming_path)
		warming_path = ""
	prepared_stream = null
	prepared_path = ""
	desired_path = ""
	voices.clear()

func apply_balanced_mix() -> void:
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	for bus in DEFAULT_BUS_DB:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), DEFAULT_BUS_DB[bus])
		config.set_value("audio", bus, DEFAULT_BUS_DB[bus])
	config.save("user://settings.cfg")

func cancel_shuffle() -> void:
	shuffle_enabled = false
	shuffle_bag.clear()

func toggle_shuffle() -> String:
	if shuffle_enabled:
		resume_floor()
		return "MP3 · shuffle off. Back to the floor's beat."
	var unlocked: Array = get_node("/root/Campaign").unlocked_tracks().filter(func(id): return catalog.has(id))
	if unlocked.is_empty():return "No unlocked beats to shuffle yet."
	shuffle_enabled = true
	review_override = true
	shuffle_bag.clear()
	play_shuffle_track()
	return "MP3 · shuffle on [H]. Checkpoint music takes priority."

func play_shuffle_track() -> void:
	if not shuffle_enabled:return
	var unlocked: Array = get_node("/root/Campaign").unlocked_tracks().filter(func(id): return catalog.has(id))
	if unlocked.is_empty():resume_floor();return
	shuffle_bag = shuffle_bag.filter(func(id):return unlocked.has(id))
	if shuffle_bag.is_empty():
		for id in unlocked:
			if unlocked.size()==1 or str(id)!=track_id:shuffle_bag.append(str(id))
	var index := shuffle_rng.randi_range(0, shuffle_bag.size()-1)
	var next: String = shuffle_bag[index]
	shuffle_bag.remove_at(index)
	play_track(next, false, true)

func shuffle_finished(index: int) -> void:
	if shuffle_enabled and index == active:play_shuffle_track()

func checkpoint_music() -> void:
	if shuffle_enabled:resume_floor()
