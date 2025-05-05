package game

import m "../math"

// Uniform buffer for object transformations
GPUObjectBuffer :: struct {
    model: m.Mat4
}

// Uniform buffer for world transforms
GPUWorldBuffer :: struct {
    view: m.Mat4,
    proj: m.Mat4,
}

// Uniform buffer for test shader
GPUTestBuffer :: struct {
    test: m.Vec4
}

// Uniform buffer for joint matrices used in skinning
GPUSkinBuffer :: struct {
    joint_matrices: [100]m.Mat4, // MAX_JOINTS = 100 as defined in mesh.vert.hlsl
}