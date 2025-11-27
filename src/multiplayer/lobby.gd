extends Node

@export var testing_label : Label

func _ready() -> void:
    var args = Array(OS.get_cmdline_args())
    # Spin up a server instance
    # TODO: listen to arguments to have multiple servers on the same machine
    if args.has("--server"):
        testing_label.text += "\nHosting game"
        MultiplayerManager.host_game()
    elif args.has("--roomid"):
        var room_id = Utils.get_cmdline_arg_value("--roomid")
        testing_label.text += "\n" + room_id
        MultiplayerManager.room_id = room_id
        if args.has("--url"):
            testing_label.text += "\n" + Utils.get_websocket_server()
            print(Utils.get_websocket_server())
            print(room_id)
            pass
        else:
            pass
            # MultiplayerManager.join_specific_room(room_id)
            call_deferred("_start_client")

func _start_client():
    MultiplayerManager.join_game()
    get_tree().change_scene_to_file("res://scenes/client.tscn")
