package game

import "core:log"
import sa "core:container/small_array"

import m "../math"


projectile_update :: proc(proj: ^Entity_Projectile) {
    if world_in_bounds(proj.pos) {
        proj.pos += m.normalize(proj.velocity) * proj.speed * dt
        
        eids: CollidedWith
        
        phys_check_collisions(proj, &eids)
        eids_loop: for i in 0..<sa.len(eids) {
            eid := sa.get(eids, i)
            for j in 0..<sa.len(proj.collided) {
                // if the eid is already present in proj.collided, than skip it
                // this means the same proj can never collide the same eid twice
                (sa.get(proj.collided, j) != eid) or_continue eids_loop
            }
            #partial switch &v in world.entities[eid] {
                case Entity_Opp:
                    opp_take_damage(v.eid, proj.damage)
            }
            
            proj.collided = eids // tell the proj who it has collided with
            
            log.infof("{} hit {}", proj.parent, sa.get(eids, i))
        }
    } else {
        if proj.pos.y != 0 do world_destroy(proj^)
    }
}