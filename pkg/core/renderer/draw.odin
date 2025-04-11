#+private
package renderer

import "core:fmt"
import "core:mem"
import "core:log"

import "vendor:wgpu"

import "pkg:core/ecs"
import m "pkg:core/math"
import "pkg:core/window"


draw_world :: proc () {
    ecs.for_each({ .Mesh }, draw_entity)
}

draw_ui :: proc () {}

draw_entity :: proc (e: ecs.Entity) {
   
    transform_comp, mesh_comp := ecs.get_components(ecs.Transform{}, ecs.Mesh{}, e)

    camera := ecs.get_first_camera()
    camera_transform, camera_comp := ecs.get_components(ecs.Transform{}, ecs.Camera{}, camera)

    mvp_matrix: m.Mat4
    switch type in camera_comp {
        case ecs.Perspective:
            view_matrix := m.to_matrix(camera_transform.pos, m.quat(camera_transform.rot), camera_transform.scale)
            projection_matrix := m.perspective(type.fov, window.get_aspect_ratio(), type.near, type.far)
            mvp_matrix = m.mvp(transform_comp.pos, m.quat(transform_comp.rot), transform_comp.scale, view_matrix, projection_matrix)
        case ecs.Orthographic:
            view_matrix := m.to_matrix(camera_transform.pos, m.quat(camera_transform.rot), camera_transform.scale)
            left, right := -type.xmag, type.xmag
            bottom, top := -type.ymag, type.ymag
            projection_matrix := m.ortho(left, right, bottom, top, type.near, type.far)
            mvp_matrix = m.mvp(transform_comp.pos, m.quat(transform_comp.rot), transform_comp.scale, view_matrix, projection_matrix)
    }

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

        wgpu.RenderPassEncoderSetPipeline(state.render_pass_encoder, pipeline)

        wgpu.RenderPassEncoderSetBindGroup(state.render_pass_encoder, 0, state.bind_group_0, nil)
        wgpu.RenderPassEncoderSetBindGroup(state.render_pass_encoder, 1, primitive.material.bind_group, nil)

        wgpu.RenderPassEncoderSetVertexBuffer(state.render_pass_encoder, 0, primitive.vertex_buffer, 0, size_of(Vertex) * u64(len(primitive.vertices)))
        wgpu.RenderPassEncoderSetIndexBuffer(state.render_pass_encoder, primitive.index_buffer, wgpu.IndexFormat.Uint32, 0, size_of(u32) * u64(len(primitive.indices)))

        wgpu.RenderPassEncoderDrawIndexed(state.render_pass_encoder, primitive.index_count, primitive.instance_count, primitive.first_index, primitive.base_vertex, primitive.first_instance)

    }

}

