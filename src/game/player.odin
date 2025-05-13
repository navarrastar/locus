package game

import "core:log"

 import m "../math"
// import "core:math/linalg"


NORTH     :: m.Vec3{ 0, 0, -1}
NORTHEAST :: m.Vec3{ 1, 0, -1}
EAST      :: m.Vec3{ 1, 0,  0}
SOUTHEAST :: m.Vec3{ 1, 0,  1}
SOUTH     :: m.Vec3{ 0, 0,  1}
SOUTHWEST :: m.Vec3{-1, 0,  1}
WEST      :: m.Vec3{-1, 0,  0} 
NORTHWEST :: m.Vec3{-1, 0, -1}


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
    if input_key_newly_down(.M) do player_cycle_anim(player)    
    if input_key_newly_down(.W) do player_set_wish_dir(player, NORTH)
    if input_key_newly_down(.A) do player_set_wish_dir(player, WEST)
    if input_key_newly_down(.S) do player_set_wish_dir(player, SOUTH)
    if input_key_newly_down(.D) do player_set_wish_dir(player, EAST)
    // if input_key_newly_down(.SPACE) do player_try_jump(player)
    // if input_key_newly_down(.LSHIFT) do player_try_dash(player)
    // if input_key_newly_down(.LCTRL) do player_try_block(player)

    if input_key_released(.W) do player_set_wish_dir(player, SOUTH)
    if input_key_released(.A) do player_set_wish_dir(player, EAST)
    if input_key_released(.S) do player_set_wish_dir(player, NORTH)
    if input_key_released(.D) do player_set_wish_dir(player, WEST)

    if input_key_down(.Q) do player_try_use_weapon(player, .First)
    if input_key_down(.E) do player_try_use_weapon(player, .Second)
    if input_key_down(.R) do player_try_use_weapon(player, .Third)
    if input_key_down(.F) do player_try_use_weapon(player, .Forth)
    if input_key_down(.Z) do player_try_use_weapon(player, .Fifth)

    player_move(player)
    player_set_face_dir(player)
    player_set_anim_state(player)
}

player_cleanup :: proc() {
}

player_move :: proc(player: ^Entity_Player) {
    player.pos += player.wish_dir * player.speed * dt
    player.geom.model_matrix = m.to_matrix(player.transform)
}

player_set_wish_dir :: proc(player: ^Entity_Player, wish_dir: m.Vec3) {
    player.wish_dir += wish_dir
}

player_set_face_dir :: proc(player: ^Entity_Player) {
    camera := world_camera()
    
    // Convert mouse position to normalized device coordinates (NDC)
    mouse_ndc_x := (2.0 * mouse_pos.x / f32(window_width)) - 1.0
    mouse_ndc_y := 1.0 - (2.0 * mouse_pos.y / f32(window_height))
    
    // Create ray in clip space
    ray_clip := m.Vec4{mouse_ndc_x, mouse_ndc_y, -1.0, 1.0}
    
    // Transform to eye space
    ray_eye := m.inverse(camera.proj) * ray_clip
    ray_eye.z = -1.0
    ray_eye.w = 0.0
    
    // Transform to world space
    ray_world := (m.inverse(camera.view) * ray_eye)
    ray_dir := m.normalize(ray_world.xyz)
    
    // Intersect ray with ground plane (y = 0)
    t := -camera.pos.y / ray_dir.y
    
    // Calculate intersection point
    intersection := camera.pos + ray_dir * t
    
    // Calculate direction from player to intersection
    dir_to_point := m.normalize(m.Vec3{
        intersection.x - player.pos.x,
        0, // We only care about xz plane for a top-down game
        intersection.z - player.pos.z,
    })
    
    // Update player's facing direction and rotation
    yaw := m.atan2(dir_to_point.x, dir_to_point.z)
    
    player.rot = {0, yaw, 0}
    player.face_dir = dir_to_point
}

player_set_anim_state :: proc(player: ^Entity_Player) {
    skeleton, ok := &player.geom.skeleton.?
    if !ok do return
    
    angle := m.to_degrees(player.rot.y)
    // Converts from [-180, 180] to [0, 360]
    if angle < 0 do angle += 360
    
    anim_name: string
    switch player.wish_dir {
    case NORTH:
        if angle < 50                 do anim_name = "RunningBackward"
        if m.between(angle, 50, 130)  do anim_name = "LeftStrafe"
        if m.between(angle, 130, 230) do anim_name = "StandardRun"
        if m.between(angle, 230, 310) do anim_name = "RightStrafe"
        if angle > 310                do anim_name = "RunningBackward"
        
    case NORTHEAST:
        if angle < 90                 do anim_name = "LeftStrafe"
        if m.between(angle, 90, 180)  do anim_name = "StandardRun"
        if m.between(angle, 180, 270) do anim_name = "RightStrafe"
        if angle > 270                do anim_name = "RunningBackward"
        
    case EAST:
        if m.between(angle, 0, 50)    do anim_name = "LeftStrafe"
        if m.between(angle, 50, 140)  do anim_name = "StandardRun"
        if m.between(angle, 140, 220) do anim_name = "RightStrafe"
        if m.between(angle, 220, 320) do anim_name = "RunningBackward"
        if m.between(angle, 320, 360) do anim_name = "LeftStrafe"
        
    case SOUTHEAST:
        if angle < 90                 do anim_name = "StandardRun"
        if m.between(angle, 90, 180)  do anim_name = "RightStrafe"
        if m.between(angle, 180, 270) do anim_name = "RunningBackward"
        if angle > 270                do anim_name = "LeftStrafe"
        
    case SOUTH:
        if angle < 50                 do anim_name = "StandardRun"
        if m.between(angle, 50, 130)  do anim_name = "RightStrafe"
        if m.between(angle, 130, 230) do anim_name = "RunningBackward"
        if m.between(angle, 230, 310) do anim_name = "LeftStrafe"
        if angle > 310                do anim_name = "StandardRun"
        
    case SOUTHWEST:
        if angle < 90                 do anim_name = "RightStrafe"
        if m.between(angle, 90, 180)  do anim_name = "RunningBackward"
        if m.between(angle, 180, 270) do anim_name = "LeftStrafe"
        if angle > 270                do anim_name = "StandardRun"
        
    case WEST:
        if m.between(angle, 0, 40)    do anim_name = "RightStrafe"
        if m.between(angle, 40, 140)  do anim_name = "RunningBackward"
        if m.between(angle, 140, 220) do anim_name = "LeftStrafe"
        if m.between(angle, 220, 310) do anim_name = "StandardRun"
        if m.between(angle, 310, 360) do anim_name = "RightStrafe"
        
    case NORTHWEST:
        if angle < 90                 do anim_name = "RunningBackward"
        if m.between(angle, 90, 180)  do anim_name = "LeftStrafe"
        if m.between(angle, 180, 270) do anim_name = "StandardRun"
        if angle > 270                do anim_name = "RightStrafe"
        
    case:
        anim_name = "Idle"
    }
    
    skeleton.next_anim_idx = anim_find(skeleton^, anim_name)
    // skeleton.anim_idx = anim_find(skeleton^, anim_name)
}

player_try_use_weapon :: proc(player: ^Entity_Player, slot: WeaponSlot) {
    weapon_use(&player.inventory.weapons[slot], player.eid)
}

player_cycle_anim :: proc(player: ^Entity_Player) {
    steam_get_current_player_count()
    skeleton, ok := &player.geom.skeleton.?
    if !ok do return
    
    skeleton.anim_idx = (skeleton.anim_idx + 1) % len(skeleton.anims)
    log.info(skeleton.anims[skeleton.anim_idx].name)
}