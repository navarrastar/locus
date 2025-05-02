package game

import "core:fmt"
import "core:mem"
import sdl "vendor:sdl3"

import gltf "../../third_party/gltf2"

import m "../math"

Index :: u16

Geometry :: struct {
	model_matrix:  m.Mat4,
	vertices:      []f32,
	vertex_size:   int,
	vertex_stride: int,
	vertex_buffer: ^sdl.GPUBuffer,
	vertex_count:  u32,
	indices:       []Index,
	index_buffer:  ^sdl.GPUBuffer,
	index_count:   u32,
	material_type: MaterialType,
	diffuse:       ^Texture,
	normal:        ^Texture,
	emissive:      ^Texture,
}

Pos :: m.Vec3
Color :: m.Vec4
UV :: m.Vec2
Normal :: m.Vec3
Tangent :: m.Vec3
Joints :: [4]u8
Weights :: m.Vec4

COLOR_WHITE: [4]f32 : {1, 1, 1, 1}
COLOR_BLACK: [4]f32 : {0, 0, 0, 1}
COLOR_RED: [4]f32 : {1, 0, 0, 1}
COLOR_GREEN: [4]f32 : {0, 1, 0, 1}
COLOR_BLUE: [4]f32 : {0, 0, 1, 1}
COLOR_YELLOW: [4]f32 : {1, 1, 0, 1}
COLOR_MAGENTA: [4]f32 : {1, 0, 1, 1}
COLOR_CYAN: [4]f32 : {0, 1, 1, 1}
COLOR_GRAY: [4]f32 : {0.5, 0.5, 0.5, 1}
COLOR_ORANGE: [4]f32 : {1, 0.5, 0, 1}
COLOR_PURPLE: [4]f32 : {0.5, 0, 0.5, 1}
COLOR_BROWN: [4]f32 : {0.6, 0.4, 0.2, 1}


DEFAULT_TRIANGLE_VERTICES :: [21]f32 {
	//    Position       Color
	0,
	1,
	0,
	1,
	1,
	1,
	1,
	-0.5,
	0,
	0,
	1,
	1,
	1,
	1,
	0.5,
	0,
	0,
	1,
	1,
	1,
	1,
}

DEFAULT_RECTANGLE_VERTICES :: [28]f32 {
	//     Position         Color
	-0.5,
	-0.5,
	0,
	1,
	1,
	1,
	1, // bl
	-0.5,
	0.5,
	0,
	1,
	1,
	1,
	1, // tl
	0.5,
	0.5,
	0,
	1,
	1,
	1,
	1, // tr
	0.5,
	-0.5,
	0,
	1,
	1,
	1,
	1, // br
}

DEFAULT_GRID_VERTICES :: [28]f32 {
	//    Position        Color
	-100,
	0,
	100,
	1,
	1,
	1,
	1,
	100,
	0,
	100,
	1,
	1,
	1,
	1,
	100,
	0,
	-100,
	1,
	1,
	1,
	1,
	-100,
	0,
	-100,
	1,
	1,
	1,
	1,
}

