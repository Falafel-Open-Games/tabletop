extends Control

@onready var connect_button = $VBoxContainer/ConnectButton
@onready var create_button = $VBoxContainer/CreateButton
@onready var join_button = $VBoxContainer/JoinButton
@onready var room_code_input = $VBoxContainer/RoomCodeInput
@onready var player_list = $VBoxContainer/PlayerList
@onready var start_button = $VBoxContainer/StartButton
@onready var status_label = $StatusLabel

var is_connected: bool = false
var is_in_room: bool = false
var room_id: String

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

    var room_id_arg = Arguments.get_argument(&"roomid")

    if not room_id_arg.is_ok():
        _throw_error_room_id(room_id_arg)
        return

    room_id = room_id_arg.value()
    room_code_input.text = room_id

    # Initially disable room buttons until connected
    _update_ui_state()

func _on_connect_pressed():
    if is_connected:
        status_label.text = "Disconnecting..."
        NetworkManager.multiplayer.multiplayer_peer = null
        is_connected = false
        _update_ui_state()
        return

    connect_button.disabled = true
    NetworkManager.connect_to_server()

func _on_connected_to_server():
    print("Connected to server!")
    is_connected = true
    status_label.text = "Connected to server"
    _update_ui_state()

func _on_disconnected_from_server():
    print("Disconnected from server")
    is_connected = false
    status_label.text = "Disconnected from server"
    _update_ui_state()

func _on_create_pressed():
    if not is_connected:
        status_label.text = "Connect to server first!"
        return

    status_label.text = "Creating room..."

    NetworkManager.create_room(room_id)

func _on_join_pressed():
    if not is_connected:
        status_label.text = "Connect to server first!"
        return

    var room_code = room_code_input.text.to_upper()

    status_label.text = "Joining room " + room_code + "..."
    NetworkManager.join_room(room_id)

func _on_room_created(room_id: String):
    status_label.text = "Room created! Code: " + room_id
    _update_start_button()
    _clear_player_list()
    player_list.add_item("You (Host)")

func _on_room_joined(room_data: Dictionary):
    status_label.text = "Joined room: " + room_data.room_id
    _update_start_button()
    _clear_player_list()

    for player_id in room_data.player_ids:
        var is_host = (player_id == room_data.host_id)
        var prefix = "You" if player_id == NetworkManager.multiplayer.get_unique_id() else "Player"
        if is_host:
            prefix += " (Host)"
        player_list.add_item(prefix + "_" + str(player_id))

func _on_room_creation_failed(reason: String):
    status_label.text = "Room creation failed: " + reason
    _update_ui_state()

func _on_join_failed(reason: String):
    status_label.text = "Join failed: " + reason
    is_in_room = false
    _update_ui_state()

func _on_player_joined(player_id: int, _player_info: Dictionary):
    var prefix = "Player_" + str(player_id)
    if player_id == NetworkManager.multiplayer.get_unique_id():
        prefix = "You"
    player_list.add_item(prefix)
    is_in_room = true
    _update_ui_state()
    _update_start_button()

func _on_player_left(player_id: int):
    _clear_player_list()
    _update_start_button()

func _on_host_changed(new_host_id: int):
    if new_host_id == NetworkManager.multiplayer.get_unique_id():
        status_label.text = "You are now the host"
    _update_start_button()

func _update_ui_state():
    var connected = is_connected
    create_button.disabled = not connected
    join_button.disabled = not connected or is_in_room
    # room_code_input.disabled = not connected
    connect_button.text = "Disconnect" if connected else "Connect"
    connect_button.disabled = false

func _update_start_button():
    start_button.disabled = not is_connected

func _clear_player_list():
    player_list.clear()

func _on_start_pressed():
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
