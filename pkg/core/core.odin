package core

import "base:runtime"
import "core:log"

import m "pkg:core/math"
import "pkg:core/window"
import "pkg:core/event"
import "pkg:core/renderer"


init :: proc() {
    if !window.init()     do panic("Failed to initialize window")
    if !renderer.init()   do panic("Failed to initialize renderer")
    if !event.init()      do panic("Failed to initalize event")
}

loop :: proc() {
    renderer.loop()
}

cleanup :: proc() {
    renderer.cleanup()
    window.cleanup()
    event.cleanup()
}
