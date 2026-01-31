@tool
extends EditorImportPlugin

func _get_importer_name():
	return "stl.importer"
	
func _get_visible_name():
	return "STL Importer"
	
func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["stl"])
	
func _get_save_extension():
	return "mesh"
	
func _get_resource_type():
	return "Mesh"
	
func _get_preset_count():
	return 0
	
func _get_import_options(path: String, preset_index: int) -> Array[Dictionary]:
	return []
	
func _get_preset_name(preset):
	return "Unknown"
	
func _import(source_file: String, save_path: String, options: Dictionary, platform_variants: Array[String], gen_files: Array[String]):
	# STL file format: https://web.archive.org/web/20210428125112/http://www.fabbers.com/tech/STL_Format
	
	var file := FileAccess.open(source_file, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	if is_ascii_stl(file):
		print("load ascii file", source_file)
		process_ascii_stl(file, surface_tool)
	else:
		print("load binary file", source_file)
		process_binary_stl(file, surface_tool)
	
	var final_mesh := surface_tool.commit()
	return ResourceSaver.save(final_mesh, "%s.%s" % [save_path, _get_save_extension()])
	
func is_ascii_stl(file: FileAccess):
	# binary STL has a 80 character header which cannot begin with "solid"
	# ASCII STL begins with "solid"
	# so if first 5 bytes say "solid" it should be an ASCII file,
	# however there are non-ASCII files in the wild that have a "solid" header
	
	var file_len: int = file.get_length()
	if file_len < 84:
		file.seek(0)
		return true

	file.seek(0)
	var beginning_bytes: PackedByteArray = file.get_buffer(5)
	var header_start: String = beginning_bytes.get_string_from_ascii()
	if header_start != "solid":
		file.seek(0)
		return false
	
	# Binary STL structure
	# Bytes 0-79: Header
	# Bytes 80-83: Number of triangles (Unsigned 32-bit Integer, Little Endian)
	# Bytes 84+: Triangle data (50 bytes per triangle)
	file.seek(80)
	var triangle_count = file.get_32() # Reads 4 bytes as little-endian integer
	
	# Calculate what the size WOULD be if this is a valid binary STL
	var expected_binary_size = 84 + (triangle_count * 50)
	
	var is_ascii = false
	
	if file_len == expected_binary_size:
		is_ascii = false
	else:
		# If sizes don't match, the "solid" header wasn't a lie
		is_ascii = true

	# Reset cursor and return
	file.seek(0)
	return is_ascii

# Helper to read 32-bit floats.
# Godot 4s get_floats reads 64 bit, which corrupts STL data
func get_float32(file: FileAccess) -> float:
	var buffer := file.get_buffer(4)
	return buffer.decode_float(0)

func process_binary_stl(file: FileAccess, surface_tool: SurfaceTool):
	# first 80 bytes is an ASCII header, this is not important and can be skipped
	file.seek(80)
	
	# next 4 bytes is the number of facets the file contains
	var number_of_facets: int = file.get_32()
	
	for i in range(number_of_facets):
		# first there will be 3 floats for the normals
		var normal_x := get_float32(file)
		var normal_y := get_float32(file)
		var normal_z := get_float32(file)
		surface_tool.set_normal(Vector3(normal_x, normal_y, normal_z))
		
		# then there wil be 3 vertices
		# STL lists its vertices in counterclockwise order
		# while Godot uses clockwise order for front faces in primitive triangle mode
		# so we will temporarily store them and when we leave a facet add the vertices to surface_tool
		var vertices: Array[Vector3] = []
		for j in range(3):
			var x := get_float32(file)
			var y := get_float32(file)
			var z := get_float32(file)
			vertices.insert(0, Vector3(x, y, z))
		
		for vec in vertices:
			surface_tool.add_vertex(vec)
		
		# lastly there are 2 bytes that contain the attribute byte count
		# this should be 0 but we will skipp the given amount to be sure we 
		# process the rest of the file correctly
		var attribute_byte_count := file.get_16()
		file.seek(file.get_position() + attribute_byte_count)
	
func process_ascii_stl(file: FileAccess, surface_tool: SurfaceTool):
	# STL lists its vertices in counterclockwise order
	# while Godot uses clockwise order for front faces in primitive triangle mode
	# so we will temporarily store them and when we leave a facet add the vertices to surface_tool
	var vertices: Array[Vector3] = []
	
	# first line should be in the format "solid name"
	# we are going to ignore the name
	file.get_line()
	
	var parsing_state := PARSE_STATE.SOLID
	
	while !file.eof_reached():
		if parsing_state == PARSE_STATE.SOLID:
			var line := file.get_line().strip_edges(true, true)
			
			# last line should be "endsolid name"
			# just continue because the loop should end because EOF reached
			if line.begins_with("endsolid"):
				continue
			elif line != "":
				var parts = line.split(" ")
				
				# first 2 items of the parts array should be "facet" and "normal"
				# the next 3 items should be the normals
				var normal_x = float(parts[2])
				var normal_y = float(parts[3])
				var normal_z = float(parts[4])
				surface_tool.add_normal(Vector3(normal_x, normal_y, normal_z))
				
				parsing_state = PARSE_STATE.FACET
				
		elif parsing_state == PARSE_STATE.FACET:
			var line := file.get_line().strip_edges(true, true)
			
			if line == "endfacet":
				parsing_state = PARSE_STATE.SOLID
			elif line != "":
				# line should be "outer loop"
				# we can ignore this line and continue on to parsing the vertices
				parsing_state = PARSE_STATE.OUTER_LOOP
		
		elif parsing_state == PARSE_STATE.OUTER_LOOP:
			var line := file.get_line().strip_edges(true, true)
			
			if line == "endloop":
				for vec in vertices:
					surface_tool.add_vertex(vec)
					
				vertices.clear()
				parsing_state = PARSE_STATE.FACET
			elif line != "":
				var parts = line.split(" ")
				
				# first item of the parts array should be "vertex"
				# the next 3 items should be the vertex coordinates
				var x := float(parts[1])
				var y := float(parts[2])
				var z := float(parts[3])
				
				# add the vertex at the front of the array 
				# this way we don't have to loop over the array in reverse
                # to add the vertices to the mesh
                vertices.insert(0, Vector3(x, y, z))

enum PARSE_STATE {SOLID, FACET, OUTER_LOOP}
