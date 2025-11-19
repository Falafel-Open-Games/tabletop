class_name Table extends Node3D

@export var seats_container: Node3D
@export var seat_model: Node3D
@export var seat_material: Material
@export var selected_seat_material: Material

var _seats_count: int
var _current_player: int

## Public API
# -----------------------------------------------------------------------------
signal seats_count_changed(new_total: int)

## The number of seats in the table
@export var seats_count: int:
    get():
        return _seats_count
    set(value):
        _seats_count = value
        _clear_seats()
        _setup_seats()
        seats_count_changed.emit(value)

## The index (starting at zero) of the active seat in a truns-based game
@export var current_player: int:
    get():
        return _current_player
    set(value):
        _current_player = value
        _clear_seats()
        _setup_seats()

# -----------------------------------------------------------------------------

func _ready() -> void:
    assert(seat_model, "Missing seats container")
    assert(seat_model, "Missing seat model")

func _clear_seats():
    for c in seats_container.get_children():
        if c != seat_model:
            c.queue_free()

func _setup_seats() -> void:
    assert(_seats_count >= Constants.MIN_PLAYERS && \
            _seats_count <= Constants.MAX_PLAYERS, "Invalid number of seats")
    for s in range(_seats_count):
        var seat_rotation: float = (360.0 / _seats_count) * s
        var seat: Node3D
        if s == 0:
            seat = seat_model
        else:
            seat = seat_model.duplicate()
            seat.name = "Seat %s" % (s + 1)
            seat.rotate_y(deg_to_rad(seat_rotation))
            seats_container.add_child(seat)
        var seat_mesh: MeshInstance3D = seat.get_node("./Seat Mesh")
        assert(seat_mesh, "Error, selected seat dont have a mesh")
        seat_mesh.set_surface_override_material(0, seat_material if s != _current_player else selected_seat_material)
