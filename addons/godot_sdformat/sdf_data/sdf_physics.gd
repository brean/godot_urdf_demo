class_name SDFPhysics
# see https://sdformat.org/spec/1.12/physics/
extends Resource

# we ignore the engine and just use Jolt
enum EngineType { ODE, BULLET, SIMBODY, DART, CUSTOM }

@export var engine: EngineType = EngineType.CUSTOM  # aka type
@export var max_step_size: float = 0.001
@export var real_time_factor: float = 1.0
@export var real_time_update_rate: float = 1000.0

func apply_to_world(world_node: Node) -> void:
    return
	# ProjectSettings.set_setting(
    #     "physics/3d/default_gravity_vector", Vector3(0,-1,0))
    # get_tree().call_group("gravity_change", "gravity_changed")