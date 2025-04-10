package loaded

import "pkg:core/filesystem/loader"
import "core:log"


models: map[string]loader.Model

meshes: map[string]^loader.Mesh
materials: map[string]^loader.Material

init :: proc() -> bool {
    models = make(map[string]loader.Model)
    return true
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

    for &material in model.materials {
        add_material(&material)
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

get_mesh :: proc(name: string) -> (^loader.Mesh, bool) {
    if mesh, ok := meshes[name]; ok {
        return mesh, true
    }
    log.error("Mesh not found:", name)
    return nil, false
}

get_material :: proc(name: string) -> (^loader.Material, bool) {
    if material, ok := materials[name]; ok {
        return material, true
    }
    log.error("Material not found:", name)
    return nil, false
}

@(private)
add_mesh :: proc(mesh: ^loader.Mesh) -> (added: bool) {
    if mesh.name in meshes {
        log.error("Mesh with name", mesh.name, "already exists")
        return false
    }

    meshes[mesh.name] = mesh
    log.info("Stored Mesh:", mesh.name)
    return true
}

@(private)
add_material :: proc(material: ^loader.Material) -> (added: bool) {
    if material.name in materials {
        log.error("Material with name", material.name, "already exists")
        return false
    }

    materials[material.name] = material
    log.info("Stored Material:", material.name)
    return true
}
