package core

import "core:log"
import "base:runtime"

import "pkg:core/window"

init :: proc(ctx: ^runtime.Context) {
    window.init()
}

cleanup :: proc() {
    window.cleanup()
}