DEFAULT_CUBE_VERTICES :: [168]f32 {
	// Position         Color
	// Front
	-0.5,
	-0.5,
	0.5,
	1,
	1,
	1,
	1, // bl
	-0.5,
	0.5,
	0.5,
	1,
	1,
	1,
	1, // tl
	0.5,
	0.5,
	0.5,
	1,
	1,
	1,
	1, // tr
	0.5,
	-0.5,
	0.5,
	1,
	1,
	1,
	1, // br
	// Left
	-0.5,
	-0.5,
	-0.5,
	1,
	1,
	1,
	1, // bl
	-0.5,
	0.5,
	-0.5,
	1,
	1,
	1,
	1, // tl
	-0.5,
	0.5,
	0.5,
	1,
	1,
	1,
	1, // tr
	-0.5,
	-0.5,
	0.5,
	1,
	1,
	1,
	1, // br
	// Back
	0.5,
	-0.5,
	-0.5,
	1,
	1,
	1,
	1, // bl
	0.5,
	0.5,
	-0.5,
	1,
	1,
	1,
	1, // tl
	-0.5,
	0.5,
	-0.5,
	1,
	1,
	1,
	1, // tr
	-0.5,
	-0.5,
	-0.5,
	1,
	1,
	1,
	1, // br
	// Right
	0.5,
	-0.5,
	0.5,
	1,
	1,
	1,
	1, // bl
	0.5,
	0.5,
	0.5,
	1,
	1,
	1,
	1, // tl
	0.5,
	0.5,
	-0.5,
	1,
	1,
	1,
	1, // tr
	0.5,
	-0.5,
	-0.5,
	1,
	1,
	1,
	1, // br
	// Top
	-0.5,
	0.5,
	0.5,
	1,
	1,
	1,
	1, // bl
	-0.5,
	0.5,
	-0.5,
	1,
	1,
	1,
	1, // tl
	0.5,
	0.5,
	-0.5,
	1,
	1,
	1,
	1, // tr
	0.5,
	0.5,
	0.5,
	1,
	1,
	1,
	1, // br
	// Bottom
	-0.5,
	-0.5,
	-0.5,
	1,
	1,
	1,
	1, // bl
	-0.5,
	-0.5,
	0.5,
	1,
	1,
	1,
	1, // tl
	0.5,
	-0.5,
	0.5,
	1,
	1,
	1,
	1, // tr
	0.5,
	-0.5,
	-0.5,
	1,
	1,
	1,
	1, // br
}


triangle :: proc(
	v1: Pos = {
		DEFAULT_TRIANGLE_VERTICES[0],
		DEFAULT_TRIANGLE_VERTICES[1],
		DEFAULT_TRIANGLE_VERTICES[2],
	},
	v2: Pos = {
		DEFAULT_TRIANGLE_VERTICES[7],
		DEFAULT_TRIANGLE_VERTICES[8],
		DEFAULT_TRIANGLE_VERTICES[9],
	},
	v3: Pos = {
		DEFAULT_TRIANGLE_VERTICES[14],
		DEFAULT_TRIANGLE_VERTICES[15],
		DEFAULT_TRIANGLE_VERTICES[16],
	},
	color: Color = COLOR_WHITE,
	material: MaterialType = .Default,
) -> Geometry {
	// Calculate normal
	edge1 := v2 - v1
	edge2 := v3 - v1
	normal := m.normalize(m.cross(edge1, edge2))

	// Find the lowest y value to adjust relative to bottom
	min_y := min(v1.y, min(v2.y, v3.y))

	// Adjust vertices so bottom is at y=0
	adjusted_v1 := v1 - {0, min_y, 0}
	adjusted_v2 := v2 - {0, min_y, 0}
	adjusted_v3 := v3 - {0, min_y, 0}

	vertices_dst := make([]f32, 30)
	
	vertices_src := [30]f32 {
		adjusted_v1.x,
		adjusted_v1.y,
		adjusted_v1.z,
		color.x,
		color.y,
		color.z,
		color.w,
		normal.x,
		normal.y,
		normal.z,
		adjusted_v2.x,
		adjusted_v2.y,
		adjusted_v2.z,
		color.x,
		color.y,
		color.z,
		color.w,
		normal.x,
		normal.y,
		normal.z,
		adjusted_v3.x,
		adjusted_v3.y,
		adjusted_v3.z,
		color.x,
		color.y,
		color.z,
		color.w,
		normal.x,
		normal.y,
		normal.z,
	}
	
	mem.copy(raw_data(vertices_dst), &vertices_src, size_of(vertices_src))

	indices_dst := make([]Index, 3)
	indices_src := [3]Index{0, 1, 2}
	
	mem.copy(raw_data(indices_dst), &indices_src, size_of(indices_src))
	
	return Geometry {
		model_matrix = m.IDENTITY_MAT,
		vertices = vertices_dst,
		vertex_count = 3,
		vertex_size = size_of(Vertex_PosColNorm),
		vertex_stride = size_of(Vertex_PosColNorm) / size_of(f32),
		indices = indices_dst,
		index_count = 3,
		material_type = material,
	}
}

