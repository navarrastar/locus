package game

import sdl "vendor:sdl3"

import m "../math"



Geometry :: struct {
    model_matrix:  m.Mat4,
    vertices:      []f32,
    vertex_size:   u32,

    vertex_buffer: ^sdl.GPUBuffer,
    vertex_count:  u32,
    index_buffer:  ^sdl.GPUBuffer,
    index_count:   u32,
    material_type: MaterialType,
}

Pos       :: m.Vec3
Color     :: m.Vec4
UV        :: m.Vec2
Normal    :: m.Vec3
Tangent   :: m.Vec3
Joints    :: [4]u8
Weights   :: m.Vec4

COLOR_WHITE : [4]f32 : { 1, 1, 1, 1 }

DEFAULT_TRIANGLE_VERTICES :: [21]f32 {
//    Position       Color       
       0, 1, 0,   1, 1, 1, 1,   
    -0.5, 0, 0,   1, 1, 1, 1,
     0.5, 0, 0,   1, 1, 1, 1
}

DEFAULT_RECTANGLE_VERTICES :: [28]f32 {
//     Position         Color     
    -0.5, -0.5, 0,   1, 1, 1, 1, // bl
    -0.5,  0.5, 0,   1, 1, 1, 1, // tl
     0.5,  0.5, 0,   1, 1, 1, 1, // tr
     0.5, -0.5, 0,   1, 1, 1, 1, // br
}

DEFAULT_GRID_VERTICES :: [28]f32 {
//    Position        Color
    -100, 0,  100,   1, 1, 1, 1,
     100, 0,  100,   1, 1, 1, 1,
     100, 0, -100,   1, 1, 1, 1,
    -100, 0, -100,   1, 1, 1, 1,
}

DEFAULT_CUBE_VERTICES :: [168]f32 {
    // Position         Color
    // Front
    -0.5, -0.5,  0.5,   1, 1, 1, 1, // bl
    -0.5,  0.5,  0.5,   1, 1, 1, 1, // tl
     0.5,  0.5,  0.5,   1, 1, 1, 1, // tr
     0.5, -0.5,  0.5,   1, 1, 1, 1, // br
    // Left
    -0.5, -0.5, -0.5,   1, 1, 1, 1, // bl
    -0.5,  0.5, -0.5,   1, 1, 1, 1, // tl
    -0.5,  0.5,  0.5,   1, 1, 1, 1, // tr
    -0.5, -0.5,  0.5,   1, 1, 1, 1, // br
    // Back
     0.5, -0.5, -0.5,   1, 1, 1, 1, // bl
     0.5,  0.5, -0.5,   1, 1, 1, 1, // tl
    -0.5,  0.5, -0.5,   1, 1, 1, 1, // tr
    -0.5, -0.5, -0.5,   1, 1, 1, 1, // br
    // Right
     0.5, -0.5,  0.5,   1, 1, 1, 1, // bl
     0.5,  0.5,  0.5,   1, 1, 1, 1, // tl
     0.5,  0.5, -0.5,   1, 1, 1, 1, // tr
     0.5, -0.5, -0.5,   1, 1, 1, 1, // br
    // Top
    -0.5,  0.5,  0.5,   1, 1, 1, 1, // bl
    -0.5,  0.5, -0.5,   1, 1, 1, 1, // tl
     0.5,  0.5, -0.5,   1, 1, 1, 1, // tr
     0.5,  0.5,  0.5,   1, 1, 1, 1, // br
    // Bottom
    -0.5, -0.5, -0.5,   1, 1, 1, 1, // bl
    -0.5, -0.5,  0.5,   1, 1, 1, 1, // tl
     0.5, -0.5,  0.5,   1, 1, 1, 1, // tr
     0.5, -0.5, -0.5,   1, 1, 1, 1, // br
}



Vertex_PosColor :: struct {
    pos:   Pos,
    color: Color,
}

Vertex_PosColorNormal :: struct {
    pos:    Pos,
    color:  Color,
    normal: Normal,
}

MeshVertex :: struct {
    pos:     Pos,
    color:   Color,
    uv:      UV,
    normal:  Normal,
    tangent: Tangent,
    joints:  Joints,
    weights: Weights
}



