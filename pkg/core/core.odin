package core

import "base:runtime"
import "core:log"

import "pkg:core/world"
import m "pkg:core/math"
import "pkg:core/window"
import "pkg:core/event"
import "pkg:core/renderer"


init :: proc() {
    window.init()
    renderer.init()
    event.init()
    world.init()
}

loop :: proc() {
    renderer.loop()
}

cleanup :: proc() {
    renderer.cleanup()
    window.cleanup()
    event.cleanup()
}