rectangle :: proc(
	bl: Pos = {
		DEFAULT_RECTANGLE_VERTICES[0],
		DEFAULT_RECTANGLE_VERTICES[1],
		DEFAULT_RECTANGLE_VERTICES[2],
	},
	br: Pos = {
		DEFAULT_RECTANGLE_VERTICES[7],
		DEFAULT_RECTANGLE_VERTICES[8],
		DEFAULT_RECTANGLE_VERTICES[9],
	},
	tr: Pos = {
		DEFAULT_RECTANGLE_VERTICES[14],
		DEFAULT_RECTANGLE_VERTICES[15],
		DEFAULT_RECTANGLE_VERTICES[16],
	},
	tl: Pos = {
		DEFAULT_RECTANGLE_VERTICES[21],
		DEFAULT_RECTANGLE_VERTICES[22],
		DEFAULT_RECTANGLE_VERTICES[23],
	},
	color: Color = COLOR_WHITE,
	material: MaterialType = .Default,
) -> Geometry {
	// Calculate normal
	edge1 := br - bl
	edge2 := tl - bl
	normal := m.normalize(m.cross(edge1, edge2))

	// Find the lowest y value to adjust relative to bottom
	min_y := min(bl.y, min(br.y, min(tr.y, tl.y)))

	// Adjust vertices so bottom is at y=0
	adjusted_bl := bl - {0, min_y, 0}
	adjusted_br := br - {0, min_y, 0}
	adjusted_tr := tr - {0, min_y, 0}
	adjusted_tl := tl - {0, min_y, 0}

	vertices_dst := make([]f32, 40) // 4 vertices * 10 components each
	vertices_src := [40]f32 {
		// Position        Color                   Normal
		adjusted_bl.x, adjusted_bl.y, adjusted_bl.z, color.x, color.y, color.z, color.w, normal.x, normal.y, normal.z,
		adjusted_br.x, adjusted_br.y, adjusted_br.z, color.x, color.y, color.z, color.w, normal.x, normal.y, normal.z,
		adjusted_tr.x, adjusted_tr.y, adjusted_tr.z, color.x, color.y, color.z, color.w, normal.x, normal.y, normal.z,
		adjusted_tl.x, adjusted_tl.y, adjusted_tl.z, color.x, color.y, color.z, color.w, normal.x, normal.y, normal.z,
	}

	mem.copy(raw_data(vertices_dst), &vertices_src, size_of(vertices_src))

	// Add indices for two triangles that make the rectangle
	// First triangle: bl, br, tr
	// Second triangle: bl, tr, tl
	indices_dst := make([]Index, 6)
	indices_src := [6]Index {0, 1, 2, 0, 2, 3}

	mem.copy(raw_data(indices_dst), &indices_src, size_of(indices_src))

	return Geometry {
		model_matrix = m.IDENTITY_MAT,
		vertices = vertices_dst,
		vertex_count = 4,
		vertex_size = size_of(Vertex_PosColNorm),
		vertex_stride = size_of(Vertex_PosColNorm) / size_of(f32),
		indices = indices_dst,
		index_count = 6,
		material_type = material,
	}
}

grid :: proc(
	bl: Pos = {DEFAULT_GRID_VERTICES[0], DEFAULT_GRID_VERTICES[1], DEFAULT_GRID_VERTICES[2]},
	br: Pos = {DEFAULT_GRID_VERTICES[7], DEFAULT_GRID_VERTICES[8], DEFAULT_GRID_VERTICES[9]},
	tr: Pos = {DEFAULT_GRID_VERTICES[14], DEFAULT_GRID_VERTICES[15], DEFAULT_GRID_VERTICES[16]},
	tl: Pos = {DEFAULT_GRID_VERTICES[21], DEFAULT_GRID_VERTICES[22], DEFAULT_GRID_VERTICES[23]},
	color: Color = COLOR_WHITE,
	material: MaterialType = .Grid,
) -> Geometry {
	vertices_dst := make([]f32, 28) // 4 vertices * 7 components each (position + color)
	vertices_src := [28]f32 {
		// Position        Color
		bl.x, bl.y, bl.z, color.x, color.y, color.z, color.w,
		br.x, br.y, br.z, color.x, color.y, color.z, color.w,
		tr.x, tr.y, tr.z, color.x, color.y, color.z, color.w,
		tl.x, tl.y, tl.z, color.x, color.y, color.z, color.w,
	}

	mem.copy(raw_data(vertices_dst), &vertices_src, size_of(vertices_src))

	// Add indices for the grid (two triangles)
	indices_dst := make([]Index, 6)
	indices_src := [6]Index {0, 1, 2, 0, 2, 3}

	mem.copy(raw_data(indices_dst), &indices_src, size_of(indices_src))

	return Geometry {
		model_matrix = m.IDENTITY_MAT,
		vertices = vertices_dst,
		vertex_count = 4,
		vertex_size = size_of(Vertex_PosCol),
		vertex_stride = size_of(Vertex_PosCol) / size_of(f32),
		indices = indices_dst,
		index_count = 6,
		material_type = material,
	}
}

