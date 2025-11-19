class_name CurrentPlayerInput extends HBoxContainer

@export var table: Table
@export var index_select: SpinBox

func _ready() -> void:
    table.seats_count_changed.connect(_on_total_seats_change)
    index_select.value_changed.connect(_on_value_change)
    _on_total_seats_change(table.seats_count)
    
func _on_total_seats_change(new_total: int):
    index_select.min_value = 0
    index_select.max_value = new_total - 1
    index_select.value = table.current_player
    
func _on_value_change(value: float):
    table.current_player = int(value)
