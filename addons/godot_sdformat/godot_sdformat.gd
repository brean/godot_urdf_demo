@tool
extends EditorPlugin

var godot_sdformat = GodotSDFImporter.new()

func _enter_tree() -> void:
	add_import_plugin(godot_sdformat)

func _exit_tree() -> void:
	remove_import_plugin(godot_sdformat)
