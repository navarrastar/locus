package game

import "core:mem"

import im "../../third_party/imgui"
import im_sdlgpu "../../third_party/imgui/imgui_impl_sdlgpu3"
import sdl "vendor:sdl3"

NEAR_PLANE :: 0.001
FAR_PLANE :: 1000
DEPTH_STENCIL_FORMAT :: sdl.GPUTextureFormat.D32_FLOAT_S8_UINT


render_state: struct {
	gpu:               ^sdl.GPUDevice,
	swapchain_texture: ^sdl.GPUTexture,
	depth_texture:     ^sdl.GPUTexture,
	cmd_buffer:        ^sdl.GPUCommandBuffer,
}

renderer_init :: proc() {
	render_state.gpu = sdl.CreateGPUDevice({SHADER_FORMAT}, true, nil)
	assert(render_state.gpu != nil, string(sdl.GetError()))

	assert(sdl.ClaimWindowForGPUDevice(render_state.gpu, window), string(sdl.GetError()))

	swapchain_texture_format = sdl.GetGPUSwapchainTextureFormat(render_state.gpu, window)

	depth_texture_info := sdl.GPUTextureCreateInfo {
		type                 = .D2,
		format               = DEPTH_STENCIL_FORMAT,
		usage                = {.DEPTH_STENCIL_TARGET},
		width                = u32(window_width),
		height               = u32(window_height),
		layer_count_or_depth = 1,
		num_levels           = 1,
	}

	render_state.depth_texture = sdl.CreateGPUTexture(render_state.gpu, depth_texture_info)
	assert(render_state.depth_texture != nil, string(sdl.GetError()))
}

renderer_begin_cmd_buffer :: proc() {
	render_state.cmd_buffer = sdl.AcquireGPUCommandBuffer(render_state.gpu)
}

renderer_end_cmd_buffer :: proc() {
	assert(sdl.SubmitGPUCommandBuffer(render_state.cmd_buffer))
}

renderer_begin_pass :: proc() -> ^sdl.GPURenderPass {
	renderer_update_swapchain_texture()
	if render_state.swapchain_texture == nil do return nil

	color_target := sdl.GPUColorTargetInfo {
		texture     = render_state.swapchain_texture,
		load_op     = .CLEAR,
		clear_color = {0, 0, 0, 1.0},
		store_op    = .STORE,
	}

	depth_target_info := sdl.GPUDepthStencilTargetInfo {
		texture     = render_state.depth_texture,
		load_op     = .LOAD,
		clear_depth = 1,
		store_op    = .DONT_CARE,
	}
	return sdl.BeginGPURenderPass(render_state.cmd_buffer, &color_target, 1, &depth_target_info)
}

renderer_end_pass :: proc(pass: ^sdl.GPURenderPass) {
	sdl.EndGPURenderPass(pass)
}

renderer_cleanup :: proc() {
	free(&render_state)
}


/* DRAW */

renderer_draw_entity :: proc(pass: ^sdl.GPURenderPass, base: ^EntityBase) {
	if base.geom.vertex_count == 0 do return
	if (base.geom.vertex_buffer == nil) {
		renderer_setup_vertex_buffer(&base.geom)
	}
	if (base.geom.index_buffer == nil) {
	    renderer_setup_index_buffer(&base.geom)
	}
	if (materials[base.geom.material_type].pipeline == nil) {
		material_create(base.geom.material_type)
	}

	pipeline_bind(pass, base.geom)

	sdl.BindGPUVertexBuffers(pass, 0, &sdl.GPUBufferBinding{buffer = base.geom.vertex_buffer}, 1)
	sdl.BindGPUIndexBuffer(pass, {buffer = base.geom.index_buffer}, ._16BIT)
	
	sdl.DrawGPUIndexedPrimitives(pass, base.geom.index_count, 1, 0, 0, 0)
}

