extends Node

# ─────────────────────────────────────────────────────────────────
# NetworkManager works as a Singleton to connect client and server calls
# It listens to server changes and client calls, broadcasting messages
# It also holds client states
# ─────────────────────────────────────────────────────────────────

# signal connected_to_server
signal disconnected_from_server
signal user_authenticated
signal user_authentication_failed(reason: String)
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

var current_room_id: String = ""
var is_host: bool = false
var local_player_id: int = -1
var room_host_id: int
var current_players: Array = []  # list of dictionaries { id, name, ... }
var current_game_state: int = Constants.GameState.WAITING
var my_user_id: String # e.g. User_UUID_A -  Load this from save data
var my_token: String = "secret_token" # Change this later
var is_authenticated: bool = false
var is_reconnecting: bool = false
var is_player_connected: bool = false

var server_address: String
var server_ip: String
var server_port: int

var connection_check_timer: Timer

# Queue for outgoing messages: [ { "method": "chat", "args": ["hi"] } ]
var request_queue: Array = []

const SERVER_NODE = "/root/Server"

func _ready():
    multiplayer.connected_to_server.connect(_on_connected)
    multiplayer.server_disconnected.connect(_on_disconnected)
    multiplayer.connection_failed.connect(_on_connection_failed)

    # Create and configure the timer
    connection_check_timer = Timer.new()
    connection_check_timer.wait_time = 1.0
    connection_check_timer.one_shot = false
    connection_check_timer.timeout.connect(_on_connection_check_timeout)
    add_child(connection_check_timer)

# Debugging purposes
func _input(event: InputEvent) -> void:
    if Input.is_action_pressed("debug_disconnect"):
        NetworkManager.debug_simulate_disconnect()

func connect_to_server(address: String = Constants.DEFAULT_SERVER_URL) -> bool:
    var peer = WebSocketMultiplayerPeer.new()

    print(address)
    # Store server details in case of reconnection
    server_address = address
    var full_address = Utils.get_ip_and_port(server_address)
    server_ip = full_address["ip"]
    server_port = full_address["port"]

    var error = peer.create_client(address)
    if error != OK:
        printerr("Failed to create client: ", error)
        return false

    multiplayer.multiplayer_peer = peer
    return true

func disconnect_from_server():
    if not multiplayer.multiplayer_peer:
        return

    connection_check_timer.stop()
    _handle_server_disconnected()

func reconnect_to_server():
    if is_reconnecting:
        return  # Already trying to reconnect

    is_reconnecting = true
    is_authenticated = false  # Reset auth state

    # Close any existing peer
    if multiplayer.has_multiplayer_peer():
        multiplayer.multiplayer_peer.close()

    var new_peer = WebSocketMultiplayerPeer.new()
    var err = new_peer.create_client(server_address)

    if err != OK:
        print("Failed to create client: ", err)
        is_reconnecting = false
        return

    # Disconnect signals
    multiplayer.connected_to_server.disconnect(_on_connected)
    multiplayer.server_disconnected.disconnect(_on_disconnected)
    multiplayer.connection_failed.disconnect(_on_connection_failed)

    # Assign the new peer and connect signals
    multiplayer.multiplayer_peer = new_peer
    multiplayer.connected_to_server.connect(_on_connected)
    multiplayer.server_disconnected.connect(_on_disconnected)
    multiplayer.connection_failed.connect(_on_connection_failed)

    print("Attempting to reconnect to ", server_address)

# ─────────────────────────────────────────────────────────────────
# MULTIPLAYER CALLBACKS
# ─────────────────────────────────────────────────────────────────

func _on_connected():
    print("_on_connected")
    is_reconnecting = false
    _authenticate_user()

func _authenticate_user():
    print("_authenticate_user")
    authenticate_user(my_user_id, my_token)

func _on_disconnected():
    _handle_server_disconnected()

