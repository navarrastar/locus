package ecs

import "core:log"
import "core:strings"
import "core:fmt"

import c "pkg:core/ecs/component"
import m "pkg:core/math"
import "pkg:core/filesystem/loader"

eid :: u32

ComponentType :: enum u32 {
    Transform = 1 << 0,
    Mesh      = 1 << 1,
    Camera    = 1 << 2,
    Light     = 1 << 3,

}

@(private)
w: World

Entity :: struct {
    name: string,
    id: eid,
}

World :: struct {
    entity_count: u32,
    entities: [1024]Entity,

    transform: [1024]c.Transform,
    camera: [1024]c.Camera,
    light: [1024]c.Light,
    mesh: [1024]c.Mesh,
    
    component_masks: [1024]u32,
}

spawn :: proc(pos := m.Vec3{}, rot := m.Vec3{}, s := f32{}, name := string{}) -> (e: Entity) {
    e = Entity {
        name = name,
        id = w.entity_count,
    }

    t: c.Transform = {
        pos = pos,
        rot = m.quat(rot),
        scale = s,
    }

    add_component(t, e)

    w.entity_count += 1
    w.entities[e.id] = e
    log.debug("Spawning", e, "at", pos)
    return e
}

add_component :: proc(component: c.Component, e: Entity) -> bool {
    switch type in component {
        case c.Transform:
            w.transform[e.id] = component.(c.Transform)
            w.component_masks[e.id] |= u32(ComponentType.Transform)

        case c.Camera:
            log.debug("Adding camera to", e, "with value", component.(c.Camera))
            w.camera[e.id] = component.(c.Camera)
            w.component_masks[e.id] |= u32(ComponentType.Camera)

        case c.Light:
            log.debug("Adding light to", e, "with value", component.(c.Light))
            w.light[e.id] = component.(c.Light)
            w.component_masks[e.id] |= u32(ComponentType.Light)

        case c.Mesh:
            log.debug("Adding mesh to", e, "with value", component.(c.Mesh))
            w.mesh[e.id] = component.(c.Mesh)
            w.component_masks[e.id] |= u32(ComponentType.Mesh)

        case:
            log.error("Unknown component type", component)
            return false
    }
    return true
}

get_component :: proc(comp_type: ComponentType, e: Entity) -> any {
    switch comp_type {
    case .Transform:
        if has_component(comp_type, e) {
            return &w.transform[e.id]
        }
    case .Mesh:
        if has_component(comp_type, e) {
            return &w.mesh[e.id]
        }
    case .Camera:
        if has_component(comp_type, e) {
            return &w.camera[e.id]
        }
    case .Light:
        if has_component(comp_type, e) {
            return &w.light[e.id]
        }
    }
    return nil
}

has_component :: proc(comp_type: ComponentType, e: Entity) -> bool {
    return (w.component_masks[e.id] & u32(comp_type)) != 0
}

for_each :: proc(comp_type: ComponentType, callback: proc(entity: Entity)) {
    comp_bit: u32
    switch comp_type {
    case .Mesh:
        comp_bit = u32(ComponentType.Mesh)
    case .Transform:
        comp_bit = u32(ComponentType.Transform)
    case .Camera:
        comp_bit = u32(ComponentType.Camera)
    case .Light:
        comp_bit = u32(ComponentType.Light)
    case:
        log.error("Unsupported component type in for_each:", comp_type)
        return
    }
    
    for i in 0..<int(w.entity_count) {
        if (w.component_masks[i] & comp_bit) != 0 {
            callback(w.entities[i])
        }
    }
}

spawn_from_model :: proc(model: ^loader.Model) -> []Entity {
    start_id := w.entity_count
    
    for i in 0..<len(model.nodes) {
        node := model.nodes[i]
        e := spawn(node.translation, m.euler(node.rotation), 1.0, node.name)
        
        if node.mesh != nil {
            mesh := c.Mesh {
                name = node.mesh.name,
            }
            add_component(mesh, e)
        }
    }
    // spawn() increments w.entity_count, so this is 
    // the slice of all entities that this Model added
    return w.entities[start_id:w.entity_count]
}