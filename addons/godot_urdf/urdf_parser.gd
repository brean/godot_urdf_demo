class_name URDFXMLParser extends XMLParser

# Helper to recursively set owner for the final scene tree
func recursive_set_owner(node: Node3D, target: Node3D):
	if node != target and target != null:
		node.owner = target
	for child in node.get_children():
		recursive_set_owner(child, target)

func as_node3d(source_path: String, options: Dictionary) -> Node3D:
	var robot: URDFRobot = parse(source_path, options)
	if not robot:
		return null
		
	var root_node = Node3D.new()
	root_node.name = robot.name
	var links_map = {} # Map<LinkName, Node3D>

	for link in robot.links:
		var link_node3d = URDF_Link_Node3D.new()

		link_node3d.name = link.name
		root_node.add_child(link_node3d)
		links_map[link.name] = link_node3d

		for visual in link.visuals:
			var visual_instance = _create_visual_instance(
				visual, options, source_path)
			visual_instance.name = "Visual"
			link_node3d.add_child(visual_instance)
			
		if link.colliders.size() > 0:
			var collision_body: CollisionObject3D
			
			if options.get("create_physics", false):
				collision_body = RigidBody3D.new()
				collision_body.freeze = true
			else:
				collision_body = StaticBody3D.new()
			
			collision_body.name = "CollisionBody"
			link_node3d.add_child(collision_body)

			for collider in link.colliders:
				var collision_shape = _create_collision_shape(collider)
				collision_body.add_child(collision_shape)

	for joint in robot.joints:
		var child_node = links_map.get(joint.child)
		var parent_node = links_map.get(joint.parent)

		if !child_node:
			push_warning("Joint child link not found: ", joint.child)
			continue
		if !parent_node:
			push_warning("Joint parent link not found: ", joint.parent)
			continue
		
		# Reparent
		child_node.get_parent().remove_child(child_node)
		parent_node.add_child(child_node)
		
		child_node.position = joint.origin_xyz
		# child_node.rotation = joint.origin_rpy
		child_node.origin_rpy = joint.origin_rpy
		child_node.on_angle_change()
		child_node.name = joint.name
		if "axis" in child_node:
			child_node.axis = joint.axis_xyz.normalized()
		if "joint_type" in child_node:
			match joint.type:
				"revolute", "continuous":
					child_node.joint_type = child_node.JointType.REVOLUTE
					# child_node.axis = joint.axis_xyz.normalized()
					child_node.axis = joint.axis_xyz
				"fixed":
					child_node.joint_type = child_node.JointType.FIXED
				_:
					push_warning("Unsupported joint type: ", joint.type, " treating as fixed.")
					child_node.joint_type = child_node.JointType.FIXED

	# recursive_set_owner(root_node, root_node)
	return root_node


func parse(source_path: String, options: Dictionary) -> URDFRobot:
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
					var link_name := parser.get_named_attribute_value_safe("name")
					print("parsing link: ",  link_name)
					robot.links.append(get_urdf_link(parser))
				"joint":
					print("parsing joint")
					robot.joints.append(get_urdf_joint(parser))
				_:
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

		if node_type == XMLParser.NODE_ELEMENT:
			match node_name:
				"parent":
					joint.parent = parser.get_named_attribute_value_safe("link")
				"child":
					joint.child = parser.get_named_attribute_value_safe("link")
				"axis":
					parse_axis(parser, joint)
				"origin":
					parse_origin(parser, joint)
				_:
					push_error("Unsupported joint: ", node_name)
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
					print("parsing visual")
					link.visuals.append(get_link_visual(parser))
				"collision":
					print("parsing collision")
					link.colliders.append(get_link_collider(parser))
				"inertial":
					# we don't simulate the physics for now so we ignore this.
					parser.skip_section()
				_:
					parser.skip_section()
					push_error("Unsupported Tag in Link: ", node_type)
		elif node_type == XMLParser.NODE_ELEMENT_END:
			if node_name == "link":
				return link
	return link

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
					parse_origin(parser, collider)
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
					parse_origin(parser, visual)
				"geometry":
					parse_geometry(parser, visual, true)
				"material":
					visual.material_name = parser.get_named_attribute_value_safe("name")
					parse_material(parser, visual)
				_:
					push_error("Unsupported node for Visual link: ", node_name)
					parser.skip_section()
		elif node_type == XMLParser.NODE_ELEMENT_END:
			if node_name == "visual":
				return visual
	return visual

func parse_axis(parser: XMLParser, target_object: Object) -> void:
	var xyz = parser.get_named_attribute_value_safe("xyz")
	if xyz.is_empty():
		# throw error?
		return
	var xyz_split = xyz.split(" ", false)
	if xyz_split.size() >= 3:
		target_object.axis_xyz = Vector3(
			float(xyz_split[0]),
			float(xyz_split[2]),
			-float(xyz_split[1]))

func parse_xyz(parser: XMLParser, target_object: Object) -> void:
	var xyz = parser.get_named_attribute_value_safe("xyz")
	if xyz.is_empty():
		# throw error?
		return
	var xyz_split = xyz.split(" ", false)
	if xyz_split.size() >= 3:
		target_object.origin_xyz = Vector3(
			float(xyz_split[0]),
			float(xyz_split[2]),
			-float(xyz_split[1]))

func parse_rpy(parser: XMLParser, target_object: Object) -> void:
	var rpy = parser.get_named_attribute_value_safe("rpy")
	if rpy.is_empty():
		# throw error?
		return
	var rpy_split = rpy.split(" ", false)
	if rpy_split.size() >= 3:
		target_object.origin_rpy = Vector3(
			float(rpy_split[0]),
			float(rpy_split[2]),
			-float(rpy_split[1]))

func parse_origin(parser: XMLParser, target_object: Object) -> void:
	parse_xyz(parser, target_object)
	parse_rpy(parser, target_object)

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

func parse_material(parser: XMLParser, visual: URDFVisual) -> void:
	if parser.is_empty():
		return

	while parser.read() == OK:
		var node_type = parser.get_node_type()
		if node_type == XMLParser.NODE_TEXT: continue

		if node_type == XMLParser.NODE_ELEMENT:
			if parser.get_node_name() == "color":
				var rgba_str = parser.get_named_attribute_value_safe("rgba")
				var color_split = rgba_str.split(" ", false)
				if color_split.size() >= 4:
					visual.material_color = Vector4(
						float(color_split[0]),
						float(color_split[1]),
						float(color_split[2]),
						float(color_split[3])
					)
		elif node_type == XMLParser.NODE_ELEMENT_END:
			if parser.get_node_name() == "material":
				return


func _create_visual_instance(
		visual: URDFVisual,
		options: Dictionary,
		source_path: String) -> MeshInstance3D:
	var visual_instance = MeshInstance3D.new()
	visual_instance.name = "Visual"

	var material = StandardMaterial3D.new()
	if visual.material_name != "":
		visual_instance.name = "Visual_" + visual.material_name
	
	var c = visual.material_color
	if c != Vector4.ZERO:
		material.albedo_color = Color(c.x, c.y, c.z, c.w)
	
	visual_instance.position = visual.origin_xyz
	visual_instance.rotation = visual.origin_rpy
	
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

func _create_collision_shape(collider: URDFCollider) -> CollisionShape3D:
	var collision_shape = CollisionShape3D.new()
	collision_shape.name = "Collision"
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
		_:
			push_error("Unsupported collider type: ", collider.type)
	
	collision_shape.position = collider.origin_xyz
	collision_shape.rotation = collider.origin_rpy
	return collision_shape
