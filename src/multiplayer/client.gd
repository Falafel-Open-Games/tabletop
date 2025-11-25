extends Node

@export var button_send : Button
@export var chat_messages : RichTextLabel
@export var line_message : LineEdit

var player_id = "Player A"
const message_template = "%s [b]<%s>[/b]  %s"

func _ready() -> void:
    chat_messages.clear()
    chat_messages.text = ""
    button_send.pressed.connect(_on_button_send)

func _on_button_send():
    var message = message_template % [Utils.get_current_time(), player_id, line_message.text]
    line_message.clear()
    if chat_messages.text != "":
        chat_messages.text = chat_messages.text + "\n"
    chat_messages.text = chat_messages.text + message
