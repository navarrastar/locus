package game

import "core:log"

import "../stack"
import m "../math"

World :: struct {
    player: Entity_Player,
    
    opps: [16]Entity_Opp,
    opp_count: u8,
    
    cameras: [16]Entity_Camera,
    camera_count: u8,
    
    meshes: [128]Entity_Mesh,
    mesh_count: u8,
    
    projectiles: [256]Entity_Projectile,
    projectile_count: u8
}

_freed_opp_stack:        stack.Stack(u8)
_freed_camera_stack:     stack.Stack(u8)
_freed_mesh_stack:       stack.Stack(u8)
_freed_projectile_stack: stack.Stack(u8)

world_init :: proc() {
    
}

world_in_bounds :: proc(pos: m.Vec3) -> bool {
    if pos.x >= WORLD_BOUNDS do return false
    if pos.y >= WORLD_BOUNDS do return false
    if pos.z >= WORLD_BOUNDS do return false
    
    if pos.x <= -WORLD_BOUNDS do return false
    // The world is played on {0, 1, 0} so if it's below 0 on the y-axis, it's not in bounds.
    // This is so that the "zeroed" entities are not considered to be in bounds.
    if pos.y <= 0             do return false
    if pos.z <= -WORLD_BOUNDS do return false
    
    return true
}

world_spawn :: proc { 
    spawn_player,
    spawn_opp,
    spawn_camera,
    spawn_mesh,
    spawn_projectile,
}

spawn_player :: proc(player: ^Entity_Player) {
    player_setup(player)
    world.player = player^
}

spawn_opp :: proc(opp: ^Entity_Opp) {
    opp.idx = _freed_opp_stack.len > 0 ? stack.pop(&_freed_opp_stack) : world.opp_count
    world.opps[opp.idx] = opp^
    world.opp_count += 1 
}

spawn_camera :: proc(camera: ^Entity_Camera) {
    camera.idx = _freed_camera_stack.len > 0 ? stack.pop(&_freed_camera_stack) : world.camera_count
    world.cameras[camera.idx] = camera^
    world.camera_count += 1 
}

spawn_mesh :: proc(mesh: ^Entity_Mesh) {
    mesh.idx = _freed_mesh_stack.len > 0 ? stack.pop(&_freed_mesh_stack) : world.mesh_count
    world.meshes[mesh.idx] = mesh^
    world.mesh_count += 1 
}

spawn_projectile :: proc(p: ^Entity_Projectile) {
    p.idx = _freed_projectile_stack.len > 0 ? stack.pop(&_freed_projectile_stack) : world.projectile_count
    world.projectiles[p.idx] = p^
    world.projectile_count += 1 
}

world_destroy :: proc {
    destroy_player,
    destroy_opp,
    destroy_camera,
    destroy_mesh,
    destroy_projectile,
}

destroy_player :: proc() {
    player_cleanup()
}

destroy_opp :: proc(opp: Entity_Opp) {
    stack.push(&_freed_opp_stack, opp.idx)
    world.opps[opp.idx] = {}
    world.opp_count -= 1
}

destroy_camera :: proc(camera: Entity_Camera) {
    stack.push(&_freed_camera_stack, camera.idx)
    world.cameras[camera.idx] = {}
    world.camera_count -= 1
}

destroy_mesh :: proc(mesh: Entity_Mesh) {
    stack.push(&_freed_mesh_stack, mesh.idx)
    world.meshes[mesh.idx] = {}
    world.mesh_count -= 1
}

destroy_projectile :: proc(p: Entity_Projectile) { 
    stack.push(&_freed_projectile_stack, p.idx)
    world.projectiles[p.idx] = {}
    world.projectile_count -= 1
}