triangle :: proc(
    v1: Pos = { DEFAULT_TRIANGLE_VERTICES[0], DEFAULT_TRIANGLE_VERTICES[1], DEFAULT_TRIANGLE_VERTICES[2] },
    v2: Pos = { DEFAULT_TRIANGLE_VERTICES[7], DEFAULT_TRIANGLE_VERTICES[8], DEFAULT_TRIANGLE_VERTICES[9] },
    v3: Pos = { DEFAULT_TRIANGLE_VERTICES[14], DEFAULT_TRIANGLE_VERTICES[15], DEFAULT_TRIANGLE_VERTICES[16] },
    color: Color = COLOR_WHITE,
    material: MaterialType = .Default) -> Geometry {
    vertices_start := len(every_vertex)
    
    // Calculate normal
    edge1 := v2 - v1
    edge2 := v3 - v1
    normal := m.normalize(m.cross(edge1, edge2))
    
    append(&every_vertex, 
        v1.x, v1.y, v1.z, color.x, color.y, color.z, color.w, normal.x, normal.y, normal.z,
        v2.x, v2.y, v2.z, color.x, color.y, color.z, color.w, normal.x, normal.y, normal.z,
        v3.x, v3.y, v3.z, color.x, color.y, color.z, color.w, normal.x, normal.y, normal.z,
    )
    return Geometry {
        model_matrix = m.IDENTITY_MAT,
        vertices = every_vertex[vertices_start:vertices_start+30],
        vertex_count = 3,
        vertex_size = size_of(Vertex_PosColorNormal),
        material_type = material
    }
}

rectangle :: proc(
    bl: Pos = { DEFAULT_RECTANGLE_VERTICES[0], DEFAULT_RECTANGLE_VERTICES[1], DEFAULT_RECTANGLE_VERTICES[2] },
    br: Pos = { DEFAULT_RECTANGLE_VERTICES[7], DEFAULT_RECTANGLE_VERTICES[8], DEFAULT_RECTANGLE_VERTICES[9] },
    tr: Pos = { DEFAULT_RECTANGLE_VERTICES[14], DEFAULT_RECTANGLE_VERTICES[15], DEFAULT_RECTANGLE_VERTICES[16] },
    tl: Pos = { DEFAULT_RECTANGLE_VERTICES[21], DEFAULT_RECTANGLE_VERTICES[22], DEFAULT_RECTANGLE_VERTICES[23] },
    color: Color = COLOR_WHITE,
    material: MaterialType = .Default) -> Geometry {
    vertices_start := len(every_vertex)
    
    // Calculate normal
    edge1 := br - bl
    edge2 := tl - bl
    normal := m.normalize(m.cross(edge1, edge2))
    
    append(&every_vertex,
        bl.x, bl.y, bl.z, color.x, color.y, color.z, color.w, normal.x, normal.y, normal.z,
        br.x, br.y, br.z, color.x, color.y, color.z, color.w, normal.x, normal.y, normal.z,
        tr.x, tr.y, tr.z, color.x, color.y, color.z, color.w, normal.x, normal.y, normal.z,
        tl.x, tl.y, tl.z, color.x, color.y, color.z, color.w, normal.x, normal.y, normal.z,
        tr.x, tr.y, tr.z, color.x, color.y, color.z, color.w, normal.x, normal.y, normal.z,
        bl.x, bl.y, bl.z, color.x, color.y, color.z, color.w, normal.x, normal.y, normal.z,
    )
    return Geometry {
        model_matrix = m.IDENTITY_MAT,
        vertices = every_vertex[vertices_start:vertices_start+60],
        vertex_count = 6,
        vertex_size = size_of(Vertex_PosColorNormal),
        material_type = material
    }
}

