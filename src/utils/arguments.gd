class_name Arguments extends RefCounted

## gets the query string search param named arg_name using javascript bridge 
## and return its value. Example: if the html export is called with
## index.html?room=1234 _get_url_argument("room") would return "1234"
static func get_url_argument(_arg_name: StringName) -> StringResult:
    # Only available on web builds via JS bridge
    if not OS.has_feature("web"):
        return StringResult.missing()
    var js_value = JavaScriptBridge.eval(
        "new URL(window.location.href).searchParams.get('%s')" % _arg_name,
        false
    )
    if js_value == null:
        return StringResult.missing()
    var v := str(js_value)
    return StringResult.missing() if v.is_empty() else StringResult.ok(v)

## get argument passed via CLI
static func get_cli_argument(_arg_name: StringName) -> StringResult:
    var args := OS.get_cmdline_args()
    var prefix := "--%s" % _arg_name
    for i in args.size():
        var a := args[i]
        if a.begins_with(prefix + "="):
            var value := a.get_slice("=", 1)
            return StringResult.missing() if value.is_empty() else StringResult.ok(value)
        if a == prefix and i + 1 < args.size():
            var next := args[i + 1]
            if not next.begins_with("--"):
                return StringResult.missing() if next.is_empty() else StringResult.ok(next)
    return StringResult.missing()

## get argument passed via URL, fallback to argument passed via CLI
static func get_argument(_arg_name: StringName) -> StringResult:
    var arg := get_url_argument(_arg_name)
    if arg.is_ok():
        return arg
    arg = get_cli_argument(_arg_name)
    return arg

## check if a cli flag is present or not, example: --server
static func get_cli_flag(flag_name: StringName) -> bool:
    var args = Array(OS.get_cmdline_args())
    return args.has("--%s" % flag_name)
