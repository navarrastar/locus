package imgui_impl_sdlgpu3

import imgui "../"
import sdl "vendor:sdl3"

when      ODIN_OS == .Windows { foreign import lib "../imgui_windows_x64.lib" }
else when ODIN_OS == .Linux   { foreign import lib "../imgui_linux_x64.a" }
else when ODIN_OS == .Darwin  {
	when ODIN_ARCH == .amd64 { foreign import lib "../imgui_darwin_x64.a" } else { foreign import lib "../imgui_darwin_arm64.a" }
}

// imgui_impl_sdl3.h
// Last checked `v1.91.9b-docking` (4806a19)
//
// Initialization data, for ImGui_ImplSDLGPU_Init()
// - Remember to set ColorTargetFormat to the correct format. If you're rendering to the swapchain, call SDL_GetGPUSwapchainTextureFormat to query the right value
InitInfo :: struct {
	Device: ^sdl.GPUDevice,
	ColorTargetFormat: sdl.GPUTextureFormat,
	MSAASamples: sdl.GPUSampleCount
}

texture_id :: #force_inline proc(binding: ^sdl.GPUTextureSamplerBinding) -> imgui.TextureID {
	return transmute(imgui.TextureID)binding
}

@(link_prefix="ImGui_ImplSDLGPU3_")
foreign lib {
	Init :: proc(info: ^InitInfo) -> bool ---
	Shutdown :: proc() ---
	NewFrame :: proc() ---
	RenderDrawData :: proc(draw_data: ^imgui.DrawData, command_buffer: ^sdl.GPUCommandBuffer, render_pass: ^sdl.GPURenderPass, pipeline: ^sdl.GPUGraphicsPipeline = nil) ---
	CreateDeviceObjects :: proc() ---
	DestroyDeviceObjects :: proc() ---
	CreateFontsTexture :: proc() ---
	DestroyFontsTexture :: proc() ---
}

@(link_prefix="Imgui_ImplSDLGPU3_") // typo in the original lib (note the small g in Imgui)
foreign lib {
	PrepareDrawData :: proc(draw_data: ^imgui.DrawData, command_buffer: ^sdl.GPUCommandBuffer) ---
}
