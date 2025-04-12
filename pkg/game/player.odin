#+private
package game



import rl "vendor:raylib"

import "pkg:core/ecs"
import m "pkg:core/math"


spawn_player :: proc() {
    player := ecs.spawn(name="player")

    sphere := rl.GenMeshSphere(4, 20, 20)
    model_comp: ecs.Model = rl.LoadModelFromMesh(sphere)

    ecs.add_components(player, model_comp)

}

update_player :: proc() {
    player := ecs.get_entity_by_label("player")
    transform := ecs.get_components(ecs.Transform{}, player)
    transform.rot += m.Vec3{0, 0.01, 0.01}
}