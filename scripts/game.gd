extends Node

const PORT := 11111

var mode := "solo"
var session := "none"
var chosen_class := ""
var status := ""
var map: Node = null
var layer := "surface"
var quest := "none"
var notice := ""

signal join_finished(ok: bool)

func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)

func begin_run() -> void:
	layer = "surface"
	quest = "none"
	notice = ""

func play_solo() -> void:
	_close_peer()
	mode = "solo"
	session = "none"
	status = ""

func register_map(node: Node) -> void:
	map = node

func unregister_map(node: Node) -> void:
	if map == node:
		map = null

@rpc("any_peer", "reliable")
func rpc_request_state() -> void:
	if multiplayer.is_server() and map != null:
		map.call("on_peer_ready", multiplayer.get_remote_sender_id(), "warrior")

@rpc("any_peer", "reliable")
func rpc_request_state_as(class_id: String) -> void:
	if multiplayer.is_server() and map != null:
		map.call("on_peer_ready", multiplayer.get_remote_sender_id(), class_id)

@rpc("any_peer", "reliable")
func rpc_request_move(q: int, r: int) -> void:
	if multiplayer.is_server() and map != null:
		map.call("on_move_request", multiplayer.get_remote_sender_id(), Vector2i(q, r))

@rpc("any_peer", "reliable")
func rpc_end_turn() -> void:
	if multiplayer.is_server() and map != null:
		map.call("on_end_turn", multiplayer.get_remote_sender_id())

@rpc("any_peer", "reliable")
func rpc_request_attack(target_id: int) -> void:
	if multiplayer.is_server() and map != null:
		map.call("on_attack_request", multiplayer.get_remote_sender_id(), target_id)

@rpc("any_peer", "reliable")
func rpc_request_choice(villager_id: String, choice: String) -> void:
	if multiplayer.is_server() and map != null:
		map.call("on_choice", multiplayer.get_remote_sender_id(), villager_id, choice)

@rpc("any_peer", "reliable")
func rpc_request_potion() -> void:
	if multiplayer.is_server() and map != null:
		map.call("on_potion", multiplayer.get_remote_sender_id())

@rpc("authority", "call_local", "reliable")
func rpc_trip_over() -> void:
	begin_run()
	get_tree().change_scene_to_file("res://scenes/class_select.tscn")

@rpc("authority", "call_local", "reliable")
func rpc_sync(payload: Dictionary) -> void:
	if map != null:
		map.call("apply_state", payload)

@rpc("authority", "reliable")
func rpc_animate(peer_id: int, packed_path: PackedInt32Array) -> void:
	if map != null:
		map.call("play_path", peer_id, packed_path)

func host_game(port: int = PORT) -> Error:
	_close_peer()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port)
	if err != OK:
		status = "Could not host on port %d." % port
		return err
	multiplayer.multiplayer_peer = peer
	mode = "host"
	status = "Friends join with %s:%d" % [lan_ip(), port]
	return OK

func join_game(address: String) -> void:
	var parsed := parse_join_address(address)
	if str(parsed["host"]) == "" or int(parsed["port"]) <= 0:
		status = "Use an address like 192.168.1.105:11111"
		join_finished.emit(false)
		return
	_close_peer()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(str(parsed["host"]), int(parsed["port"]))
	if err != OK:
		status = "Could not join that address."
		join_finished.emit(false)
		return
	multiplayer.multiplayer_peer = peer
	mode = "join"
	status = "Connecting to %s:%d" % [parsed["host"], int(parsed["port"])]

func parse_join_address(address: String) -> Dictionary:
	var raw := address.strip_edges()
	var host := raw
	var port := PORT
	var colon := raw.rfind(":")
	if colon > 0:
		host = raw.substr(0, colon)
		port = raw.substr(colon + 1).to_int()
	if host == "" or not host.contains(".") or port <= 0 or port > 65535:
		return {"host": "", "port": -1}
	return {"host": host, "port": port}

func lan_ip() -> String:
	for address in IP.get_local_addresses():
		if address.begins_with("192.168.") or address.begins_with("10.") or address.begins_with("172."):
			return address
	return "127.0.0.1"

func _on_connected() -> void:
	status = "Joined the game."
	join_finished.emit(true)

func _on_connection_failed() -> void:
	_close_peer()
	mode = "solo"
	status = "Could not join. Check the address and try again."
	join_finished.emit(false)

func _close_peer() -> void:
	if multiplayer.multiplayer_peer == null:
		return
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
