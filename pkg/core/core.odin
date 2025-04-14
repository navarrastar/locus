package core

import "base:runtime"
import "core:log"

import m "pkg:core/math"
import "pkg:core/window"
import "pkg:core/event"
import "pkg:core/renderer"
import "pkg:game"

NEAR_PLANE: f32 : 0.001
FAR_PLANE : f32 : 1000



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

    w, h := window.size()
    proj := m.perspective(active_camera.fovy, f32(w) / f32(h), NEAR_PLANE, FAR_PLANE)

    render_data.projection_matrix = proj

    return render_data
}