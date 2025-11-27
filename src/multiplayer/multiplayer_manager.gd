extends Node

signal message_received(text_content)

const DEFAULT_SERVER_URL = "ws://127.0.0.1:8910" # For Web, use wss:// on HTTPS hosts
const DEFAULT_PORT = 8910
const MESSAGE_TEMPLATE = "\n%s [b]<%s>[/b]  %s"

var peer = WebSocketMultiplayerPeer.new()

# MAPPING: Key = Player ID (int), Value = Room Name (String)
var player_rooms = {}
var server_url : String = DEFAULT_SERVER_URL
var room_id : String

func host_game():
    var parsed := Utils.get_ip_and_port(server_url)
    var port := DEFAULT_PORT
    if parsed.has("port") and parsed["port"] > 0:
        port = parsed["port"]
    var error = peer.create_server(port)
    if error != OK:
        return error

    multiplayer.multiplayer_peer = peer
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)

    var message = "Server started. Waiting for connections..."
    print(message)
    message_received.emit(message)
    return OK

func join_game():
    # WebSockets require a URL scheme (ws:// for local/http, wss:// for secure/https)
    # If running locally, use "ws://127.0.0.1:8910" (or wss:// if your host requires it)

    var error = peer.create_client(server_url)
    if error != OK:
        return error

    multiplayer.multiplayer_peer = peer
    message_received.emit("Connecting to " + server_url + "...")

# --- ROOM LOGIC ---

func join_specific_room(room_name: String):
    print("join_specific_room ", room_name)
    request_join_room.rpc_id(1, room_name)

@rpc("any_peer", "call_remote")
func request_join_room(room_name: String):
    print("request_join_room ", room_name)
    var sender_id = multiplayer.get_remote_sender_id()

    player_rooms[sender_id] = room_name
    broadcast_message.rpc_id(sender_id, "Joined Room: %s" % room_name)

    print("Player %s joined room %s" % [sender_id, room_name])

# --- CHAT LOGIC ---

func send_chat_message(msg: String):
    print(msg)
    request_send_message.rpc_id(1, msg)

@rpc("any_peer", "call_remote")
func request_send_message(message: String):
    var sender_id = multiplayer.get_remote_sender_id()

    if not player_rooms.has(sender_id):
        return

    var current_room = player_rooms[sender_id]
    var final_msg = MESSAGE_TEMPLATE % [Utils.get_current_time(), sender_id, message]

    for player_id in player_rooms:
        if player_rooms[player_id] == current_room:
            broadcast_message.rpc_id(player_id, final_msg)

@rpc("authority", "call_local")
func broadcast_message(message: String):
    message_received.emit(message)

func _on_peer_disconnected(id):
    if player_rooms.has(id):
        player_rooms.erase(id)
