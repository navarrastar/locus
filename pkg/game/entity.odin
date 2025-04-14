package game

import "core:log"
import "core:fmt"

import m "pkg:core/math"
import geo "pkg:core/geometry"


Entity :: struct {
    using transform: m.Transform,
    name: string,
    geometry: geo.Geometry
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
    up: m.Vec3,
    fovy: f32,
    projection: enum { Perspective, Orthographic }
}

Entity_Opponent :: struct {
    using entity: Entity,
}