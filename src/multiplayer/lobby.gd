extends Node

@export var testing_label : Label

func _ready() -> void:
    pass
    # if Arguments.get_cli_flag(&"server"):
    #     # Spin up a server instance
    #     testing_label.text += "\nHosting game"
    #     _configure_server()
    #     MultiplayerManager.host_game()
    # else:
    #     # Join as a client
    #     var room_id_arg = Arguments.get_argument(&"roomid")

    #     if not room_id_arg.is_ok():
    #         _throw_error_room_id(room_id_arg)
    #         return

    #     var room_id = room_id_arg.value()
    #     testing_label.text += "\n" + room_id
    #     MultiplayerManager.room_id = room_id
    #     _configure_server()
    #     call_deferred("_start_client")


# func _start_client():
    # MultiplayerManager.join_game()
    # get_tree().change_scene_to_file("res://scenes/client.tscn")

# func _configure_server():
#     var server_url_arg = Arguments.get_argument(&"url")

#     if not server_url_arg.is_ok():
#         # Use default server config
#         return
#     var server_url = server_url_arg.value()
#     MultiplayerManager.server_url = server_url

#     testing_label.text += "\n" + server_url

# func _throw_error_room_id(result: StringResult):
#     var error_code = result.error()
#     match error_code:
#         StringResult.StringResultError.MISSING:
#             printerr("Error: missing required argument --roomid")
#             printerr("Usage: godot scenes/lobby.tscn --roomid <room_id>")
#         _:
#             printerr("Room ID Argument Error: %s" % error_code)
#     get_tree().quit(1)  # non‑zero = error
