extends Node

signal message_received(text_content)

const PORT = 8910
const message_template = "\n%s [b]<%s>[/b]  %s"
const DEFAULT_SERVER_IP = "127.0.0.1" # For Web, use "localhost" or your public IP

var peer = WebSocketMultiplayerPeer.new()

# MAPPING: Key = Player ID (int), Value = Room Name (String)
var player_rooms = {}
var room_id : String

func host_game():
    var error = peer.create_server(PORT)
    if error != OK:
        return error

    multiplayer.multiplayer_peer = peer

    # Listen for disconnects so we can remove players from the room list
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)

    var message = "Server started. Waiting for connections..."
    print(message)
    message_received.emit(message)
    return OK

func join_game():
    # WebSockets require a URL scheme (ws:// for local/http, wss:// for secure/https)
    # If running locally, use "ws://127.0.0.1:8910"
    var url = "ws://" + DEFAULT_SERVER_IP + ":" + str(PORT)
    var error = peer.create_client(url)
    if error != OK:
        return error

    multiplayer.multiplayer_peer = peer
    message_received.emit("Connecting to " + url + "...")

# --- ROOM LOGIC ---
func join_specific_room(room_name: String):
    print("join_specific_room ", room_name)
    request_join_room.rpc_id(1, room_name)

@rpc("any_peer", "call_remote")
func request_join_room(room_name: String):
    print("request_join_room ", room_name)
    var sender_id = multiplayer.get_remote_sender_id()

    # Store the player in the dictionary
    player_rooms[sender_id] = room_name

    # Notify the player they joined successfully
    var msg = "Joined Room: " + room_name
    # We use rpc_id to send ONLY to that specific player
    broadcast_message.rpc_id(sender_id, msg)

    print("Player %s joined room %s" % [sender_id, room_name])

# --- CHAT LOGIC ---

func send_chat_message(msg: String):
    print(msg)
    request_send_message.rpc_id(1, msg)

@rpc("any_peer", "call_remote")
func request_send_message(message: String):
    var sender_id = multiplayer.get_remote_sender_id()

    # Check if sender is actually in a room
    if not player_rooms.has(sender_id):
        return

    var current_room = player_rooms[sender_id]
    var final_msg = message_template % [Utils.get_current_time(), sender_id, message]

    for player_id in player_rooms:
        if player_rooms[player_id] == current_room:
            broadcast_message.rpc_id(player_id, final_msg)

@rpc("authority", "call_local")
func broadcast_message(message: String):
    message_received.emit(message)

# CLEANUP: If a player quits, remove them from the list
func _on_peer_disconnected(id):
    if player_rooms.has(id):
        player_rooms.erase(id)
