package world

import "core:log"
import "core:strings"
import "core:fmt"

import m "pkg:core/math"



entities: [1024]EntityVariant

init :: proc() {
}

spawn :: proc(entity: EntityVariant) -> (e: Entity) {
    @(static) entity_count: eid

    entities[entity_count] = entity

    e.id = entity_count
    entity_count += 1

    log.debug("Spawning", entity)
    return e
}
