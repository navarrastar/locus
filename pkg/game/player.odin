package game


import "core:log"

import m "pkg:math"



Inventory :: struct {

}

spawn_player :: proc(player: Entity_Player) {
    world.player = player
}

player_update :: proc() {
    using world
    ROTATION_SPEED := m.to_radians(f32(90))
    
    player.rot.y += ROTATION_SPEED * dt
}
