extends Node

func get_current_time(show_seconds := false) -> String:
    var time = Time.get_time_dict_from_system()

    if show_seconds:
        return "%02d:%02d:%02d" % [time.hour, time.minute, time.second]
    else:
        return "%02d:%02d" % [time.hour, time.minute]

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
        result.port = parts[1].to_int()

    return result
