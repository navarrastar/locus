package math2

import "core:math/linalg"

Vec2 :: linalg.Vector2f32
Vec3 :: linalg.Vector3f32
Vec4 :: linalg.Vector4f32
Mat4 :: linalg.Matrix4x4f32
Quat :: linalg.Quaternionf32

IDENTITY_MAT :: linalg.MATRIX4F32_IDENTITY
IDENTITY_QUAT :: linalg.QUATERNIONF32_IDENTITY

DEFAULT_TRANSFORM :: Transform{
    pos = Vec3{0, 0, 0},
    rot = Vec3{0, 0, 0},
    scale = 1,
}



Transform :: struct {
    pos: Vec3,
    rot: Vec3,
    scale: f32,
}

quat :: proc{ quat_from_euler, quat_from_4f32 }

@(require_results)
quat_from_euler :: proc(euler: Vec3) -> Quat {
    return linalg.quaternion_from_euler_angles_f32(euler.x, euler.y, euler.z, linalg.Euler_Angle_Order.XYZ)
}

@(require_results)
quat_from_4f32 :: proc(q: [4]f32) -> (quat: Quat) {
    quat.x = q[0]
    quat.y = q[1]
    quat.z = q[2]
    quat.w = q[3]
    return quat
}

@(require_results)
euler :: proc(quat: Quat) -> Vec3 {
    x, y, z := linalg.euler_angles_from_quaternion_f32(quat, linalg.Euler_Angle_Order.XYZ)
    return Vec3{x, y, z}
}

@(require_results)
cross :: proc(a: Vec3, b: Vec3) -> Vec3 {
    return linalg.vector_cross3(a, b)
}

@(require_results)
dot :: proc(a: Vec3, b: Vec3) -> f32 {
    return linalg.vector_dot(a, b)
}

@(require_results)
normalize :: proc(v: Vec3) -> Vec3 {
    return linalg.vector_normalize(v)
}

@(require_results)
length :: proc(v: Vec3) -> f32 {
    return linalg.vector_length(v)
}

@(require_results)
look_at :: proc(position: Vec3, target: Vec3, up: Vec3) -> Mat4 {
    return linalg.matrix4_look_at_f32(position, target, up)
}

@(require_results)
perspective :: proc(fov: f32, aspect: f32, near: f32, far: f32) -> Mat4 {
    return linalg.matrix4_perspective_f32(fov, aspect, near, far)
}

@(require_results)
ortho :: proc(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) -> Mat4 {
    return linalg.matrix_ortho3d_f32(left, right, bottom, top, near, far)
}

@(require_results)
to_radians :: proc(degrees: f32) -> f32 {
    return linalg.to_radians(degrees)
}

@(require_results)
to_degrees :: proc(radians: f32) -> f32 {
    return linalg.to_degrees(radians)
}

@(require_results)
to_matrix :: proc(pos: Vec3, rot: Vec3, scale: f32) -> Mat4 {
    quaternion := quat_from_euler(rot)
    
    translation := linalg.matrix4_translate_f32(pos)
    rotation := linalg.matrix4_from_quaternion_f32(quaternion)
    scaling := linalg.matrix4_scale_f32(Vec3{scale, scale, scale})

    return linalg.matrix_mul(translation, linalg.matrix_mul(rotation, scaling))
}

@(require_results)
mvp :: proc(pos: Vec3, rot: Vec3, scale: f32, view: Mat4, proj: Mat4) -> Mat4 {
    return linalg.matrix_mul(view, linalg.matrix_mul(proj, to_matrix(pos, rot, scale)))
}

@(require_results)
matrix_rotate :: proc(angle_radians: f32, v: Vec3) -> Mat4 {
    return linalg.matrix4_rotate_f32(angle_radians, v)
}

