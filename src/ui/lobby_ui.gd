extends Control

@export var connect_button : Button
@export var create_button : Button
@export var join_button : Button
@export var room_code_input: LineEdit
@export var player_list : ItemList
@export var start_button : Button
@export var chat_button : Button
@export var status_label : Label
@export var room_id_label : Label
@export var user_id_label : Label
@export var user_id_input : LineEdit

var room_id: String

func _ready():
    # Connect network signals
    NetworkManager.user_authenticated.connect(_on_user_authenticated)
    NetworkManager.user_authentication_failed.connect(_on_user_authentication_failed)
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
    NetworkManager.game_state_changed.connect(_on_game_state_changed)
    NetworkManager.game_started_failed.connect(_on_game_start_failed)

    # Connect UI signals
    connect_button.pressed.connect(_on_connect_pressed)
    create_button.pressed.connect(_on_create_pressed)
    join_button.pressed.connect(_on_join_pressed)
    start_button.pressed.connect(_on_start_pressed)
    chat_button.pressed.connect(_on_chat_pressed)

    _reset_ui_state()

    # Set room id from args
    var room_id_arg = Arguments.get_argument(&"roomid")

    if room_id_arg.is_ok():
        room_id = room_id_arg.value()
        room_code_input.text = room_id

    # Set view based on current state
    if NetworkManager.is_player_connected:
        if NetworkManager.current_room_id.is_empty():
            _set_view_create_or_join_room()
        else:
            _set_view_lobby()
    else:
        _set_view_connect()

# ─────────────────────────────────────────────────────────────────
# UI callbasks
# ─────────────────────────────────────────────────────────────────

func _on_connect_pressed():
    if NetworkManager.is_player_connected:
        status_label.text = "Disconnecting..."
        NetworkManager.disconnect_from_server()
    else:
        status_label.text = "Connecting..."
        var server_url_arg = Arguments.get_argument(&"url")
        var server_url: String = Constants.DEFAULT_SERVER_URL

        if server_url_arg.is_ok():
            server_url = server_url_arg.value()

        if user_id_input.text.is_empty():
            status_label.text = "Provide a user_id to connect"
            return

        NetworkManager.my_user_id = user_id_input.text
        NetworkManager.connect_to_server(server_url)

func _on_create_pressed():
    _reset_ui_state()

    if not NetworkManager.is_player_connected:
        status_label.text = "Connect to server first!"
        return

    status_label.text = "Creating room..."

    room_id = room_code_input.text
    NetworkManager.create_room(room_id)

func _on_join_pressed():
    _reset_ui_state()

    if not NetworkManager.is_player_connected:
        status_label.text = "Connect to server first!"
        return

    if NetworkManager.current_room_id.is_empty():
        room_id = room_code_input.text

        if room_id == "":
            return

        status_label.text = "Joining room " + room_id + "..."
        NetworkManager.join_room(room_id)
    else:
        NetworkManager.leave_room()

func _on_start_pressed():
    match NetworkManager.current_game_state:
        Constants.GameState.WAITING:
            NetworkManager.request_game_start()
        Constants.GameState.PLAYING:
            NetworkManager.request_game_finish()
        Constants.GameState.FINISHED:
            NetworkManager.request_return_lobby()

func _on_chat_pressed():
    get_tree().change_scene_to_file("res://scenes/client.tscn")

# ─────────────────────────────────────────────────────────────────
# UI screens
# ─────────────────────────────────────────────────────────────────

func _set_view_connect():
    _reset_ui_state()
    status_label.text = "Enter a valid user_id to connect"
    connect_button.visible = true
    connect_button.text = "CONNECT"
    user_id_input.visible = true

func _set_view_create_or_join_room():
    _reset_ui_state()
    status_label.text = "Connected to server"
    connect_button.visible = true
    connect_button.text = "DISCONNECT"
    create_button.visible = true
    join_button.visible = true
    room_code_input.visible = true
    user_id_label.visible = true
    user_id_label.text = "User: %s" % NetworkManager.my_user_id

