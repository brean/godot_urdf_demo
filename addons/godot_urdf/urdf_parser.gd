class_name URDFXMLParser extends XMLParser

# Helper to recursively set owner for the final scene tree
func recursive_set_owner(node: Node3D, target: Node3D):
	if node != target and target != null:
		node.owner = target
	for child in node.get_children():
		recursive_set_owner(child, target)

func as_node3d(
		source_path: String,
		options: Dictionary) -> GodotRobot:
	var start_time = Time.get_ticks_msec()
	var robot: URDFRobot = parse(source_path)
	if not robot:
		return null

	# Note that we have one root node that we will use to represent the URDF
	# tree structure, the robots collision and visual elements
	# are connected to this as well, NOT to their parents in the URDF
	# structure!
	var robot_node = GodotRobot.new()
	robot_node.urdf = robot
	robot_node.name = robot.name
	
	var links = {} # {link_name: Node3D}
	var collision_bodies = {}

	for link in robot.links:
		var link_node3d = URDF_Link_Node3D.new()

		link_node3d.name = link.name + "_link"
		robot_node.add_child(link_node3d)
		links[link.name] = link_node3d

		var visual_parent: Node3D = link_node3d
		if link.colliders.size() > 0:
			var collision_body: CollisionObject3D
			if options.get("create_physics", true):
				collision_body = RigidBody3D.new()
				if link.inertial:
					collision_body.mass = link.inertial.mass
					# TODO: add inertial.inertia and origin as center-of-mass?
			else:
				collision_body = StaticBody3D.new()
			visual_parent = collision_body
			collision_bodies[link.name] = collision_body

			collision_body.name = link.name + "_rigid_body"
			collision_body.position = link_node3d.position
			#link_node3d.add_child(collision_body)
			#root_node.reparent(collision_body)
			
			robot_node.add_child(collision_body)
			for collider in link.colliders:
				var collision_shape = _create_collision_shape(
					collider, options, source_path)
				if not collision_shape:
					continue
				collision_shape.name = link.name + "_collision"
				collision_body.add_child(collision_shape)

		for visual in link.visuals:
			var visual_instance = _create_visual_instance(
				robot, visual, options, source_path)
			visual_instance.name = link.name + "_visual"
			visual_parent.add_child(visual_instance)

	for joint in robot.joints:
		var child_node: Node3D = links.get(joint.child)
		var parent_node: Node3D = links.get(joint.parent)

		if !child_node:
			push_error("Joint child link not found: ", joint.child)
			continue
		if !parent_node:
			push_error("Joint parent link not found: ", joint.parent)
			continue

		child_node.name = joint.name

		# Reparent
		child_node.get_parent().remove_child(child_node)
		parent_node.add_child(child_node)

		# set center position and store in cache so we can
		# calculate the global collider later on.
		var local_transform: Transform3D = xyz_rpy_to_transform3d(
				joint.origin_xyz, joint.origin_rpy)
		child_node.transform = local_transform

		robot_node.add_joint(joint, local_transform)

		create_godot_joint(
			joint, collision_bodies, robot_node)

	# position collider
	for col_name in collision_bodies.keys():
		var global_rel_transform = robot_node.get_rel_transform(col_name)
		var collision = collision_bodies[col_name]
		collision.transform = global_rel_transform


	var now = Time.get_ticks_msec()
	var elapsed = (now - start_time) / 1000.0
	print("Done generating robot, took:", elapsed)
	return robot_node

