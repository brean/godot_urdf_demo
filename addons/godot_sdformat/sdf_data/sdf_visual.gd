class_name SDFVisual
# see https://sdformat.org/spec/1.12/visual/
extends SDFElement

@export var geometry: SDFGeometry = SDFGeometry.new()
@export var material: SDFMaterial = SDFMaterial.new()