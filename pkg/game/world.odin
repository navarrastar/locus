package game

import "core:log"
import "core:strings"
import "core:fmt"

import m "pkg:core/math"
import geo "pkg:core/geometry"


world: ^World

World :: struct {
    player:             Entity_Player,
    opponents:      [16]Entity_Opponent,
    cameras:        [16]Entity_Camera,
    static_meshes: [128]Entity_StaticMesh,
}

spawn :: proc { spawn_player, spawn_camera }