cube :: proc(color: Color = COLOR_WHITE, material: MaterialType = .Default) -> Geometry {
	// Define face normals
	front_normal := m.Vec3{0, 0, 1}
	back_normal := m.Vec3{0, 0, -1}
	left_normal := m.Vec3{-1, 0, 0}
	right_normal := m.Vec3{1, 0, 0}
	top_normal := m.Vec3{0, 1, 0}
	bottom_normal := m.Vec3{0, -1, 0}

	// Adjust y coordinates so bottom face is at y=0 instead of center
	// This means shifting everything up by 0.5
	y_offset: f32 = 0.5

	// Create vertices array
	vertices_dst := make([]f32, 240) // 24 vertices * 10 components each
	vertices_src := [240]f32 {
		// Front face
		-0.5, -0.5 + y_offset, 0.5, color.x, color.y, color.z, color.w, front_normal.x, front_normal.y, front_normal.z,
		-0.5, 0.5 + y_offset, 0.5, color.x, color.y, color.z, color.w, front_normal.x, front_normal.y, front_normal.z,
		0.5, 0.5 + y_offset, 0.5, color.x, color.y, color.z, color.w, front_normal.x, front_normal.y, front_normal.z,
		0.5, -0.5 + y_offset, 0.5, color.x, color.y, color.z, color.w, front_normal.x, front_normal.y, front_normal.z,
		
		// Left face
		-0.5, -0.5 + y_offset, -0.5, color.x, color.y, color.z, color.w, left_normal.x, left_normal.y, left_normal.z,
		-0.5, 0.5 + y_offset, -0.5, color.x, color.y, color.z, color.w, left_normal.x, left_normal.y, left_normal.z,
		-0.5, 0.5 + y_offset, 0.5, color.x, color.y, color.z, color.w, left_normal.x, left_normal.y, left_normal.z,
		-0.5, -0.5 + y_offset, 0.5, color.x, color.y, color.z, color.w, left_normal.x, left_normal.y, left_normal.z,
		
		// Back face
		0.5, -0.5 + y_offset, -0.5, color.x, color.y, color.z, color.w, back_normal.x, back_normal.y, back_normal.z,
		0.5, 0.5 + y_offset, -0.5, color.x, color.y, color.z, color.w, back_normal.x, back_normal.y, back_normal.z,
		-0.5, 0.5 + y_offset, -0.5, color.x, color.y, color.z, color.w, back_normal.x, back_normal.y, back_normal.z,
		-0.5, -0.5 + y_offset, -0.5, color.x, color.y, color.z, color.w, back_normal.x, back_normal.y, back_normal.z,
		
		// Right face
		0.5, -0.5 + y_offset, 0.5, color.x, color.y, color.z, color.w, right_normal.x, right_normal.y, right_normal.z,
		0.5, 0.5 + y_offset, 0.5, color.x, color.y, color.z, color.w, right_normal.x, right_normal.y, right_normal.z,
		0.5, 0.5 + y_offset, -0.5, color.x, color.y, color.z, color.w, right_normal.x, right_normal.y, right_normal.z,
		0.5, -0.5 + y_offset, -0.5, color.x, color.y, color.z, color.w, right_normal.x, right_normal.y, right_normal.z,
		
		// Top face
		-0.5, 0.5 + y_offset, 0.5, color.x, color.y, color.z, color.w, top_normal.x, top_normal.y, top_normal.z,
		-0.5, 0.5 + y_offset, -0.5, color.x, color.y, color.z, color.w, top_normal.x, top_normal.y, top_normal.z,
		0.5, 0.5 + y_offset, -0.5, color.x, color.y, color.z, color.w, top_normal.x, top_normal.y, top_normal.z,
		0.5, 0.5 + y_offset, 0.5, color.x, color.y, color.z, color.w, top_normal.x, top_normal.y, top_normal.z,
		
		// Bottom face
		-0.5, -0.5 + y_offset, -0.5, color.x, color.y, color.z, color.w, bottom_normal.x, bottom_normal.y, bottom_normal.z,
		-0.5, -0.5 + y_offset, 0.5, color.x, color.y, color.z, color.w, bottom_normal.x, bottom_normal.y, bottom_normal.z,
		0.5, -0.5 + y_offset, 0.5, color.x, color.y, color.z, color.w, bottom_normal.x, bottom_normal.y, bottom_normal.z,
		0.5, -0.5 + y_offset, -0.5, color.x, color.y, color.z, color.w, bottom_normal.x, bottom_normal.y, bottom_normal.z,
	}

	mem.copy(raw_data(vertices_dst), &vertices_src, size_of(vertices_src))

	// Create indices for each face (2 triangles per face, 6 faces)
	indices_dst := make([]Index, 36) // 6 faces * 6 indices per face
	indices_src := [36]Index {
		// Front face
		0, 1, 2, 0, 2, 3,
		// Left face
		4, 5, 6, 4, 6, 7,
		// Back face
		8, 9, 10, 8, 10, 11,
		// Right face
		12, 13, 14, 12, 14, 15,
		// Top face
		16, 17, 18, 16, 18, 19,
		// Bottom face
		20, 21, 22, 20, 22, 23,
	}

	mem.copy(raw_data(indices_dst), &indices_src, size_of(indices_src))

	return Geometry {
		model_matrix  = m.IDENTITY_MAT,
		vertices      = vertices_dst,
		vertex_count  = 24, // 6 faces * 4 vertices per face
		vertex_size   = size_of(Vertex_PosColNorm),
		vertex_stride = size_of(Vertex_PosColNorm) / size_of(f32),
		indices       = indices_dst,
		index_count   = 36, // 6 faces * 6 indices per face
		material_type = material,
	}
}