func create_godot_joint(
		joint: URDFJoint, collision_bodies: Dictionary,
		robot_node: GodotRobot):
	var collision_node_a = collision_bodies.get(joint.parent)
	var collision_node_b = collision_bodies.get(joint.child)
	if !collision_node_a or !collision_node_b:
		return

	var godot_joint: Generic6DOFJoint3D = Generic6DOFJoint3D.new()
	godot_joint.name = "joint_" + joint.name
	robot_node.add_child(godot_joint)

	godot_joint.exclude_nodes_from_collision = false

	# apply transform to position and rotate hinge
	var child_transform = robot_node.get_rel_transform(joint.child)
	godot_joint.position = child_transform.origin
	var base_basis = child_transform.basis
	var urdf_axis = joint.axis.normalized()
	var axis_rotation = Quaternion(Vector3.FORWARD, urdf_axis)
	godot_joint.transform.basis = base_basis * Basis(axis_rotation)

	# lock all movement and rotation (fixed = default)
	for axis_func in ["set_param_x", "set_param_y", "set_param_z"]:
		godot_joint.call(
			axis_func, Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0.0)
		godot_joint.call(
			axis_func, Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0.0)
	for axis_func in ["set_param_x", "set_param_y"]:
		godot_joint.call(
			axis_func, Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, 0.0)
		godot_joint.call(
			axis_func, Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, 0.0)

	if joint.type == "revolute" and joint.limit:
		# Limited hinge
		godot_joint.set_param_z(
			Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, joint.limit.lower)
		godot_joint.set_param_z(
			Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, joint.limit.upper)

	elif joint.type == "continuous":
		# Unlimited hinge: Lower > Upper disables the limit
		godot_joint.set_param_z(
			Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, 1.0)
		godot_joint.set_param_z(
			Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, 0.0)

	godot_joint.set_flag_z(
		Generic6DOFJoint3D.FLAG_ENABLE_MOTOR, true)
	godot_joint.set_param_z(
		Generic6DOFJoint3D.PARAM_ANGULAR_MOTOR_TARGET_VELOCITY, 0.0)

	if joint.dynamics:
		if joint.dynamics.friction > 0:
			godot_joint.set_param_z(
				Generic6DOFJoint3D.PARAM_ANGULAR_MOTOR_FORCE_LIMIT,
				joint.dynamics.friction)
		if joint.dynamics.damping > 0:
			# Damping is not supported by Jolt Physics, use Springinstead
			# if joint.dynamics.damping > 0:
			# 	godot_joint.set_param_z(
			# 		Generic6DOFJoint3D.PARAM_ANGULAR_DAMPING,
			# 		joint.dynamics.damping)
			godot_joint.set_flag_z(
				Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_SPRING, true)
			godot_joint.set_param_z(
				Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_DAMPING,
				joint.dynamics.damping)

	if joint.limit and joint.limit.effort > 0:
		# If friction is already using the motor, we ensure the effort is
		# at least as high as friction
		var max_force = max(
			joint.limit.effort,
			joint.dynamics.friction if joint.dynamics else 0.0)
		godot_joint.set_param_z(
			Generic6DOFJoint3D.PARAM_ANGULAR_MOTOR_FORCE_LIMIT, max_force)

	godot_joint.node_a = godot_joint.get_path_to(collision_node_a)
	godot_joint.node_b = godot_joint.get_path_to(collision_node_b)
	return godot_joint

func parse(source_path: String) -> URDFRobot:
	var parser = XMLParser.new()
	var err = parser.open(source_path)
	if err != OK:
		push_error("Failed to open URDF file: " + source_path)
		return null

	var robot = URDFRobot.new()
	while parser.read() == OK:
		var node_type = parser.get_node_type()
		if node_type == XMLParser.NODE_TEXT: continue # Skip whitespace
		
		if node_type == XMLParser.NODE_ELEMENT:
			if parser.get_node_name() == "robot":
				robot.name = parser.get_named_attribute_value_safe("name")
				print("robot name: ", robot.name)
				parse_robot_children(parser, robot)

	return robot
	
func parse_robot_children(parser: XMLParser, robot: URDFRobot) -> void:
	while parser.read() == OK:
		var node_type = parser.get_node_type()
		if node_type == XMLParser.NODE_TEXT:
			continue
		var node_name = parser.get_node_name()
		
		if node_type == XMLParser.NODE_ELEMENT:
			match node_name:
				"link":
					#var link_name := parser.get_named_attribute_value_safe("name")
					#print("parsing link: ",  link_name)
					robot.links.append(get_urdf_link(parser))
				"joint":
					#var joint_name := parser.get_named_attribute_value_safe("name")
					#print("parsing joint: ", joint_name)
					robot.joints.append(get_urdf_joint(parser))
				"material":
					var material_name = parser.get_named_attribute_value_safe("name")
					robot.materials[material_name] = parse_material_color(parser)
				_:
					push_error("Unsupported tag in robot: ", node_name)
					parser.skip_section()

		elif node_type == XMLParser.NODE_ELEMENT_END:
			if node_name == "robot":
				return

func get_urdf_joint(parser: XMLParser) -> URDFJoint:
	var joint = URDFJoint.new()
	joint.name = parser.get_named_attribute_value_safe("name")
	if parser.is_empty():
		return joint
	joint.type = parser.get_named_attribute_value_safe("type")

	while parser.read() == OK:
		var node_type = parser.get_node_type()
		if node_type == XMLParser.NODE_TEXT:
			continue
		var node_name = parser.get_node_name()
		var axis: Vector3 = Vector3(0, 0, 1)
		if node_type == XMLParser.NODE_ELEMENT:
			match node_name:
				"parent":
					joint.parent = parser.get_named_attribute_value_safe("link")
				"child":
					joint.child = parser.get_named_attribute_value_safe("link")
				"axis":
					joint.axis = parse_xyz(parser)
				"origin":
					joint.origin_xyz = parse_xyz(parser)
					joint.origin_rpy = parse_rpy(parser)
				"limit":
					parse_joint_limit(parser, joint)
				"dynamics":
					parse_joint_dynamics(parser, joint)
				_:
					push_error("Unsupported tag in joint: ", node_name)
					parser.skip_section()
		elif node_type == XMLParser.NODE_ELEMENT_END:
			if node_name == "joint":
				return joint
	return joint

