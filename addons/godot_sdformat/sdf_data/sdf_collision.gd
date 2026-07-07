class_name SDFCollision
# see https://sdformat.org/spec/1.12/collision/
extends SDFElement

# TODO: max_contacts
# TODO: laser_retro
@export var geometry: SDFGeometry = SDFGeometry.new()
# TODO: SDFSurface

func to_godot_node() -> CollisionShape3D:
	var collision = CollisionShape3D.new()
	collision.name = name
	collision.transform = pose.to_transform3d()
	collision.shape = geometry.create_godot_shape()
	return collision