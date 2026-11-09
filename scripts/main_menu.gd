extends Control
## Review menu: no spoilers/implementation detail required to start a normal run.
var music: Node

func _ready() -> void:
	theme = preload("res://scripts/visual_assets.gd").ui_theme()
	music = get_node("/root/MusicDirector")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--level="):
			var number := clampi(argument.trim_prefix("--level=").to_int(), 1, 5)
			get_node("/root/Campaign").launch_consumed = true
			# Go directly to the requested scene; avoid nested scene changes from intro._ready().
			get_tree().call_deferred("change_scene_to_file", "res://scenes/intro.tscn" if number == 1 else "res://scenes/levels/level_%02d.tscn" % number)
			return
	if "--verify-playthrough" in OS.get_cmdline_user_args():
		get_tree().call_deferred("change_scene_to_file", "res://scenes/intro.tscn")
		return
	music.review_override = false
	music.play_track("yz33")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color("272744")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var box := VBoxContainer.new()
	box.position = Vector2(95, 12)
	box.size = Vector2(450, 330)
	box.add_theme_constant_override("separation", 5)
	add_child(box)
	var title := Label.new()
	title.text = "MIRO — LAST ONE STANDING"
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	add_button(box, "Start new run", func(): launch_level(1))
	var levels := HBoxContainer.new()
	box.add_child(levels)
	for number in range(1, 6):
		add_button(levels, "Level %d" % number, launch_level.bind(number))
	var caption := Label.new()
	caption.text = "Review levels directly • F10 returns here • M mutes all audio"
	caption.add_theme_font_size_override("font_size", 11)
	box.add_child(caption)
	for bus in ["Music", "Effects", "Voice"]:
		var row := HBoxContainer.new()
		box.add_child(row)
		var label := Label.new()
		label.text = bus
		label.custom_minimum_size.x = 70
		row.add_child(label)
		var slider := HSlider.new()
		slider.min_value = -40
		slider.max_value = 0
		slider.step = 1
		slider.value = AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)
		slider.value_changed.connect(func(value): music.set_volume(bus, value))
	# Achievements Section
	var achievements_container := VBoxContainer.new()
	box.add_child(achievements_container)
	
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 10)
	achievements_container.add_child(tab_row)
	
	var beats_view := VBoxContainer.new()
	var art_view := VBoxContainer.new()
	art_view.visible = false
	achievements_container.add_child(beats_view)
	achievements_container.add_child(art_view)
	
	var beats_tab := Button.new()
	beats_tab.text = "Beats"
	beats_tab.pressed.connect(func(): 
		beats_view.visible = true
		art_view.visible = false
	)
	tab_row.add_child(beats_tab)
	
	var art_tab := Button.new()
	art_tab.text = "Artwork"
	art_tab.pressed.connect(func(): 
		beats_view.visible = false
		art_view.visible = true
	)
	tab_row.add_child(art_tab)
	
	# Beats View (Filtered list)
	var tracks := OptionButton.new()
	tracks.add_item("Choose a beat")
	var ids: Array = music.catalog.keys()
	var filtered_ids: Array = []
	for id in ids:
		if id in ["yz33", "bobblehead", "swag", "plane_drums", "shit_crashed", "dope2", "sumcrazy", "cyberpunk", "robot_attack"] or id in music.unlocked_beats:
			filtered_ids.append(id)
			tracks.add_item(music.catalog[id].title)
	tracks.item_selected.connect(func(index):
		if index > 0:
			music.review_override = true
			music.play_track(filtered_ids[index - 1]))
	beats_view.add_child(tracks)
	
	# Artwork View (Gallery)
	# Assuming artworks are defined in artspec/matrix; here we list them as a review
	var art_list := VBoxContainer.new()
	art_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art_view.add_child(art_list)
	
	# In a full implementation, this would iterate over art_branch_matrix.json
	# For now, we simulate the "viewed" status using Campaign.viewed_art
	var campaign = get_node("/root/Campaign")
	# Placeholder for artwork IDs from the spec (e.g., A01 to A27)
	for i in range(1, 28):
		var art_id = "A%02d" % i
		var art_label := Label.new()
		art_label.text = "Artwork %s" % art_id
		if art_id in campaign.viewed_art:
			art_label.modulate = Color.WHITE
		else:
			art_label.modulate = Color(0.4, 0.4, 0.4) # Greyed out
		art_list.add_child(art_label)
	
	var note := Label.new()
	note.text = "Music lowers during speech. Overheard lines have subtitles.\nLevel 3: listen for the terminal password, or inspect its slip."
	note.add_theme_font_size_override("font_size", 11)
	box.add_child(note)
	add_button(box, "Quit", func(): get_tree().quit())

func add_button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(action)
	parent.add_child(button)

func launch_level(number: int) -> void:
	var campaign = get_node("/root/Campaign")
	campaign.case_anchors.clear()
	campaign.completed_sigils.clear()
	campaign.narrative_milestones.clear()
	campaign.launch_consumed = true
	get_tree().change_scene_to_file("res://scenes/intro.tscn" if number == 1 else "res://scenes/levels/level_%02d.tscn" % number)
