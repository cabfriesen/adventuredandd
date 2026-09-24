extends Control

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color(0.12, 0.14, 0.16)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.offset_left = -160
	column.offset_top = -160
	column.offset_right = 160
	column.offset_bottom = 160
	add_child(column)

	var title := Label.new()
	title.text = "Adventure D&D"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	column.add_child(title)

	var play := _make_button("Play")
	play.pressed.connect(_on_play_pressed)
	column.add_child(play)
	column.add_child(_make_button("Settings"))
	var multiplayer := _make_button("Multiplayer")
	multiplayer.pressed.connect(_on_multiplayer_pressed)
	column.add_child(multiplayer)

func _make_button(label_text: String) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(280, 56)
	button.add_theme_font_size_override("font_size", 24)
	return button

func _on_play_pressed() -> void:
	Game.play_solo()
	get_tree().change_scene_to_file("res://scenes/class_select.tscn")

func _on_multiplayer_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/class_select.tscn")
