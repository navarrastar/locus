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
	vertex_count:  u32,
	vertex_buffer: ^sdl.GPUBuffer,
	indices:       []Index,
	index_count:   u32,
	index_buffer:  ^sdl.GPUBuffer,
	material_type: MaterialType,
	diffuse:       ^Texture,
	normal:        ^Texture,
	emissive:      ^Texture,
	skin:          Maybe(Skeleton)
}

Pos     :: m.Vec3
Color   :: m.Vec4
UV      :: m.Vec2
Normal  :: m.Vec3
Tangent :: m.Vec3
Joints  :: m.Vec4
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
    material_type: MaterialType = .Mesh
    
    vertex_size := size_of(Vertex_PosColNormUVTanSkin)
    vertex_stride := size_of(Vertex_PosColNormUVTanSkin) / size_of(f32)
    
    // Load the model - validation is done in loader_validate
    model := gltf_load(name)
    mesh := model.meshes[0]
    primitive := mesh.primitives[0]

    // Get attribute accessors
    position_accessor_idx := primitive.attributes["POSITION"]
    normal_accessor_idx   := primitive.attributes["NORMAL"]
    color_accessor_idx    := primitive.attributes["COLOR_0"]
    uv_accessor_idx       := primitive.attributes["TEXCOORD_0"]
    tan_accessor_idx      := primitive.attributes["TANGENT"]
    joints_accessor_idx   := primitive.attributes["JOINTS_0"]
    weights_accessor_idx  := primitive.attributes["WEIGHTS_0"]
    
    // Get Indices
    indices_accessor := model.accessors[primitive.indices.?]
    index_count := u32(indices_accessor.count)
    indices_buffer := gltf.buffer_slice(model, primitive.indices.?)
    indices_array := indices_buffer.([]u16)
    
    indices_dst := make([]Index, len(indices_array))
    for index, i in indices_array {
        fmt.assertf(index <= 65535, "Index value %d exceeds u16 max value (65535)", index)
        indices_dst[i] = index
    }

    // Get Vertices
    position_accessor := model.accessors[position_accessor_idx]
    vertex_count := u32(position_accessor.count)
    
    // We need to create vertices array for all vertex attributes
    vertices_dst := make([]f32, vertex_count * u32(vertex_stride))
    
    // Extract all attribute data
    positions_buffer := gltf.buffer_slice(model, position_accessor_idx)
    positions_array := positions_buffer.([][3]f32)
    
    normals_buffer := gltf.buffer_slice(model, normal_accessor_idx)
    normals_array := normals_buffer.([][3]f32)
    
    colors_buffer := gltf.buffer_slice(model, color_accessor_idx)
    colors_array := colors_buffer.([][4]u8)
    
    uvs_buffer := gltf.buffer_slice(model, uv_accessor_idx)
    uvs_array := uvs_buffer.([][2]f32)
    
    tangents_buffer := gltf.buffer_slice(model, tan_accessor_idx)
    tangents_array := tangents_buffer.([][4]f32)
    
    joints_buffer := gltf.buffer_slice(model, joints_accessor_idx)
    joints_array := joints_buffer.([][4]u8)
    
    weights_buffer := gltf.buffer_slice(model, weights_accessor_idx)
    weights_array := weights_buffer.([][4]f32)
    
    // Fill the interleaved vertex data array
    for i := 0; i < int(vertex_count); i += 1 {
        base_idx := i * vertex_stride
        
        // Position
        pos := positions_array[i]
        vertices_dst[base_idx + 0] = pos[0]
        vertices_dst[base_idx + 1] = pos[1]
        vertices_dst[base_idx + 2] = pos[2]
        
        // Color
        color := colors_array[i]
        vertices_dst[base_idx + 3] = f32(color[0])
        vertices_dst[base_idx + 4] = f32(color[1])
        vertices_dst[base_idx + 5] = f32(color[2])
        vertices_dst[base_idx + 6] = f32(color[3])
        
        // UV
        uv := uvs_array[i]
        vertices_dst[base_idx + 7] = uv[0]
        vertices_dst[base_idx + 8] = uv[1]
        
        // Normal
        normal := normals_array[i]
        vertices_dst[base_idx + 9] = normal[0]
        vertices_dst[base_idx + 10] = normal[1]
        vertices_dst[base_idx + 11] = normal[2]
        
        // Tangent
        tangent := tangents_array[i]
        vertices_dst[base_idx + 12] = tangent[0]
        vertices_dst[base_idx + 13] = tangent[1]
        vertices_dst[base_idx + 14] = tangent[2]
        
        // Joints
        joint := joints_array[i]
        vertices_dst[base_idx + 15] = f32(joint[0])
        vertices_dst[base_idx + 16] = f32(joint[1])
        vertices_dst[base_idx + 17] = f32(joint[2])
        vertices_dst[base_idx + 18] = f32(joint[3])
        
        // Weights
        weight := weights_array[i]
        vertices_dst[base_idx + 19] = weight[0]
        vertices_dst[base_idx + 20] = weight[1]
        vertices_dst[base_idx + 21] = weight[2]
        vertices_dst[base_idx + 22] = weight[3]
    }
    
    // Get Diffuse Texture
    gltf_material_idx := primitive.material.?
    gltf_material := model.materials[gltf_material_idx]
    bct_idx := gltf_material.metallic_roughness.?.base_color_texture.?.index
    bct := model.textures[bct_idx]
    bct_image_idx := bct.source.?
    diffuse := texture_create_from_gltf_image(model, bct_image_idx)

    // Create base geometry
    geometry := Geometry {
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

    // Process skinning data if available
    if len(model.skins) > 0 && len(model.animations) > 0 {
        gltf_skin := model.skins[0]
        
        
        // Create skin
        skeleton: Skeleton
        skeleton.anims = make([]Animation, len(model.animations))
        skeleton.name = gltf_skin.name != nil ? string(gltf_skin.name.?) : "unnamed_skin"
        
        // Get inverse bind matrices
        ibm_accessor_idx := gltf_skin.inverse_bind_matrices.?
        ibm_data := gltf.buffer_slice(model, ibm_accessor_idx)
        
        // Create joints
        skeleton.joints = make([]Joint, len(gltf_skin.joints))
        skeleton.joint_matrices = make([]m.Mat4, len(gltf_skin.joints))
        
        // Process joints
        for &joint, j in skeleton.joints {
            node_idx := gltf_skin.joints[j]
            
            joint.name = model.nodes[node_idx].name.?
            joint.node_idx = int(node_idx)
            joint.inverse_bind_mat = ibm_data.([]m.Mat4)[j]
            
            node := model.nodes[node_idx]
            joint.deformed_pos   = node.translation
            joint.deformed_rot   = node.rotation
            joint.deformed_scale = node.scale
            joint.undeformed_mat = node.mat
            
            skeleton.node_to_joint_idx[int(node_idx)] = j
        }
        
        load_joint(model^, &skeleton, int(gltf_skin.joints[0]), -1) // recursive
        
        // Create animations
        skeleton.anims = make([]Animation, len(model.animations))
        
        // Process animations
        for gltf_anim, a in model.animations {
            anim := Animation{
                time_scale = 1,
                weight = 1,
                start = max(f32),
                end = min(f32),
            }
            
            // Process animation samplers
            anim.samplers = make([]Sampler, len(gltf_anim.samplers))
            for gltf_sampler, s in gltf_anim.samplers {
                sampler := &anim.samplers[s]
                
                // Set interpolation type
                switch gltf_sampler.interpolation {
                case .Linear:
                    sampler.interpolation = .Linear
                case .Step:
                    sampler.interpolation = .Step
                case .Cubic_Spline:
                    sampler.interpolation = .Linear
                }
                
                // Process timestamps
                input_data := gltf.buffer_slice(model, gltf_sampler.input)
                if times, ok := input_data.([]f32); ok {
                    sampler.timestamps = make([]f32, len(times))
                    for time, t in times {
                        sampler.timestamps[t] = time
                        
                        // Update animation time range
                        if time < anim.start do anim.start = time
                        if time > anim.end do anim.end = time
                    }
                }
                
                // Process values
                output_data := gltf.buffer_slice(model, gltf_sampler.output)
                if vec3_values, ok := output_data.([][3]f32); ok {
                    sampler.values = make([]m.Vec4, len(vec3_values))
                    for value, v in vec3_values {
                        sampler.values[v] = {value[0], value[1], value[2], 0}
                    }
                } else if vec4_values, ok2 := output_data.([][4]f32); ok2 {
                    sampler.values = make([]m.Vec4, len(vec4_values))
                    for value, v in vec4_values {
                        sampler.values[v] = {value[0], value[1], value[2], value[3]}
                    }
                }
            }
            
            // Process animation channels
            anim.channels = make([]Channel, len(gltf_anim.channels))
            for gltf_channel, i in gltf_anim.channels {
                channel := &anim.channels[i]
                
                channel.sampler_idx = gltf_channel.sampler
                target := gltf_channel.target
                channel.node_idx = int(target.node.?)
                
                // Set the target path
                switch target.path {
                case .Translation:
                    channel.path = .Translation
                case .Rotation:
                    channel.path = .Rotation
                case .Scale:
                    channel.path = .Scale
                case .Weights:
                    // Skip weights animation
                    continue
                }
            }
            
            // Store the animation in the skin
            skeleton.anims[a] = anim
            }
        
        // Assign the skin to the geometry
        geometry.skin = skeleton
    }

    return geometry
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

ATTRIBUTES_POS_COL_NORM_UV_TAN_SKIN :: [?]sdl.GPUVertexAttribute {
	sdl.GPUVertexAttribute {
		location = 0,
		format = .FLOAT3,
		offset = u32(offset_of(Vertex_PosColNormUVTanSkin, pos)),
	},
	sdl.GPUVertexAttribute {
		location = 1,
		format = .FLOAT4,
		offset = u32(offset_of(Vertex_PosColNormUVTanSkin, color)),
	},
	sdl.GPUVertexAttribute {
		location = 2,
		format = .FLOAT3,
		offset = u32(offset_of(Vertex_PosColNormUVTanSkin, normal)),
	},
	sdl.GPUVertexAttribute {
		location = 3,
		format = .FLOAT2,
		offset = u32(offset_of(Vertex_PosColNormUVTanSkin, uv)),
	},
	sdl.GPUVertexAttribute {
	    location = 4,
		format = .FLOAT3,
		offset = u32(offset_of(Vertex_PosColNormUVTanSkin, tangent)),
	},
	sdl.GPUVertexAttribute {
		location = 5,
		format = .FLOAT4,
		offset = u32(offset_of(Vertex_PosColNormUVTanSkin, joints)),
	},
	sdl.GPUVertexAttribute {
		location = 6,
		format = .FLOAT4,
		offset = u32(offset_of(Vertex_PosColNormUVTanSkin, weights)),
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

Vertex_PosColNormUVTanSkin :: struct {
	pos:     Pos,
	color:   Color,
	uv:      UV,
	normal:  Normal,
	tangent: Tangent,
	joints:  Joints,
	weights: Weights,
}
