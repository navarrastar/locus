package game

import "core:log"
import sa "core:container/small_array"

import m "../math"


projectile_update :: proc(proj: ^Entity_Projectile) {
    if world_in_bounds(proj.pos) {
        proj.pos += m.normalize(proj.velocity) * proj.speed * dt
        
        eids: CollidedWith
        
        phys_check_collisions(proj, &eids)
        for i in 0..<sa.len(eids) {
            log.infof("{} hit {}", proj.parent, sa.get(eids, i))
        }
    } else {
        if proj.pos.y != 0 do world_destroy(proj^)
    }
}