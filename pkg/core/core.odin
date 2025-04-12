package core

import "base:runtime"
import "core:log"

import "pkg:core/world"
import m "pkg:core/math"
import "pkg:core/window"
import "pkg:core/event"
import "pkg:core/renderer"
import "pkg:core/ui"



init :: proc() {
    ui.init()
    window.init()
    renderer.init()
    event.init()
    world.init()
}

loop :: proc() {
    ui_commands := ui.loop()
    renderer.loop(&ui_commands)
}

cleanup :: proc() {
    renderer.cleanup()
    window.cleanup()
    event.cleanup()
}
