package game

import "core:log"

import rl "vendor:raylib"

import "pkg:core/ecs"
import "pkg:core/event"
import "pkg:core/input"
import m "pkg:core/math"



spawn_camera :: proc() {
    entity_camera := ecs.spawn(name="Perspective Camera")

    camera := ecs.Camera {
        position = { 0.0, 5.0, 5.0 },
        target = { 0.0, 2.0, 0.0 },
        up = { 0.0, 1.0, 0.0 },
        fovy = 103,
        projection = .PERSPECTIVE
    };

    ecs.add_components(entity_camera, camera)

}

update_camera :: proc() {
    camera := ecs.get_first_camera()

    rl.UpdateCamera(camera, .FREE)

}