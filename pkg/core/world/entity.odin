package world

import m "pkg:core/math"
import "core:log"
import "core:fmt"

import rl "vendor:raylib"



eid :: u32

Entity :: struct {
    using transform: m.Transform,
    id: eid,
    name: string
}

EntityVariant :: union {
    Entity_Player,
    Entity_StaticMesh,
}

Inventory :: struct {

}

Entity_Player :: struct {
    using entity: Entity,
    model: rl.Model,

    inventory: Inventory
}

Entity_StaticMesh :: struct {
    using entity: Entity,
    model: rl.Model
}