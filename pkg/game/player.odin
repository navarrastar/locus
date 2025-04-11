#+private
package game




import "pkg:core/ecs"
import m "pkg:core/math"


spawn_player :: proc() {
    player := ecs.spawn(name="player")

    mesh := ecs.Mesh {
        name = "sphere"
    }

    ecs.add_components(player, mesh)

}

update_player :: proc() {
    player := ecs.get_entity_by_name("player")
    transform := ecs.get_components(ecs.Transform{}, player)
    transform.rot += m.Vec3{0, 0.01, 0.01}
}