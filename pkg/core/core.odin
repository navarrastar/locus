package core

import "base:runtime"
import "core:log"

import m "pkg:core/math"
import "pkg:core/window"
import "pkg:core/event"
import "pkg:core/renderer"
import "pkg:game"

NEAR_PLANE :: 0.001
FAR_PLANE  :: 1000.0



render_data: ^renderer.RenderData

init :: proc(ctx: ^runtime.Context) {
    render_data = new(renderer.RenderData)
    window.init(ctx)
    renderer.init()
    event.init()
}

update :: proc(world: ^game.World) {
    render_data := create_render_data(world)
    renderer.update(render_data)
}

cleanup :: proc() {
    event.cleanup()
    renderer.cleanup()
    window.cleanup()
    free(render_data)
}

create_render_data :: proc(world: ^game.World) -> ^renderer.RenderData {
    active_camera := world.cameras[0]
    assert(active_camera.fovy != 0, "cameras[0].fovy can't be 0")

    proj := m.perspective(active_camera.fovy, f32(window.width / window.height), NEAR_PLANE, FAR_PLANE)

    ROTATION_SPEED := m.to_radians(f32(90))
    @(static) rotation: f32
    rotation += ROTATION_SPEED * window.dt

    model_mat := m.matrix_rotate(rotation, {0, 1, 0})

    log.infof("\nmodel_mat {}\nrotation {}\ndt {}", model_mat, rotation, window.dt)

    render_data.view_proj = proj * model_mat

    return render_data
}