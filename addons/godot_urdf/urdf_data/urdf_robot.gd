@tool
class_name URDFRobot
extends Resource

@export var name: String
@export var links: Array[URDFLink] = []
@export var joints: Array[URDFJoint] = []
@export var materials: Dictionary[String, Vector4] = {}

func get_child_joints(link_name: String) -> Array[URDFJoint]:
	var children: Array[URDFJoint] = []
	for joint in joints:
		if joint.parent == link_name:
			children.append(joint)
	return children
	
func get_link(link_name: String) -> URDFLink:
	for link in links:
		if link.name == link_name:
			return link
	return null

func get_root_links() -> Array[String]:
	var roots: Array[String] = []
	for link in links:
		var has_parent = false
		for joint in joints:
			if joint.child == link.name:
				has_parent = true
				break
		if not has_parent:
			roots.append(link.name)
	return roots
