extends Node

func get_current_time(show_seconds := false) -> String:
    var time = Time.get_time_dict_from_system()

    if show_seconds:
        return "%02d:%02d:%02d" % [time.hour, time.minute, time.second]
    else:
        return "%02d:%02d" % [time.hour, time.minute]
