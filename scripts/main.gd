extends Node2D

const HEX_SIZE := 46.0
const MOVE_RANGE := 8
const HOP_TIME := 0.32
const HOP_HEIGHT := 18.0
const ZOOM_MIN := 0.4
const ZOOM_MAX := 2.5
const ZOOM_STEP := 1.15
const GOBLIN_ID := -1

var _built_layer := ""
var _cells: Array[Vector2i] = []
var _walkable := {}
var _grass := {}
var _forest := {}
var _attack_mode := false
var _bars: Node2D
var _roads := {}
var _room := {}
var _blocked_terrain := {}
var _enter_cost := {}
var _houses: Array = []
var _villagers: Array = []
var _heroes := {}
var _hero_sprites := {}
var _enemies := {}
var _enemy_sprites := {}
var _turn_order: Array[int] = []
var _turn_index := 0
var _preview: Array[Vector2i] = []
var _preview_in_range := true
var _moving := false
var _pending_state := {}
var _goblin_dead := false
var _outgoing_talk = null
var _talk_id := ""
var _talk_step := ""
var _camera: Camera2D
var _hud_layer: CanvasLayer
var _hp_fill: ColorRect
var _hp_label: Label
var _level_label: Label
var _coin_label: Label
var _turn_label: Label
var _end_button: Button
var _potion_button: Button
var _talk_root: PanelContainer
var _talk_label: Label
var _talk_buttons: HBoxContainer
var _ask_at := 0

func _ready() -> void:
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	_bars = Node2D.new()
	_bars.z_index = 6
	_bars.draw.connect(_draw_enemy_bars)
	add_child(_bars)
	_build_hud()
	_load_layer(Game.layer, true)
	Game.register_map(self)
	if _online() and multiplayer.is_server():
		_ensure_player(multiplayer.get_unique_id(), Game.chosen_class)
		for peer_id in multiplayer.get_peers():
			_ensure_player(peer_id, "warrior")
		_publish()
	elif _online():
		Game.rpc_request_state_as.rpc_id(1, Game.chosen_class)
	else:
		_ensure_player(1, Game.chosen_class)
		_refresh_hud()
		_snap_camera()

func _exit_tree() -> void:
	Game.unregister_map(self)

func _process(_delta: float) -> void:
	if _online() and not multiplayer.is_server() and _heroes.is_empty() and Time.get_ticks_msec() > _ask_at:
		_ask_at = Time.get_ticks_msec() + 500
		Game.rpc_request_state_as.rpc_id(1, Game.chosen_class)
	_follow_camera(_delta)
	if _bars != null:
		_bars.queue_redraw()

func _load_layer(_layer_name: String, fresh_enemies: bool) -> void:
	Game.layer = "surface"
	_built_layer = "surface"
	var data: Dictionary = WorldMap.surface()
	_cells = data["cells"]
	_grass = data.get("grass", {})
	_forest = data["forest"]
	_roads = data["roads"]
	_room = data.get("room", {})
	_blocked_terrain = data["blocked"]
	_houses = data["houses"]
	_villagers = data["villagers"]
	_walkable.clear()
	_enter_cost.clear()
	for cell in _cells:
		if _blocked_terrain.has(cell):
			continue
		_walkable[cell] = true
		_enter_cost[cell] = 2 if _forest.has(cell) else 1
	_clear_enemies()
	if fresh_enemies:
		_spawn_layer_enemies(data)
	_place_heroes_on_spawns(data["spawns"])
	_rebuild_turn_order()
	queue_redraw()

func _spawn_layer_enemies(data: Dictionary) -> void:
	if not _goblin_dead:
		_add_enemy(GOBLIN_ID, "goblin", data["goblin"], 30, 9, 3)

func _place_heroes_on_spawns(spawns: Array) -> void:
	var ids: Array[int] = []
	for hero_id in _heroes.keys():
		ids.append(int(hero_id))
	ids.sort()
	var used := {}
	for index in ids.size():
		var cell: Vector2i = spawns[mini(index, spawns.size() - 1)]
		if used.has(cell):
			cell = _first_open_spawn(spawns, used)
		used[cell] = true
		_heroes[ids[index]]["q"] = cell.x
		_heroes[ids[index]]["r"] = cell.y
		if _hero_sprites.has(ids[index]):
			_hero_sprites[ids[index]].position = _center(cell)

func _first_open_spawn(spawns: Array, used: Dictionary) -> Vector2i:
	for cell in spawns:
		if not used.has(cell) and _walkable.has(cell):
			return cell
	return spawns[0]

func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	add_child(_hud_layer)
	var back := ColorRect.new()
	back.color = Color(0.15, 0.05, 0.05)
	back.position = Vector2(24, 16)
	back.size = Vector2(220, 22)
	_hud_layer.add_child(back)
	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(0.82, 0.16, 0.14)
	_hp_fill.position = Vector2(26, 18)
	_hp_fill.size = Vector2(216, 18)
	_hud_layer.add_child(_hp_fill)
	_hp_label = _make_label(Vector2(24, 42), 22)
	_level_label = _make_label(Vector2(24, 70), 18)
	_coin_label = _make_label(Vector2(24, 96), 16)
	_turn_label = _make_label(Vector2(270, 16), 24)
	_end_button = _make_button("End turn", Vector2(270, 52), _on_end_turn_pressed)
	_potion_button = _make_button("Drink potion", Vector2(270, 104), _on_potion_pressed)
	_talk_root = PanelContainer.new()
	_talk_root.position = Vector2(300, 12)
	_talk_root.custom_minimum_size = Vector2(720, 120)
	_talk_root.visible = false
	_hud_layer.add_child(_talk_root)
	var talk_box := VBoxContainer.new()
	talk_box.add_theme_constant_override("separation", 8)
	_talk_root.add_child(talk_box)
	_talk_label = Label.new()
	_talk_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_talk_label.custom_minimum_size = Vector2(680, 48)
	_talk_label.add_theme_font_size_override("font_size", 20)
	talk_box.add_child(_talk_label)
	_talk_buttons = HBoxContainer.new()
	_talk_buttons.add_theme_constant_override("separation", 8)
	talk_box.add_child(_talk_buttons)