mesh :: proc(name: string) -> Geometry {
   	// Each .glb file should only have one mesh.
	// You must split meshes into seperate .glb files
	// and load them seperately
	// 
	// The mesh must meet the following requirements:
	// At least POSITION, COLOR_0, NORMAL, TEXCOORD_0 attributes
	// 16 bit indices
	// base_color_texture
	// Only one primitive on the mesh
    
	model, err := gltf_load(name)
	fmt.assertf(model != nil && err == nil, "{}", err)

	if len(model.meshes) <= 0 {
		fmt.assertf(false, "Model %s does not contain any meshes", name)
		return {}
	}

	mesh := model.meshes[0]
	if len(mesh.primitives) <= 0 {
		fmt.assertf(false, "Mesh in model %s does not contain any primitives", name)
		return {}
	}

	// Get the first primitive in the mesh
	primitive := mesh.primitives[0]

	position_accessor_idx, _ := primitive.attributes["POSITION"]
	normal_accessor_idx,   _ := primitive.attributes["NORMAL"]
	color_accessor_idx,    _ := primitive.attributes["COLOR_0"]
	uv_accessor_idx,       _ := primitive.attributes["TEXCOORD_0"]

	index_count: u32 = 0
	indices_dst: []Index

	// Get index data from accessor
	indices_accessor := model.accessors[primitive.indices.?]
	index_count = u32(indices_accessor.count)

	// Get the indices from the buffer
	indices_buffer := gltf.buffer_slice(model, primitive.indices.?)

	#partial switch indices_array in indices_buffer {
	case []u16:
	    indices_dst = make([]Index, len(indices_array))
		for idx, i in indices_array {
			fmt.assertf(idx <= 65535, "Index value %d exceeds u16 max value (65535)", idx)
			indices_dst[i] = idx
		}
	case:
		panic("")
	}

	position_accessor := model.accessors[position_accessor_idx]
	vertex_count := u32(position_accessor.count)

	positions := gltf.buffer_slice(model, position_accessor_idx)

	vertices_dst: []f32

	#partial switch positions_array in positions {
	case [][3]f32:
		vertices_dst = make([]f32, int(vertex_count * 12))

		vi := 0 // vertex index for our destination buffer
		for i in 0 ..< len(positions_array) {
			pos := positions_array[i]

			// Default values
			color: [4]f32 = COLOR_WHITE
			normal: [3]f32 = {0, 1, 0}
			uv: [2]f32 = {0, 0}

			colors := gltf.buffer_slice(model, color_accessor_idx)
			if colors_vec4, ok := colors.([][4]f32); ok && i < len(colors_vec4) {
				color = colors_vec4[i]
			} else if colors_vec3, ok2 := colors.([][3]f32); ok2 && i < len(colors_vec3) {
				color = {colors_vec3[i][0], colors_vec3[i][1], colors_vec3[i][2], 1.0}
			}

			normals := gltf.buffer_slice(model, normal_accessor_idx)
			if normals_vec3, ok := normals.([][3]f32); ok && i < len(normals_vec3) {
				normal = normals_vec3[i]
			}

			// Add position, color, normal
			vertices_dst[vi] = pos[0]; vi += 1
			vertices_dst[vi] = pos[1]; vi += 1
			vertices_dst[vi] = pos[2]; vi += 1
			vertices_dst[vi] = color[0]; vi += 1
			vertices_dst[vi] = color[1]; vi += 1
			vertices_dst[vi] = color[2]; vi += 1
			vertices_dst[vi] = color[3]; vi += 1
			vertices_dst[vi] = normal[0]; vi += 1
			vertices_dst[vi] = normal[1]; vi += 1
			vertices_dst[vi] = normal[2]; vi += 1

			uvs := gltf.buffer_slice(model, uv_accessor_idx)
			if uvs_vec2, ok := uvs.([][2]f32); ok && i < len(uvs_vec2) {
				uv = uvs_vec2[i]
			}
			vertices_dst[vi] = uv[0]; vi += 1
			vertices_dst[vi] = uv[1]; vi += 1
		}
	case:
		fmt.assertf(false, "Unsupported position format in mesh %s", name)
		return {}
	}
	
	material_type: MaterialType = .Mesh

	diffuse: ^Texture = nil
	assert(primitive.material != nil)
	material_idx := primitive.material.?
	gltf_material := model.materials[material_idx]

	assert(gltf_material.metallic_roughness != nil)
	assert(gltf_material.metallic_roughness.?.base_color_texture != nil)

	texture_idx := gltf_material.metallic_roughness.?.base_color_texture.?.index
	gltf_texture := model.textures[texture_idx]

	assert(gltf_texture.source != nil)
	image_idx := gltf_texture.source.?
	diffuse = texture_create_from_gltf_image(model, int(image_idx))

	assert(diffuse != nil)

	vertex_size   := size_of(Vertex_PosColNormUV)
	vertex_stride := size_of(Vertex_PosColNormUV) / size_of(f32)

	return Geometry {
		model_matrix = m.IDENTITY_MAT,
		vertices = vertices_dst[:],
		vertex_count = vertex_count,
		vertex_size = vertex_size,
		vertex_stride = vertex_stride,
		indices = indices_dst[:],
		index_count = index_count,
		material_type = material_type,
		diffuse = diffuse,
	}
}


