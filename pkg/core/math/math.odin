package math2

import "core:math/linalg"

Vec2 :: linalg.Vector2f32
Vec3 :: linalg.Vector3f32
Vec4 :: linalg.Vector4f32
Mat4 :: linalg.Matrix4x4f32
Quat :: linalg.Quaternionf32

IDENTITY_MAT :: linalg.MATRIX4F32_IDENTITY 
IDENTITY_QUAT :: linalg.QUATERNIONF32_IDENTITY

quat :: proc(euler: Vec3) -> (q: Quat) {
    q = linalg.quaternion_from_euler_angles_f32(euler.x, euler.y, euler.z, linalg.Euler_Angle_Order.XYZ)
    return q
}