grid :: proc(
    bl: Pos = { DEFAULT_GRID_VERTICES[0], DEFAULT_GRID_VERTICES[1], DEFAULT_GRID_VERTICES[2] },
    br: Pos = { DEFAULT_GRID_VERTICES[7], DEFAULT_GRID_VERTICES[8], DEFAULT_GRID_VERTICES[9] },
    tr: Pos = { DEFAULT_GRID_VERTICES[14], DEFAULT_GRID_VERTICES[15], DEFAULT_GRID_VERTICES[16] },
    tl: Pos = { DEFAULT_GRID_VERTICES[21], DEFAULT_GRID_VERTICES[22], DEFAULT_GRID_VERTICES[23] },
    color: Color = COLOR_WHITE,
    material: MaterialType = .Grid) -> Geometry {
    vertices_start := len(every_vertex)
    
    append(&every_vertex,
        bl.x, bl.y, bl.z, color.x, color.y, color.z, color.w,
        br.x, br.y, br.z, color.x, color.y, color.z, color.w,
        tr.x, tr.y, tr.z, color.x, color.y, color.z, color.w,
        tl.x, tl.y, tl.z, color.x, color.y, color.z, color.w,
        tr.x, tr.y, tr.z, color.x, color.y, color.z, color.w,
        bl.x, bl.y, bl.z, color.x, color.y, color.z, color.w,
    )
    return Geometry {
        model_matrix = m.IDENTITY_MAT,
        vertices = every_vertex[vertices_start:vertices_start+42],
        vertex_count = 6,
        vertex_size = size_of(Vertex_PosColor),
        material_type = material
    }
}

cube :: proc(color: Color = COLOR_WHITE, material: MaterialType = .Default) -> Geometry {
    vertices_start := len(every_vertex)
    
    // Define face normals
    front_normal  := m.Vec3{ 0,  0,  1}
    back_normal   := m.Vec3{ 0,  0, -1}
    left_normal   := m.Vec3{-1,  0,  0}
    right_normal  := m.Vec3{ 1,  0,  0}
    top_normal    := m.Vec3{ 0,  1,  0}
    bottom_normal := m.Vec3{ 0, -1,  0}
    
    // Front face
    append(&every_vertex,
        // Front
        -0.5, -0.5,  0.5, color.x, color.y, color.z, color.w, front_normal.x, front_normal.y, front_normal.z,
        -0.5,  0.5,  0.5, color.x, color.y, color.z, color.w, front_normal.x, front_normal.y, front_normal.z,
         0.5,  0.5,  0.5, color.x, color.y, color.z, color.w, front_normal.x, front_normal.y, front_normal.z,
         0.5, -0.5,  0.5, color.x, color.y, color.z, color.w, front_normal.x, front_normal.y, front_normal.z,
         0.5,  0.5,  0.5, color.x, color.y, color.z, color.w, front_normal.x, front_normal.y, front_normal.z,
        -0.5, -0.5,  0.5, color.x, color.y, color.z, color.w, front_normal.x, front_normal.y, front_normal.z,
        
        // Left
        -0.5, -0.5, -0.5, color.x, color.y, color.z, color.w, left_normal.x, left_normal.y, left_normal.z,
        -0.5,  0.5, -0.5, color.x, color.y, color.z, color.w, left_normal.x, left_normal.y, left_normal.z,
        -0.5,  0.5,  0.5, color.x, color.y, color.z, color.w, left_normal.x, left_normal.y, left_normal.z,
        -0.5, -0.5,  0.5, color.x, color.y, color.z, color.w, left_normal.x, left_normal.y, left_normal.z,
        -0.5,  0.5,  0.5, color.x, color.y, color.z, color.w, left_normal.x, left_normal.y, left_normal.z,
        -0.5, -0.5, -0.5, color.x, color.y, color.z, color.w, left_normal.x, left_normal.y, left_normal.z,
        
        // Back
         0.5, -0.5, -0.5, color.x, color.y, color.z, color.w, back_normal.x, back_normal.y, back_normal.z,
         0.5,  0.5, -0.5, color.x, color.y, color.z, color.w, back_normal.x, back_normal.y, back_normal.z,
        -0.5,  0.5, -0.5, color.x, color.y, color.z, color.w, back_normal.x, back_normal.y, back_normal.z,
        -0.5, -0.5, -0.5, color.x, color.y, color.z, color.w, back_normal.x, back_normal.y, back_normal.z,
        -0.5,  0.5, -0.5, color.x, color.y, color.z, color.w, back_normal.x, back_normal.y, back_normal.z,
         0.5, -0.5, -0.5, color.x, color.y, color.z, color.w, back_normal.x, back_normal.y, back_normal.z,
        
        // Right
         0.5, -0.5,  0.5, color.x, color.y, color.z, color.w, right_normal.x, right_normal.y, right_normal.z,
         0.5,  0.5,  0.5, color.x, color.y, color.z, color.w, right_normal.x, right_normal.y, right_normal.z,
         0.5,  0.5, -0.5, color.x, color.y, color.z, color.w, right_normal.x, right_normal.y, right_normal.z,
         0.5, -0.5, -0.5, color.x, color.y, color.z, color.w, right_normal.x, right_normal.y, right_normal.z,
         0.5,  0.5, -0.5, color.x, color.y, color.z, color.w, right_normal.x, right_normal.y, right_normal.z,
         0.5, -0.5,  0.5, color.x, color.y, color.z, color.w, right_normal.x, right_normal.y, right_normal.z,
        
        // Top
        -0.5,  0.5,  0.5, color.x, color.y, color.z, color.w, top_normal.x, top_normal.y, top_normal.z,
        -0.5,  0.5, -0.5, color.x, color.y, color.z, color.w, top_normal.x, top_normal.y, top_normal.z,
         0.5,  0.5, -0.5, color.x, color.y, color.z, color.w, top_normal.x, top_normal.y, top_normal.z,
         0.5,  0.5,  0.5, color.x, color.y, color.z, color.w, top_normal.x, top_normal.y, top_normal.z,
         0.5,  0.5, -0.5, color.x, color.y, color.z, color.w, top_normal.x, top_normal.y, top_normal.z,
        -0.5,  0.5,  0.5, color.x, color.y, color.z, color.w, top_normal.x, top_normal.y, top_normal.z,
        
        // Bottom
        -0.5, -0.5, -0.5, color.x, color.y, color.z, color.w, bottom_normal.x, bottom_normal.y, bottom_normal.z,
        -0.5, -0.5,  0.5, color.x, color.y, color.z, color.w, bottom_normal.x, bottom_normal.y, bottom_normal.z,
         0.5, -0.5,  0.5, color.x, color.y, color.z, color.w, bottom_normal.x, bottom_normal.y, bottom_normal.z,
         0.5, -0.5, -0.5, color.x, color.y, color.z, color.w, bottom_normal.x, bottom_normal.y, bottom_normal.z,
         0.5, -0.5,  0.5, color.x, color.y, color.z, color.w, bottom_normal.x, bottom_normal.y, bottom_normal.z,
        -0.5, -0.5, -0.5, color.x, color.y, color.z, color.w, bottom_normal.x, bottom_normal.y, bottom_normal.z,
    )
    
    return Geometry {
        model_matrix = m.IDENTITY_MAT,
        vertices = every_vertex[vertices_start:vertices_start+360], // 36 vertices * 10 components each
        vertex_count = 36, // 6 faces * 6 vertices per face
        vertex_size = size_of(Vertex_PosColorNormal),
        material_type = material
    }
}

