extends Node

func _ready():
    if OS.has_feature("dedicated_server") or Arguments.get_cli_flag("server"):
        get_tree().change_scene_to_file("res://scenes/server.tscn")
    else:
        get_tree().change_scene_to_file("res://scenes/lobby.tscn")
