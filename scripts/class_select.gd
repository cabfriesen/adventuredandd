extends Control

var _picked := ""
var _cards := {}
var _statuses := {}
var _start_button: Button

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color(0.12, 0.14, 0.16)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(column)

	var title := Label.new()
	title.text = "Choose a class"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	column.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	row.add_child(_make_card("warrior", "Warrior", WarriorSprite.texture()))
	row.add_child(_make_card("archer", "Archer", ArcherSprite.texture()))

	_start_button = Button.new()
	_start_button.text = "Start"
	_start_button.custom_minimum_size = Vector2(260, 56)
	_start_button.add_theme_font_size_override("font_size", 24)
	_start_button.disabled = true
	_start_button.pressed.connect(_on_start_pressed)
	column.add_child(_start_button)

func _card_style(selected: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.16, 0.34, 0.2) if selected else Color(0.2, 0.22, 0.26)
	box.border_color = Color(0.5, 0.95, 0.45) if selected else Color(0.55, 0.58, 0.64)
	box.set_border_width_all(6 if selected else 2)
	box.set_corner_radius_all(14)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	return box

func _make_card(class_id: String, title: String, texture: Texture2D) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(240, 0)
	card.add_theme_stylebox_override("panel", _card_style(false))
	card.gui_input.connect(_on_card_input.bind(class_id))
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner)
	var picture_box := Control.new()
	picture_box.custom_minimum_size = Vector2(200, 130)
	picture_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(picture_box)
	var picture := TextureRect.new()
	picture.texture = texture
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	picture_box.add_child(picture)
	var name_label := Label.new()
	name_label.text = title
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(name_label)
	var status := Label.new()
	status.text = "Click to choose"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 18)
	status.add_theme_color_override("font_color", Color(0.75, 0.78, 0.8))
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(status)
	_cards[class_id] = card
	_statuses[class_id] = status
	return card

func _on_card_input(event: InputEvent, class_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_class(class_id)

func _select_class(class_id: String) -> void:
	_picked = class_id
	Game.chosen_class = class_id
	for id in _cards.keys():
		var card: PanelContainer = _cards[id]
		var status: Label = _statuses[id]
		var selected: bool = id == class_id
		card.add_theme_stylebox_override("panel", _card_style(selected))
		status.text = "Selected" if selected else "Click to choose"
		status.add_theme_color_override("font_color", Color(0.55, 0.95, 0.5) if selected else Color(0.75, 0.78, 0.8))
	_start_button.disabled = false

func _on_start_pressed() -> void:
	if _picked == "":
		return
	Game.begin_run()
	if Game.join_before_class:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/multiplayer.tscn")