renderer_draw_ui :: proc(ui_draw_data: ^im.DrawData) {
	if ui_draw_data == nil do return
	im_sdlgpu.PrepareDrawData(ui_draw_data, render_state.cmd_buffer)

	color_target := sdl.GPUColorTargetInfo {
		texture  = render_state.swapchain_texture,
		load_op  = .LOAD,
		store_op = .STORE,
	}

	render_pass := sdl.BeginGPURenderPass(render_state.cmd_buffer, &color_target, 1, nil)

	im_sdlgpu.RenderDrawData(ui_draw_data, render_state.cmd_buffer, render_pass)

	sdl.EndGPURenderPass(render_pass)
}

/* ^DRAW^ */

renderer_setup_vertex_buffer :: proc(geom: ^Geometry) {
	vertices_size := u32(geom.vertex_size) * geom.vertex_count
	vertex_buffer := sdl.CreateGPUBuffer(
		render_state.gpu,
		{usage = {.VERTEX}, size = vertices_size},
	)
	assert(vertex_buffer != nil, string(sdl.GetError()))

	transfer_buffer := sdl.CreateGPUTransferBuffer(
		render_state.gpu,
		{usage = .UPLOAD, size = vertices_size},
	)
	assert(transfer_buffer != nil, string(sdl.GetError()))

	transfer_mem := sdl.MapGPUTransferBuffer(render_state.gpu, transfer_buffer, false)
	mem.copy(transfer_mem, raw_data(geom.vertices), int(vertices_size))
	sdl.UnmapGPUTransferBuffer(render_state.gpu, transfer_buffer)

	copy_cmd_buf := sdl.AcquireGPUCommandBuffer(render_state.gpu)

	copy_pass := sdl.BeginGPUCopyPass(copy_cmd_buf)

	sdl.UploadToGPUBuffer(
		copy_pass,
		{transfer_buffer = transfer_buffer},
		{buffer = vertex_buffer, size = vertices_size},
		false,
	)

	geom.vertex_buffer = vertex_buffer

	sdl.EndGPUCopyPass(copy_pass)

	sdl.ReleaseGPUTransferBuffer(render_state.gpu, transfer_buffer)

	_ = sdl.SubmitGPUCommandBuffer(copy_cmd_buf)
}

renderer_setup_index_buffer :: proc(geom: ^Geometry) {
	indices_size := size_of(Index) * geom.index_count
	index_buffer := sdl.CreateGPUBuffer(
		render_state.gpu,
		{usage = {.INDEX}, size = indices_size},
	)
	assert(index_buffer != nil, string(sdl.GetError()))

	transfer_buffer := sdl.CreateGPUTransferBuffer(
		render_state.gpu,
		{usage = .UPLOAD, size = indices_size},
	)
	assert(transfer_buffer != nil, string(sdl.GetError()))

	transfer_mem := sdl.MapGPUTransferBuffer(render_state.gpu, transfer_buffer, false)
	mem.copy(transfer_mem, raw_data(geom.indices), int(indices_size))
	sdl.UnmapGPUTransferBuffer(render_state.gpu, transfer_buffer)

	copy_cmd_buf := sdl.AcquireGPUCommandBuffer(render_state.gpu)

	copy_pass := sdl.BeginGPUCopyPass(copy_cmd_buf)

	sdl.UploadToGPUBuffer(
		copy_pass,
		{transfer_buffer = transfer_buffer},
		{buffer = index_buffer, size = indices_size},
		false,
	)

	geom.index_buffer = index_buffer

	sdl.EndGPUCopyPass(copy_pass)

	sdl.ReleaseGPUTransferBuffer(render_state.gpu, transfer_buffer)

	_ = sdl.SubmitGPUCommandBuffer(copy_cmd_buf)
}

renderer_update_swapchain_texture :: proc() {
	_ = sdl.WaitAndAcquireGPUSwapchainTexture(
		render_state.cmd_buffer,
		window,
		&render_state.swapchain_texture,
		nil,
		nil,
	)
}
