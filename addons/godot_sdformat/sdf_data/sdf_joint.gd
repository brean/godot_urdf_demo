class_name SDFJoint
# see https://sdformat.org/spec/1.12/joint/
extends SDFElement

enum JointType { REVOLUTE, PRISMATIC, FIXED, BALL, SCREW, UNIVERSAL }

@export var type: JointType = JointType.FIXED
@export var parent_link: String = ""
@export var child_link: String = ""
@export var gearbox_ratio: float = 0.0
# TODO: gearbox_reference_body
# TODO: thread_pitch
# TODO: screw_thread_pitch
@export var axis: Vector3 = Vector3.UP
@export var damping: float = 0.0  # TODO: part of axis?
@export var friction: float = 0.0  # TODO: part of axis?

# TODO: create SDFLimit?
@export var limit_lower: float = 0.0  # TODO: -infinity
@export var limit_upper: float = 0.0  # TODO: infinity
@export var limit_effort: float = 0.0  # TODO: infinity
@export var limit_velocity: float = 0.0  # TODO: infinity
@export var limit_stiffness: float = 0.0
@export var limit_dissipation: float = 1.0
# TODO: mimic
# TODO: axis2
# TODO: pyhsics


func get_joint_type_string() -> String:
	match type:
		JointType.REVOLUTE:
			return "revolute"
		JointType.PRISMATIC:
			return "prismatic"
		JointType.FIXED:
			return "fixed"
		JointType.BALL:
			return "ball"
		JointType.SCREW:
			return "screw"
		JointType.UNIVERSAL:
			return "universal"
		_:
			return "fixed"

func has_limits() -> bool:
	return type in [JointType.REVOLUTE, JointType.PRISMATIC]