func get_urdf_link(parser: XMLParser) -> URDFLink:
	var link: URDFLink = URDFLink.new()
	link.name = parser.get_named_attribute_value_safe("name")
	if parser.is_empty():
		return link

	while parser.read() == OK:
		var node_type = parser.get_node_type()
		if node_type == XMLParser.NODE_TEXT:
			continue
		var node_name = parser.get_node_name()
		if node_type == XMLParser.NODE_ELEMENT:
			match node_name:
				"visual":
					link.visuals.append(get_link_visual(parser))
				"collision":
					link.colliders.append(get_link_collider(parser))
				"inertial":
					link.inertial = get_link_inertial(parser)
				_:
					parser.skip_section()
					push_error("Unsupported Tag in Link: ", node_type)
		elif node_type == XMLParser.NODE_ELEMENT_END:
			if node_name == "link":
				return link
	return link

func get_link_inertial(parser: XMLParser) -> URDFInertial:
	var inertial = URDFInertial.new()
	if parser.is_empty():
		return inertial
	while parser.read() == OK:
		var node_type = parser.get_node_type()
		if node_type == XMLParser.NODE_TEXT:
			continue
		var node_name = parser.get_node_name() 
		if node_type == XMLParser.NODE_ELEMENT:
			match node_name:
				"mass":
					var mass = parser.get_named_attribute_value_safe("value")
					if mass.is_valid_float():
						inertial.mass = float(mass)
				"origin":
					inertial.origin_xyz = parse_xyz(parser)
					inertial.origin_rpy = parse_rpy(parser)
				"inertia":
					inertial.inertia_tensor = parse_inertia(parser)
				_:
					push_error("Unsupported tag for inertial: ", node_name)
					parser.skip_section()
		elif node_type == XMLParser.NODE_ELEMENT_END:
			if node_name == "inertial":
				return inertial
	return inertial

func parse_inertia(parser: XMLParser) -> Dictionary:
	var inertia = {}
	for idx in range(parser.get_attribute_count()):
		var attr_name = parser.get_attribute_name(idx)
		var attr_value = parser.get_attribute_value(idx)
		if attr_value.is_valid_float():
			inertia[attr_name] = float(attr_value)
	return inertia

func get_link_collider(parser: XMLParser) -> URDFCollider:
	var collider = URDFCollider.new()
	
	if parser.is_empty():
		return collider

	while parser.read() == OK:
		var node_type = parser.get_node_type()
		if node_type == XMLParser.NODE_TEXT:
			continue
		var node_name = parser.get_node_name() 
		if node_type == XMLParser.NODE_ELEMENT:
			match node_name:
				"origin":
					collider.origin_xyz = parse_xyz(parser)
					collider.origin_rpy = parse_rpy(parser)
				"geometry":
					parse_geometry(parser, collider, false)
				_:
					push_error("Unsupported collider for Link: ", node_name)
					parser.skip_section()
		elif node_type == XMLParser.NODE_ELEMENT_END:
			if node_name == "collision":
				return collider
	return collider

func get_link_visual(parser: XMLParser) -> URDFVisual:
	var visual = URDFVisual.new()
	
	if parser.is_empty():
		return visual
	
	while parser.read() == OK:
		var node_type = parser.get_node_type()
		if node_type == XMLParser.NODE_TEXT:
			continue
		var node_name = parser.get_node_name()

		if node_type == XMLParser.NODE_ELEMENT:
			match node_name:
				"origin":
					visual.origin_xyz = parse_xyz(parser)
					visual.origin_rpy = parse_rpy(parser)
				"geometry":
					parse_geometry(parser, visual, true)
				"material":
					visual.material_name = parser.get_named_attribute_value_safe("name")
					visual.material_color = parse_material_color(parser)
				_:
					push_error("Unsupported node for Visual link: ", node_name)
					parser.skip_section()
		elif node_type == XMLParser.NODE_ELEMENT_END:
			if node_name == "visual":
				return visual
	return visual

