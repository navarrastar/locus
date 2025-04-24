package game

import "core:mem"

import im "shared:imgui"
import im_sdlgpu "shared:imgui/imgui_impl_sdlgpu3"
import sdl "vendor:sdl3"

import m "../math"

NEAR_PLANE :: 0.001
FAR_PLANE :: 1000
DEPTH_STENCIL_FORMAT :: sdl.GPUTextureFormat.D32_FLOAT_S8_UINT


RenderState :: struct {
	gpu:               ^sdl.GPUDevice,
	swapchain_texture: ^sdl.GPUTexture,
	depth_texture:     ^sdl.GPUTexture,
	cmd_buffer:        ^sdl.GPUCommandBuffer,
}

renderer_init :: proc() {
	render_state.gpu = sdl.CreateGPUDevice({SHADER_FORMAT}, true, nil)
	assert(render_state.gpu != nil, string(sdl.GetError()))

	assert(sdl.ClaimWindowForGPUDevice(render_state.gpu, window), "GPU failed to claim window")

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

renderer_cleanup :: proc() {
	free(&render_state)
}



/* DRAW */

renderer_draw :: proc {
	renderer_draw_world,
	renderer_draw_entity,
	renderer_draw_geometry,
}

renderer_draw_world :: proc() {
    active_camera := world.cameras[0]
    
    world_buffer: GPUWorldBuffer
	world_buffer.view       = m.look_at(active_camera.transform.pos, active_camera.target, active_camera.up)
	world_buffer.proj       = m.perspective(active_camera.fovy, window_aspect_ratio(), NEAR_PLANE, FAR_PLANE)
	
	renderer_update_swapchain_texture()
	if render_state.swapchain_texture == nil do return

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
	render_pass := sdl.BeginGPURenderPass(
		render_state.cmd_buffer,
		&color_target,
		1,
		&depth_target_info,
	)

	
	if len(world.player.geometry.vertices) != 0 {
		renderer_draw(render_pass, &world.player)
	}
	for &opponent in world.opponents {
		if len(opponent.geometry.vertices) == 0 do continue
		renderer_draw(render_pass, &opponent)
	}
	for &camera in world.cameras {
		if len(camera.geometry.vertices) == 0 do continue
		renderer_draw(render_pass, &camera)
	}
	for &static_mesh in world.static_meshes {
		if len(static_mesh.geometry.vertices) == 0 do continue
		// This doesnt work unless it is right here
		sdl.PushGPUVertexUniformData(render_state.cmd_buffer, 0, &world_buffer, size_of(GPUWorldBuffer)) 
		renderer_draw(render_pass, &static_mesh)
	}

	sdl.EndGPURenderPass(render_pass)
}

renderer_draw_entity :: proc(render_pass: ^sdl.GPURenderPass, entity: ^Entity) {
	entity.geometry.model_matrix = m.to_matrix(entity.transform)
	renderer_draw(render_pass, &entity.geometry)
}

renderer_draw_geometry :: proc(render_pass: ^sdl.GPURenderPass, geom: ^Geometry) {
	if (geom.vertex_buffer == nil) {
		renderer_setup_vertex_buffer(geom)
	}
	if (materials[geom.material_type].pipeline == nil) {
	    material_create(geom.material_type)
	}

	sdl.BindGPUGraphicsPipeline(render_pass, materials[geom.material_type].pipeline)
	
	object_buffer: GPUObjectBuffer
	object_buffer.model = geom.model_matrix
	sdl.PushGPUVertexUniformData(render_state.cmd_buffer, 1, &object_buffer, size_of(GPUObjectBuffer))

	sdl.BindGPUVertexBuffers(render_pass, 0, &sdl.GPUBufferBinding{buffer = geom.vertex_buffer}, 1)


	sdl.DrawGPUPrimitives(render_pass, geom.vertex_count, 1, 0, 0)
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

renderer_setup_vertex_buffer :: proc(geom: ^Geometry) {
	vertices_size := geom.vertex_size * geom.vertex_count
	vertex_buffer := sdl.CreateGPUBuffer(render_state.gpu, {usage = {.VERTEX}, size = vertices_size})
	assert(vertex_buffer != nil, string(sdl.GetError()))

	transfer_buffer := sdl.CreateGPUTransferBuffer(render_state.gpu, {usage = .UPLOAD, size = vertices_size})
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

renderer_update_swapchain_texture :: proc() {
	_ = sdl.WaitAndAcquireGPUSwapchainTexture(
		render_state.cmd_buffer,
		window,
		&render_state.swapchain_texture,
		nil,
		nil,
	)
}
