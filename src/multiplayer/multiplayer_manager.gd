extends Node

signal message_received(text_content)

const PORT = 8910
const message_template = "\n%s [b]<%s>[/b]  %s"
const DEFAULT_SERVER_IP = "127.0.0.1" # For Web, use "localhost" or your public IP

var peer = WebSocketMultiplayerPeer.new()

func host_game():
    var error = peer.create_server(PORT)
    if error != OK:
        return error

    multiplayer.multiplayer_peer = peer

    var message = "Server started (WebSockets). Waiting..."
    print(message)
    message_received.emit(message)
    return OK

func join_game():
    # WebSockets require a URL scheme (ws:// for local/http, wss:// for secure/https)
    # If running locally, use "ws://127.0.0.1:7000"
    var url = "ws://" + DEFAULT_SERVER_IP + ":" + str(PORT)

    var error = peer.create_client(url)
    if error != OK:
        return error

    multiplayer.multiplayer_peer = peer
    message_received.emit("Connecting to " + url + "...")

# --- RPC FUNCTIONS ---

func send_chat_message(msg: String):
    request_send_message.rpc_id(1, msg)

@rpc("any_peer", "call_remote")
func request_send_message(message: String):
    var sender_id = multiplayer.get_remote_sender_id()
    var final_msg = message_template % [Utils.get_current_time(), sender_id, message]
    broadcast_message.rpc(final_msg)

@rpc("authority", "call_local")
func broadcast_message(message: String):
    message_received.emit(message)
