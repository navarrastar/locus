package ecs

import m "pkg:core/math"
import "core:log"
import "core:fmt"

import rl "vendor:raylib"


Component :: union {
    Transform,
    Camera,
    Light,
    Model,
    Label
}

Transform :: struct {
    pos: m.Vec3,
    rot: m.Vec3,
    scale: f32,
}

Camera :: rl.Camera3D

Label :: string

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

Model :: rl.Model

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

            case Label:
                w.label[e.id] = component.(Label)
                w.entities[e.id].comp_flags |= { .Label }

            case Camera:
                log.debug("Adding camera to", e, "with value", component.(Camera))
                w.camera[e.id] = component.(Camera)
                w.entities[e.id].comp_flags |= { .Camera }

            case Light:
                log.debug("Adding light to", e.comp_flags, "with value", component.(Light))
                w.light[e.id] = component.(Light)
                w.entities[e.id].comp_flags |= { .Light }

            case Model:
                log.debug("Adding mesh to", e, "with value", component.(Model))
                w.model[e.id] = component.(Model)
                w.entities[e.id].comp_flags |= { .Model }

            case:
                fmt.panicf("Unknown component type", component)
        }
    }
    return true
}

has_components :: proc(e: Entity, comp_flags: ComponentTypeFlags) -> bool {
    return comp_flags <= e.comp_flags
}

@(require_results)
get_components :: proc { get_transform_component, get_model_component, get_camera_component, get_light_component, get_transform_model_component, get_transform_camera_component }

@(private)
get_transform_component :: proc(transform: Transform, e: Entity) -> ^Transform {
    return &w.transform[e.id]
}

@(private)
get_model_component :: proc(model: Model, e: Entity) -> ^Model {
    return &w.model[e.id]
}

@(private)
get_camera_component :: proc(camera: Camera, e: Entity) -> ^Camera {
    return &w.camera[e.id]
}

@(private)
get_light_component :: proc(light: Light, e: Entity) -> ^Light {
    return &w.light[e.id]
}

@(private)
get_transform_model_component :: proc(transform: Transform, model: Model, e: Entity) -> (^Transform, ^Model) {
    return &w.transform[e.id], &w.model[e.id]
}

@(private)
get_transform_camera_component :: proc(transform: Transform, camera: Camera, e: Entity) -> (^Transform, ^Camera) {
    return &w.transform[e.id], &w.camera[e.id]
}

