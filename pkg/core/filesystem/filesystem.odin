package filesystem

import "pkg:core/filesystem/loaded"

init :: proc() -> bool {
    return loaded.init()
}

cleanup :: proc() {
    loaded.cleanup()
}