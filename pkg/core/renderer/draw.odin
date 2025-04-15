#+private
package renderer

import "core:fmt"
import "core:mem"
import "core:log"

import sdl "vendor:sdl3"

import "pkg:game"
import m "pkg:core/math"
import "pkg:core/window"
import geo "pkg:core/geometry"



draw_render_data :: proc (using rd: ^RenderData) {
    assert(render_pass != nil, "Tried to draw but render_pass is nil")
    for mesh in  meshes {
        draw(mesh)
    }
    for &triangle in triangles {
        draw(&triangle)
    }
    for pyramid in pyramids {
        draw(pyramid)
    }
    for rectangle in rectangles {
        draw(rectangle)
    }
    for cube in cubes {
        draw(cube)
    }
    for circle in circles {
        draw(circle)
    }
    for sphere in spheres {
        draw(sphere)
    }
    for capsule in capsules {
        draw(capsule)
    }
    for cylinder in cylinders {
        draw(cylinder)
    }
}

draw :: proc { 
    draw_mesh, 
    draw_triangle, 
    draw_pyramid, 
    draw_rectangle, 
    draw_cube, 
    draw_circle, 
    draw_sphere, 
    draw_capsule, 
    draw_cylinder,
}

draw_mesh :: proc(geo.Mesh) {

}

draw_triangle :: proc(triangle: ^geo.Triangle) {

    vertex_buffer := sdl.CreateGPUBuffer(gpu, {
        usage = { .VERTEX },
        size = size_of(geo.TriangleVertex) * 3
    })

    transfer_buffer := sdl.CreateGPUTransferBuffer(gpu, {
        usage = .UPLOAD,
        size = size_of(geo.TriangleVertex) * 3
    })

    transfer_mem :=  sdl.MapGPUTransferBuffer(gpu, transfer_buffer, false)
    mem.copy(transfer_mem, &triangle.vertices, size_of(geo.TriangleVertex) * 3)
    sdl.UnmapGPUTransferBuffer(gpu, transfer_buffer)

    copy_cmd_buf := sdl.AcquireGPUCommandBuffer(gpu)

    copy_pass := sdl.BeginGPUCopyPass(copy_cmd_buf)

    sdl.UploadToGPUBuffer(copy_pass,
        {transfer_buffer = transfer_buffer},
        {buffer = vertex_buffer, size = size_of(geo.TriangleVertex) * 3}, 
         false)

    sdl.EndGPUCopyPass(copy_pass)

    sdl.ReleaseGPUTransferBuffer(gpu, transfer_buffer)

    ok := sdl.SubmitGPUCommandBuffer(copy_cmd_buf)

    assert(pipelines[.Triangle] != nil)
    sdl.BindGPUGraphicsPipeline(render_pass, pipelines[.Triangle])

    sdl.BindGPUVertexBuffers(render_pass, 0, &sdl.GPUBufferBinding{ buffer = vertex_buffer }, 1)

    sdl.DrawGPUPrimitives(render_pass, 3, 1, 0, 0)
}

draw_pyramid :: proc(geo.Pyramid) {

}

draw_rectangle :: proc(geo.Rectangle) {

}

draw_cube :: proc(geo.Cube) {

}

draw_circle :: proc(geo.Circle) {

}

draw_sphere :: proc(geo.Sphere) {

}

draw_capsule :: proc(geo.Capsule) {

}

draw_cylinder :: proc(geo.Cylinder) {

}
