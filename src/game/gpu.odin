package game

import m "../math"

GPUObjectBuffer :: struct {
    model: m.Mat4
}

GPUWorldBuffer :: struct {
    view: m.Mat4,
    proj: m.Mat4,
}

GPUTestBuffer :: struct {
    test: m.Vec4
}