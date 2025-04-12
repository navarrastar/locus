#+private
package game




import rl "vendor:raylib"

import w "pkg:core/world"
import m "pkg:core/math"


spawn_player :: proc() {
    sphere := rl.GenMeshSphere(4, 20, 20)

    player := w.Entity_Player {
        name = "player",
        transform = m.DEFAULT_TRANSFORM,
        model = rl.LoadModelFromMesh(sphere)
    }

    w.spawn(player)
}
