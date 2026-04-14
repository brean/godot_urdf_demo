class_name URDFJoint
extends Resource

@export var name: String
@export var type: String

# Link names
@export var parent: String
@export var child: String

# Transform
# All XYZ will be kept as is originally in URDF file
# Y and Z should be flipped when generating Nodes
@export var origin_xyz: Vector3
@export var origin_rpy: Vector3
@export var axis: Vector3

# Physics
@export var limit: URDFLimit = null
@export var dynamics: URDFDynamics = null

class URDFLimit extends Resource:
	@export var lower: float
	@export var upper: float
	@export var effort: float
	@export var velocity: float

class URDFDynamics extends Resource:
	@export var damping: float
	@export var friction: float