ATTRIBUTES_POS_COL :: [?]sdl.GPUVertexAttribute {
	sdl.GPUVertexAttribute {
		location = 0,
		format = .FLOAT3,
		offset = u32(offset_of(Vertex_PosCol, pos)),
	},
	sdl.GPUVertexAttribute {
		location = 1,
		format = .FLOAT4,
		offset = u32(offset_of(Vertex_PosCol, color)),
	},
}

ATTRIBUTES_POS_COL_NORM :: [?]sdl.GPUVertexAttribute {
	sdl.GPUVertexAttribute {
		location = 0,
		format = .FLOAT3,
		offset = u32(offset_of(Vertex_PosColNorm, pos)),
	},
	sdl.GPUVertexAttribute {
		location = 1,
		format = .FLOAT4,
		offset = u32(offset_of(Vertex_PosColNorm, color)),
	},
	sdl.GPUVertexAttribute {
		location = 2,
		format = .FLOAT3,
		offset = u32(offset_of(Vertex_PosColNorm, normal)),
	},
}

ATTRIBUTES_POS_COL_NORM_UV :: [?]sdl.GPUVertexAttribute {
	sdl.GPUVertexAttribute {
		location = 0,
		format = .FLOAT3,
		offset = u32(offset_of(Vertex_PosColNormUV, pos)),
	},
	sdl.GPUVertexAttribute {
		location = 1,
		format = .FLOAT4,
		offset = u32(offset_of(Vertex_PosColNormUV, color)),
	},
	sdl.GPUVertexAttribute {
		location = 2,
		format = .FLOAT3,
		offset = u32(offset_of(Vertex_PosColNormUV, normal)),
	},
	sdl.GPUVertexAttribute {
		location = 3,
		format = .FLOAT2,
		offset = u32(offset_of(Vertex_PosColNormUV, uv)),
	},
}

