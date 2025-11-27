class_name StringResult extends RefCounted

enum StringResultError {MISSING, OK}    

var _error: StringResultError
var _value: String

func _init(e: StringResultError = StringResultError.MISSING, v: String = "") -> void:
    _error = e
    _value = v

static func ok(v: String) -> StringResult:
    return StringResult.new(StringResultError.OK, v)

static func missing() -> StringResult:
    return StringResult.new(StringResultError.MISSING, "")

func error() -> StringResultError:
    return _error

func value() -> String:
    return _value

func is_ok() -> bool:
    return _error == StringResultError.OK