capsule :: proc(
    radius: f32 = 0.5,
    half_height: f32 = 1.0,
    segments: int = 16,
    rings: int = 8,
    color: Color = COLOR_WHITE,
    material: MaterialType = .Default
) -> Geometry {
    vertices_start := len(every_vertex)
    
    // Calculate the number of vertices needed
    vertex_count := 0
    
    // Vertices for top hemisphere
    for ring := 0; ring < rings; ring += 1 {
        ring_angle1 := f32(ring) * m.PI / (2 * f32(rings))
        ring_angle2 := f32(ring + 1) * m.PI / (2 * f32(rings))
        
        for segment := 0; segment < segments; segment += 1 {
            segment_angle1 := f32(segment) * 2 * m.PI / f32(segments)
            segment_angle2 := f32(segment + 1) * 2 * m.PI / f32(segments)
            
            // First triangle
            x1 := radius * m.cos(ring_angle1) * m.cos(segment_angle1)
            y1 := radius * m.sin(ring_angle1) + half_height
            z1 := radius * m.cos(ring_angle1) * m.sin(segment_angle1)
            nx1 := m.cos(ring_angle1) * m.cos(segment_angle1)
            ny1 := m.sin(ring_angle1)
            nz1 := m.cos(ring_angle1) * m.sin(segment_angle1)
            
            x2 := radius * m.cos(ring_angle1) * m.cos(segment_angle2)
            y2 := radius * m.sin(ring_angle1) + half_height
            z2 := radius * m.cos(ring_angle1) * m.sin(segment_angle2)
            nx2 := m.cos(ring_angle1) * m.cos(segment_angle2)
            ny2 := m.sin(ring_angle1)
            nz2 := m.cos(ring_angle1) * m.sin(segment_angle2)
            
            x3 := radius * m.cos(ring_angle2) * m.cos(segment_angle2)
            y3 := radius * m.sin(ring_angle2) + half_height
            z3 := radius * m.cos(ring_angle2) * m.sin(segment_angle2)
            nx3 := m.cos(ring_angle2) * m.cos(segment_angle2)
            ny3 := m.sin(ring_angle2)
            nz3 := m.cos(ring_angle2) * m.sin(segment_angle2)
            
            append(&every_vertex,
                x1, y1, z1, color.x, color.y, color.z, color.w, nx1, ny1, nz1,
                x2, y2, z2, color.x, color.y, color.z, color.w, nx2, ny2, nz2,
                x3, y3, z3, color.x, color.y, color.z, color.w, nx3, ny3, nz3,
            )
            
            // Second triangle
            x4 := radius * m.cos(ring_angle2) * m.cos(segment_angle1)
            y4 := radius * m.sin(ring_angle2) + half_height
            z4 := radius * m.cos(ring_angle2) * m.sin(segment_angle1)
            nx4 := m.cos(ring_angle2) * m.cos(segment_angle1)
            ny4 := m.sin(ring_angle2)
            nz4 := m.cos(ring_angle2) * m.sin(segment_angle1)
            
            append(&every_vertex,
                x1, y1, z1, color.x, color.y, color.z, color.w, nx1, ny1, nz1,
                x3, y3, z3, color.x, color.y, color.z, color.w, nx3, ny3, nz3,
                x4, y4, z4, color.x, color.y, color.z, color.w, nx4, ny4, nz4,
            )
            
            vertex_count += 6
        }
    }
    
    // Vertices for cylinder body
    for segment := 0; segment < segments; segment += 1 {
        angle1 := f32(segment) * 2 * m.PI / f32(segments)
        angle2 := f32(segment + 1) * 2 * m.PI / f32(segments)
        
        x1 := radius * m.cos(angle1)
        z1 := radius * m.sin(angle1)
        nx1 := m.cos(angle1)
        nz1 := m.sin(angle1)
        
        x2 := radius * m.cos(angle2)
        z2 := radius * m.sin(angle2)
        nx2 := m.cos(angle2)
        nz2 := m.sin(angle2)
        
        // First triangle
        append(&every_vertex,
            x1, half_height, z1, color.x, color.y, color.z, color.w, nx1, 0, nz1,
            x2, half_height, z2, color.x, color.y, color.z, color.w, nx2, 0, nz2,
            x2, -half_height, z2, color.x, color.y, color.z, color.w, nx2, 0, nz2,
        )
        
        // Second triangle
        append(&every_vertex,
            x1, half_height, z1, color.x, color.y, color.z, color.w, nx1, 0, nz1,
            x2, -half_height, z2, color.x, color.y, color.z, color.w, nx2, 0, nz2,
            x1, -half_height, z1, color.x, color.y, color.z, color.w, nx1, 0, nz1,
        )
        
        vertex_count += 6
    }
    
    // Vertices for bottom hemisphere
    for ring := 0; ring < rings; ring += 1 {
        ring_angle1 := f32(ring) * m.PI / (2 * f32(rings))
        ring_angle2 := f32(ring + 1) * m.PI / (2 * f32(rings))
        
        for segment := 0; segment < segments; segment += 1 {
            segment_angle1 := f32(segment) * 2 * m.PI / f32(segments)
            segment_angle2 := f32(segment + 1) * 2 * m.PI / f32(segments)
            
            // First triangle
            x1 := radius * m.cos(ring_angle1) * m.cos(segment_angle1)
            y1 := -radius * m.sin(ring_angle1) - half_height
            z1 := radius * m.cos(ring_angle1) * m.sin(segment_angle1)
            nx1 := m.cos(ring_angle1) * m.cos(segment_angle1)
            ny1 := -m.sin(ring_angle1)
            nz1 := m.cos(ring_angle1) * m.sin(segment_angle1)
            
            x2 := radius * m.cos(ring_angle1) * m.cos(segment_angle2)
            y2 := -radius * m.sin(ring_angle1) - half_height
            z2 := radius * m.cos(ring_angle1) * m.sin(segment_angle2)
            nx2 := m.cos(ring_angle1) * m.cos(segment_angle2)
            ny2 := -m.sin(ring_angle1)
            nz2 := m.cos(ring_angle1) * m.sin(segment_angle2)
            
            x3 := radius * m.cos(ring_angle2) * m.cos(segment_angle2)
            y3 := -radius * m.sin(ring_angle2) - half_height
            z3 := radius * m.cos(ring_angle2) * m.sin(segment_angle2)
            nx3 := m.cos(ring_angle2) * m.cos(segment_angle2)
            ny3 := -m.sin(ring_angle2)
            nz3 := m.cos(ring_angle2) * m.sin(segment_angle2)
            
            append(&every_vertex,
                x1, y1, z1, color.x, color.y, color.z, color.w, nx1, ny1, nz1,
                x2, y2, z2, color.x, color.y, color.z, color.w, nx2, ny2, nz2,
                x3, y3, z3, color.x, color.y, color.z, color.w, nx3, ny3, nz3,
            )
            
            // Second triangle
            x4 := radius * m.cos(ring_angle2) * m.cos(segment_angle1)
            y4 := -radius * m.sin(ring_angle2) - half_height
            z4 := radius * m.cos(ring_angle2) * m.sin(segment_angle1)
            nx4 := m.cos(ring_angle2) * m.cos(segment_angle1)
            ny4 := -m.sin(ring_angle2)
            nz4 := m.cos(ring_angle2) * m.sin(segment_angle1)
            
            append(&every_vertex,
                x1, y1, z1, color.x, color.y, color.z, color.w, nx1, ny1, nz1,
                x3, y3, z3, color.x, color.y, color.z, color.w, nx3, ny3, nz3,
                x4, y4, z4, color.x, color.y, color.z, color.w, nx4, ny4, nz4,
            )
            
            vertex_count += 6
        }
    }
    
    return Geometry {
        model_matrix = m.IDENTITY_MAT,
        vertices = every_vertex[vertices_start:vertices_start + vertex_count * 10],
        vertex_count = u32(vertex_count),
        vertex_size = size_of(Vertex_PosColorNormal),
        material_type = material,
    }
}
   


