class_name SDFPose
# see e.g. https://sdformat.org/spec/1.12/actor/#actor_pose
extends Resource

@export var position: Vector3 = Vector3.ZERO
@export var rotation: Quaternion = Quaternion.IDENTITY
@export var relative_to: String = ""  # Frame this pose is relative to
# degrees?
# rotation_format? -> euler_rpy or quat_xyzw

func to_transform3d() -> Transform3D:
	return Transform3D(rotation, position)