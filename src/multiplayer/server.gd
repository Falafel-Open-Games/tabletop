extends Node

const MESSAGE_TEMPLATE = "\n%s [b]<%s>[/b]  %s"

var server_url : String = Constants.DEFAULT_SERVER_URL

var rooms: Dictionary = {}  # room_id -> RoomInfo

var network_manager_node: Node

# Maps persistent User IDs to temporary Peer IDs: { "User_UUID_A": ["id": "User_UUID_A", "peer_id": 105, "room_id: "1234"] }
var active_sessions: Dictionary = {}

# Buffers messages for offline users: { "User_UUID_A": [ { "method": "...", "args": [...] } ] }
var pending_messages: Dictionary = {}

func _ready():
    if not (OS.has_feature("dedicated_server") or Arguments.get_argument("server")):
        printerr("Server must be run with --headless or as dedicated server export!")
        get_tree().quit()

    var server_peer = WebSocketMultiplayerPeer.new()
    var parsed := Utils.get_ip_and_port(server_url)
    var port := Constants.DEFAULT_PORT
    if parsed.has("port") and parsed["port"] > 0:
        port = parsed["port"]

    # Bind to port and start listening
    var error = server_peer.create_server(port)
    if error != OK:
        printerr("Failed to start server on port ", port, ": ", error)
        get_tree().quit()

    multiplayer.multiplayer_peer = server_peer
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    print("✅ Server listening on port ", port)
    print("✅ Multiplayer peer set: ", multiplayer.multiplayer_peer)

    network_manager_node = get_node("/root/NetworkManager")

# ─────────────────────────────────────────────────────────────────
# MULTIPLAYER CALLBACKS
# ─────────────────────────────────────────────────────────────────

func _on_peer_connected(peer_id: int):
    print("Player connected: ", peer_id)

func _on_peer_disconnected(peer_id: int):
    print("Player disconnected: ", peer_id)

    var player = find_session_by_peer_id(peer_id)
    var room_id = player["room_id"]
    if room_id != "":
        _remove_player_from_room(peer_id, room_id)

    # Reverse lookup to remove user from active_sessions
    for user_id in active_sessions:
        if active_sessions[user_id]["peer_id"] == peer_id:
            active_sessions.erase(user_id)
            break

# ─────────────────────────────────────────────────────────────────
# CLIENT-SIDE METHODS
# These RPCs are sent from client
# ─────────────────────────────────────────────────────────────────

@rpc("any_peer", "call_remote", "reliable")
func authenticate_user(claimed_user_id: String, token: String):
    print("authenticate_user %s" % claimed_user_id)
    var sender_id = multiplayer.get_remote_sender_id()

    # 1. Validate Token (Pseudo-code)
    if not _validate_token(claimed_user_id, token):
        multiplayer.multiplayer_peer.disconnect_peer(sender_id)
        return

    # 2. Handle Duplicate Logins (Kick old session if exists)
    if active_sessions.has(claimed_user_id):
        var old_peer = active_sessions[claimed_user_id]["peer_id"]
        if old_peer != sender_id and old_peer in multiplayer.get_peers():
            multiplayer.multiplayer_peer.disconnect_peer(old_peer)

    # 3. Register Session
    active_sessions[claimed_user_id] = {}
    active_sessions[claimed_user_id]["id"] = claimed_user_id
    active_sessions[claimed_user_id]["peer_id"] = sender_id
    active_sessions[claimed_user_id]["room_id"] = ""
    print("User authenticated: ", claimed_user_id, " on Peer ", sender_id)

    # 4. Confirm Success to Client (Triggers Client-side flush)
    network_manager_node.rpc_id(sender_id, "receive_auth_success")

    # 5. Flush Server-side Buffer (Send missed server msgs to Client)
    _flush_server_buffer(claimed_user_id, sender_id)

@rpc("any_peer", "call_local")
func rpc_create_room(room_id: String, max_players: int = Constants.MAX_PLAYERS) -> void:
    print("✅ SERVER: rpc_create_room CALLED!")
    print("   room_id: ", room_id)
    print("   max_players: ", max_players)

    var peer_id = multiplayer.get_remote_sender_id()

    # Prevent creating multiple rooms
    var player = find_session_by_peer_id(peer_id)
    if player["room_id"] != "":
        network_manager_node.rpc_id(peer_id, "on_room_creation_failed", "Already in a room")
        return

    # Create room
    var room = Constants.RoomInfo.new(room_id, peer_id, max_players)
    rooms[room_id] = room
    active_sessions[player["id"]]["room_id"] = room_id

    # Notify creator
    network_manager_node.rpc_id(peer_id, "on_room_created", room_id)
    _notify_room_player_list(room_id)

