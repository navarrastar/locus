package core

import "base:runtime"
import "core:log"

import m "pkg:core/math"
import "pkg:core/window"
import "pkg:core/filesystem"
import "pkg:core/event"
import "pkg:core/renderer"


init :: proc(ctx: ^runtime.Context) {
    if !window.init(ctx)  do panic("Failed to initialize window")
    if !filesystem.init() do panic("Failed to initialize filesystem")
    if !renderer.init()   do panic("Failed to initialize renderer")
    if !event.init()      do panic("Failed to initalize event")
}

loop :: proc() {
    renderer.loop()
}

cleanup :: proc() {
    renderer.cleanup()
    window.cleanup()
    filesystem.cleanup()
}
