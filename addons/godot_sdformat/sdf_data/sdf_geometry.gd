class_name SDFGeometry
# see https://sdformat.org/spec/1.12/geometry/
extends Resource

# see also URDFCollider.Type
enum GeometryType { BOX, SPHERE, CONE, CYLINDER, MESH, PLANE }
# TODO: ellipsoid
# TODO: heightmap
# TODO: image
# TODO: polyline

@export var type: GeometryType = GeometryType.BOX
@export var size: Vector3 = Vector3.ONE  # box
@export var radius: float = 1.0  # sphere or cylinder
@export var length: float = 1.0  # cylinder
@export var uri: String = ""  # mesh
@export var scale: Vector3 = Vector3.ONE  # mesh

func create_godot_shape() -> Shape3D:
	match type:
		GeometryType.BOX:
			var shape = BoxShape3D.new()
			shape.size = size
			return shape
		GeometryType.SPHERE:
			var shape = SphereShape3D.new()
			shape.radius = radius
			return shape
        # TODO: cone
		GeometryType.CYLINDER:
			var shape = CylinderShape3D.new()
			shape.radius = radius
			shape.height = length
			return shape
		GeometryType.PLANE:
			return BoxShape3D.new()  # Simplified as flat box for now
		_:
			return BoxShape3D.new()

func create_godot_mesh() -> Mesh:
	match type:
		GeometryType.BOX:
			var mesh = BoxMesh.new()
			mesh.size = box_size
			return mesh
		GeometryType.SPHERE:
			var mesh = SphereMesh.new()
			mesh.radius = radius
			mesh.height = radius * 2.0
			return mesh
		GeometryType.CYLINDER:
			var mesh = CylinderMesh.new()
			mesh.radius = radius
			mesh.height = length
			return mesh
		GeometryType.MESH:
			if ResourceLoader.exists(uri):
				return load(uri)
			return PlaneMesh.new()
		_:
			return PlaneMesh.new()