@rpc("any_peer", "call_local")
func rpc_join_room(room_id: String) -> bool:
    var peer_id = multiplayer.get_remote_sender_id()

    # Validate room exists
    if not rooms.has(room_id):
        network_manager_node.rpc_id(peer_id, "on_join_failed", "Room not found")
        return false

    var room = rooms[room_id]

    # Check if already in room
    var player = find_session_by_peer_id(peer_id)
    if player["room_id"] != "":
        network_manager_node.rpc_id(peer_id, "on_join_failed", "Already in a room")
        return false

    # Check capacity
    if room.player_ids.size() >= room.max_players:
        network_manager_node.rpc_id(peer_id, "on_join_failed", "Room is full")
        return false

    # Check game state
    if room.game_state != Constants.GameState.WAITING:
        network_manager_node.rpc_id(peer_id, "on_join_failed", "Game already started")
        return false

    # Add player to room
    room.player_ids.append(peer_id)
    active_sessions[player["id"]]["room_id"] = room_id

    print("Player ", peer_id, " joined room ", room_id)

    # Notify all players in the room
    for player_id in room.player_ids:
        network_manager_node.rpc_id(player_id, "on_player_joined", peer_id, find_session_by_peer_id(peer_id))

    # Send room state to new player
    network_manager_node.rpc_id(peer_id, "on_room_joined", room_id, _serialize_room(room))
    _notify_room_player_list(room_id)

    return true

@rpc("any_peer", "call_local")
func rpc_leave_room():
    var peer_id = multiplayer.get_remote_sender_id()

    var player = find_session_by_peer_id(peer_id)
    if player["room_id"] == "":
        return

    var room_id = player["room_id"]
    _remove_player_from_room(peer_id, room_id)
    network_manager_node.rpc_id(peer_id, "on_room_left")

@rpc("any_peer", "call_local")
func rpc_go_to_lobby() -> void:
    var peer_id = multiplayer.get_remote_sender_id()

    # Security check: Ensure the caller is actually the host of their room
    var player = find_session_by_peer_id(peer_id)
    if player["room_id"] == "":
        return

    var room_id = player["room_id"]
    var room = rooms[room_id]

    if room.host_id != peer_id:
        print("Unauthorized start attempt by peer ", peer_id)
        return

    # Check game state
    if room.game_state == Constants.GameState.WAITING:
        network_manager_node.rpc_id(peer_id, "on_game_start_failed", "Players are already in lobby")
        return

    if room.game_state == Constants.GameState.PLAYING:
        network_manager_node.rpc_id(peer_id, "on_game_start_failed", "Game already started")
        return

    # Update state
    room.game_state = Constants.GameState.WAITING

    # Broadcast to everyone in the room
    for player_id in room.player_ids:
        network_manager_node.rpc_id(player_id, "on_game_state_changed", room.game_state)


@rpc("any_peer", "call_local")
func rpc_start_game() -> void:
    var peer_id = multiplayer.get_remote_sender_id()

    var player = find_session_by_peer_id(peer_id)
    if player["room_id"] == "":
        return

    var room_id = player["room_id"]
    var room = rooms[room_id]

    if room.host_id != peer_id:
        print("Unauthorized start attempt by peer ", peer_id)
        return

    # Check game state
    if room.game_state == Constants.GameState.PLAYING:
        network_manager_node.rpc_id(peer_id, "on_game_start_failed", "Game already started")
        return

    if room.game_state == Constants.GameState.FINISHED:
        network_manager_node.rpc_id(peer_id, "on_game_start_failed", "Game already finished")
        return

    # Update state
    room.game_state = Constants.GameState.PLAYING

    # Broadcast to everyone in the room
    for player_id in room.player_ids:
        network_manager_node.rpc_id(player_id, "on_game_state_changed", room.game_state)

@rpc("any_peer", "call_local")
func rpc_finish_game() -> void:
    var peer_id = multiplayer.get_remote_sender_id()

    var player = find_session_by_peer_id(peer_id)
    if player["room_id"] == "":
        return

    var room_id = player["room_id"]
    var room = rooms[room_id]

    if room.host_id != peer_id:
        print("Unauthorized start attempt by peer ", peer_id)
        return

    # Check game state
    if room.game_state == Constants.GameState.WAITING:
        network_manager_node.rpc_id(peer_id, "on_game_start_failed", "Game hasn't started yet.")
        return

    if room.game_state == Constants.GameState.FINISHED:
        network_manager_node.rpc_id(peer_id, "on_game_start_failed", "Game already finished")
        return

    # Update state
    room.game_state = Constants.GameState.FINISHED

    # Broadcast to everyone in the room
    for player_id in room.player_ids:
        network_manager_node.rpc_id(player_id, "on_game_state_changed", room.game_state)

