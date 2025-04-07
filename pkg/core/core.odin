package core

import "core:log"
import "base:runtime"

import m "pkg:core/math"
import "pkg:core/window"
import "pkg:core/filesystem"



init :: proc(ctx: ^runtime.Context) {
    window.init(ctx)
    filesystem.init()
}

cleanup :: proc() {
    window.cleanup()
    filesystem.cleanup()
}
