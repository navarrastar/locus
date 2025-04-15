package core

import "base:runtime"
import "core:log"

import m "pkg:core/math"
import "pkg:core/window"
import "pkg:core/event"
import "pkg:core/renderer"
import "pkg:game"
import geo "pkg:core/geometry"

NEAR_PLANE :: 0.001
FAR_PLANE  :: 1000.0



render_data: ^renderer.RenderData

init :: proc(ctx: ^runtime.Context) {
    render_data = new(renderer.RenderData)
    render_data.meshes     = make([dynamic]geo.Mesh)
    render_data.triangles  = make([dynamic]geo.Triangle)
    render_data.pyramids   = make([dynamic]geo.Pyramid)
    render_data.rectangles = make([dynamic]geo.Rectangle)
    render_data.cubes      = make([dynamic]geo.Cube)
    render_data.circles    = make([dynamic]geo.Circle)
    render_data.spheres    = make([dynamic]geo.Sphere)
    render_data.capsules   = make([dynamic]geo.Capsule)
    render_data.cylinders  = make([dynamic]geo.Cylinder)
    
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

create_render_data :: proc(using world: ^game.World) -> ^renderer.RenderData {
    active_camera := cameras[0]
    assert(active_camera.fovy != 0, "cameras[0].fovy can't be 0")

    proj := m.perspective(active_camera.fovy, f32(window.width / window.height), NEAR_PLANE, FAR_PLANE)

    ROTATION_SPEED := m.to_radians(f32(90))
    player.rot.y += ROTATION_SPEED * window.dt


    // Getting geometries
    geometries: [1024]^geo.Geometry

    geometries[0] = &player.geometry

    model_mat := m.to_matrix(player.pos, player.rot, player.scale)

    render_data.view_proj = proj * model_mat

    geometry_count := 1
    for &opponent in world.opponents {
        if opponent.geometry == nil do continue
        geometries[geometry_count] = &opponent.geometry
        geometry_count += 1
    }
    for &camera in world.cameras {
        if camera.geometry == nil do continue
        geometries[geometry_count] = &camera.geometry
        geometry_count += 1
    }
    for &mesh in world.static_meshes {
        if mesh.geometry == nil do continue
        geometries[geometry_count] = &mesh.geometry
        geometry_count += 1
    }

    clear(&render_data.meshes)
    clear(&render_data.triangles)
    clear(&render_data.pyramids)
    clear(&render_data.rectangles)
    clear(&render_data.cubes)
    clear(&render_data.circles)
    clear(&render_data.spheres)
    clear(&render_data.capsules)
    clear(&render_data.cylinders)

    for i := 0; i < geometry_count; i += 1 {
        switch type in geometries[i] {
            case geo.Mesh:
                append(&render_data.meshes, geometries[i].(geo.Mesh))
            case geo.Triangle:
                append(&render_data.triangles, geometries[i].(geo.Triangle))
            case geo.Pyramid:
                append(&render_data.pyramids, geometries[i].(geo.Pyramid))
            case geo.Rectangle:
                append(&render_data.rectangles, geometries[i].(geo.Rectangle))
            case geo.Cube:
                append(&render_data.cubes, geometries[i].(geo.Cube))
            case geo.Circle:
                append(&render_data.circles, geometries[i].(geo.Circle))
            case geo.Sphere:
                append(&render_data.spheres, geometries[i].(geo.Sphere))
            case geo.Capsule:
                append(&render_data.capsules, geometries[i].(geo.Capsule))
            case geo.Cylinder:
                append(&render_data.cylinders, geometries[i].(geo.Cylinder))
        }
    }
    return render_data
}