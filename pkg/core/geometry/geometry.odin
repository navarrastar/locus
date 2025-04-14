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