package core

import "core:log"
import "base:runtime"

import m "pkg:core/math"
import "pkg:core/window"
import "pkg:core/filesystem"
import "pkg:core/event"
import r "pkg:core/renderer"


init :: proc(ctx: ^runtime.Context) {
    if !window.init(ctx)  do panic("Failed to initialize window")
    if !filesystem.init() do panic("Failed to initialize filesystem")
    if !r.init()          do panic("Failed to initialize renderer")
    if !event.init()      do panic("Failed to initalize event")

}

cleanup :: proc() {
    window.cleanup()
    filesystem.cleanup()
}
