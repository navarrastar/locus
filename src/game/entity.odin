package game

import "base:builtin"

import m "../math"
import t "../types"

eID :: u64

// Every variant MUST begin with "using base: EntityBase"
// because this is a common operation: 
// cast(^EntityBase)&entity
Entity :: union {
    EntityBase,
    Entity_Player,
    Entity_Opp,
    Entity_Mesh,
    Entity_Camera,
    Entity_Projectile
}

EntityBase :: struct {
    using transform: m.Transform,
    eid:      eID,
    parent:   eID,
    name:     string,
    geom:     Geometry,
    phys:     Physics,
    face_dir: m.Vec3,
    velocity: m.Vec3,
}

Entity_Player :: struct {
    using base: EntityBase,
    inventory:  Inventory,
    wish_dir:   m.Vec3,
    speed: f32
}

Entity_Mesh :: struct {
    using base: EntityBase,
}

Entity_Camera :: struct {
    using base: EntityBase,
    target: m.Vec3,
    up: m.Vec3,
    fovy: f32,
    projection: enum { Perspective, Orthographic }
}

Entity_Opp :: struct {
    using base: EntityBase,
    inventory:  Inventory,
    health:     t.Health
}

opp_take_damage :: proc(eid: eID, damage: f32) {
    opp := &world.entities[eid].(Entity_Opp)
    opp.health.current -= damage
    if opp.health.current <= 0 do world_destroy(opp^)
}

Entity_Projectile :: struct {
    using base: EntityBase,
    speed:    f32,
    damage:   f32,
    collided: CollidedWith
}

get_base :: proc(eid: eID) -> ^EntityBase {
    return cast(^EntityBase)&world.entities[eid]
}