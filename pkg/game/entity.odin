package game

import "core:log"
import "core:fmt"

import m "pkg:math"

Entity :: struct {
    using transform: m.Transform,
    name: string,
    geometry: Geometry
}

Entity_Player :: struct {
    using entity: Entity,
    inventory: Inventory
}

Entity_StaticMesh :: struct {
    using entity: Entity,
}

Entity_Camera :: struct {
    using entity: Entity,
    target: m.Vec3,
    up: m.Vec3,
    fovy: f32,
    projection: enum { Perspective, Orthographic }
}

Entity_Opponent :: struct {
    using entity: Entity,
}