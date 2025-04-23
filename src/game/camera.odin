package game








spawn_camera :: proc(camera: Entity_Camera, index: int) {
    world.cameras[index] = camera
}