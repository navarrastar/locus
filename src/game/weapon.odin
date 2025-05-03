package game

import "core:log"
import "core:time"
// import sdl "vendor:sdl3"


// Every variant MUST begin with "using base: WeaponBase"
// because this is a common operation:
// cast(^WeaponBase)&weapon
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

weapon_can_use :: proc(weapon: WeaponBase) -> bool {
	return time.diff(weapon.last_used, time.now()) >= weapon.cooldown
}

weapon_use :: proc(weapon: ^Weapon, user: eID) -> (used: bool) {
	base := cast(^WeaponBase)weapon
	weapon_can_use(base^) or_return
	switch &v in weapon {
	case Weapon_Fireball:
		_use_fireball(&v, user)
		return true
	case Weapon_Scythe:
		_use_scythe(&v, user)
		return true
	case:
		log.error("You dont have a weapon equiped in that slot")
	}
	return false
}

// ----------------------------------------

WEAPON_FIREBALL_SPEED :: 30
WEAPON_FIREBALL_DAMAGE :: 25
WEAPON_FIREBALL_COOLDOWN :: time.Second
WEAPON_FIREBALL_SIZE :: 1.5

Weapon_Fireball :: struct {
	using base: WeaponBase,
}

weapon_fireball :: proc() -> Weapon_Fireball {
	return Weapon_Fireball {
		speed = WEAPON_FIREBALL_SPEED,
		damage = WEAPON_FIREBALL_DAMAGE,
		size = WEAPON_FIREBALL_SIZE,
		cooldown = WEAPON_FIREBALL_COOLDOWN,
	}
}

_use_fireball :: proc(fireball: ^Weapon_Fireball, user: eID) {
	user_base := get_base(user)
	proj := Entity_Projectile {
		name = "Fireball",
		parent = user,
		transform = {
			// if the projectile is on y=0, it wont update
			pos   = user_base.pos + {0, 0.1, 0},
			rot   = user_base.rot,
			scale = fireball.size,
		},
		geom = cube(material = .Test),
		speed = fireball.speed,
		damage = fireball.damage,
		velocity = user_base.face_dir,
		phys = {layer = {.Layer1}, mask = {.Mask0}},
	}
	world_spawn(&proj)

	fireball.last_used = time.now()
}

// ----------------------------------------

WEAPON_SCYTHE_SPEED :: 15
WEAPON_SCYTHE_DAMAGE :: 10
WEAPON_SCYTHE_COOLDOWN :: time.Millisecond * 500
WEAPON_SCYTHE_SIZE :: 2

Weapon_Scythe :: struct {
	using base: WeaponBase,
}

weapon_scythe :: proc() -> Weapon_Scythe {
	return Weapon_Scythe {
		speed = WEAPON_SCYTHE_SPEED,
		damage = WEAPON_SCYTHE_DAMAGE,
		size = WEAPON_SCYTHE_SIZE,
		cooldown = WEAPON_SCYTHE_COOLDOWN,
	}
}

_use_scythe :: proc(fireball: ^Weapon_Scythe, user: eID) {
	user_base := get_base(user)
	proj := Entity_Projectile {
		name = "Fireball",
		parent = user,
		transform = {
			// if the projectile is on y=0, it wont update
			pos   = user_base.pos + {0, 0.1, 0},
			rot   = user_base.rot,
			scale = fireball.size,
		},
		geom = cube(material = .Test),
		speed = fireball.speed,
		damage = fireball.damage,
		velocity = user_base.face_dir,
		phys = {layer = {.Layer1}, mask = {.Mask0}},
	}
	world_spawn(&proj)

	fireball.last_used = time.now()
}

// ----------------------------------------
