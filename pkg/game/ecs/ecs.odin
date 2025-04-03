package ecs

import "core:log"

import c "pkg:game/ecs/component"
import m "pkg:core/math"
import "pkg:core/filesystem/gltf"

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
    light: [dynamic]c.Light,
    mesh: [dynamic]c.Mesh,
}

init :: proc() {
    w = World {
        entity_count = 0,
        entities  = make([dynamic]Entity, 0, 1024),
        transform = make([dynamic]c.Transform, 0, 1024),
        camera    = make([dynamic]c.Camera, 0, 1024),
        light     = make([dynamic]c.Light, 0, 1024),
        mesh      = make([dynamic]c.Mesh, 0, 1024),
    }

}

cleanup :: proc() {
    // Clean up any allocated resources
    for mesh in w.mesh {
        if mesh.material_indices != nil {
            delete(mesh.material_indices)
        }
    }
    
    delete(w.entities)
    delete(w.transform)
    delete(w.camera)
    delete(w.light)
    delete(w.mesh)
}

loop :: proc() {
    // Main loop for ECS systems
}

spawn_from_model :: proc(model: gltf.Model) -> (entities: [dynamic]Entity) {
    for node in model.nodes {
        e := spawn(node.local_transform[3].xyz, node.local_transform[0].xyz, 1.0, node.name)
        append(&entities, e)
        
        // If the node has a mesh, add a mesh component
        if node.mesh_index >= 0 {
            material_indices := make([]int, len(model.meshes[node.mesh_index].primitives))
            for i := 0; i < len(model.meshes[node.mesh_index].primitives); i += 1 {
                material_indices[i] = model.meshes[node.mesh_index].primitives[i].material_index
            }
            
            mesh_comp := c.Mesh{
                mesh_index = node.mesh_index,
                material_indices = material_indices,
                visible = true,
            }
            add_component(e, mesh_comp)
        }
    }
    return entities
}


spawn :: proc(pos := m.Vec3{}, rot := m.Vec3{}, s := f32{}, name := string{}) -> (e: Entity) {
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
        case c.Mesh:
            add_component_mesh(e, comp.(c.Mesh))
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

@(private)
add_component_mesh :: proc(e: Entity, m: c.Mesh) {
    log.debug("Adding mesh to", e, "with mesh index", m.mesh_index)
    append(&w.mesh, m)
}

// Get all entities that have a mesh component
get_entities_with_mesh :: proc() -> []Entity {
    entities := make([]Entity, len(w.mesh))
    for i in 0..<len(w.mesh) {
        if i < len(w.entities) {
            entities[i] = w.entities[i]
        }
    }
    return entities
}

// Get mesh component for an entity
get_mesh_component :: proc(e: Entity) -> ^c.Mesh {
    if int(e.id) < len(w.mesh) {
        return &w.mesh[e.id]
    }
    return nil
}

// Get transform component for an entity
get_transform_component :: proc(e: Entity) -> ^c.Transform {
    if int(e.id) < len(w.transform) {
        return &w.transform[e.id]
    }
    return nil
}