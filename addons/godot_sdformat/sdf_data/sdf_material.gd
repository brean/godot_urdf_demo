class_name SDFVisual
# https://sdformat.org/spec/1.12/material/
extends Resource

@export var render_order: float = 0
@export var lighting: bool = true
@export var ambient: Color = Color.WHITE
@export var diffuse: Color = Color.WHITE
@export var specular: Color = Color.WHITE
@export var shininess: float = 0.0
@export var double_sided: bool = false
@export var emissive: Color = Color.BLACK
