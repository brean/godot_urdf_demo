@tool
class_name GodotSDFImporter
extends EditorImportPlugin

func _get_importer_name() -> String:
	return "godot_sdformat"

func _get_visible_name() -> String:
	return "Godot SDFormat"

func _get_recognized_extensions():
	return ["sdf"]

func _get_resource_type():
	return "tscn"
