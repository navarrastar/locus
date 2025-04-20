package game

import sdl "vendor:sdl3"

import m "pkg:math"



Geometry :: struct {
    model_matrix:  m.Mat4,
    vertices:      []f32,
    vertex_size:   u32,

    vertex_buffer: ^sdl.GPUBuffer,
    vertex_count:  u32,
    index_buffer:  ^sdl.GPUBuffer,
    index_count:   u32,
    material:      Material,
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
    -0.5, -0.5, 0,   1, 1, 1, 1,
    -0.5,  0.5, 0,   1, 1, 1, 1,
     0.5,  0.5, 0,   1, 1, 1, 1,
     0.5, -0.5, 0,   1, 1, 1, 1,
}

DEFAULT_GRID_VERTICES :: [28]f32 {
//    Position        Color
    -100, 0,  100,   1, 1, 1, 1,
     100, 0,  100,   1, 1, 1, 1,
     100, 0, -100,   1, 1, 1, 1,
    -100, 0, -100,   1, 1, 1, 1,
} 



Vertex_PosColor :: struct {
    pos:   Pos,
    color: Color,
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
    append(&every_vertex, 
        v1.x, v1.y, v1.z, color.x, color.y, color.z, color.w,
        v2.x, v2.y, v2.z, color.x, color.y, color.z, color.w,
        v3.x, v3.y, v3.z, color.x, color.y, color.z, color.w,
    )
    return Geometry {
        model_matrix = m.IDENTITY_MAT,
        vertices = every_vertex[vertices_start:vertices_start+21],
        vertex_count = 3,
        vertex_size = size_of(Vertex_PosColor),
        material = materials[material]
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
        material = materials[material]
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
        material = materials[material]
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
        offset = u32(offset_of(Vertex_PosColor, pos))
    },
    sdl.GPUVertexAttribute {
        location = 1,
        format = .FLOAT4,
        offset = u32(offset_of(Vertex_PosColor, color)),
    }
}






