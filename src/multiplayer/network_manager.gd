extends Node

signal connected_to_server
signal disconnected_from_server
signal room_created(room_id: String)
signal room_joined(room_info: Dictionary)
signal room_left
signal room_creation_failed(reason: String)
signal join_failed(reason: String)
signal player_joined(player_id: int, player_info: Dictionary)
signal player_left(player_id: int)
signal host_changed(new_host_id: int)
signal message_received(text_content)
signal room_player_list_updated(room_id: String, players: Array)
signal game_started(board_state: Dictionary)
signal game_state_changed(new_state: int)
signal game_started_failed(reason: String)
signal piece_moved(piece_id: int, new_position: Vector3)
signal turn_changed(current_player_id: int)

var peer = WebSocketMultiplayerPeer
var current_room_id: String = ""
var is_host: bool = false
var room_host_id: int
var is_player_connected: bool = false
var current_players: Array = []  # list of dictionaries { id, name, ... }
var current_game_state: int = Constants.GameState.WAITING

const SERVER_NODE = "/root/Server"

func connect_to_server(address: String = Constants.DEFAULT_SERVER_URL) -> bool:
    peer = WebSocketMultiplayerPeer.new()
    peer.supported_protocols = ["godot-game"]

    multiplayer.connected_to_server.connect(_on_connected)
    multiplayer.server_disconnected.connect(_on_disconnected)
    multiplayer.connection_failed.connect(_on_connection_failed)
    multiplayer.peer_disconnected.connect(_on_disconnected)

    print(address)
    var error = peer.create_client(address)
    if error != OK:
        printerr("Failed to create client: ", error)
        return false

    multiplayer.multiplayer_peer = peer
    return true

func disconnect_from_server():
    if not multiplayer.multiplayer_peer:
        return

    print("Disconnecting from server...")
    _handle_server_disconnected()

func _on_connected():
    print("Connected to server")
    is_player_connected = true
    connected_to_server.emit()

func _on_disconnected():
    print("Disconnected from server")
    _handle_server_disconnected()

func _handle_server_disconnected():
    is_player_connected = false
    current_room_id = ""
    is_host = false
    current_players.clear()
    multiplayer.multiplayer_peer.close()
    multiplayer.multiplayer_peer = null
    disconnected_from_server.emit()

func _on_connection_failed():
    print("Connection failed - check server address")
    is_player_connected = false

# ─────────────────────────────────────────────────────────────────
# CLIENT-SIDE METHODS
# These send RPC calls to the server
# ─────────────────────────────────────────────────────────────────

func create_room(room_id: String, max_players: int = Constants.MAX_PLAYERS) -> void:
    if not multiplayer.multiplayer_peer:
        printerr("Not connected to server")
        return

    rpc_id(1, "rpc_create_room", room_id, max_players)


func join_room(room_id: String):
    if not multiplayer.multiplayer_peer:
        printerr("Not connected to server")
        return

    rpc_id(1, "rpc_join_room", room_id)

func leave_room():
    if not multiplayer.multiplayer_peer or current_room_id.is_empty():
        return

    rpc_id(1, "rpc_leave_room")
    current_room_id = ""
    is_host = false

func request_return_lobby():
    if is_host:
        rpc_id(1, "rpc_go_to_lobby")

func request_game_start():
    if is_host:
        rpc_id(1, "rpc_start_game")

func request_game_finish():
    if is_host:
        rpc_id(1, "rpc_finish_game")

func send_chat_message(msg: String):
    print(msg)
    rpc_id(1, "rpc_send_chat_message", msg)

# ─────────────────────────────────────────────────────────────────
# RPC STUBS - These must exist on client, even if empty
# Server calls these back to the client
# ─────────────────────────────────────────────────────────────────

@rpc("any_peer", "call_local")
func rpc_create_room(room_id: String, max_players: int) -> void:
    print("rpc_create_room %s" % max_players)
    if not multiplayer.is_server():
        return

    get_node(SERVER_NODE).rpc_create_room(room_id, max_players)

