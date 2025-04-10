#+private
package renderer

import "core:fmt"
import "core:mem"
import "core:log"

import "vendor:wgpu"

import "pkg:core/ecs"
import c "pkg:core/ecs/component"
import m "pkg:core/math"



draw_world :: proc () {
    ecs.for_each(.Mesh, draw_entity)
}

draw_ui :: proc () {}

draw_entity :: proc (e: ecs.Entity) {
    any_comp := ecs.get_component(.Mesh, e)
    mesh_comp := any_comp.(^c.Mesh)

    any_comp = ecs.get_component(.Transform, e)
    transform_comp := any_comp.(^c.Transform)

    camera := ecs.get_first_camera()

    any_comp = ecs.get_component(.Camera, camera)
    camera_comp := any_comp.(^c.Camera)

    any_comp = ecs.get_component(.Transform, camera)
    camera_transform_comp := any_comp.(^c.Transform)

    mvp_matrix: m.Mat4
    switch type in camera_comp {
        case c.Perspective:
            view_matrix := m.to_matrix(camera_transform_comp.pos, camera_transform_comp.rot, camera_transform_comp.scale)
            projection_matrix := m.perspective(type.fov, 1920 / 1080, type.near, type.far)
            mvp_matrix = m.mvp(transform_comp.pos, transform_comp.rot, transform_comp.scale, view_matrix, projection_matrix)
        case c.Orthographic:
            view_matrix := m.to_matrix(camera_transform_comp.pos, camera_transform_comp.rot, camera_transform_comp.scale)
            left, right := -type.xmag, type.xmag
            bottom, top := -type.ymag, type.ymag
            projection_matrix := m.ortho(left, right, bottom, top, type.near, type.far)
            mvp_matrix = m.mvp(transform_comp.pos, transform_comp.rot, transform_comp.scale, view_matrix, projection_matrix)
    }

    fmt.printfln("mvp: %v", mvp_matrix)

    update_bind_group_0(&mvp_matrix)
    draw_mesh(mesh_comp.name)
}

draw_mesh :: proc (name: string) {
    mesh, exists := get_mesh(name)
    if !exists {
        log.error("Failed to find mesh, then failed to load mesh")
    }

    for primitive in mesh.primitives {
        pipeline := primitive.material.pipeline

        if pipeline != state.pipeline {
            wgpu.RenderPassEncoderSetPipeline(state.render_pass_encoder, pipeline)
        }

        wgpu.RenderPassEncoderSetBindGroup(state.render_pass_encoder, 0, state.bind_group_0, nil)
        wgpu.RenderPassEncoderSetBindGroup(state.render_pass_encoder, 1, primitive.material.bind_group, nil)

        wgpu.RenderPassEncoderSetVertexBuffer(state.render_pass_encoder, 0, primitive.vertex_buffer, 0, size_of(Vertex) * u64(len(primitive.vertices)))
        wgpu.RenderPassEncoderSetIndexBuffer(state.render_pass_encoder, primitive.index_buffer, wgpu.IndexFormat.Uint32, 0, size_of(u32) * u64(len(primitive.indices)))

        wgpu.RenderPassEncoderDrawIndexed(state.render_pass_encoder, primitive.index_count, primitive.instance_count, primitive.first_index, primitive.base_vertex, primitive.first_instance)

    }

}

