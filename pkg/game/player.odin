#+private
package game




import w "pkg:core/world"
import m "pkg:core/math"


spawn_player :: proc() {

    player := w.Entity_Player {
        name = "player",
        transform = m.DEFAULT_TRANSFORM,
    }

    w.spawn(player)
}
