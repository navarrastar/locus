package ecs

import m "pkg:core/math"
import "core:log"
import "core:fmt"

Component :: union {
  Transform,
  Camera,
  Light,
  Mesh,
}

Transform :: struct {
  pos: m.Vec3,
  rot: m.Vec3,
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

add_components :: proc(e: Entity, components: ..Component) -> bool {
    for component in components {
        switch type in component {
            case Transform:
                w.transform[e.id] = component.(Transform)
                w.entities[e.id].comp_flags |= { .Transform }

            case Camera:
                log.debug("Adding camera to", e, "with value", component.(Camera))
                w.camera[e.id] = component.(Camera)
                w.entities[e.id].comp_flags |= { .Camera }

            case Light:
                log.debug("Adding light to", e.comp_flags, "with value", component.(Light))
                w.light[e.id] = component.(Light)
                w.entities[e.id].comp_flags |= { .Light }

            case Mesh:
                log.debug("Adding mesh to", e, "with value", component.(Mesh))
                w.mesh[e.id] = component.(Mesh)
                w.entities[e.id].comp_flags |= { .Mesh }

            case:
                fmt.panicf("Unknown component type", component)
        }
    }
    return true
}

has_components :: proc(e: Entity, comp_flags: ComponentTypeFlags) -> bool {
    return comp_flags <= e.comp_flags
}

get_components :: proc { get_transform_component, get_mesh_component, get_camera_component, get_light_component, get_transform_mesh_component, get_transform_camera_component }

get_transform_component :: proc(transform: Transform, e: Entity) -> ^Transform {
    return &w.transform[e.id]
}

get_mesh_component :: proc(mesh: Mesh, e: Entity) -> ^Mesh {
    return &w.mesh[e.id]
}

get_camera_component :: proc(camera: Camera, e: Entity) -> ^Camera {
    return &w.camera[e.id]
}

get_light_component :: proc(light: Light, e: Entity) -> ^Light {
    return &w.light[e.id]
}

get_transform_mesh_component :: proc(transform: Transform, mesh: Mesh, e: Entity) -> (^Transform, ^Mesh) {
    return &w.transform[e.id], &w.mesh[e.id]
}

get_transform_camera_component :: proc(transform: Transform, camera: Camera, e: Entity) -> (^Transform, ^Camera) {
    return &w.transform[e.id], &w.camera[e.id]
}

