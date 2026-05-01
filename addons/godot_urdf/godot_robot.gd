@tool
class_name GodotRobot
extends Node3D

var _transform_cache = {}
var joint_defs = {} # {"parent": String, "transform": Transform3D}

@export var urdf: URDFRobot

func add_joint(joint: URDFJoint, local_transform: Transform3D):
	joint_defs[joint.child] = {
		"parent": joint.parent,
		"transform": local_transform
	}


func get_rel_transform(link_name: String) -> Transform3D:
	if _transform_cache.has(link_name):
		return _transform_cache[link_name]
	
	if not joint_defs.has(link_name):
		_transform_cache[link_name] = Transform3D.IDENTITY
		return Transform3D.IDENTITY
	
	var joint = joint_defs[link_name]
	var parent_transform = get_rel_transform(joint.parent)
	var transform = parent_transform * joint.transform
	
	_transform_cache[link_name] = transform
	return transform