func _set_view_lobby():
    _reset_ui_state()
    connect_button.visible = true
    connect_button.text = "DISCONNECT"
    chat_button.visible = true
    player_list.visible = true
    start_button.visible = NetworkManager.is_host
    room_id_label.visible = true
    room_id_label.text = "Room: %s" % room_id
    user_id_label.visible = true
    user_id_label.text = "User: %s" % NetworkManager.my_user_id
    join_button.text = "LEAVE ROOM"
    player_list.clear()
    _update_players_list_obj()

# ─────────────────────────────────────────────────────────────────
# NETWORK MANAGER callbasks
# ─────────────────────────────────────────────────────────────────

func _on_user_authenticated():
    _set_view_create_or_join_room()

    # Auto join room
    if room_id != "":
        _on_join_pressed()

func _on_user_authentication_failed(reason: String):
    _set_view_connect()
    status_label.text = "Auth failed: %s" % reason

func _on_disconnected_from_server():
    status_label.text = "Disconnected from server"
    _reset_ui_state()
    connect_button.text = "CONNECT"
    user_id_input.visible = true

func _on_room_created(new_room_id: String):
    _set_view_lobby()
    status_label.text = "Room created and joined! Code: " + new_room_id
    player_list.add_item("You (Host) %s" % NetworkManager.multiplayer.get_unique_id())

func _on_room_joined(room_data: Dictionary):
    _set_view_lobby()
    status_label.text = "Joined room: " + room_data.room_id
    _update_players_list_ids(room_data.player_ids)

func _on_room_left():
    _set_view_create_or_join_room()
    status_label.text = "Left room"

func _on_room_creation_failed(reason: String):
    _set_view_create_or_join_room()
    status_label.text = "Room creation failed: " + reason

func _on_join_failed(reason: String):
    _set_view_create_or_join_room()
    status_label.text = "Join failed: " + reason

func _on_player_joined(player_id: int, _player_info: Dictionary):
    var prefix = "Player_" + str(player_id)
    if player_id == multiplayer.get_unique_id():
        prefix = "You"
    player_list.add_item(prefix)

func _on_player_left(player_id: int):
    print("_on_player_left %s" % player_id)

func _on_host_changed(new_host_id: int):
    if new_host_id == multiplayer.get_unique_id():
        status_label.text = "You are now the host"
        start_button.visible = true
    _update_players_list_obj()

func _on_room_player_list_updated(_room_id: String, players: Array) -> void:
    print("_on_room_player_list_updated %s" % players.size())
    _update_players_list_obj(players)

func _on_game_state_changed(game_state: Constants.GameState):
    var game_states = Constants.GameState.keys()
    status_label.text = "Match status changed to %s" % game_states[game_state]

    match game_state:
        Constants.GameState.WAITING:
            start_button.text = "START MATCH"
        Constants.GameState.PLAYING:
            start_button.text = "END MATCH"
        Constants.GameState.FINISHED:
            start_button.text = "WAIT FOR PLAYERS"

func _on_game_start_failed(reason: String):
    status_label.text = "Game failed to start: %s" % reason

# ─────────────────────────────────────────────────────────────────
# Helper methods
# ─────────────────────────────────────────────────────────────────

func _reset_ui_state():
    create_button.visible = false
    join_button.visible = false
    room_code_input.visible = false
    user_id_input.visible = false
    chat_button.visible = false
    start_button.visible = false
    player_list.visible = false
    room_id_label.visible = false
    user_id_label.visible = false
    status_label.text = ""

func _update_players_list_ids(player_ids: Array[int] = []):
    player_list.clear()

    for player_id in player_ids:
        var prefix = "You" if player_id == multiplayer.get_unique_id() else "Player"
        if player_id == NetworkManager.room_host_id:
            prefix += " (Host)"
        player_list.add_item(prefix + "_" + str(player_id))

func _update_players_list_obj(players: Array = NetworkManager.current_players):
    var _player_ids: Array[int]
    for player in players:
        print(player)
        _player_ids.append(player["peer_id"])

    _update_players_list_ids(_player_ids)

func _throw_error_room_id(result: StringResult):
    var error_code = result.error()
    match error_code:
        StringResult.StringResultError.MISSING:
            printerr("Error: missing required argument --roomid")
            printerr("Usage: godot scenes/lobby.tscn --roomid <room_id>")
        _:
            printerr("Room ID Argument Error: %s" % error_code)
    get_tree().quit(1)  # non‑zero = error