MESH_ATTRIBUTES :: [?]sdl.GPUVertexAttribute {
    // Position
    sdl.GPUVertexAttribute {
        location = 0,
        format = .FLOAT3,
        offset = u32(offset_of(MeshVertex, pos))
    },
    // Color
    sdl.GPUVertexAttribute {
        location = 1,
        format = .FLOAT4,
        offset = u32(offset_of(MeshVertex, color))
    },
    // UV
    sdl.GPUVertexAttribute {
        location = 2,
        format = .FLOAT2,
        offset = u32(offset_of(MeshVertex, uv))
    },
    // Normal
    sdl.GPUVertexAttribute {
        location = 3,
        format = .FLOAT3,
        offset = u32(offset_of(MeshVertex, normal))
    },
    // Tangent
    sdl.GPUVertexAttribute {
        location = 4,
        format = .FLOAT4,
        offset = u32(offset_of(MeshVertex, tangent))
    },
    // Joints
    sdl.GPUVertexAttribute {
        location = 5,
        format = .UINT4,
        offset = u32(offset_of(MeshVertex, joints))
    },
    // Weights
    sdl.GPUVertexAttribute {
        location = 6,
        format = .FLOAT4,
        offset = u32(offset_of(MeshVertex, weights))
    }
}

ATTRIBUTES_POS_COLOR :: [?]sdl.GPUVertexAttribute {
    sdl.GPUVertexAttribute {
        location = 0,
        format = .FLOAT3, 
        offset = u32(offset_of(Vertex_PosColorNormal, pos))
    },
    sdl.GPUVertexAttribute {
        location = 1,
        format = .FLOAT4,
        offset = u32(offset_of(Vertex_PosColorNormal, color)),
    },
    sdl.GPUVertexAttribute {
        location = 3,
        format = .FLOAT3,
        offset = u32(offset_of(Vertex_PosColorNormal, normal)),
    }
}






