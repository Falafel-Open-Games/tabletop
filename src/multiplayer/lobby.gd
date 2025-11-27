extends Node

func _ready() -> void:
    var args = Array(OS.get_cmdline_args())
    if args.has("--server"):
        MultiplayerManager.host_game()
    elif args.has("--ip") and args.has("--port") and args.has("--roomid"):
        # var room_name = args.(--"roomid")
        NetworkManager.join_specific_room(room_name)
        get_tree().change_scene_to_file("res://scenes/client.tscn")
