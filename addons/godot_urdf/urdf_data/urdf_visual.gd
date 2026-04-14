class_name URDFVisual
extends Resource
# transform
var origin_xyz: Vector3
var origin_rpy: Vector3

var material_name: String
var material_color: Vector4 = Vector4.ZERO
var material_texture_path: String

var type: Type
# BOX
var size: Vector3
# SPHERE, CYLINDER
var radius: float
var length: float

# MESH
var mesh_path: String
var mesh_scale: Vector3

enum Type {BOX, MESH, CYLINDER, SPHERE}
