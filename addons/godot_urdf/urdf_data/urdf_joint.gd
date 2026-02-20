class_name URDFJoint extends Object
var name: String
var type: String

# Link names
var parent: String
var child: String

# Transform
# All XYZ will be kept as is originally in URDF file
# Y and Z should be flipped when generating Nodes
var origin_xyz: Vector3
var origin_rpy: Vector3
var axis: Vector3

# Physics
var limit: URDFLimit = null
var dynamics: URDFDynamics = null


class URDFLimit extends Object:
	var lower: float
	var upper: float
	var effort: float
	var velocity: float

class URDFDynamics extends Object:
	var damping: float
	var friction: float