@rpc("any_peer", "call_local")
func rpc_join_room(room_id: String):
    print("rpc_join_room %s" % room_id)
    if not multiplayer.is_server():
        return

    get_node(SERVER_NODE).rpc_join_room(room_id)

@rpc("any_peer", "call_local")
func rpc_leave_room():
    print("rpc_leave_room")
    if not multiplayer.is_server():
        return

    get_node(SERVER_NODE).rpc_leave_room()

@rpc("any_peer", "call_local")
func rpc_go_to_lobby():
    print("rpc_go_to_lobby")
    if not multiplayer.is_server():
        return

    get_node(SERVER_NODE).rpc_go_to_lobby()

@rpc("any_peer", "call_local")
func rpc_start_game():
    print("rpc_start_game")
    if not multiplayer.is_server():
        return

    get_node(SERVER_NODE).rpc_start_game()

@rpc("any_peer", "call_local")
func rpc_finish_game():
    print("rpc_finish_game")
    if not multiplayer.is_server():
        return

    get_node(SERVER_NODE).rpc_finish_game()

@rpc("any_peer", "call_local")
func rpc_send_chat_message(msg: String):
    print("rpc_send_chat_message: %s" % msg)
    if not multiplayer.is_server():
        return

    get_node(SERVER_NODE).rpc_send_chat_message(msg)

# ─────────────────────────────────────────────────────────────────
# SERVER RESPONSES - Called by server to notify client
# These update client state and emit signals
# ─────────────────────────────────────────────────────────────────

@rpc("any_peer")
func on_room_created(room_id: String):
    current_room_id = room_id
    room_host_id = multiplayer.get_unique_id()
    is_host = true
    room_created.emit(room_id)

@rpc("any_peer")
func on_room_joined(room_id: String, room_data: Dictionary):
    current_room_id = room_id
    room_host_id = room_data.host_id
    is_host = false
    room_joined.emit(room_data)

    if room_data.has("game_state"):
        current_game_state = room_data.game_state
        game_state_changed.emit(current_game_state)

@rpc("any_peer")
func on_room_left():
    current_room_id = ""
    is_host = false
    room_left.emit()

@rpc("any_peer")
func on_room_creation_failed(reason: String):
    room_creation_failed.emit(reason)

@rpc("any_peer")
func on_join_failed(reason: String):
    join_failed.emit(reason)

@rpc("any_peer")
func on_player_joined(player_id: int, player_info: Dictionary):
    player_joined.emit(player_id, player_info)

@rpc("any_peer")
func on_player_left(player_id: int):
    player_left.emit(player_id)

@rpc("any_peer")
func on_host_changed(new_host_id: int):
    room_host_id = new_host_id
    is_host = (new_host_id == multiplayer.get_unique_id())
    host_changed.emit(new_host_id)

@rpc("any_peer")
func on_game_started(board_state: Dictionary):
    game_started.emit(board_state)

@rpc("any_peer")
func on_game_start_failed(reason: String):
    game_started_failed.emit(reason)

@rpc("any_peer")
func on_piece_moved(piece_id: int, new_position: Vector3):
    piece_moved.emit(piece_id, new_position)

@rpc("any_peer")
func on_turn_changed(current_player_id: int):
    turn_changed.emit(current_player_id)

@rpc("any_peer")
func on_broadcasted_message(text_content: String):
    message_received.emit(text_content)

@rpc("any_peer")
func on_room_player_list_updated(room_id: String, players: Array) -> void:
    if room_id != current_room_id:
        return  # Ignore if this is not our active room

    current_players.clear()
    current_players = players
    room_player_list_updated.emit(room_id, players)

@rpc("any_peer")
func on_game_state_changed(new_state: int):
    current_game_state = new_state
    game_state_changed.emit(new_state)
    print("Game state changed to: ", new_state)
