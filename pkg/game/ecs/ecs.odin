package ecs

import "core:log"

import c "pkg:game/ecs/component"
import m "pkg:core/math"

eid :: u32

@(private)
w: World

Entity :: struct {
    name: string,
    id: eid,
}

World :: struct {
    entity_count: u32,
    entities: [dynamic]Entity,
    transform: [dynamic]c.Transform,
    camera: [dynamic]c.Camera,
    light: [dynamic]c.Light
}

init :: proc() {
    w = World {
        entity_count = 0,
        entities  = make([dynamic]Entity, 0, 1024),

        transform = make([dynamic]c.Transform, 0, 1024),
        camera    = make([dynamic]c.Camera, 0, 1024),
        light     = make([dynamic]c.Light, 0, 1024),
    }

}

cleanup :: proc() {
    

}

loop :: proc() {

}

spawn_entity :: proc(pos := m.Vec3{}, rot := m.Vec3{}, s := f32{}, name := string{}) -> (e: Entity) {
    e = Entity {
        name = name,
        id = w.entity_count,
    }
    log.debug("Spawning", e, "at", pos)

    t: c.Transform = {
        pos = pos,
        rot = m.quat(rot),
        scale = s,
    }

    add_component(e, t)

    w.entity_count += 1
    append(&w.entities, e)
    return e
}

add_component :: proc(e: Entity, comp: c.Component) -> bool {
    switch type in comp {
        case c.Transform:
            add_component_transform(e, comp.(c.Transform))
        case c.Camera:
            add_component_camera(e, comp.(c.Camera))
        case c.Light:
            add_component_light(e, comp.(c.Light))
        case:
            log.error("Unknown component type", comp)
            return false
    }
    return true
}

@(private)
add_component_transform :: proc(e: Entity, t: c.Transform) {
    append(&w.transform, t)
}

@(private)
add_component_camera :: proc(e: Entity, cam: c.Camera) {
    log.debug("Adding camera to", e, "with value", cam)
    append(&w.camera, cam)
}

@(private)
add_component_light :: proc(e: Entity, l: c.Light) {
    log.debug("Adding light to", e, "with value", l)
    append(&w.light, l)
}