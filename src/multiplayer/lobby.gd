extends Control

@export var button_host : Button
@export var button_client : Button

func _ready() -> void:
    button_host.pressed.connect(_on_host)
    button_client.pressed.connect(_on_client)

func _on_host():
    MultiplayerManager.host_game()

func _on_client():
    MultiplayerManager.join_game()
    get_tree().change_scene_to_file("res://scenes/client.tscn")
