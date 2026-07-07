class_name SDFWorld
# see https://sdformat.org/spec/1.12/world/
extends SDFElement

@export var physics: SDFPhysics = SDFPhysics.new()
@export var scene: SDFScene = SDFScene.new()

# export?
var models: Dictionary = {}  # name -> SDFModel
var lights: Dictionary = {}  # name -> SDFLight

var includes: Array[String] = []

func add_model(model: SDFModel) -> void:
	models[model.name] = model


func add_light(light: SDFLight) -> void:
	lights[light.name] = light

func get_model(model_name: String) -> SDFModel:
	return models.get(model_name)

func to_godot_scene() -> Node3D:
	var world_node = Node3D.new()
	world_node.name = name

	var world_env = WorldEnvironment.new()
	world_env.name = "Environment"
	world_env.environment = Environment.new()
	world_node.add_child(world_env)
	scene.apply_to_environment(world_env)
	
	var lights_node = Node3D.new()
	lights_node.name = "Lights"
	world_node.add_child(lights_node)
	
	for light_name in lights.keys():
		var light = lights[light_name]
		lights_node.add_child(light.to_godot_node())
	
	var models_node = Node3D.new()
	models_node.name = "Models"
	world_node.add_child(models_node)
	
	for model_name in models.keys():
		var model = models[model_name]
		models_node.add_child(model.to_godot_scene())
	
	return world_node