@tool
class_name URDF_Link_Node3D extends Node3D

enum JointType {REVOLUTE, FIXED}

@export var joint_type: JointType
@export var axis: Vector3 = Vector3(1,0,0)
var origin_rpy: Vector3 = Vector3.ZERO


@export_range(-360.0, 360.0, 0.1) var value: float = 0:
	set(_value):
		value = _value
		on_angle_change()

func on_angle_change():
	rotation = origin_rpy
	match joint_type:
		JointType.REVOLUTE:
			# rotate_object_local(axis, value)
			rotate_object_local(axis.normalized(), deg_to_rad(value))

func _ready() -> void:
	on_angle_change()
