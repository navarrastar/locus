package game

// import "core:log"

import m "../math"
import "../stack"

World :: struct {
	entities:     [1024]Entity,
	entity_count: eID,
}

_freed_eid_stack: stack.Stack(eID)

world_spawn :: proc {
	spawn_base,
	spawn_player,
	spawn_opp,
	spawn_camera,
	spawn_mesh,
	spawn_projectile,
}

spawn_base :: proc(base: ^EntityBase) {
	base.eid = 0
	world.entities[0] = base^
	world.entity_count += 1
}

spawn_player :: proc(player: ^Entity_Player) {
	player_setup(player)
	player.eid = _freed_eid_stack.len > 0 ? stack.pop(&_freed_eid_stack) : world.entity_count
	world.entities[player.eid] = player^
	world.entity_count += 1
}

spawn_opp :: proc(opp: ^Entity_Opp) {
	opp.eid = _freed_eid_stack.len > 0 ? stack.pop(&_freed_eid_stack) : world.entity_count
	world.entities[opp.eid] = opp^
	world.entity_count += 1
}

spawn_camera :: proc(camera: ^Entity_Camera) {
	camera.eid = _freed_eid_stack.len > 0 ? stack.pop(&_freed_eid_stack) : world.entity_count
	world.entities[camera.eid] = camera^
	world.entity_count += 1
}

spawn_mesh :: proc(mesh: ^Entity_Mesh) {
	mesh.eid = _freed_eid_stack.len > 0 ? stack.pop(&_freed_eid_stack) : world.entity_count
	world.entities[mesh.eid] = mesh^
	world.entity_count += 1
}

spawn_projectile :: proc(p: ^Entity_Projectile) {
	p.eid = _freed_eid_stack.len > 0 ? stack.pop(&_freed_eid_stack) : world.entity_count
	world.entities[p.eid] = p^
	world.entity_count += 1
}

world_destroy :: proc {
	destroy_player,
	destroy_opp,
	destroy_camera,
	destroy_mesh,
	destroy_projectile,
}

destroy_player :: proc() {
	player_cleanup()
}

destroy_opp :: proc(opp: Entity_Opp) {
    if opp.geom.vertices != nil do delete(opp.geom.vertices)
	stack.push(&_freed_eid_stack, opp.eid)
	world.entities[opp.eid] = {}
	world.entity_count -= 1
}

destroy_camera :: proc(camera: Entity_Camera) {
    if camera.geom.vertices != nil do delete(camera.geom.vertices)
	stack.push(&_freed_eid_stack, camera.eid)
	world.entities[camera.eid] = {}
	world.entity_count -= 1
}

destroy_mesh :: proc(mesh: Entity_Mesh) {
    if mesh.geom.vertices != nil do delete(mesh.geom.vertices)
	stack.push(&_freed_eid_stack, mesh.eid)
	world.entities[mesh.eid] = {}
	world.entity_count -= 1
}

destroy_projectile :: proc(p: Entity_Projectile) {
    if p.geom.vertices != nil do delete(p.geom.vertices)
	stack.push(&_freed_eid_stack, p.eid)
	world.entities[p.eid] = {}
	world.entity_count -= 1
}

world_update_entity :: proc(e: ^Entity) {
	switch &v in e {
	case EntityBase:

	case Entity_Player:
	    player_update(&v)
	case Entity_Opp:
	    // log.info(v.health)
	case Entity_Mesh:

	case Entity_Camera:
	    camera_update(&v)
	case Entity_Projectile:
		projectile_update(&v)
	}	
	
	base := cast(^EntityBase)e
	animation_continue(base)
	base.geom.model_matrix = m.to_matrix(base.transform)
}

world_camera :: proc() -> Entity_Camera {
	for e in world.entities {
		if cam, ok := e.(Entity_Camera); ok {
			return cam
		}
	}
	panic("")
}

world_in_bounds :: proc(pos: m.Vec3) -> bool {
	if pos.x >= WORLD_BOUNDS do return false
	if pos.y >= WORLD_BOUNDS do return false
	if pos.z >= WORLD_BOUNDS do return false

	if pos.x <= -WORLD_BOUNDS do return false
	// The world is played on {0, 1, 0} so if it's below 0 on the y-axis, it's not in bounds.
	// This is so that the "zeroed" entities are not considered to be in bounds.
	if pos.y <= 0 do return false
	if pos.z <= -WORLD_BOUNDS do return false

	return true
}

world_get_player :: proc() -> ^Entity_Player {
	for &e in world.entities {
		#partial switch v in e {
		case Entity_Player:
			return &e.(Entity_Player)
		}
	}
	panic("")
}
