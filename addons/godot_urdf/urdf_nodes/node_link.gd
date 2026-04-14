@tool
class_name URDFLinkNode3D
extends Node3D

@export var data: Resource # URDFLink
@export var joint_type: JointType
@export var axis: Vector3 = Vector3(1,0,0)
@export var origin_rpy: Vector3 = Vector3(0,0,0)

# TODO: add function to create Joint3D
enum JointType {REVOLUTE, FIXED}
