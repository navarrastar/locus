#+private
package game




import m "pkg:core/math"



Inventory :: struct {

}

spawn_player :: proc(player: Entity_Player) {
    world.player = player
}
