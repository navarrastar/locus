#+private
package game




import "pkg:core/ecs"
import c "pkg:core/ecs/component"


spawn_player :: proc() {
    player := ecs.spawn(name="player")

    mesh := c.Mesh {
        name = "sphere"
    }

    ecs.add_component(mesh, player)

}