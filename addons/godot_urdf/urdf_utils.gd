class_name URDFUtils

static func apply_defaults(options: Dictionary):
	if "scale" not in options:
		options["scale"] = 0.001
	if "package_folder" not in options:
		options["package_folder"] = "res://urdf"
	if "create_physics" not in options:
		options["create_physics"] = true

static func _load_yaml(yaml_config: String, parser: YAMLParser):
	var options = null
	if FileAccess.file_exists(yaml_config):
		var yaml_file = FileAccess.open(yaml_config, FileAccess.READ)
		var yaml_text = yaml_file.get_as_text()
		options = parser.parse(yaml_text)
		yaml_file.close()
	return options

static func get_urdf_config(basename):
	var yaml_parser = YAMLParser.new()
	var options = _load_yaml(basename + ".yml", yaml_parser)
	if options:
		return options
	options = _load_yaml(basename + ".yaml", yaml_parser)
	if options:
		return options
	return {}

static func parse_xyz(xyz: String) -> Vector3:
	var xyz_split = xyz.split(" ", false)
	if xyz.is_empty() or xyz_split.size() < 3:
		push_error("not enough values for XYZ!")
		return Vector3(0, 0, 0)
	return Vector3(
		float(xyz_split[0]),
		float(xyz_split[2]),
		-float(xyz_split[1]))

static func parse_rpy(rpy: String) -> Vector3:
	if rpy.is_empty():
		return Vector3.ZERO
	var rpy_split = rpy.split(" ", false)
	if rpy_split.size() < 3:
		# throw error?
		push_error("not enough values for RPY: " + rpy)
		return Vector3.ZERO
	return Vector3(
			float(rpy_split[0]),
			float(rpy_split[2]),
			-float(rpy_split[1]))

static func xyz_rpy_to_transform3d(xyz: Vector3, rpy: Vector3) -> Transform3D:
	# Convert XYZ RPY vector to 3D transform
	var basis = Basis.from_euler(rpy, EULER_ORDER_XYZ)
	return Transform3D(basis, xyz)
