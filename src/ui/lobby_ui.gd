extends Control

@onready var connect_button = $VBoxContainer/ConnectButton
@onready var create_button = $VBoxContainer/CreateButton
@onready var join_button = $VBoxContainer/JoinButton
@onready var room_code_input = $VBoxContainer/RoomCodeInput
@onready var player_list = $VBoxContainer/PlayerList
@onready var start_button = $VBoxContainer/StartButton
@onready var chat_button = $VBoxContainer/ChatButton
@onready var status_label = $StatusLabel

var room_id: String
var room_host_id: int

func _ready():
    # Connect network signals
    NetworkManager.connected_to_server.connect(_on_connected_to_server)
    NetworkManager.disconnected_from_server.connect(_on_disconnected_from_server)
    NetworkManager.room_created.connect(_on_room_created)
    NetworkManager.room_joined.connect(_on_room_joined)
    NetworkManager.room_left.connect(_on_room_left)
    NetworkManager.room_creation_failed.connect(_on_room_creation_failed)
    NetworkManager.join_failed.connect(_on_join_failed)
    NetworkManager.player_joined.connect(_on_player_joined)
    NetworkManager.player_left.connect(_on_player_left)
    NetworkManager.host_changed.connect(_on_host_changed)
    NetworkManager.room_player_list_updated.connect(_on_room_player_list_updated)

    # Connect UI signals
    connect_button.pressed.connect(_on_connect_pressed)
    create_button.pressed.connect(_on_create_pressed)
    join_button.pressed.connect(_on_join_pressed)
    start_button.pressed.connect(_on_start_pressed)
    chat_button.pressed.connect(_on_chat_pressed)

    _reset_ui_state()

    var room_id_arg = Arguments.get_argument(&"roomid")

    if room_id_arg.is_ok():
        room_id = room_id_arg.value()
        room_code_input.text = room_id

    if NetworkManager.is_player_connected:
        if NetworkManager.current_room_id.is_empty() and not room_id.is_empty():
            # Joining an existent room
            _on_join_pressed()
        else:
            # Back from chat to lobby while in a room
            chat_button.visible = true
            player_list.visible = true
            status_label.text = "Joined room: " + NetworkManager.current_room_id
            join_button.text = "LEAVE ROOM"
            connect_button.text = "DISCONNECT"
            var player_ids: Array[int]
            for player in NetworkManager.current_players:
                player_ids.append(player.id)
            _update_players_list(player_ids)

    else:
        # Connecting to server
        _on_connect_pressed()

func _on_connect_pressed():
    _reset_ui_state()

    if NetworkManager.is_player_connected:
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
    else:
        _on_join_pressed()

func _on_disconnected_from_server():
    print("Disconnected from server")
    status_label.text = "Disconnected from server"
    connect_button.text = "CONNECT"
    _reset_ui_state()

func _on_create_pressed():
    _reset_ui_state()
    if not NetworkManager.is_player_connected:
        status_label.text = "Connect to server first!"
        return

    status_label.text = "Creating room..."

    NetworkManager.create_room(room_id)

func _on_join_pressed():
    _reset_ui_state()
    if not NetworkManager.is_player_connected:
        status_label.text = "Connect to server first!"
        return

    if NetworkManager.current_room_id.is_empty():
        var room_code = room_code_input.text

        if room_code == "":
            return

        status_label.text = "Joining room " + room_code + "..."
        NetworkManager.join_room(room_id)
    else:
        NetworkManager.leave_room()


func _on_room_created(new_room_id: String):
    _reset_ui_state()
    chat_button.visible = true
    player_list.visible = true
    status_label.text = "Room created and joined! Code: " + new_room_id
    join_button.text = "LEAVE ROOM"
    player_list.clear()
    room_host_id = NetworkManager.multiplayer.get_unique_id()
    player_list.add_item("You (Host) %s" % room_host_id)

func _on_room_joined(room_data: Dictionary):
    _reset_ui_state()
    chat_button.visible = true
    player_list.visible = true
    status_label.text = "Joined room: " + room_data.room_id
    join_button.text = "LEAVE ROOM"
    room_host_id = room_data.host_id

    print("_on_room_player_list_updated %s" % room_data.player_ids.size())
    _update_players_list(room_data.player_ids)

func _on_room_left():
    _reset_ui_state()
    create_button.visible = true
    room_code_input.visible = true
    status_label.text = "Left room"
    join_button.text = "JOIN ROOM"

func _on_room_creation_failed(reason: String):
    status_label.text = "Room creation failed: " + reason
    _reset_ui_state()
    create_button.visible = true
    room_code_input.visible = true

func _on_join_failed(reason: String):
    status_label.text = "Join failed: " + reason
    _reset_ui_state()
    create_button.visible = true
    room_code_input.visible = true

func _on_player_joined(player_id: int, _player_info: Dictionary):
    var prefix = "Player_" + str(player_id)
    if player_id == NetworkManager.multiplayer.get_unique_id():
        prefix = "You"
    player_list.add_item(prefix)

func _on_player_left(player_id: int):
    print("_on_player_left %s" % player_id)

func _on_host_changed(new_host_id: int):
    room_host_id = new_host_id
    if new_host_id == NetworkManager.multiplayer.get_unique_id():
        status_label.text = "You are now the host"
    var player_ids: Array[int]
    for player in NetworkManager.current_players:
        player_ids.append(player.id)
    _update_players_list(player_ids)

func _reset_ui_state():
    create_button.visible = false
    room_code_input.visible = false
    chat_button.visible = false
    start_button.visible = false
    player_list.visible = false

func _on_room_player_list_updated(_room_id: String, players: Array) -> void:
    print("_on_room_player_list_updated %s" % players.size())
    var player_ids: Array[int]
    for player in players:
        player_ids.append(player.id)
    _update_players_list(player_ids)

func _update_players_list(player_ids: Array[int]):
    player_list.clear()
    for player_id in player_ids:
        var prefix = "You" if player_id == NetworkManager.multiplayer.get_unique_id() else "Player"
        if player_id == room_host_id:
            prefix += " (Host)"
        player_list.add_item(prefix + "_" + str(player_id))

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
