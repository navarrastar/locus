package renderer

import "core:log"
import "base:runtime"
import "core:path/filepath"

import rl "vendor:raylib"

import w "pkg:core/world"
import "pkg:core/window"
import m "pkg:core/math"



init :: proc() {
    
}

loop :: proc() {
    rl.ClearBackground({ 74, 45, 83, 100 })
    rl.BeginDrawing()

    rl.BeginMode3D(w.camera)
    rl.DrawGrid(10, 1)

    draw_world()

    rl.EndMode3D()
    rl.EndDrawing()
}

cleanup :: proc() {

}
