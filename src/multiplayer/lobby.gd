extends Control

@export var button_host : Button
@export var button_client : Button

func _ready() -> void:
    var args = Array(OS.get_cmdline_args())
    if args.has("--server"):
        MultiplayerManager.host_game()
    else:
        MultiplayerManager.join_game()
        get_tree().change_scene_to_file("res://scenes/client.tscn")
