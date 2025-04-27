package game

import "core:log"
import m "../math"


projectile_update :: proc() {
    for &projectile in world.projectiles {
        if world_in_bounds(projectile.pos) {
            projectile.pos += m.normalize(projectile.velocity) * projectile.speed * dt
        } else {
            if projectile.pos.y != 0 do world_destroy(projectile)
        }
    }
}