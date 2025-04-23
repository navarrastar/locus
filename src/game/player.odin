package game



import m "../math"



Inventory :: struct {

}

spawn_player :: proc(player: Entity_Player) {
    world.player = player
}

player_update :: proc() {
    ROTATION_SPEED := m.to_radians(f32(90))
    
    world.player.rot.y += ROTATION_SPEED * dt
}
