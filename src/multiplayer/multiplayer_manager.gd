extends Node

# Signal to tell the UI (or any other node) that a message arrived
signal message_received(text_content)

const PORT = 7000
const DEFAULT_SERVER_IP = "127.0.0.1"
const message_template = "\n%s [b]<%s>[/b]  %s"

var peer = ENetMultiplayerPeer.new()

func host_game():
	var error = peer.create_server(PORT)
	if error != OK:
		return error

	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = peer

	# Optional: Let the host know the server started locally
	var message = "Server started. Waiting for connections..."
	message_received.emit(message)
	print(message)
	return OK

func join_game():
	peer.create_client(DEFAULT_SERVER_IP, PORT)

	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = peer

	message_received.emit("Connecting to server...")

# --- RPC FUNCTIONS ---

# Call this function from your UI to send a chat
func send_chat_message(msg: String):
	# RPC to Server (ID 1)
	request_send_message.rpc_id(1, msg)

# 1. CLIENT -> SERVER
@rpc("any_peer", "call_remote")
func request_send_message(message: String):
	var sender_id = multiplayer.get_remote_sender_id()
	var final_msg = message_template % [Utils.get_current_time(), sender_id, message]

	# 2. SERVER -> ALL
	broadcast_message.rpc(final_msg)

# 3. SERVER -> ALL (Broadcast)
@rpc("authority", "call_local")
func broadcast_message(message: String):
	# Emit signal so the UI knows to update
	message_received.emit(message)
