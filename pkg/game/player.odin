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