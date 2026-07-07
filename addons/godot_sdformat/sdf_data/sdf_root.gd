class_name SDFRoot
# see https://sdformat.org/spec/1.12/sdf/
extends Resource

@export var version: String = "1.10"
@export var world: SDFWorld = SDFWorld.new()


func get_version_parts() -> Dictionary:
	var parts = version.split(".")
	if parts.size() >= 2:
		return {
			"major": int(parts[0]),
			"minor": int(parts[1])
		}
	return {"major": 1, "minor": 0}