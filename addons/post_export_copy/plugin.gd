@tool
extends EditorPlugin

class ExportCopyPlugin:
    extends EditorExportPlugin

    const WRAPPER := "res://web/wrapper.html"
    const TARGET := "build/html-client/index.html"

    var _should_copy := false

    func _get_name() -> String:
        return "PostExportCopyExporter"

    func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
        _should_copy = features.has("web")

    func _export_end() -> void:
        if not _should_copy:
            return
        _should_copy = false
        var src := ProjectSettings.globalize_path(WRAPPER)
        var dst := ProjectSettings.globalize_path(TARGET)
        var err := DirAccess.copy_absolute(src, dst)
        if err != OK:
            push_error("PostExportCopy failed (%s): %s -> %s" % [err, WRAPPER, TARGET])

var _exporter: ExportCopyPlugin

func _enter_tree() -> void:
    _exporter = ExportCopyPlugin.new()
    add_export_plugin(_exporter)

func _exit_tree() -> void:
    if _exporter:
        remove_export_plugin(_exporter)
        _exporter = null
