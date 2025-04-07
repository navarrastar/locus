package renderer

import "core:fmt"

import "vendor:wgpu"

import "pkg:core/ecs"
import c "pkg:core/ecs/component"

draw_world :: proc () {
    ecs.for_each(.Mesh, draw_entity)
}

draw_ui :: proc () {}

draw_entity :: proc (e: ecs.Entity) {
    any_comp := ecs.get_component(.Mesh, e)
    mesh_comp := any_comp.(c.Mesh)

    draw_mesh(mesh_comp.name)
}

draw_mesh :: proc (name: string) {
    fmt.println(name)
}