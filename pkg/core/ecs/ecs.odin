package ecs

import "core:log"
import "core:strings"
import "core:fmt"

import "vendor:wgpu"

import m "pkg:core/math"
import "pkg:core/filesystem/loader"



eid :: u32

ComponentType :: enum {
    Transform,
    Mesh,
    Camera,
    Light 
}

ComponentTypeFlags :: bit_set[ComponentType; u8]

@(private)
w: World

Entity :: struct {
    name: string,
    id: eid,
    comp_flags: ComponentTypeFlags
}

World :: struct {
    entity_count: u32,
    entities: [1024]Entity,

    transform: [1024]Transform,
    camera: [1024]Camera,
    light: [1024]Light,
    mesh: [1024]Mesh,
}

spawn :: proc(pos := m.Vec3{}, rot := m.Vec3{}, s := f32(1), name := string{}) -> (e: Entity) {
    e = Entity {
        name = name,
        id = w.entity_count,
    }

    t: Transform = {
        pos = pos,
        rot = rot,
        scale = s,
    }

    w.entities[e.id] = e

    w.entity_count += 1

    add_components(e, t)

    log.debug("Spawning", e, "at", pos)
    return e
}


for_each :: proc(comp_flags: ComponentTypeFlags, callback: proc(entity: Entity)) {
    for &e in w.entities {
        if comp_flags <= e.comp_flags {
            callback(e)
        }
    }
}

spawn_from_model :: proc(model: ^loader.Model) -> []Entity {
    start_id := w.entity_count
    
    for i in 0..<len(model.nodes) {
        node := model.nodes[i]
        e := spawn(node.translation, m.euler(node.rotation), 1.0, node.name)
        
        if node.mesh != nil {
            mesh := Mesh {
                name = node.mesh.name,
            }
            add_components(e, mesh)
        }
    }
    // spawn() increments w.entity_count, so this is 
    // the slice of all entities that this Model added
    return w.entities[start_id:w.entity_count]
}

get_first_camera :: proc() -> Entity {
    for e in w.entities {
        if .Camera in e.comp_flags {
            return e
        }
    }
    panic("No camera found")
}

get_entity_by_name :: proc(name: string) -> Entity {
    for e in w.entities {
        if e.name == name {
            return e
        }
    }
    fmt.panicf("No entity found with name: %s\n", name)
}