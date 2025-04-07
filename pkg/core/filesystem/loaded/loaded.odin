package loaded

import "pkg:core/filesystem/loader"
import "core:log"


models: map[string]loader.Model

meshes: map[string]^loader.Mesh

init :: proc() {
    models = make(map[string]loader.Model)
}

cleanup :: proc() {
    for _, &model in models {
        loader.free_model(&model)
    }
}

add_model :: proc(model: loader.Model) -> (added: bool) {
    if (model.name in models) {
        log.error("Model with name", model.name, "already exists")
        return false
    }

    models[model.name] = model
   
    log.info("Stored Model", model.name)

    for &mesh in model.meshes {
        add_mesh(&mesh)
    }
    return true
}

get_model :: proc(name: string) -> ^loader.Model {
    if model, ok := &models[name]; ok {
        return model
    }
    log.error("Model not found:", name)
    return nil
}

get_mesh :: proc(name: string) -> ^loader.Mesh {
    if mesh, ok := meshes[name]; ok {
        return mesh
    }
    log.error("Mesh not found:", name)
    return nil
}

@(private)
add_mesh :: proc(mesh: ^loader.Mesh) -> (added: bool) {
    if (mesh.name in meshes) {
        log.error("Mesh with name", mesh.name, "already exists")
        return false
    }

    meshes[mesh.name] = mesh
    return true
}
