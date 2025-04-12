#+private
package renderer

import "core:fmt"
import "core:mem"
import "core:log"

import rl "vendor:raylib"

import w "pkg:core/world"
import m "pkg:core/math"
import "pkg:core/window"


draw_world :: proc () {
    for entity in w.entities {
        #partial switch variant in entity {
            case w.Entity_Player:
                using e := entity.(w.Entity_Player)
                rl.DrawModel(e.model, entity.pos, entity.scale, rl.PINK)
            
            case w.Entity_StaticMesh:
                using e := entity.(w.Entity_StaticMesh)
                rl.DrawModel(e.model, entity.pos, entity.scale, rl.BLACK)
        }
    }
}

draw_ui :: proc () {}


