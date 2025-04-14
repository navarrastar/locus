package game

import "core:log"
import "core:strings"
import "core:fmt"

import m "pkg:core/math"


world: ^World

World :: struct {
    player:             Entity_Player,
    opponents:      [10]Entity_Opponent,
    cameras:        [10]Entity_Camera,
    static_meshes: [100]Entity_StaticMesh
}

spawn :: proc { 
    spawn_player,
    spawn_camera
}