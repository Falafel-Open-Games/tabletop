extends Node

@export var button_send : Button
@export var chat_messages : RichTextLabel
@export var line_message : LineEdit

func _ready() -> void:
    chat_messages.clear()
    chat_messages.text = ""
    button_send.pressed.connect(_on_submit)
    multiplayer.connected_to_server.connect(_on_connected_to_server)
    MultiplayerManager.message_received.connect(_on_message_received)

func _input(event: InputEvent) -> void:
    if Input.is_action_pressed("ui_text_submit") and chat_messages.text != "":
        _send_msg()

func _on_submit():
    _send_msg()

func _send_msg():
    if line_message.text == "":
        return

    MultiplayerManager.send_chat_message(line_message.text.strip_edges())
    line_message.clear()

func _on_message_received(text_content):
    chat_messages.text += text_content

func _on_connected_to_server():
    MultiplayerManager.join_specific_room(MultiplayerManager.room_id)
