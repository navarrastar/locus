package game

import "core:reflect"
import "base:builtin"

import m "../math"



Entity :: struct {
    using transform: m.Transform,
    idx:      u8,
    name:     string,
    geometry: Geometry,
    physics:  Physics,
    velocity: m.Vec3,
}

Entity_Player :: struct {
    using entity: Entity,
    inventory:  ^Inventory,
    wish_dir:   m.Vec3,
    face_dir:   m.Vec3,
    speed: f32
}

Entity_Mesh :: struct {
    using entity: Entity,
}

Entity_Camera :: struct {
    using entity: Entity,
    target: m.Vec3,
    up: m.Vec3,
    fovy: f32,
    projection: enum { Perspective, Orthographic }
}

Entity_Opp :: struct {
    using entity: Entity,
    inventory:  ^Inventory,
}

Entity_Projectile :: struct {
    using entity: Entity,
    speed: f32,
}