func _handle_server_disconnected():
    is_authenticated = false
    is_reconnecting = false
    is_player_connected = false
    is_host = false
    # current_room_id = ""
    current_players.clear()
    multiplayer.multiplayer_peer.close()
    multiplayer.multiplayer_peer = null
    disconnected_from_server.emit()

func _on_connection_failed():
    print("Connection failed - check server address")
    is_player_connected = false

func _on_connection_check_timeout():
    if not is_connected_to_server():
        print("⚠️ Connection lost! Detected by timer.")
        reconnect_to_server()

# ─────────────────────────────────────────────────────────────────
# CLIENT-SIDE METHODS
# These send RPC calls to the server
# ─────────────────────────────────────────────────────────────────

func authenticate_user(claimed_user_id: String, session_token: String):
    rpc_id(1, "rpc_authenticate_user", claimed_user_id, session_token)

func create_room(room_id: String, max_players: int = Constants.MAX_PLAYERS) -> void:
    if not multiplayer.multiplayer_peer:
        printerr("Not connected to server")
        return

    send_to_server("rpc_create_room", [room_id, max_players])

func join_room(room_id: String):
    if not multiplayer.multiplayer_peer:
        printerr("Not connected to server")
        return

    send_to_server("rpc_join_room", [room_id])

func leave_room():
    if not multiplayer.multiplayer_peer or current_room_id.is_empty():
        return

    send_to_server("rpc_leave_room", [])
    current_room_id = ""
    is_host = false

func request_return_lobby():
    if is_host:
        send_to_server("rpc_go_to_lobby", [])

func request_game_start():
    if is_host:
        send_to_server("rpc_start_game", [])

func request_game_finish():
    if is_host:
        send_to_server("rpc_finish_game", [])

func send_chat_message(msg: String):
    print(msg)
    send_to_server("rpc_send_chat_message", [msg])

# ─────────────────────────────────────────────────────────────────
# RPC STUBS - These must exist on client, even if empty
# Server calls these back to the client
# ─────────────────────────────────────────────────────────────────

@rpc("any_peer", "call_local", "reliable")
func rpc_authenticate_user(claimed_user_id: String, session_token: String):
    print("rpc_authenticate_user %s %s" % [claimed_user_id, session_token])
    if not multiplayer.is_server():
        return

    get_node(SERVER_NODE).authenticate_user(claimed_user_id, session_token)

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

@rpc("authority", "call_remote", "reliable")
func receive_auth_success():
    print("Authentication successful. Sending queued messages...")
    is_authenticated = true
    is_player_connected = true
    local_player_id = multiplayer.get_unique_id()
    connection_check_timer.start()
    user_authenticated.emit()

    # Auto join room
    if not current_room_id.is_empty():
        join_room(current_room_id)

@rpc("authority", "call_remote", "reliable")
func receive_auth_failed(reason: String):
    print("Authentication failed: %s" % reason)
    user_authentication_failed.emit(reason)

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
    _flush_client_queue()

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

# ─────────────────────────────────────────────────────────────────
# HELPER METHODS
# ─────────────────────────────────────────────────────────────────

func is_connected_to_server() -> bool:
    # Check if peer exists AND if connection status is CONNECTED
    return (
        multiplayer.multiplayer_peer != null
        and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
    )

func send_to_server(method: String, args: Array):
    if is_authenticated and multiplayer.peer_connected:
        callv("rpc_id", [1, method] + args)
        return

    print("Not connected. Attempting to reconnect before sending: ", method)
    request_queue.append({ "method": method, "args": args })
    reconnect_to_server()
    return

func _flush_client_queue():
    while request_queue.size() > 0:
        var req = request_queue.pop_front()

        var peer_id = 1
        var method_name = req["method"]
        var method_args = req["args"]

        var full_args = [peer_id, method_name]
        full_args.append_array(method_args)

        callv("rpc_id", full_args)


func debug_simulate_disconnect():
    print("🔌 Simulating network disconnect...")
    if multiplayer.multiplayer_peer:
        multiplayer.multiplayer_peer.close()
