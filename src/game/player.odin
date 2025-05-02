package game

// import "core:log"

import m "../math"

WeaponSlot :: enum {
	First,
	Second,
	Third,
	Forth,
	Fifth,
}

Inventory :: struct {
    weapons: [WeaponSlot]Weapon
}

player_setup :: proc(player: ^Entity_Player) {
    player.inventory.weapons[.First] = weapon_scythe()
    player.inventory.weapons[.Third] = weapon_fireball()
}

player_update :: proc(player: ^Entity_Player) {
    if input_key_newly_down(.W) do player_set_wish_dir(player, {0, 0, -1})
    if input_key_newly_down(.A) do player_set_wish_dir(player, {-1, 0, 0})
    if input_key_newly_down(.S) do player_set_wish_dir(player, {0, 0, 1})
    if input_key_newly_down(.D) do player_set_wish_dir(player, {1, 0, 0})

    if input_key_released(.W) do player_set_wish_dir(player, {0, 0, 1})
    if input_key_released(.A) do player_set_wish_dir(player, {1, 0, 0})
    if input_key_released(.S) do player_set_wish_dir(player, {0, 0, -1})
    if input_key_released(.D) do player_set_wish_dir(player, {-1, 0, 0})

    if input_key_down(.J)         do player_use_weapon(player, .First)
    if input_key_down(.K)         do player_use_weapon(player, .Second)
    if input_key_down(.L)         do player_use_weapon(player, .Third)
    if input_key_down(.SEMICOLON) do player_use_weapon(player, .Forth)
    if input_key_down(.APOSTROPHE)do player_use_weapon(player, .Fifth)

    player_move(player)
    player_set_face_dir(player)
}

player_cleanup :: proc() {
}

player_move :: proc(player: ^Entity_Player) {
    player.pos += player.wish_dir * player.speed * dt
    player.geom.model_matrix = m.to_matrix(player.transform)
}

player_set_wish_dir :: proc(player: ^Entity_Player, wish_dir: m.Vec3) {
    player.wish_dir = player.wish_dir + wish_dir
}

player_set_face_dir :: proc(player: ^Entity_Player) {
    camera := world_camera()
    world_pos  := m.Vec4{player.pos.x, player.pos.y, player.pos.z, 1.0}
    screen_pos := camera.viewProj * world_pos
    
    if screen_pos.w != 0 do screen_pos /= screen_pos.w
    
    screen_pos_2D: m.Vec2
    screen_pos_2D.x = (screen_pos.x * 0.5 + 0.5) * f32(window_width) 
    screen_pos_2D.y = (1.0 - (screen_pos.y * 0.5 + 0.5)) * f32(window_height)
    
    dir := mouse_pos - screen_pos_2D 
    yaw := m.atan2(dir.x, dir.y)
    
    player.rot = {0, yaw, 0}
    player.face_dir = {m.sin(yaw), 0, m.cos(yaw)}
}

player_use_weapon :: proc(player: ^Entity_Player, slot: WeaponSlot) {
    weapon_use(&player.inventory.weapons[slot], player.eid)
}
