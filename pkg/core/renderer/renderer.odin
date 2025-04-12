package renderer

import "core:log"
import "base:runtime"
import "core:path/filepath"

import rl "vendor:raylib"

import "pkg:core/window"
import "pkg:core/ecs"
import m "pkg:core/math"



init :: proc() -> bool {
    return true
}

loop :: proc() {
    rl.ClearBackground({ 74, 45, 83, 100 })
    rl.BeginDrawing()

    camera := ecs.get_first_camera()
    rl.BeginMode3D(camera^)
    rl.DrawGrid(10, 1)

    draw_world()

    rl.EndMode3D()
    rl.EndDrawing()
}

cleanup :: proc() {

}
