package geometry

import sdl "vendor:sdl3"

import m "pkg:core/math"

Geometry :: union {
    Mesh,
    Triangle,
    Pyramid,
    Rectangle,
    Cube,
    Circle,
    Sphere,
    Capsule,
    Cylinder
}

Mesh :: struct {
    using transform: m.Transform,
    model_matrix: m.Mat4
}

Triangle :: struct {
    using transform: m.Transform,
    model_matrix: m.Mat4,

    vertices: [3]TriangleVertex,
}

Pyramid :: struct {

}

Rectangle :: struct {

}

Cube :: struct {

}

Circle :: struct {

}

Sphere :: struct {

}

Capsule :: struct {

}

Cylinder :: struct {

}

TriangleVertex :: struct {
    pos: m.Vec3,
    color: m.Vec4
}

triangle_attributes :: proc() -> [2]sdl.GPUVertexAttribute {
    return {
        sdl.GPUVertexAttribute {
            location = 0,
            format = .FLOAT3, 
            offset = u32(offset_of(TriangleVertex, pos))
        },
        sdl.GPUVertexAttribute {
            location = 1,
            format = .FLOAT4,
            offset = u32(offset_of(TriangleVertex, color)),
        }
    }
}


triangle :: proc(v1, v2, v3: m.Vec3, color: m.Vec4) -> Triangle {
    return Triangle {
        vertices = { 
            { pos = v1, color = color },
            { pos = v2, color = color },
            { pos = v3, color = color },
        }
    }
}