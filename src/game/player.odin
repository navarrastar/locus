package game

//import "core:log"

// import sdl "vendor:sdl3"
import m "../math"


Inventory :: struct {
    weapons: [WeaponSlot]Weapon
}

setup_player :: proc(player: ^Entity_Player) {
    player.inventory.weapons[.Third] = weapon_fireball()
}

update_player :: proc() {
    if input_key_newly_down(.W) do set_wish_dir_player({0, 0, -1})
    if input_key_newly_down(.A) do set_wish_dir_player({-1, 0, 0})
    if input_key_newly_down(.S) do set_wish_dir_player({0, 0, 1})
    if input_key_newly_down(.D) do set_wish_dir_player({1, 0, 0})

    if input_key_released(.W) do set_wish_dir_player({0, 0, 1})
    if input_key_released(.A) do set_wish_dir_player({1, 0, 0})
    if input_key_released(.S) do set_wish_dir_player({0, 0, -1})
    if input_key_released(.D) do set_wish_dir_player({-1, 0, 0})

    if input_key_down(.J)         do use_weapon_player(.First)
    if input_key_down(.K)         do use_weapon_player(.Second)
    if input_key_down(.L)         do use_weapon_player(.Third)
    if input_key_down(.SEMICOLON) do use_weapon_player(.Forth)
    if input_key_down(.APOSTROPHE)do use_weapon_player(.Fifth)

    move_player()
}

cleanup_player :: proc() {
}

move_player :: proc() {
    player := world_get_player()
    player.pos += player.wish_dir * player.speed * dt
    player.geom.model_matrix = m.to_matrix(player.transform)
}

set_wish_dir_player :: proc(wish_dir: m.Vec3) {
    player := world_get_player()
    player.wish_dir = player.wish_dir + wish_dir
    if player.wish_dir != {0, 0, 0} do player.face_dir = player.wish_dir
}

use_weapon_player :: proc(slot: WeaponSlot) {
    player := world_get_player()
    weapon_use(&player.inventory.weapons[slot], player.eid)

    //log.info("Shooting Fireball", world.player.face_dir)
}
