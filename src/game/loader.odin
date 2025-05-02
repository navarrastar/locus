package game

import "core:log"
import "core:strings"

import gltf "../../third_party/gltf2"



gltf_load :: proc(name: string) -> (data: ^gltf.Data, err: gltf.Error) {
    log.infof("loading {}", name)
    path, _ := strings.concatenate({MODEL_DIR, name, ".glb"})
    return gltf.load_from_file(path)
}