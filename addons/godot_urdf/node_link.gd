@tool
class_name URDF_Link_Node3D extends Node3D

enum JointType {REVOLUTE, FIXED}

@export var joint_type: JointType
@export var axis: Vector3 = Vector3(1,0,0)
@export var origin_rpy: Vector3 = Vector3(0,0,0)
