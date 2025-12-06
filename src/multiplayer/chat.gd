extends Node

@export var button_send : Button
@export var button_exit : Button
@export var chat_messages : RichTextLabel
@export var line_message : LineEdit
@export var connected_players : Label

func _ready() -> void:
    chat_messages.clear()
    chat_messages.text = ""
    button_send.pressed.connect(_on_button_send)
    button_exit.pressed.connect(_on_button_exit)
    NetworkManager.message_received.connect(_on_message_received)
    NetworkManager.room_player_list_updated.connect(_on_room_player_list_updated)
    _on_room_player_list_updated(NetworkManager.current_room_id, NetworkManager.current_players)

func _input(event: InputEvent) -> void:
    if Input.is_action_pressed("ui_text_submit") and chat_messages.text != "":
        _on_button_send()

func _on_button_send():
    if line_message.text == "":
        return

    NetworkManager.send_chat_message(line_message.text.strip_edges())
    line_message.clear()

func _on_button_exit():
    get_tree().change_scene_to_file("res://scenes/lobby.tscn")

func _on_message_received(text_content):
    chat_messages.text += text_content

func _on_room_player_list_updated(_room_id: String, players: Array):
    print("_on_room_player_list_updated: %s" % players.size())
    connected_players.text = "PLAYERS:"
    for p in players:
        var entry: String = p.name if p.has("name") else "Player_%s" % p.id
        if int(p.id) == multiplayer.get_unique_id():
            entry += " (You)"
        connected_players.text += "\n%s" % entry