ATTRIBUTES_POS_COL_NORM_UV_TAN :: [?]sdl.GPUVertexAttribute {
	sdl.GPUVertexAttribute {
		location = 0,
		format = .FLOAT3,
		offset = u32(offset_of(Vertex_PosColNormUVTan, pos)),
	},
	sdl.GPUVertexAttribute {
		location = 1,
		format = .FLOAT4,
		offset = u32(offset_of(Vertex_PosColNormUVTan, color)),
	},
	sdl.GPUVertexAttribute {
		location = 2,
		format = .FLOAT3,
		offset = u32(offset_of(Vertex_PosColNormUVTan, normal)),
	},
	sdl.GPUVertexAttribute {
		location = 3,
		format = .FLOAT2,
		offset = u32(offset_of(Vertex_PosColNormUVTan, uv)),
	},
	sdl.GPUVertexAttribute {
		location = 4,
		format = .FLOAT3,
		offset = u32(offset_of(Vertex_PosColNormUVTan, tan)),
	},
}

ATTRIBUTES_ALL :: [?]sdl.GPUVertexAttribute {
	sdl.GPUVertexAttribute {
		location = 0,
		format = .FLOAT3,
		offset = u32(offset_of(Vertex_AllAttributes, pos)),
	},
	sdl.GPUVertexAttribute {
		location = 1,
		format = .FLOAT4,
		offset = u32(offset_of(Vertex_AllAttributes, color)),
	},
	sdl.GPUVertexAttribute {
		location = 3,
		format = .FLOAT3,
		offset = u32(offset_of(Vertex_AllAttributes, normal)),
	},
	sdl.GPUVertexAttribute {
		location = 2,
		format = .FLOAT2,
		offset = u32(offset_of(Vertex_AllAttributes, uv)),
	},
	sdl.GPUVertexAttribute {
		location = 4,
		format = .FLOAT4,
		offset = u32(offset_of(Vertex_AllAttributes, tangent)),
	},
	sdl.GPUVertexAttribute {
		location = 5,
		format = .UINT4,
		offset = u32(offset_of(Vertex_AllAttributes, joints)),
	},
	sdl.GPUVertexAttribute {
		location = 6,
		format = .FLOAT4,
		offset = u32(offset_of(Vertex_AllAttributes, weights)),
	},
}

Vertex_PosCol :: struct {
	pos:   Pos,
	color: Color,
}

Vertex_PosColNorm :: struct {
	pos:    Pos,
	color:  Color,
	normal: Normal,
}

Vertex_PosColNormUV :: struct {
	pos:    Pos,
	color:  Color,
	normal: Normal,
	uv:     UV,
}

Vertex_PosColNormUVTan :: struct {
	pos:    Pos,
	color:  Color,
	normal: Normal,
	uv:     UV,
	tan:    Tangent,
}

Vertex_AllAttributes :: struct {
	pos:     Pos,
	color:   Color,
	uv:      UV,
	normal:  Normal,
	tangent: Tangent,
	joints:  Joints,
	weights: Weights,
}
