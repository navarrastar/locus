package game

import "core:log"
import "core:time"
// import sdl "vendor:sdl3"

WEAPON_FIREBALL_SPEED    :: 30
WEAPON_FIREBALL_DAMAGE   :: 10
WEAPON_FIREBALL_COOLDOWN :: time.Second
WEAPON_FIREBALL_SIZE     :: 2

WeaponSlot :: enum {
    First,
    Second,
    Third,
    Forth,
    Fifth
}

Weapon :: union {
    Weapon_Fireball,
    Weapon_Scythe,
}

WeaponBase :: struct {
    damage:    f32,
    size:      f32,
    speed:     f32,
    cooldown:  time.Duration,
    last_used: time.Time,
    // sprite: ^sdl.GPUTexture,
    // tooltip: Tooltip
}

Weapon_Fireball :: struct {
    using weapon: WeaponBase
}

weapon_fireball :: proc() -> Weapon_Fireball {
    return Weapon_Fireball {
        speed    = WEAPON_FIREBALL_SPEED,
        damage   = WEAPON_FIREBALL_DAMAGE,
        size     = WEAPON_FIREBALL_SIZE,
        cooldown = WEAPON_FIREBALL_COOLDOWN
    }
}

Weapon_Scythe :: struct {
    using weapon: WeaponBase
}

weapon_can_use :: proc(weapon: WeaponBase) -> bool {
    return time.diff(weapon.last_used, time.now())>= weapon.cooldown
}

weapon_use :: proc(weapon: ^Weapon, entity: Entity) -> (activated: bool) {
    switch &weap in weapon {
    case Weapon_Fireball:
        if weapon_can_use(weap.weapon) {
            fireball := Entity_Projectile {
                name = "Fireball",
                transform = { pos = world.player.pos + {0, 0.1, 0}, rot = world.player.rot, scale = weap.size },
                geometry = sphere(material=.Test),
                speed = weap.speed,
                velocity = world.player.face_dir
            }
            world_spawn(&fireball)
            
            weap.last_used = time.now()
            return true
        } else {
            return false 
        }
    case Weapon_Scythe:
        
        return true
    case:
        log.error("You dont have a weapon equiped in that slot")
    }
    return false
}

