package game

import "core:fmt"

import "../stack"
import m "../math"

import "core:log"



PhysicsWorld :: struct {
    objects:      [256]PhysicsObject,
    object_count: u8
}

_freed_phys_objects: stack.Stack(u8)

PhysicsObject :: struct {
    idx: u8,
    pos: m.Vec3,
    vel: m.Vec3,
}

physics_init :: proc() {
    
}

physics_update :: proc() {
//    log.info(len(phys_world.objects))
}

physics_spawn :: proc(obj: ^PhysicsObject) {
    obj.idx = _freed_phys_objects.len > 0 ? stack.pop(&_freed_phys_objects) : phys_world.object_count
    phys_world.objects[obj.idx] = obj^
    phys_world.object_count += 1
}

physics_destroy :: proc(obj: PhysicsObject) {
    
    
    phys_world.object_count -= 1
}