func parse_xyz(parser: XMLParser) -> Vector3:
	var xyz = parser.get_named_attribute_value_safe("xyz")
	var xyz_split = xyz.split(" ", false)
	if xyz.is_empty() or xyz_split.size() < 3:
		push_error("not enough values for XYZ!")
		return Vector3(0, 0, 0)
	return Vector3(
		float(xyz_split[0]),
		float(xyz_split[2]),
		-float(xyz_split[1]))

func parse_rpy(parser: XMLParser) -> Vector3:
	var rpy = parser.get_named_attribute_value_safe("rpy")
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

func _get_named_float(parser: XMLParser, name: String) -> float:
	var value = parser.get_named_attribute_value_safe(name)
	return 0.0 if value.is_empty() else float(value)

func parse_joint_limit(parser: XMLParser, joint: URDFJoint) -> void:
	joint.limit = URDFJoint.URDFLimit.new()
	joint.limit.lower = _get_named_float(parser, "lower")
	joint.limit.upper = _get_named_float(parser, "upper")
	joint.limit.effort = _get_named_float(parser, "effort")
	joint.limit.velocity = _get_named_float(parser, "velocity")

func parse_joint_dynamics(parser: XMLParser, joint: URDFJoint) -> void:
	joint.dynamics = URDFJoint.URDFDynamics.new()
	joint.dynamics.damping = _get_named_float(parser, "damping")
	joint.dynamics.friction = _get_named_float(parser, "friction")

func xyz_rpy_to_transform3d(xyz: Vector3, rpy: Vector3) -> Transform3D:
	# Convert XYZ RPY vector to 3D transform
	var basis = Basis.from_euler(rpy, EULER_ORDER_XYZ)
	return Transform3D(basis, xyz)

func parse_geometry(
		parser: XMLParser,
		target_object: Object,
		is_visual: bool) -> void:
	if parser.is_empty():
		return
	
	while parser.read() == OK:
		var node_type = parser.get_node_type()
		if node_type == XMLParser.NODE_TEXT: continue
		
		if node_type == XMLParser.NODE_ELEMENT:
			var node_name = parser.get_node_name()
			match node_name:
				"box":
					if is_visual: target_object.type = URDFVisual.Type.BOX
					else: target_object.type = URDFCollider.Type.BOX
					
					var size_split = parser.get_named_attribute_value_safe("size").split(" ", false)
					if size_split.size() >= 3:
						target_object.size = Vector3(
							float(size_split[0]),
							float(size_split[2]),
							float(size_split[1])
						)
				"cylinder":
					if is_visual: target_object.type = URDFVisual.Type.CYLINDER
					else: target_object.type = URDFCollider.Type.CYLINDER
					
					target_object.length = float(parser.get_named_attribute_value_safe("length"))
					target_object.radius = float(parser.get_named_attribute_value_safe("radius"))
				"sphere":
					if is_visual: target_object.type = URDFVisual.Type.SPHERE
					else: target_object.type = URDFCollider.Type.SPHERE
					
					target_object.radius = float(parser.get_named_attribute_value_safe("radius"))
				"mesh":
					if is_visual: target_object.type = URDFVisual.Type.MESH
					else: target_object.type = URDFCollider.Type.MESH
					
					var filename = parser.get_named_attribute_value_safe("filename")
					target_object.mesh_path = filename
				_:
					push_error("Unsupported geometry for visual in link properties: ", node_name)
					parser.skip_section()
		elif node_type == XMLParser.NODE_ELEMENT_END:
			if parser.get_node_name() == "geometry":
				return

func parse_material_color(parser: XMLParser) -> Vector4:
	var material_color = Vector4.ZERO
	if parser.is_empty():
		return material_color

	while parser.read() == OK:
		var node_type = parser.get_node_type()
		if node_type == XMLParser.NODE_TEXT: continue

		if node_type == XMLParser.NODE_ELEMENT and \
				parser.get_node_name() == "color":
			var rgba_str = parser.get_named_attribute_value_safe("rgba")
			if rgba_str and !rgba_str.is_empty():
				var color_split = rgba_str.split(" ", false)
				if color_split.size() >= 4:
					material_color = Vector4(
						float(color_split[0]),
						float(color_split[1]),
						float(color_split[2]),
						float(color_split[3])
					)
				else:
					push_warning("Invalid color: ", rgba_str)
					
		elif node_type == XMLParser.NODE_ELEMENT_END:
			if parser.get_node_name() == "material":
				return material_color

	return material_color

