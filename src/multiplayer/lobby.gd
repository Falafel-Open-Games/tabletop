extends Node

@export var testing_label : Label

func _ready() -> void:
    var args = Array(OS.get_cmdline_args())
    if args.has("--server"):
        # Spin up a server instance
        testing_label.text += "\nHosting game"
        _configure_server()
        MultiplayerManager.host_game()
    else:
        # Join as a client
        var room_id = Utils.get_cmdline_arg_value("--roomid")

        if room_id == "":
            _throw_error_missing_room_id()
        else:
            testing_label.text += "\n" + room_id
            MultiplayerManager.room_id = room_id
            _configure_server()
            call_deferred("_start_client")

func _start_client():
    MultiplayerManager.join_game()
    get_tree().change_scene_to_file("res://scenes/client.tscn")

func _configure_server():
    var server_url = Utils.get_websocket_server()

    if server_url == "":
        # Use default server config
        return

    var server_ip_port_dict = Utils.get_ip_and_port(server_url)
    MultiplayerManager.server_ip = server_ip_port_dict["ip"]
    MultiplayerManager.port = server_ip_port_dict["port"]

    testing_label.text += "\n" + Utils.get_websocket_server()

func _throw_error_missing_room_id():
    printerr("Error: missing required argument --roomid")
    printerr("Usage: godot scenes/lobby.tscn --roomid <room_id>")
    get_tree().quit(1)  # non‑zero = error
