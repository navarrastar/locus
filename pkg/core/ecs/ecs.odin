package ecs

import "core:log"
import "core:strings"
import "core:fmt"

import rl "vendor:raylib"

import m "pkg:core/math"



eid :: u32

ComponentType :: enum {
    Transform,
    Model,
    Camera,
    Light,
    Label
}

ComponentTypeFlags :: bit_set[ComponentType; u8]

@(private)
w: World

Entity :: struct {
    id: eid,
    comp_flags: ComponentTypeFlags
}

World :: struct {
    entity_count: u32,
    entities: [1024]Entity,

    label: [1024]Label,
    transform: [1024]Transform,
    camera: [1024]Camera,
    light: [1024]Light,
    model: [1024]Model,
}

spawn :: proc(pos := m.Vec3{}, rot := m.Vec3{}, s := f32(1), name := string{}) -> (e: Entity) {
    e = Entity {
        id = w.entity_count,
    }

    l: Label = name

    t: Transform = {
        pos = pos,
        rot = rot,
        scale = s,
    }

    w.entities[e.id] = e

    w.entity_count += 1

    add_components(e, t, l)

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

// spawn_from_model :: proc(model: ^loader.Model) -> []Entity {
//     start_id := w.entity_count
    
//     for i in 0..<len(model.nodes) {
//         node := model.nodes[i]
//         e := spawn(node.translation, m.euler(node.rotation), 1.0, node.name)
        
//         if node.mesh != nil {
//             mesh := Mesh {
//                 name = node.mesh.name,
//             }
//             add_components(e, mesh)
//         }
//     }
//     // spawn() increments w.entity_count, so this is 
//     // the slice of all entities that this Model added
//     return w.entities[start_id:w.entity_count]
// }

get_first_camera :: proc() -> ^rl.Camera3D {
    for e in w.entities {
        if .Camera in e.comp_flags {
            return &w.camera[e.id]
        }
    }
    panic("No camera found")
}

get_entity_by_label :: proc(label: Label) -> Entity {
    for e in w.entities {
        if .Label in e.comp_flags && strings.compare(w.label[e.id], label) == 0 {
            return e
        }
    }
    panic(fmt.tprintf("No entity with label '%s' found", label))
}