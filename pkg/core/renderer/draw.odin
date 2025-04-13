#+private
package renderer

import "core:fmt"
import "core:mem"
import "core:log"

import w "pkg:core/world"
import m "pkg:core/math"
import "pkg:core/window"


draw_world :: proc () {
    for entity in w.entities {
        #partial switch variant in entity {
            case w.Entity_Player:
                using e := entity.(w.Entity_Player)
            
            case w.Entity_StaticMesh:
                using e := entity.(w.Entity_StaticMesh)
        }
    }
}

draw_ui :: proc () {}