func _create_visual_instance(
		robot: URDFRobot,
		visual: URDFVisual,
		options: Dictionary,
		source_path: String) -> MeshInstance3D:
	var visual_instance = MeshInstance3D.new()

	var material = StandardMaterial3D.new()
	if visual.material_name != "":
		visual_instance.name = "Visual_" + visual.material_name
	
	var c = visual.material_color
	if c != Vector4.ZERO:
		material.albedo_color = Color(c.x, c.y, c.z, c.w)
	elif visual.material_name in robot.materials:
		c = robot.materials[visual.material_name]
		material.albedo_color = Color(c.x, c.y, c.z, c.w)
	
	visual_instance.transform = xyz_rpy_to_transform3d(
		visual.origin_xyz, visual.origin_rpy)
	
	match visual.type:
		URDFVisual.Type.BOX:
			var box_mesh = BoxMesh.new()
			box_mesh.size = abs(visual.size)
			box_mesh.material = material
			visual_instance.mesh = box_mesh
		URDFVisual.Type.CYLINDER:
			var cylinder_mesh = CylinderMesh.new()
			cylinder_mesh.height = abs(visual.length)
			cylinder_mesh.bottom_radius = abs(visual.radius)
			cylinder_mesh.top_radius = abs(visual.radius)
			cylinder_mesh.material = material
			visual_instance.mesh = cylinder_mesh
		URDFVisual.Type.SPHERE:
			var sphere_mesh = SphereMesh.new()
			sphere_mesh.radius = abs(visual.radius)
			sphere_mesh.height = abs(visual.radius * 2)
			sphere_mesh.material = material
			visual_instance.mesh = sphere_mesh
		URDFVisual.Type.MESH:
			# Expected options["package_folder"] to be "res://path/to/urdf_root"
			var clean_path = visual.mesh_path.replace("package://", "")
			var full_source_path = ""
			if options.has("package_folder"):
				full_source_path = options["package_folder"].path_join(clean_path)
			else:
				# Fallback: try to find it relative to the URDF file
				full_source_path = source_path.get_base_dir().path_join(clean_path)

			# Check if file exists in Godot project
			if !FileAccess.file_exists(full_source_path):
				push_error("Mesh not found at: ", full_source_path)

			var imported_mesh = load(full_source_path)
			if imported_mesh:
				visual_instance.mesh = imported_mesh
				var ext = full_source_path.get_extension().to_lower()
				if ext == "stl":
					visual_instance.scale = Vector3(0.001, 0.001, 0.001)
					visual_instance.rotate_x(-PI / 2)
				else:
					visual_instance.scale = Vector3(1, 1, 1)
				if c != Vector4.ZERO:
					visual_instance.material_override = material
			else:
				push_error("Failed to load mesh: ", full_source_path)
		_:
			push_error("Unsupported visual type: ", visual.type)

	return visual_instance

func _create_collision_shape(
		collider: URDFCollider,
		options: Dictionary,
		source_path: String) -> CollisionShape3D:
	var collision_shape = CollisionShape3D.new()
	match collider.type:
		URDFCollider.Type.BOX:
			var box_shape = BoxShape3D.new()
			box_shape.size = abs(collider.size)
			collision_shape.shape = box_shape
		URDFCollider.Type.CYLINDER:
			var cylinder_shape = CylinderShape3D.new()
			cylinder_shape.height = abs(collider.length)
			cylinder_shape.radius = abs(collider.radius)
			collision_shape.shape = cylinder_shape
		URDFCollider.Type.SPHERE:
			var sphere_shape = SphereShape3D.new()
			sphere_shape.radius = abs(collider.radius)
			collision_shape.shape = sphere_shape
		URDFCollider.Type.MESH:
			# var mesh_helper = MeshInstance3D.new()

			# var clean_path = collider.mesh_path.replace("package://", "")
			# var full_source_path = ""
			# if options.has("package_folder"):
			# 	full_source_path = options["package_folder"].path_join(clean_path)
			# else:
			# 	# Fallback: try to find it relative to the URDF file
			# 	full_source_path = source_path.get_base_dir().path_join(clean_path)

			# # Check if file exists in Godot project
			# if !FileAccess.file_exists(full_source_path):
			# 	push_error("Mesh not found at: ", full_source_path)

			# var imported_mesh = load(full_source_path)

			# mesh_helper.mesh = imported_mesh
			# mesh_helper.create_multiple_convex_collisions()
			
			# var child = mesh_helper.get_child(1)
			# mesh_helper.remove_child(child)
			push_error("FIXME: IGNORING MESH!")
			return null
		_:
			push_error("Unsupported collider type: ", collider.type)
			return null
	
	collision_shape.transform = xyz_rpy_to_transform3d(
		collider.origin_xyz, collider.origin_rpy)

	return collision_shape
