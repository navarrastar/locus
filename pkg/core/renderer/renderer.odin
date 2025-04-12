package renderer

import "core:log"
import "base:runtime"
import "core:path/filepath"

import rl "vendor:raylib"

import "third_party:clay"

import w "pkg:core/world"
import "pkg:core/window"
import m "pkg:core/math"



init :: proc() {

}

loop :: proc(ui_commands: ^clay.ClayArray(clay.RenderCommand)) {
    rl.ClearBackground({ 74, 45, 83, 100 })
    rl.BeginDrawing()
    

    rl.BeginMode3D(w.camera)
    rl.DrawGrid(100, 5)

    draw_world()

    rl.EndMode3D()
    draw_ui(ui_commands)
    rl.EndDrawing()
}

cleanup :: proc() {

}