func _make_label(at: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	_hud_layer.add_child(label)
	return label

func _make_button(text: String, at: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.custom_minimum_size = Vector2(170, 42)
	button.add_theme_font_size_override("font_size", 18)
	button.visible = false
	button.pressed.connect(callback)
	_hud_layer.add_child(button)
	return button

func _online() -> bool:
	return multiplayer.multiplayer_peer != null

func _authority() -> bool:
	return not _online() or multiplayer.is_server()

func _my_id() -> int:
	if not _online():
		return 1
	return multiplayer.get_unique_id()

func _my_turn() -> bool:
	if _heroes.is_empty() or not _heroes.has(_my_id()):
		return false
	if int(_heroes[_my_id()]["hp"]) <= 0:
		return false
	if not _online() and not _action_ends_turn():
		return true
	if _turn_order.is_empty():
		return not _online()
	return _turn_order[_turn_index] == _my_id()

func _action_ends_turn() -> bool:
	if _online():
		return true
	return _goblin_aggro()

func _follow_camera(delta: float) -> void:
	if not _hero_sprites.has(_my_id()):
		return
	var goal := _center(_cell_of(_my_id()))
	_camera.position = _camera.position.lerp(goal, minf(1.0, delta * 4.0))

func _snap_camera() -> void:
	if _hero_sprites.has(_my_id()):
		_camera.position = _hero_sprites[_my_id()].position

func _center(cell: Vector2i) -> Vector2:
	return Vector2(
		HEX_SIZE * (sqrt(3.0) * cell.x + sqrt(3.0) / 2.0 * cell.y),
		HEX_SIZE * (1.5 * cell.y)
	)

func _corners(cell: Vector2i) -> PackedVector2Array:
	var middle := _center(cell)
	var points := PackedVector2Array()
	for i in 6:
		var angle := deg_to_rad(60.0 * i - 30.0)
		points.append(middle + Vector2(cos(angle), sin(angle)) * (HEX_SIZE - 2.0))
	return points

func _draw() -> void:
	var tinted := {}
	for cell in _preview:
		tinted[cell] = true
	for cell in _cells:
		var points := _corners(cell)
		draw_colored_polygon(points, _ground_color(cell))
		if tinted.has(cell):
			var wash := Color(0.45, 0.95, 0.4, 0.38) if _preview_in_range else Color(0.95, 0.28, 0.22, 0.38)
			draw_colored_polygon(points, wash)
		if _forest.has(cell):
			_draw_tree(_center(cell))
		points.append(points[0])
		draw_polyline(points, Color(0.18, 0.2, 0.16), 3.0, true)
	for house in _houses:
		_draw_house(house)
	for villager in _villagers:
		_draw_villager(villager)

func _ground_color(cell: Vector2i) -> Color:
	if _blocked_terrain.has(cell):
		return Color(0.5, 0.38, 0.28)
	if _room.has(cell):
		return Color(0.3, 0.28, 0.36)
	if _grass.has(cell):
		return Color(0.46, 0.74, 0.34)
	if _forest.has(cell):
		return Color(0.16, 0.36, 0.16)
	if _roads.has(cell):
		return Color(0.72, 0.62, 0.42)
	return Color(0.58, 0.72, 0.36)

func _draw_tree(middle: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([
		middle + Vector2(0, -22), middle + Vector2(-12, -2), middle + Vector2(12, -2),
	]), Color(0.1, 0.32, 0.14))
	draw_rect(Rect2(middle + Vector2(-2, -2), Vector2(4, 12)), Color(0.38, 0.24, 0.12))

func _draw_house(house: Dictionary) -> void:
	var cells: Array = house["cells"]
	var middle := Vector2.ZERO
	for cell in cells:
		middle += _center(cell)
	middle /= cells.size()
	var roof: Color = house["color"]
	draw_colored_polygon(PackedVector2Array([
		middle + Vector2(0, -34), middle + Vector2(-28, -6), middle + Vector2(28, -6),
	]), roof)
	draw_rect(Rect2(middle + Vector2(-18, -6), Vector2(36, 26)), Color(0.93, 0.9, 0.82))
	draw_rect(Rect2(middle + Vector2(-5, 4), Vector2(10, 16)), Color(0.35, 0.22, 0.12))

func _draw_villager(villager: Dictionary) -> void:
	var middle := _center(villager["cell"])
	draw_circle(middle + Vector2(0, -14), 6, Color(0.96, 0.82, 0.7))
	draw_rect(Rect2(middle + Vector2(-6, -8), Vector2(12, 14)), villager["shirt"])

func _unhandled_input(event: InputEvent) -> void:
	if _zoom_input(event):
		return
	if _talk_root.visible:
		return
	if event is InputEventMouseMotion:
		_set_preview(_cell_at(get_global_mouse_position()))
	elif event is InputEventMouseButton and event.pressed:
		var cell := _cell_at(get_global_mouse_position())
		if cell == Vector2i(9999, 9999):
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_attack_mode = not _attack_mode
			_set_preview(_cell_at(get_global_mouse_position()))
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_try_click(cell)

func _zoom_input(event: InputEvent) -> bool:
	var factor := 0.0
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			factor = ZOOM_STEP
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			factor = 1.0 / ZOOM_STEP
	elif event is InputEventMagnifyGesture:
		factor = event.factor
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_EQUAL or event.keycode == KEY_KP_ADD:
			factor = ZOOM_STEP
		elif event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT:
			factor = 1.0 / ZOOM_STEP
	if factor <= 0.0:
		return false
	var next := clampf(_camera.zoom.x * factor, ZOOM_MIN, ZOOM_MAX)
	_camera.zoom = Vector2(next, next)
	get_viewport().set_input_as_handled()
	return true

func _cell_at(world: Vector2) -> Vector2i:
	var local := to_local(world)
	var best := Vector2i(9999, 9999)
	var best_distance := HEX_SIZE * 0.95
	for cell in _cells:
		var gap := local.distance_to(_center(cell))
		if gap < best_distance:
			best_distance = gap
			best = cell
	return best

func _try_click(cell: Vector2i) -> void:
	if not _my_turn() or _moving:
		return
	if _attack_mode:
		var enemy_id := _enemy_at(cell)
		if enemy_id != 0 and _attack_distance_ok(_my_id(), cell):
			_request_attack(enemy_id)
		return
	if _villager_at(cell) != "" and _distance_of(_my_id(), cell) <= 1:
		_try_talk(cell)
		return
	_try_move(cell)

func _try_talk(cell: Vector2i) -> void:
	if _moving or not _heroes.has(_my_id()) or int(_heroes[_my_id()]["hp"]) <= 0:
		return
	for villager in _villagers:
		if villager["cell"] != cell:
			continue
		if _distance_of(_my_id(), cell) > 1:
			return
		_talk_id = villager["id"]
		_talk_step = "hello"
		_show_talk(_greeting(villager["id"]), _choice_labels(villager["id"], "hello"))
		return

func _request_attack(target_id: int) -> void:
	if _online() and not multiplayer.is_server():
		Game.rpc_request_attack.rpc_id(1, target_id)
	else:
		on_attack_request(_my_id(), target_id)

func _try_move(cell: Vector2i) -> void:
	if _online() and not multiplayer.is_server():
		Game.rpc_request_move.rpc_id(1, cell.x, cell.y)
	else:
		on_move_request(_my_id(), cell)

func on_peer_ready(peer_id: int, class_id: String = "warrior") -> void:
	_ensure_player(peer_id, class_id)
	_publish()

func on_move_request(sender: int, cell: Vector2i) -> void:
	if not _can_act(sender) or not _walkable.has(cell):
		return
	var path := _path_for(sender, cell)
	if path.size() < 2 or _path_cost(path) > _range_for(sender):
		return
	_moving = true
	_preview = []
	_begin_move(sender, path)

func on_attack_request(sender: int, target_id: int) -> void:
	if not _can_act(sender) or not _enemies.has(target_id):
		return
	if not _attack_distance_ok(sender, _cell_of(target_id)):
		return
	_moving = true
	_strike(sender, target_id)
	_finish_player_action(sender)

func on_end_turn(sender: int) -> void:
	if not _can_act(sender):
		return
	_moving = true
	_finish_player_action(sender)

func on_choice(sender: int, villager_id: String, choice: String) -> void:
	if not _adjacent_villager(sender, villager_id):
		return
	_outgoing_talk = _mutate_choice(sender, villager_id, choice)
	_publish()

func on_potion(sender: int) -> void:
	if not _heroes.has(sender):
		return
	var hero: Dictionary = _heroes[sender]
	if int(hero["potions"]) <= 0 or int(hero["hp"]) <= 0:
		return
	hero["potions"] = int(hero["potions"]) - 1
	hero["hp"] = mini(int(hero["max_hp"]), int(hero["hp"]) + 30)
	_publish()

func _begin_move(actor_id: int, path: Array[Vector2i]) -> void:
	await _broadcast_and_wait(actor_id, path)
	if actor_id > 0:
		await _finish_player_action(actor_id)
	else:
		_moving = false

func _pack_path(path: Array[Vector2i]) -> PackedInt32Array:
	var packed := PackedInt32Array()
	for cell in path:
		packed.append(cell.x)
		packed.append(cell.y)
	return packed

func _broadcast_and_wait(actor_id: int, path: Array[Vector2i]) -> void:
	if path.size() <= 1:
		return
	if _online() and multiplayer.is_server():
		Game.rpc_animate.rpc(actor_id, _pack_path(path))
	await _animate_visual(actor_id, path)

func play_path(actor_id: int, packed_path: PackedInt32Array) -> void:
	var path: Array[Vector2i] = []
	var index := 0
	while index + 1 < packed_path.size():
		path.append(Vector2i(packed_path[index], packed_path[index + 1]))
		index += 2
	if _moving:
		_pending_state["queued_path_id"] = actor_id
		_pending_state["queued_path"] = path
		return
	await _animate_visual(actor_id, path)
	_apply_queued_path()

func _apply_queued_path() -> void:
	if not _pending_state.has("queued_path"):
		if not _pending_state.is_empty() and _pending_state.has("heroes"):
			apply_state(_pending_state)
			_pending_state = {}
		return
	var actor_id := int(_pending_state["queued_path_id"])
	var path: Array[Vector2i] = _pending_state["queued_path"]
	_pending_state.erase("queued_path")
	_pending_state.erase("queued_path_id")
	await _animate_visual(actor_id, path)

func _animate_visual(actor_id: int, path: Array[Vector2i]) -> void:
	_moving = true
	_preview.clear()
	queue_redraw()
	var sprite := _sprite_for(actor_id)
	if sprite == null:
		_moving = false
		return
	for index in range(1, path.size()):
		var start := _center(path[index - 1])
		var target := _center(path[index])
		var tween := create_tween()
		tween.tween_method(_place_hop.bind(sprite, start, target), 0.0, 1.0, HOP_TIME)
		await tween.finished
		sprite.position = target
		_set_cell(actor_id, path[index])
	_moving = false
	if not _authority() and _pending_state.has("heroes"):
		var pending: Dictionary = _pending_state
		_pending_state = {}
		_apply_state_now(pending)

func _place_hop(amount: float, sprite: Sprite2D, start: Vector2, target: Vector2) -> void:
	var point := start.lerp(target, amount)
	point.y -= sin(amount * PI) * HOP_HEIGHT
	sprite.position = point

func _finish_player_action(player_id: int) -> void:
	if not _action_ends_turn():
		_moving = false
		_refresh_hud()
		queue_redraw()
		return
	_rebuild_turn_order()
	_advance_turn()
	var guard := 0
	while guard < 6 and _enemy_turn_now():
		guard += 1
		var enemy_id := _turn_order[_turn_index]
		await _enemy_act(enemy_id)
		if _living_hero_count() <= 0:
			return
		_rebuild_turn_order()
		if _turn_order.is_empty():
			break
		if _turn_index < _turn_order.size() and _turn_order[_turn_index] == enemy_id:
			_advance_turn()
	_moving = false
	_publish()

func _enemy_act(enemy_id: int) -> void:
	if not _enemies.has(enemy_id):
		return
	var target_id := _nearest_hero(enemy_id)
	if target_id == 0:
		return
	var budget := int(_enemies[enemy_id]["move"])
	var path := _approach(enemy_id, _cell_of(target_id), budget)
	await _broadcast_and_wait(enemy_id, path)
	if _distance_between(enemy_id, target_id) <= int(_enemies[enemy_id]["attack_range"]):
		_damage_hero(target_id, int(_enemies[enemy_id]["atk"]))

func _approach(mover_id: int, goal: Vector2i, budget: int) -> Array[Vector2i]:
	var current := _cell_of(mover_id)
	var path: Array[Vector2i] = [current]
	var spent := 0
	while spent < budget and HexGrid.distance(current, goal) > 1:
		var best := current
		var best_distance := HexGrid.distance(current, goal)
		var best_cost := 0
		for next in HexGrid.neighbors(current):
			if not _walkable.has(next) or _occupied(next, mover_id):
				continue
			var step_cost := int(_enter_cost.get(next, 1))
			if spent + step_cost > budget:
				continue
			var gap := HexGrid.distance(next, goal)
			if gap < best_distance:
				best = next
				best_distance = gap
				best_cost = step_cost
		if best == current:
			break
		spent += best_cost
		current = best
		path.append(current)
	return path

func _strike(attacker_id: int, target_id: int) -> void:
	var enemy: Dictionary = _enemies[target_id]
	var hero: Dictionary = _heroes[attacker_id]
	enemy["hp"] = int(enemy["hp"]) - int(hero["atk"])
	if int(enemy["hp"]) > 0:
		return
	_grant_xp(hero, 20)
	if target_id == GOBLIN_ID:
		_add_copper(hero, 12)
		_goblin_dead = true
	_remove_enemy(target_id)

func _damage_hero(hero_id: int, amount: int) -> void:
	if not _heroes.has(hero_id):
		return
	var hero: Dictionary = _heroes[hero_id]
	hero["hp"] = maxi(0, int(hero["hp"]) - amount)
	if int(hero["hp"]) <= 0:
		_respawn_hero(hero_id)

func _grant_xp(hero: Dictionary, amount: int) -> void:
	hero["xp"] = int(hero["xp"]) + amount
	while int(hero["xp"]) >= int(hero["xp_next"]):
		hero["xp"] = int(hero["xp"]) - int(hero["xp_next"])
		hero["level"] = int(hero["level"]) + 1
		hero["max_hp"] = int(hero["max_hp"]) + 20
		hero["atk"] = int(hero["atk"]) + 3
		hero["hp"] = int(hero["max_hp"])
		hero["xp_next"] = 40 * int(hero["level"])

func _add_copper(hero: Dictionary, amount: int) -> void:
	var total := int(hero["copper"]) + int(hero["silver"]) * 10 + int(hero["gold"]) * 100 + amount
	hero["gold"] = int(total / 100)
	hero["silver"] = int((total % 100) / 10)
	hero["copper"] = total % 10

func _spend_copper(hero: Dictionary, amount: int) -> bool:
	var total := int(hero["copper"]) + int(hero["silver"]) * 10 + int(hero["gold"]) * 100
	if total < amount:
		return false
	_add_copper(hero, -amount)
	return true

func _can_act(sender: int) -> bool:
	if _moving or not _heroes.has(sender) or int(_heroes[sender]["hp"]) <= 0:
		return false
	if not _online() and not _action_ends_turn():
		return true
	return not _turn_order.is_empty() and _turn_order[_turn_index] == sender

func _finish_player_action_guard() -> void:
	pass

func _enemy_turn_now() -> bool:
	if _turn_order.is_empty() or _turn_index >= _turn_order.size():
		return false
	var actor := _turn_order[_turn_index]
	return actor < 0 and _enemies.has(actor)

func _rebuild_turn_order() -> void:
	var current := 0
	if _turn_index < _turn_order.size():
		current = _turn_order[_turn_index]
	var order: Array[int] = []
	var ids: Array[int] = []
	for hero_id in _heroes.keys():
		if int(_heroes[hero_id]["hp"]) > 0:
			ids.append(int(hero_id))
	ids.sort()
	for hero_id in ids:
		order.append(hero_id)
	if _enemies.has(GOBLIN_ID) and _goblin_aggro():
		order.append(GOBLIN_ID)
	_turn_order = order
	if order.is_empty():
		_turn_index = 0
		return
	var found := order.find(current)
	_turn_index = found if found >= 0 else mini(_turn_index, order.size() - 1)

func _advance_turn() -> void:
	if _turn_order.is_empty():
		return
	_turn_index = (_turn_index + 1) % _turn_order.size()

func _goblin_aggro() -> bool:
	if not _enemies.has(GOBLIN_ID):
		return false
	var goblin_cell := _cell_of(GOBLIN_ID)
	for hero_id in _heroes.keys():
		if int(_heroes[hero_id]["hp"]) <= 0:
			continue
		if HexGrid.distance(_cell_of(int(hero_id)), goblin_cell) <= 8:
			return true
	return false

func _range_for(actor_id: int) -> int:
	if actor_id < 0:
		return int(_enemies[actor_id]["move"])
	var move_range := int(_heroes[actor_id]["move"])
	if Game.layer == "surface" and _enemies.has(GOBLIN_ID):
		if HexGrid.distance(_cell_of(actor_id), _cell_of(GOBLIN_ID)) <= 8:
			return maxi(1, move_range / 2)
	return move_range

func _path_for(mover_id: int, goal: Vector2i) -> Array[Vector2i]:
	return HexGrid.cheapest_path(_cell_of(mover_id), goal, _walkable, _enter_cost, _blocked_cells(mover_id))

func _path_cost(path: Array[Vector2i]) -> int:
	var total := 0
	for index in range(1, path.size()):
		total += int(_enter_cost.get(path[index], 1))
	return total

func _blocked_cells(mover_id: int) -> Dictionary:
	var blocked := {}
	for hero_id in _heroes.keys():
		if int(hero_id) == mover_id or int(_heroes[hero_id]["hp"]) <= 0:
			continue
		blocked[_cell_of(int(hero_id))] = true
	for enemy_id in _enemies.keys():
		if int(enemy_id) == mover_id:
			continue
		blocked[_cell_of(int(enemy_id))] = true
	for villager in _villagers:
		blocked[villager["cell"]] = true
	return blocked

func _occupied(cell: Vector2i, mover_id: int) -> bool:
	return _blocked_cells(mover_id).has(cell)

func _set_preview(cell: Vector2i) -> void:
	_preview = []
	if not _my_turn() or _moving or not _heroes.has(_my_id()):
		queue_redraw()
		return
	if _attack_mode:
		_preview_in_range = false
		for spot in _cells:
			if _attack_distance_ok(_my_id(), spot):
				_preview.append(spot)
		queue_redraw()
		return
	if cell == Vector2i(9999, 9999) or cell == _cell_of(_my_id()) or _enemy_at(cell) != 0:
		queue_redraw()
		return
	var path := _path_for(_my_id(), cell)
	if path.size() <= 1:
		queue_redraw()
		return
	_preview = path.slice(1)
	_preview_in_range = _path_cost(path) <= _range_for(_my_id())
	queue_redraw()

func _ensure_player(peer_id: int, class_id: String = "warrior") -> void:
	if _heroes.has(peer_id):
		return
	var spawns: Array = WorldMap.surface()["spawns"]
	var cell: Vector2i = spawns[mini(_heroes.size(), spawns.size() - 1)]
	var stats := _class_stats(class_id)
	_heroes[peer_id] = {
		"id": peer_id, "class_id": class_id, "q": cell.x, "r": cell.y,
		"spawn_q": cell.x, "spawn_r": cell.y,
		"hp": stats["hp"], "max_hp": stats["hp"], "atk": stats["atk"],
		"move": stats["move"], "range_min": stats["range_min"], "range_max": stats["range_max"],
		"level": 1, "xp": 0, "xp_next": 40,
		"copper": 0, "silver": 0, "gold": 0, "potions": 0,
	}
	_add_hero_sprite(peer_id, cell)
	_rebuild_turn_order()

func _class_stats(class_id: String) -> Dictionary:
	if class_id == "archer":
		return {"hp": 80, "atk": 10, "move": 6, "range_min": 2, "range_max": 4}
	return {"hp": 125, "atk": 10, "move": 8, "range_min": 1, "range_max": 1}

func _attack_distance_ok(hero_id: int, cell: Vector2i) -> bool:
	if not _heroes.has(hero_id):
		return false
	var dist := HexGrid.distance(_cell_of(hero_id), cell)
	return dist >= int(_heroes[hero_id]["range_min"]) and dist <= int(_heroes[hero_id]["range_max"])

func _respawn_hero(hero_id: int) -> void:
	var hero: Dictionary = _heroes[hero_id]
	var cell := Vector2i(int(hero["spawn_q"]), int(hero["spawn_r"]))
	if _occupied(cell, hero_id) or not _walkable.has(cell):
		var spawns: Array = WorldMap.surface()["spawns"]
		for candidate in spawns:
			if _walkable.has(candidate) and not _occupied(candidate, hero_id):
				cell = candidate
				break
	hero["hp"] = int(hero["max_hp"])
	hero["q"] = cell.x
	hero["r"] = cell.y
	if _hero_sprites.has(hero_id):
		_hero_sprites[hero_id].position = _center(cell)
		_hero_sprites[hero_id].modulate = Color(0.7, 0.85, 1.0) if hero_id != 1 else Color.WHITE

func _villager_at(cell: Vector2i) -> String:
	for villager in _villagers:
		if villager["cell"] == cell:
			return str(villager["id"])
	return ""

func _draw_enemy_bars() -> void:
	for enemy_id in _enemies.keys():
		var middle := _center(_cell_of(int(enemy_id)))
		var hp := float(int(_enemies[enemy_id]["hp"]))
		var max_hp := maxf(1.0, float(int(_enemies[enemy_id]["max_hp"])))
		_bars.draw_rect(Rect2(middle + Vector2(-18, -50), Vector2(36, 7)), Color(0.12, 0.08, 0.08, 0.9))
		_bars.draw_rect(Rect2(middle + Vector2(-17, -49), Vector2(34.0 * hp / max_hp, 5)), Color(0.86, 0.16, 0.14, 0.95))

func _add_hero_sprite(peer_id: int, cell: Vector2i) -> void:
	var sprite := Sprite2D.new()
	var class_id := str(_heroes[peer_id].get("class_id", "warrior"))
	sprite.texture = ArcherSprite.texture() if class_id == "archer" else WarriorSprite.texture()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * (72.0 / sprite.texture.get_height())
	sprite.position = _center(cell)
	sprite.z_index = 3
	if peer_id != 1:
		sprite.modulate = Color(0.7, 0.85, 1.0)
	add_child(sprite)
	_hero_sprites[peer_id] = sprite

func _add_enemy(enemy_id: int, kind: String, cell: Vector2i, hp: int, atk: int, move: int) -> void:
	_enemies[enemy_id] = {
		"id": enemy_id, "kind": kind, "q": cell.x, "r": cell.y,
		"hp": hp, "max_hp": hp, "atk": atk, "move": move, "attack_range": 1,
	}
	var sprite := Sprite2D.new()
	sprite.texture = GoblinSprite.texture()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * (58.0 / sprite.texture.get_height())
	sprite.position = _center(cell)
	sprite.z_index = 3
	add_child(sprite)
	_enemy_sprites[enemy_id] = sprite

func _remove_enemy(enemy_id: int) -> void:
	if _enemy_sprites.has(enemy_id):
		_enemy_sprites[enemy_id].queue_free()
		_enemy_sprites.erase(enemy_id)
	_enemies.erase(enemy_id)

func _clear_enemies() -> void:
	for enemy_id in _enemy_sprites.keys():
		_enemy_sprites[enemy_id].queue_free()
	_enemy_sprites.clear()
	_enemies.clear()

func _sprite_for(actor_id: int) -> Sprite2D:
	if actor_id > 0 and _hero_sprites.has(actor_id):
		return _hero_sprites[actor_id]
	if _enemy_sprites.has(actor_id):
		return _enemy_sprites[actor_id]
	return null

func _cell_of(actor_id: int) -> Vector2i:
	if actor_id > 0:
		return Vector2i(int(_heroes[actor_id]["q"]), int(_heroes[actor_id]["r"]))
	return Vector2i(int(_enemies[actor_id]["q"]), int(_enemies[actor_id]["r"]))

func _set_cell(actor_id: int, cell: Vector2i) -> void:
	var record: Dictionary = _heroes[actor_id] if actor_id > 0 else _enemies[actor_id]
	record["q"] = cell.x
	record["r"] = cell.y

func _distance_of(actor_id: int, cell: Vector2i) -> int:
	return HexGrid.distance(_cell_of(actor_id), cell)

func _distance_between(a: int, b: int) -> int:
	return HexGrid.distance(_cell_of(a), _cell_of(b))

func _enemy_at(cell: Vector2i) -> int:
	for enemy_id in _enemies.keys():
		if _cell_of(int(enemy_id)) == cell:
			return int(enemy_id)
	return 0

func _nearest_hero(enemy_id: int) -> int:
	var best := 0
	var best_distance := 999
	for hero_id in _heroes.keys():
		if int(_heroes[hero_id]["hp"]) <= 0:
			continue
		var gap := _distance_between(enemy_id, int(hero_id))
		if gap < best_distance:
			best_distance = gap
			best = int(hero_id)
	return best

func _living_hero_count() -> int:
	var count := 0
	for hero_id in _heroes.keys():
		if int(_heroes[hero_id]["hp"]) > 0:
			count += 1
	return count

func _role_of(villager_id: String) -> String:
	for villager in _villagers:
		if villager["id"] == villager_id:
			return villager["role"]
	return ""

func _adjacent_villager(hero_id: int, villager_id: String) -> bool:
	if not _heroes.has(hero_id):
		return false
	for villager in _villagers:
		if villager["id"] == villager_id:
			return HexGrid.distance(_cell_of(hero_id), villager["cell"]) <= 1
	return false

func _greeting(villager_id: String) -> String:
	var role := _role_of(villager_id)
	if role == "quest":
		if Game.quest == "none":
			return "Hello I could use some help"
		if Game.quest == "started":
			return "Please find my battle axe of gold."
		return "Thank you for finding my battle axe."
	if role == "shop":
		if Game.quest == "complete":
			return "The axe is home. The war can wait."
		if Game.quest == "started":
			return "I hate the war! My gold was stolen!"
		return "Hello."
	if role == "thief":
		if Game.quest == "complete":
			return "I'm sorry I took the axe."
		if Game.quest == "started":
			return "I just got some shiny gold from a friend."
		return "Hello."
	if Game.quest == "complete":
		return "I knew that gold loving guy was the thief."
	if Game.quest == "started":
		return "That gold loving guy over there shouldn't be trusted."
	return "Hello."

func _choice_labels(villager_id: String, step: String) -> Array[String]:
	var role := _role_of(villager_id)
	if role == "quest" and Game.quest == "none" and step == "hello":
		return ["Yes", "No"]
	if role == "quest" and step == "axe":
		return ["Later", "Oh no"]
	var labels: Array[String] = ["Goodbye"]
	if role == "shop":
		labels = ["Goodbye", "Buy potion (2 silver)", "Rest (1 silver)"]
	if Game.quest == "started":
		labels.append("That gold is the stolen axe")
	return labels

func _choice_key(label: String) -> String:
	match label:
		"Yes":
			return "yes"
		"No":
			return "no"
		"Later":
			return "later"
		"Oh no":
			return "oh_no"
		"Buy potion (2 silver)":
			return "buy"
		"Rest (1 silver)":
			return "rest"
		"That gold is the stolen axe":
			return "accuse"
		_:
			return "goodbye"

func _show_talk(line: String, labels: Array[String]) -> void:
	_talk_root.visible = true
	_talk_label.text = line
	for child in _talk_buttons.get_children():
		child.queue_free()
	for label in labels:
		var button := Button.new()
		button.text = label
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_on_talk_button.bind(label))
		_talk_buttons.add_child(button)

func _close_talk() -> void:
	_talk_root.visible = false
	_talk_id = ""
	_talk_step = ""

func _on_talk_button(label: String) -> void:
	var choice := _choice_key(label)
	if choice == "yes":
		_talk_step = "axe"
		_show_talk("Theres a thief among us I got stolen from. My presius battle axe of gold", _choice_labels(_talk_id, "axe"))
		return
	if choice == "goodbye" or choice == "no" or choice == "later":
		_close_talk()
		return
	if choice == "oh_no":
		if _online() and not multiplayer.is_server():
			Game.rpc_request_choice.rpc_id(1, _talk_id, choice)
		else:
			on_choice(_my_id(), _talk_id, choice)
		_close_talk()
		return
	if _online() and not multiplayer.is_server():
		Game.rpc_request_choice.rpc_id(1, _talk_id, choice)
		return
	on_choice(_my_id(), _talk_id, choice)

func _mutate_choice(sender: int, villager_id: String, choice: String) -> Dictionary:
	var hero: Dictionary = _heroes[sender]
	Game.notice = ""
	if choice == "oh_no":
		Game.quest = "started"
		return {"close": true}
	if choice == "accuse" and Game.quest == "started":
		if _role_of(villager_id) == "thief":
			Game.quest = "complete"
			return {"id": villager_id, "step": "confess", "line": "Fine. The axe is yours.", "labels": ["Goodbye"]}
		return {"id": villager_id, "step": "deny", "line": "I didn't take the axe.", "labels": ["Goodbye"]}
	if choice == "buy":
		if _spend_copper(hero, 20):
			hero["potions"] = int(hero["potions"]) + 1
			Game.notice = "Bought a potion."
		else:
			Game.notice = "You need 2 silver."
		return {"id": villager_id, "step": "shop", "line": _greeting(villager_id) + "\n" + Game.notice, "labels": _choice_labels(villager_id, "shop")}
	if choice == "rest":
		if _spend_copper(hero, 10):
			hero["hp"] = int(hero["max_hp"])
			Game.notice = "You feel rested."
		else:
			Game.notice = "You need 1 silver."
		return {"id": villager_id, "step": "shop", "line": _greeting(villager_id) + "\n" + Game.notice, "labels": _choice_labels(villager_id, "shop")}
	return {"close": true}

func _on_end_turn_pressed() -> void:
	if not _my_turn() or _moving:
		return
	if _online() and not multiplayer.is_server():
		Game.rpc_end_turn.rpc_id(1)
	else:
		on_end_turn(_my_id())

func _on_potion_pressed() -> void:
	if _online() and not multiplayer.is_server():
		Game.rpc_request_potion.rpc_id(1)
	else:
		on_potion(_my_id())

func _trip_over() -> void:
	_moving = false
	if _online() and multiplayer.is_server():
		Game.rpc_trip_over.rpc()
	elif not _online():
		Game.begin_run()
		get_tree().change_scene_to_file("res://scenes/class_select.tscn")

func _publish() -> void:
	if _online() and multiplayer.is_server():
		Game.rpc_sync.rpc(_snapshot())
	else:
		if _outgoing_talk != null:
			var talk: Dictionary = _outgoing_talk
			_outgoing_talk = null
			_apply_talk(talk)
		_refresh_hud()
		queue_redraw()

func _snapshot() -> Dictionary:
	var heroes: Array[Dictionary] = []
	for hero_id in _heroes.keys():
		heroes.append(_heroes[hero_id].duplicate())
	var enemies: Array[Dictionary] = []
	for enemy_id in _enemies.keys():
		enemies.append(_enemies[enemy_id].duplicate())
	var payload := {
		"layer": Game.layer,
		"quest": Game.quest,
		"notice": Game.notice,
		"goblin_dead": _goblin_dead,
		"heroes": heroes,
		"enemies": enemies,
		"order": _turn_order.duplicate(),
		"turn": _turn_index,
	}
	if _outgoing_talk != null:
		payload["talk"] = _outgoing_talk
		_outgoing_talk = null
	return payload

func apply_state(payload: Dictionary) -> void:
	if _moving:
		_pending_state = payload
		return
	_apply_state_now(payload)

func _apply_state_now(payload: Dictionary) -> void:
	_goblin_dead = bool(payload.get("goblin_dead", _goblin_dead))
	Game.quest = str(payload.get("quest", Game.quest))
	Game.notice = str(payload.get("notice", ""))
	var layer_name := str(payload.get("layer", Game.layer))
	if layer_name != _built_layer:
		_load_layer(layer_name, false)
	_sync_heroes(payload.get("heroes", []))
	_sync_enemies(payload.get("enemies", []))
	_turn_order.clear()
	for actor_id in payload.get("order", []):
		_turn_order.append(int(actor_id))
	_turn_index = int(payload.get("turn", 0))
	if payload.has("talk"):
		_apply_talk(payload["talk"])
	_refresh_hud()
	queue_redraw()

func _sync_heroes(entries: Array) -> void:
	var keep := {}
	for entry in entries:
		var hero_id := int(entry["id"])
		keep[hero_id] = true
		var cell := Vector2i(int(entry["q"]), int(entry["r"]))
		if not _heroes.has(hero_id):
			_heroes[hero_id] = entry.duplicate()
			_add_hero_sprite(hero_id, cell)
		else:
			_heroes[hero_id] = entry.duplicate()
			if _hero_sprites.has(hero_id):
				_hero_sprites[hero_id].position = _center(cell)
				_hero_sprites[hero_id].modulate = Color(0.4, 0.4, 0.4) if int(entry["hp"]) <= 0 else (Color(0.7, 0.85, 1.0) if hero_id != 1 else Color.WHITE)
	for hero_id in _heroes.keys():
		if not keep.has(int(hero_id)):
			if _hero_sprites.has(hero_id):
				_hero_sprites[hero_id].queue_free()
				_hero_sprites.erase(hero_id)
			_heroes.erase(hero_id)

func _sync_enemies(entries: Array) -> void:
	var keep := {}
	for entry in entries:
		var enemy_id := int(entry["id"])
		keep[enemy_id] = true
		var cell := Vector2i(int(entry["q"]), int(entry["r"]))
		if not _enemies.has(enemy_id):
			_add_enemy(enemy_id, str(entry["kind"]), cell, int(entry["hp"]), int(entry["atk"]), int(entry["move"]))
			_enemies[enemy_id] = entry.duplicate()
		else:
			_enemies[enemy_id] = entry.duplicate()
			if _enemy_sprites.has(enemy_id):
				_enemy_sprites[enemy_id].position = _center(cell)
	for enemy_id in _enemies.keys():
		if not keep.has(int(enemy_id)):
			_remove_enemy(int(enemy_id))

func _apply_talk(talk: Dictionary) -> void:
	if bool(talk.get("close", false)):
		_close_talk()
		return
	_talk_id = str(talk.get("id", ""))
	_talk_step = str(talk.get("step", "hello"))
	var labels: Array[String] = []
	for label in talk.get("labels", []):
		labels.append(str(label))
	_show_talk(str(talk.get("line", "")), labels)

func _refresh_hud() -> void:
	var hero: Dictionary = _heroes[_my_id()] if _heroes.has(_my_id()) else {}
	var hp := int(hero.get("hp", 0))
	var max_hp := maxi(1, int(hero.get("max_hp", 125)))
	_hp_fill.size.x = 216.0 * float(hp) / float(max_hp)
	_hp_label.text = str(hp)
	if hero.is_empty():
		_level_label.text = ""
		_coin_label.text = ""
	else:
		_level_label.text = "Level %d    %d/%d xp" % [int(hero["level"]), int(hero["xp"]), int(hero["xp_next"])]
		_coin_label.text = "%d copper   %d silver   %d gold\nPotions %d" % [int(hero["copper"]), int(hero["silver"]), int(hero["gold"]), int(hero["potions"])]
	_potion_button.visible = not hero.is_empty() and int(hero.get("potions", 0)) > 0 and hp > 0
	var show_end := _my_turn() and not _moving and (_online() or _action_ends_turn())
	_end_button.visible = show_end
	if not _online():
		_turn_label.text = "Goblin's turn" if _enemy_turn_now() else ""
	elif _my_turn():
		_turn_label.text = "Attack" if _attack_mode else "Your turn"
	else:
		_turn_label.text = "Waiting for the other player"
	if not _online() and _my_turn() and _attack_mode:
		_turn_label.text = "Attack"
	if _bars != null:
		_bars.queue_redraw()
