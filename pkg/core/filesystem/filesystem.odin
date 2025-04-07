package filesystem

import "pkg:core/filesystem/loaded"

init :: proc() {
    loaded.init()
}

cleanup :: proc() {
    loaded.cleanup()
}