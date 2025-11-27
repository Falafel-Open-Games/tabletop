extends Node

func get_current_time(show_seconds := false) -> String:
    var time = Time.get_time_dict_from_system()

    if show_seconds:
        return "%02d:%02d:%02d" % [time.hour, time.minute, time.second]
    else:
        return "%02d:%02d" % [time.hour, time.minute]

func get_cmdline_arg_value(target_key: String) -> String:
    var args = OS.get_cmdline_args()
    for i in range(args.size()):
        var arg = args[i]

        # Format 1: --key value
        if arg == target_key and i + 1 < args.size():
            return args[i + 1]

        # Format 2: --key=value
        if arg.begins_with(target_key + "="):
            return arg.split("=")[1]

    return ""

func get_websocket_server() -> String:
    # 1. Get the raw string from command line (using the logic from before)
    var raw_url = get_cmdline_arg_value("--url")

    if raw_url.is_empty():
        return "" # Or handle error / return default like "ws://127.0.0.1:8910"

    # 2. Check for protocol and add if missing
    if not raw_url.begins_with("ws://") and not raw_url.begins_with("wss://"):
        return "ws://" + raw_url

    return raw_url

func get_ip_and_port(full_url: String) -> Dictionary:
    var clean_url = full_url.trim_prefix("wss://").trim_prefix("ws://")
    var parts = clean_url.split(":")

    var result = {
        "ip": "",
        "port": 0 # Default integer for port
    }

    if parts.size() >= 1:
        result.ip = parts[0]

    if parts.size() >= 2:
        result.port = parts[1].to_int() # Convert string "8910" to int 8910

    return result
