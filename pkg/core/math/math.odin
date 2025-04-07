package math2

import "core:math/linalg"

Vec2 :: linalg.Vector2f32
Vec3 :: linalg.Vector3f32
Vec4 :: linalg.Vector4f32
Mat4 :: linalg.Matrix4x4f32
Quat :: linalg.Quaternionf32

IDENTITY_MAT :: linalg.MATRIX4F32_IDENTITY 
IDENTITY_QUAT :: linalg.QUATERNIONF32_IDENTITY

quat :: proc{quat_from_euler, quat_from_4f32}

quat_from_euler :: proc(euler: Vec3) -> Quat {
    return linalg.quaternion_from_euler_angles_f32(euler.x, euler.y, euler.z, linalg.Euler_Angle_Order.XYZ)
}

quat_from_4f32 :: proc(q: [4]f32) -> (quat: Quat) {
    quat.x = q[0]
    quat.y = q[1]
    quat.z = q[2]
    quat.w = q[3]
    return quat
}

euler :: proc(quat: Quat) -> Vec3 {
    x, y, z := linalg.euler_angles_from_quaternion_f32(quat, linalg.Euler_Angle_Order.XYZ)
    return Vec3{x, y, z}
}

cross :: proc(a: Vec3, b: Vec3) -> Vec3 {
    return linalg.vector_cross3(a, b)
}

dot :: proc(a: Vec3, b: Vec3) -> f32 {
    return linalg.vector_dot(a, b)
}

normalize :: proc(v: Vec3) -> Vec3 {
    return linalg.vector_normalize(v)
}

length :: proc(v: Vec3) -> f32 {
    return linalg.vector_length(v)
}

look_at :: proc(position: Vec3, target: Vec3, up: Vec3) -> Mat4 {
    return linalg.matrix4_look_at_f32(position, target, up)
}


perspective :: proc(fov: f32, aspect: f32, near: f32, far: f32) -> Mat4 {
    return linalg.matrix4_perspective_f32(fov, aspect, near, far)
}

ortho :: proc(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) -> Mat4 {
    return linalg.matrix_ortho3d_f32(left, right, bottom, top, near, far)
}

to_radians :: proc(degrees: f32) -> f32 {
    return linalg.to_radians(degrees)
}

to_degrees :: proc(radians: f32) -> f32 {
    return linalg.to_degrees(radians)
}