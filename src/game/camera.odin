package game

import m "../math"


camera_update :: proc(cam: ^Entity_Camera) {
	cam.view = m.look_at(cam.transform.pos, cam.target, cam.up)
	cam.proj = m.perspective(cam.fovy, window_aspect_ratio(), NEAR_PLANE, FAR_PLANE)
	cam.viewProj = cam.proj * cam.view
}
