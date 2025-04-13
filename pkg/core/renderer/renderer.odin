package renderer

import "core:log"
import "base:runtime"
import "core:path/filepath"

import sdl "vendor:sdl3"

import w "pkg:core/world"
import "pkg:core/window"
import m "pkg:core/math"



gpu: ^sdl.GPUDevice

init :: proc() {
    gpu = sdl.CreateGPUDevice({ .MSL }, true, nil)
    assert(gpu != nil, "Failed to create GPU device")

    assert(sdl.ClaimWindowForGPUDevice(gpu, window.window), "GPU failed to claim window")
}

loop :: proc() {
    cmd_buffer := sdl.AcquireGPUCommandBuffer(gpu)

    swapchain_texture: ^sdl.GPUTexture
    assert(sdl.WaitAndAcquireGPUSwapchainTexture(cmd_buffer, window.window, &swapchain_texture, nil, nil))

    color_target := sdl.GPUColorTargetInfo {
        texture = swapchain_texture,
        load_op = .CLEAR,
        clear_color = { 0.2, 0.2, 0.4, 1.0 },
        store_op = .STORE
    }
    render_pass := sdl.BeginGPURenderPass(cmd_buffer, &color_target, 1, nil)
    // rl.ClearBackground({ 74, 45, 83, 100 })
    // rl.BeginDrawing()

    // rl.BeginMode3D(w.camera)
    // rl.DrawGrid(10, 1)

    // draw_world()

    // rl.EndMode3D()
    // rl.EndDrawing()
    sdl.EndGPURenderPass(render_pass)
    assert(sdl.SubmitGPUCommandBuffer(cmd_buffer))
}

cleanup :: proc() {

}