package game

import "core:log"
import "core:strings"
import "core:fmt"

import m "pkg:math"

World :: struct {
    player:             Entity_Player,
    opponents:      [16]Entity_Opponent,
    cameras:        [16]Entity_Camera,
    static_meshes: [128]Entity_StaticMesh,
}

world_spawn :: proc { spawn_player, spawn_camera, spawn_static_mesh }

spawn_static_mesh :: proc(mesh: Entity_StaticMesh) {
    @static mesh_count := 0

    world.static_meshes[mesh_count] = mesh 

    mesh_count += 1
}