@rpc("any_peer", "call_local")
func rpc_send_chat_message(message: String):
    print("SERVER rpc_send_chat_message: %s" % message)

    var peer_id = multiplayer.get_remote_sender_id()

    var player = find_session_by_peer_id(peer_id)
    if player["room_id"] == "":
        return

    var room_id = player["room_id"]
    var final_msg = MESSAGE_TEMPLATE % [Utils.get_current_time(), peer_id, message]
    _broadcast_to_room(room_id, "on_broadcasted_message", final_msg)

# ─────────────────────────────────────────────────────────────────
# SERVER-SIDE METHODS
# These apply changes to the server and notify clients
# ─────────────────────────────────────────────────────────────────

func _remove_player_from_room(peer_id: int, room_id: String):
    print("_remove_player_from_room %s" % peer_id)
    var room = rooms.get(room_id)
    if room == null:
        return

    if not room.player_ids.has(peer_id):
        return

    room.player_ids.erase(peer_id)

    # Notify remaining players
    for player_id in room.player_ids:
        network_manager_node.rpc_id(player_id, "on_player_left", peer_id)

    # Destroy room if empty
    if room.player_ids.is_empty():
        _destroy_room(room_id)
    else:
        _notify_room_player_list(room_id)

        # Transfer host if host left
        if room.host_id == peer_id:
            room.host_id = room.player_ids[0]
            for player_id in room.player_ids:
                network_manager_node.rpc_id(player_id, "on_host_changed", room.host_id)

func _destroy_room(room_id: String):
    print("Destroying room: ", room_id)
    rooms.erase(room_id)

func _notify_room_player_list(room_id: String) -> void:
    var room = rooms.get(room_id)
    if room == null:
        return

    var players: Array = []
    for peer_id in room.player_ids:
        players.append(find_session_by_peer_id(peer_id))

    for peer_id in room.player_ids:
        network_manager_node.rpc_id(peer_id, "on_room_player_list_updated", room_id, players)

func _broadcast_to_room(room_id: String, rpc_method: String, message: String):
    if not rooms.has(room_id):
        printerr("❌ Room not found: ", room_id)
        return

    var room = rooms[room_id]

    for player_id in room.player_ids:
        network_manager_node.rpc_id(player_id, rpc_method, message)

# ─────────────────────────────────────────────────────────────────
# HELPER METHODS
# ─────────────────────────────────────────────────────────────────

func send_safe_rpc(target_user_id: String, method: String, args: Array):
    # Check if user is online and the peer connection is valid
    if active_sessions.has(target_user_id):
        var peer_id = active_sessions[target_user_id]
        if peer_id in multiplayer.get_peers():
            rpc_id(peer_id, method, args)
            return

    # If offline, buffer it
    if not pending_messages.has(target_user_id):
        pending_messages[target_user_id] = []

    pending_messages[target_user_id].append({ "method": method, "args": args })

func _validate_token(user, token) -> bool:
    print("_validate_token %s %s" % [user, token])
    return true # Implement your real auth logic here

func _flush_server_buffer(user_id: String, peer_id: int):
    if pending_messages.has(user_id):
        for msg in pending_messages[user_id]:
            # Use call_deferred to ensure client is ready
            call_deferred("rpc_id", peer_id, msg["method"], msg["args"])
        pending_messages.erase(user_id)

func find_session_by_peer_id(target_peer_id: int) -> Dictionary:
    for user_id in active_sessions:
        var session: Dictionary = active_sessions[user_id]
        if session.get("peer_id") == target_peer_id:
            return session
    return {}

func find_user_id_by_peer_id(target_peer_id: int) -> String:
    for user_id in active_sessions:
        var session: Dictionary = active_sessions[user_id]
        if session.get("peer_id") == target_peer_id:
            return user_id
    return ""

func _serialize_room(room: Constants.RoomInfo) -> Dictionary:
    return {
        "room_id": room.room_id,
        "host_id": room.host_id,
        "player_ids": room.player_ids,
        "max_players": room.max_players,
        "game_state": room.game_state,
        "custom_properties": room.custom_properties
    }
