package component

import m "pkg:core/math"

Component :: union {
  Transform,
  Camera,
  Light,
  Mesh,
}

Transform :: struct {
  pos: m.Vec3,
  rot: m.Quat,
  scale: f32,
}

Camera :: union { 
  Perspective,
  Orthographic,
}

Perspective :: struct {
  near: f32 `json:"znear"`,
  far: f32 `json:"zfar"`,

  fov: f32 `json:"yfov"`,
}

Orthographic :: struct {
  near: f32 `json:"znear"`,
  far: f32 `json:"zfar"`,

  xmag: f32 `json:"xmag"`, 
  ymag: f32 `json:"ymag"`,
}

Light :: union {
  Point,
  Spot,
  Directional,
}

Point :: struct {
  color: m.Vec3 `json:"color"`,
  intensity: f32 `json:"intensity"`,
  range: f32 `json:"range"`,
}

Spot :: struct {
  color: m.Vec3 `json:"color"`,
  intensity: f32 `json:"intensity"`,
  range: f32 `json:"range"`,

  inner_cone_angle: f32 `json:"innerConeAngle"`,
  outer_cone_angle: f32 `json:"outerConeAngle"`,
}

Directional :: struct {
  color: m.Vec3 `json:"color"`,
  intensity: f32 `json:"intensity"`,
}

Mesh :: struct {
  name: string
}

Weapon :: struct {
  damage: f32 `json:"damage"`,
  falloff: map[u32]u32 `json:"range"`, // key: meters, value: % damage
  fire_rate: f32 `json:"fireRate"`,
}
