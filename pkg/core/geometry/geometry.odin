package geometry

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

    vertices: [3]m.Vec3,
    color: [4]u8
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

triangle :: proc(v1, v2, v3: m.Vec3, color: [4]u8) -> Triangle {
    return Triangle {
        vertices = {v1, v2, v3},
        color = color,
    }
}