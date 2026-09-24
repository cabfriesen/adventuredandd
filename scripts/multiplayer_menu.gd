extends Control

var _style := ""
var _connect_choice := ""
var _pick_box: VBoxContainer
var _connect_box: VBoxContainer
var _style_buttons: Array[Button] = []
var _address: LineEdit
var _port: LineEdit
var _host_line: Label
var _continue_button: Button
var _status: Label
var _waiting := false

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color(0.12, 0.14, 0.16)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	var title := Label.new()
	title.text = "Multiplayer"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	column.add_child(title)

	_pick_box = VBoxContainer.new()
	_pick_box.add_theme_constant_override("separation", 12)
	column.add_child(_pick_box)
	_add_style_button("No multiplayer", "none")
	_add_style_button("Friends multiplayer", "friends")
	_add_style_button("Multiplayer", "multiplayer")
	var pick_note := Label.new()
	pick_note.name = "PickNote"
	pick_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pick_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pick_note.custom_minimum_size = Vector2(460, 40)
	_pick_box.add_child(pick_note)
	var pick_continue := _make_button("Continue")
	pick_continue.name = "StyleContinue"
	pick_continue.disabled = true
	pick_continue.pressed.connect(_on_style_continue)
	_pick_box.add_child(pick_continue)

	_connect_box = VBoxContainer.new()
	_connect_box.add_theme_constant_override("separation", 12)
	_connect_box.visible = false
	column.add_child(_connect_box)
	var host := _make_button("Host a game")
	host.pressed.connect(_choose_host)
	_connect_box.add_child(host)
	var join := _make_button("Join a game")
	join.pressed.connect(_choose_join)
	_connect_box.add_child(join)
	_port = LineEdit.new()
	_port.placeholder_text = "Port, such as 11111"
	_port.text = "11111"
	_port.custom_minimum_size = Vector2(460, 48)
	_port.add_theme_font_size_override("font_size", 22)
	_port.visible = false
	_port.text_changed.connect(func(_text): _update_host_line())
	_connect_box.add_child(_port)
	_host_line = Label.new()
	_host_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_host_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_host_line.custom_minimum_size = Vector2(460, 48)
	_host_line.visible = false
	_connect_box.add_child(_host_line)
	_address = LineEdit.new()
	_address.placeholder_text = "192.168.1.105:11111"
	_address.custom_minimum_size = Vector2(460, 48)
	_address.add_theme_font_size_override("font_size", 22)
	_address.visible = false
	_address.text_changed.connect(func(_text): _refresh_connect())
	_connect_box.add_child(_address)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(460, 56)
	_connect_box.add_child(_status)
	_continue_button = _make_button("Continue")
	_continue_button.disabled = true
	_continue_button.pressed.connect(_on_connect_continue)
	_connect_box.add_child(_continue_button)
	var back := _make_button("Back")
	back.pressed.connect(_on_back_to_styles)
	_connect_box.add_child(back)

	var leave := _make_button("Back to class")
	leave.pressed.connect(_on_back_to_class)
	column.add_child(leave)
	Game.join_finished.connect(_on_join_finished)

func _add_style_button(label_text: String, style_name: String) -> void:
	var button := _make_button(label_text)
	button.pressed.connect(_choose_style.bind(style_name, button))
	_style_buttons.append(button)
	_pick_box.add_child(button)

func _make_button(label_text: String) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(460, 52)
	button.add_theme_font_size_override("font_size", 22)
	return button

func _choose_style(style_name: String, button: Button) -> void:
	_style = style_name
	for other in _style_buttons:
		other.modulate = Color(0.65, 0.95, 0.65) if other == button else Color.WHITE
	(_pick_box.get_node("StyleContinue") as Button).disabled = false
	var pick_note := _pick_box.get_node("PickNote") as Label
	if style_name == "friends":
		pick_note.text = "Friends multiplayer uses the same game as multiplayer for now."
	elif style_name == "multiplayer":
		pick_note.text = "One person hosts. The other joins with an address like 192.168.1.105:11111"
	else:
		pick_note.text = "Play on this computer only."

func _on_style_continue() -> void:
	if _style == "":
		return
	if _style == "none":
		Game.play_solo()
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	Game.session = _style
	_pick_box.visible = false
	_connect_box.visible = true
	_connect_choice = ""
	_address.visible = false
	_address.text = ""
	_port.visible = false
	_host_line.visible = false
	_status.text = "Host the game, or join with the host's address and port."
	_refresh_connect()

func _choose_host() -> void:
	_connect_choice = "host"
	_address.visible = false
	_port.visible = true
	_host_line.visible = true
	_update_host_line()
	_status.text = "Give your friend the address above."
	_refresh_connect()

func _choose_join() -> void:
	_connect_choice = "join"
	_port.visible = false
	_host_line.visible = false
	_address.visible = true
	_address.placeholder_text = "192.168.1.105:11111"
	_address.grab_focus()
	_status.text = "Type the host address and port, like 192.168.1.105:11111"
	_refresh_connect()

func _update_host_line() -> void:
	var port := _port.text.strip_edges().to_int()
	if port <= 0:
		_host_line.text = "Type a port, such as 11111"
		return
	_host_line.text = "Join address: %s:%d" % [Game.lan_ip(), port]

func _refresh_connect() -> void:
	if _waiting:
		_continue_button.disabled = true
		return
	if _connect_choice == "host":
		var port := _port.text.strip_edges().to_int()
		_continue_button.disabled = port <= 0 or port > 65535
	elif _connect_choice == "join":
		var parsed := Game.parse_join_address(_address.text)
		_continue_button.disabled = str(parsed["host"]) == ""
	else:
		_continue_button.disabled = true

func _on_connect_continue() -> void:
	if _connect_choice == "host":
		var err := Game.host_game(_port.text.strip_edges().to_int())
		_status.text = Game.status
		if err == OK:
			get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	if _connect_choice != "join":
		return
	_waiting = true
	_refresh_connect()
	_status.text = "Connecting..."
	Game.join_game(_address.text)

func _on_join_finished(ok: bool) -> void:
	_waiting = false
	_status.text = Game.status
	_refresh_connect()
	if ok and is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_back_to_styles() -> void:
	_waiting = false
	_connect_box.visible = false
	_pick_box.visible = true
	_connect_choice = ""

func _on_back_to_class() -> void:
	Game.play_solo()
	get_tree().change_scene_to_file("res://scenes/class_select.tscn")
