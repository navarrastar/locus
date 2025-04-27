package game

//import "core:log"

// import sdl "vendor:sdl3"
import m "../math"


Inventory :: struct {
    weapons: [WeaponSlot]Weapon
}

player_setup :: proc(player: ^Entity_Player) {
    inventory := new(Inventory)
    
    inventory.weapons[.Third] = weapon_fireball()
    
    player.inventory = inventory
}

player_update :: proc() {
    if input_key_newly_down(.W) do player_set_wish_dir({0, 0, -1})
    if input_key_newly_down(.A) do player_set_wish_dir({-1, 0, 0})
    if input_key_newly_down(.S) do player_set_wish_dir({0, 0, 1})
    if input_key_newly_down(.D) do player_set_wish_dir({1, 0, 0})
    
    if input_key_released(.W) do player_set_wish_dir({0, 0, 1})
    if input_key_released(.A) do player_set_wish_dir({1, 0, 0})
    if input_key_released(.S) do player_set_wish_dir({0, 0, -1})
    if input_key_released(.D) do player_set_wish_dir({-1, 0, 0})
    
    if input_key_down(.J)         do player_use_weapon(.First)
    if input_key_down(.K)         do player_use_weapon(.Second)
    if input_key_down(.L)         do player_use_weapon(.Third)
    if input_key_down(.SEMICOLON) do player_use_weapon(.Forth)
    if input_key_down(.APOSTROPHE)do player_use_weapon(.Fifth)
    
    player_move()
}

player_cleanup :: proc() {
    free(world.player.inventory)
}

player_move :: proc() {
    world.player.pos += world.player.wish_dir * world.player.speed * dt
}

player_set_wish_dir :: proc(wish_dir: m.Vec3) {
    world.player.wish_dir = world.player.wish_dir + wish_dir
    if world.player.wish_dir != {0, 0, 0} do world.player.face_dir = world.player.wish_dir
}

player_use_weapon :: proc(slot: WeaponSlot) {
    weapon_use(&world.player.inventory.weapons[slot], world.player)
    
    //log.info("Shooting Fireball", world.player.face_dir)
}
