package world

import "core:log"
import "core:strings"
import "core:fmt"

import rl "vendor:raylib"

import m "pkg:core/math"



entities: [1024]EntityVariant
camera: rl.Camera3D

init :: proc() {
    camera = rl.Camera3D {
        position = rl.Vector3{0.0, 10.0, 10.0},
        target = rl.Vector3{0.0, 0.0, 0.0},
        up = rl.Vector3{0.0, 1.0, 0.0},
        fovy = 103,
        projection = .PERSPECTIVE,
    }
}

spawn :: proc(entity: EntityVariant) -> (e: Entity) {
    @(static) entity_count: eid

    entities[entity_count] = entity

    e.id = entity_count
    entity_count += 1

    log.debug("Spawning", entity)
    return e
}
