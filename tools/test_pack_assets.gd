extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var failures: Array[String] = []
	if not FileAccess.file_exists("res://data/inner_dialogue.json"):
		failures.append("Missing inner dialogue")
	for path in ["res://assets/weapons/remote.svg", "res://scripts/trapdoor.gd", "res://scripts/player_controls.gd", "res://assets/weapons/smg.svg", "res://assets/weapons/flamethrower.svg", "res://assets/weapons/flame.svg", "res://assets/audio/flame.wav"]:
		if not ResourceLoader.exists(path):
			failures.append("Missing combat asset: " + path)
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/music/runtime_catalog.json"))
	for track in catalog.tracks.values():
		var stream = load(track.stream)
		if not stream is AudioStream or stream.get_length() <= 0:
			failures.append("Missing music: " + track.stream)
	var voices: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/voice/provenance.json"))
	for id in voices:
		var stream = load("res://assets/audio/voice/%s.mp3" % id)
		if not stream is AudioStream or stream.get_length() <= 0:
			failures.append("Missing voice: " + id)
	for path in ["res://.env", "res://.env.local", "res://soundselection/beats/YZ33.mp3", "res://tools/generate_guard_voices.py"]:
		if FileAccess.file_exists(path):
			failures.append("Excluded file present: " + path)
	for error in failures:
		push_error(error)
	print("PACK_AUDIO_RESULT: ", catalog.tracks.size(), " music + ", voices.size(), " voices; exclusions checked; failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
