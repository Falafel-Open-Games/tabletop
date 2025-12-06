extends Control

@onready var connect_button = $VBoxContainer/ConnectButton
@onready var create_button = $VBoxContainer/CreateButton
@onready var join_button = $VBoxContainer/JoinButton
@onready var room_code_input = $VBoxContainer/RoomCodeInput
@onready var player_list = $VBoxContainer/PlayerList
@onready var start_button = $VBoxContainer/StartButton
@onready var chat_button = $VBoxContainer/ChatButton
@onready var status_label = $StatusLabel

var is_in_room: bool = false
var room_id: String

# Rules
# When the scene loads, If has room id => connect and join room
# If room id is empty => show connect button
# Once connected, show create and join buttons
# Once joined, show chat button, players list and match status
# If player is host, show match state button

func _ready():
    # Connect network signals
    NetworkManager.connected_to_server.connect(_on_connected_to_server)
    NetworkManager.disconnected_from_server.connect(_on_disconnected_from_server)
    NetworkManager.room_created.connect(_on_room_created)
    NetworkManager.room_joined.connect(_on_room_joined)
    NetworkManager.room_creation_failed.connect(_on_room_creation_failed)
    NetworkManager.join_failed.connect(_on_join_failed)
    NetworkManager.player_joined.connect(_on_player_joined)
    NetworkManager.player_left.connect(_on_player_left)
    NetworkManager.host_changed.connect(_on_host_changed)

    # Connect UI signals
    connect_button.pressed.connect(_on_connect_pressed)
    create_button.pressed.connect(_on_create_pressed)
    join_button.pressed.connect(_on_join_pressed)
    start_button.pressed.connect(_on_start_pressed)
    chat_button.pressed.connect(_on_chat_pressed)

    var room_id_arg = Arguments.get_argument(&"roomid")

    # Create or join room
    if room_id_arg.is_ok():
        if NetworkManager.is_connected:
            _reset_ui_state()
            chat_button.visible = true
            player_list.visible = true
        else:
            room_id = room_id_arg.value()
            room_code_input.text = room_id
            _on_connect_pressed()
    else:
        _reset_ui_state()

func _on_connect_pressed():
    _reset_ui_state()

    if NetworkManager.is_connected:
        status_label.text = "Disconnecting..."
        NetworkManager.disconnect_from_server()
    else:
        NetworkManager.connect_to_server()

func _on_connected_to_server():
    print("Connected to server!")
    status_label.text = "Connected to server"
    connect_button.text = "DISCONNECT"

    if room_id == "":
        _reset_ui_state()
        create_button.visible = true
        room_code_input.visible = true
        join_button.visible = true
    else:
        _on_join_pressed()

func _on_disconnected_from_server():
    print("Disconnected from server")
    status_label.text = "Disconnected from server"
    connect_button.text = "CONNECT"
    _reset_ui_state()

func _on_create_pressed():
    _reset_ui_state()
    if not NetworkManager.is_connected:
        status_label.text = "Connect to server first!"
        return

    status_label.text = "Creating room..."

    NetworkManager.create_room(room_id)

func _on_join_pressed():
    _reset_ui_state()
    if not NetworkManager.is_connected:
        status_label.text = "Connect to server first!"
        return

    var room_code = room_code_input.text.to_upper()

    if room_code == "":
        return

    status_label.text = "Joining room " + room_code + "..."
    NetworkManager.join_room(room_id)

func _on_room_created(new_room_id: String):
    _reset_ui_state()
    chat_button.visible = true
    player_list.visible = true
    status_label.text = "Room created! Code: " + new_room_id
    _clear_player_list()
    player_list.add_item("You (Host)")

func _on_room_joined(room_data: Dictionary):
    _reset_ui_state()
    chat_button.visible = true
    player_list.visible = true
    status_label.text = "Joined room: " + room_data.room_id
    _clear_player_list()

    for player_id in room_data.player_ids:
        var is_host = (player_id == room_data.host_id)
        var prefix = "You" if player_id == NetworkManager.multiplayer.get_unique_id() else "Player"
        if is_host:
            prefix += " (Host)"
        player_list.add_item(prefix + "_" + str(player_id))

func _on_room_creation_failed(reason: String):
    status_label.text = "Room creation failed: " + reason
    _reset_ui_state()
    create_button.visible = true
    room_code_input.visible = true
    join_button.visible = true

func _on_join_failed(reason: String):
    status_label.text = "Join failed: " + reason
    is_in_room = false
    _reset_ui_state()
    create_button.visible = true
    room_code_input.visible = true
    join_button.visible = true

func _on_player_joined(player_id: int, _player_info: Dictionary):
    var prefix = "Player_" + str(player_id)
    if player_id == NetworkManager.multiplayer.get_unique_id():
        prefix = "You"
    player_list.add_item(prefix)
    is_in_room = true

func _on_player_left(player_id: int):
    _clear_player_list()

func _on_host_changed(new_host_id: int):
    if new_host_id == NetworkManager.multiplayer.get_unique_id():
        status_label.text = "You are now the host"

# func _update_ui_state():
    # var connected = is_player_connected
    # create_button.disabled = not connected
    # join_button.disabled = not connected or is_in_room
    # room_code_input.disabled = not connected
    # connect_button.text = "Disconnect" if connected else "Connect"
    # connect_button.disabled = false

func _reset_ui_state():
    create_button.visible = false
    room_code_input.visible = false
    join_button.visible = false
    chat_button.visible = false
    start_button.visible = false
    player_list.visible = false

func _clear_player_list():
    player_list.clear()

func _on_start_pressed():
    pass
    # Change match to Running
    # Change button label
    # Change match status

func _on_chat_pressed():
    get_tree().change_scene_to_file("res://scenes/client.tscn")

func _throw_error_room_id(result: StringResult):
    var error_code = result.error()
    match error_code:
        StringResult.StringResultError.MISSING:
            printerr("Error: missing required argument --roomid")
            printerr("Usage: godot scenes/lobby.tscn --roomid <room_id>")
        _:
            printerr("Room ID Argument Error: %s" % error_code)
    get_tree().quit(1)  # non‑zero = error
