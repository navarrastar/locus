package game

import "core:log"
import "core:time"
// import sdl "vendor:sdl3"

WEAPON_FIREBALL_SPEED :: 30
WEAPON_FIREBALL_DAMAGE :: 50
WEAPON_FIREBALL_COOLDOWN :: time.Second
WEAPON_FIREBALL_SIZE :: 2

WeaponSlot :: enum {
	First,
	Second,
	Third,
	Forth,
	Fifth,
}

Weapon :: union {
	Weapon_Fireball,
	Weapon_Scythe,
}

WeaponBase :: struct {
	owner:     eID,
	damage:    f32,
	size:      f32,
	speed:     f32,
	cooldown:  time.Duration,
	last_used: time.Time,
	// sprite: ^sdl.GPUTexture,
	// tooltip: Tooltip
}

Weapon_Fireball :: struct {
	using weapon: WeaponBase,
}

weapon_fireball :: proc() -> Weapon_Fireball {
	return Weapon_Fireball {
		speed = WEAPON_FIREBALL_SPEED,
		damage = WEAPON_FIREBALL_DAMAGE,
		size = WEAPON_FIREBALL_SIZE,
		cooldown = WEAPON_FIREBALL_COOLDOWN,
	}
}

Weapon_Scythe :: struct {
	using weapon: WeaponBase,
}

weapon_can_use :: proc(weapon: WeaponBase) -> bool {
	return time.diff(weapon.last_used, time.now()) >= weapon.cooldown
}

weapon_use :: proc(weapon: ^Weapon, eid: eID) -> (activated: bool) {
    player := world_get_player()
	switch &weap in weapon {
	case Weapon_Fireball:
		if weapon_can_use(weap.weapon) {
			fireball := Entity_Projectile {
				name = "Fireball",
				parent = eid,
				transform = {
					pos = get_base(eid).pos + {0, 0.1, 0},
					rot = player.rot,
					scale = weap.size,
				},
				geom = sphere(material = .Test),
				speed = weap.speed,
				damage = WEAPON_FIREBALL_DAMAGE,
				velocity = player.face_dir,
				phys = {layer = .Layer0, mask = .Mask0},
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
