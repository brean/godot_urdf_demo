@tool
extends Node3D

@export_file("*.urdf", "*.xml") var urdf_file_path: String

@export var load_robot: bool = false:
    set(value):
        if value:
            _load_urdf()
            load_robot = false

# Change "package://robot_description/meshes/..." to "res://urdf/..."
@export_dir var package_folder: String = "res://"

func _load_urdf():
    for child in get_children():
        child.free()

    if urdf_file_path.is_empty():
        push_error("No URDF file selected!")
        return

    var parser = URDFXMLParser.new()

    var options = {
        "package_folder": package_folder,
        "create_physics": true
    }

    var robot_node = parser.as_node3d(urdf_file_path, options)

    if robot_node:
        add_child(robot_node)
        var scene_root = get_tree().edited_scene_root
        
        if scene_root:
            parser.recursive_set_owner(robot_node, scene_root)
        else:
            robot_node.owner = self
            
        print("Robot loaded successfully!")
    else:
        push_error("Failed to load robot node.")
