#+private
package renderer

import "core:fmt"
import "core:mem"
import "core:log"

import rl "vendor:raylib"

import "pkg:core/ecs"
import m "pkg:core/math"
import "pkg:core/window"


draw_world :: proc () {
    ecs.for_each({ .Model }, draw_entity)
}

draw_ui :: proc () {}

draw_entity :: proc (e: ecs.Entity) {
    transform_comp, model_comp := ecs.get_components(ecs.Transform{}, ecs.Model{}, e)
    
    rl.DrawModel(model_comp^, transform_comp.pos, transform_comp.scale, rl.WHITE)

    draw_model(model_comp)
}

draw_model :: proc(model: ^rl.Model) {

}

