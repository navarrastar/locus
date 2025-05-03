package game

import "core:log"
import "core:time"

import sdl "vendor:sdl3"

import m "../math"


pipeline_bind :: proc(pass: ^sdl.GPURenderPass, geom: Geometry) {
	sdl.BindGPUGraphicsPipeline(pass, materials[geom.material_type].pipeline)

	pipeline_push_buffers(pass, geom)

	object_buffer: GPUObjectBuffer
	object_buffer.model = geom.model_matrix
	sdl.PushGPUVertexUniformData(
		render_state.cmd_buffer,
		0,
		&object_buffer,
		size_of(GPUObjectBuffer),
	)
}


pipeline_push_buffers :: proc(pass: ^sdl.GPURenderPass, geom: Geometry) {
	switch geom.material_type {
	case .Default, .Grid:
		camera := world_camera()

		world_buffer := GPUWorldBuffer {
		    view = camera.view,
			proj = camera.proj
		}

		sdl.PushGPUVertexUniformData(
			render_state.cmd_buffer,
			1,
			&world_buffer,
			size_of(GPUWorldBuffer),
		)
	case .Test:
		time_elapsed := time.since(start_time)
		seconds := f32(time.duration_seconds(time_elapsed))

		test_buffer: GPUTestBuffer
		test_buffer.test.x = seconds // elapsed time in seconds
		test_buffer.test.y = f32(window_height)
		test_buffer.test.z = f32(window_width)

		sdl.PushGPUFragmentUniformData(
			render_state.cmd_buffer,
			0,
			&test_buffer,
			size_of(GPUTestBuffer),
		)
	case .Mesh:
		active_camera := world_camera()

		world_buffer: GPUWorldBuffer
		world_buffer.view = m.look_at(
			active_camera.transform.pos,
			active_camera.target,
			active_camera.up,
		)
		world_buffer.proj = m.perspective(
			active_camera.fovy,
			window_aspect_ratio(),
			NEAR_PLANE,
			FAR_PLANE,
		)

		sdl.PushGPUVertexUniformData(
			render_state.cmd_buffer,
			1,
			&world_buffer,
			size_of(GPUWorldBuffer),
		)

		sdl.BindGPUFragmentSamplers(
			pass,
			0,
			&(sdl.GPUTextureSamplerBinding {
					texture = geom.diffuse.texture,
					sampler = geom.diffuse.sampler,
				}),
			1,
		)
	}

}

pipeline_create :: proc(type: MaterialType) {
	switch type {
	case .Default:
		pipeline_create_default()
	case .Grid:
		pipeline_create_grid()
	case .Test:
		pipeline_create_test()
	case .Mesh:
		pipeline_create_mesh()
	}
}

pipeline_create_default :: proc() {
	vert_shader := shader_load(SHADER_DIR + "hlsl/default.vert.hlsl", 2, 0)
	frag_shader := shader_load(SHADER_DIR + "hlsl/default.frag.hlsl", 0, 0)
	if vert_shader == nil || frag_shader == nil {
		log.error("Failed to load default shaders")
		return
	}
	attributes := ATTRIBUTES_POS_COL_NORM
	pipeline_desc := sdl.GPUGraphicsPipelineCreateInfo {
		vertex_shader = vert_shader,
		fragment_shader = frag_shader,
		primitive_type = .TRIANGLELIST,
		vertex_input_state = {
			num_vertex_buffers = 1,
			vertex_buffer_descriptions = &(sdl.GPUVertexBufferDescription {
					slot = 0,
					pitch = size_of(Vertex_PosColNorm),
				}),
			num_vertex_attributes = u32(len(attributes)),
			vertex_attributes = &attributes[0],
		},
		depth_stencil_state = {
			compare_op = .LESS,
			enable_depth_test = true,
			enable_depth_write = true,
		},
		target_info = {
			num_color_targets = 1,
			color_target_descriptions = &(sdl.GPUColorTargetDescription {
					format = swapchain_texture_format,
				}),
			has_depth_stencil_target = true,
			depth_stencil_format = DEPTH_STENCIL_FORMAT,
		},
	}
	materials[.Default].pipeline = sdl.CreateGPUGraphicsPipeline(render_state.gpu, pipeline_desc)
	assert(materials[.Default].pipeline != nil, string(sdl.GetError()))

	sdl.ReleaseGPUShader(render_state.gpu, vert_shader)
	sdl.ReleaseGPUShader(render_state.gpu, frag_shader)
}

pipeline_create_grid :: proc() {
	vert_shader := shader_load(SHADER_DIR + "hlsl/grid.vert.hlsl", 2, 0)
	frag_shader := shader_load(SHADER_DIR + "hlsl/grid.frag.hlsl", 0, 0)
	if vert_shader == nil || frag_shader == nil {
		log.error("Failed to load grid shaders")
		return
	}

	attributes := ATTRIBUTES_POS_COL
	pipeline_desc := sdl.GPUGraphicsPipelineCreateInfo {
		vertex_shader = vert_shader,
		fragment_shader = frag_shader,
		primitive_type = .TRIANGLELIST,
		vertex_input_state = {
			num_vertex_buffers = 1,
			vertex_buffer_descriptions = &(sdl.GPUVertexBufferDescription {
					slot = 0,
					pitch = size_of(Vertex_PosCol),
				}),
			num_vertex_attributes = u32(len(attributes)),
			vertex_attributes = &attributes[0],
		},
		depth_stencil_state = {
			compare_op = .LESS,
			enable_depth_test = true,
			enable_depth_write = true,
		},
		target_info = {
			num_color_targets = 1,
			color_target_descriptions = &(sdl.GPUColorTargetDescription {
					format = swapchain_texture_format,
				}),
			has_depth_stencil_target = true,
			depth_stencil_format = DEPTH_STENCIL_FORMAT,
		},
	}
	materials[.Grid].pipeline = sdl.CreateGPUGraphicsPipeline(render_state.gpu, pipeline_desc)
	assert(materials[.Grid].pipeline != nil, string(sdl.GetError()))

	sdl.ReleaseGPUShader(render_state.gpu, vert_shader)
	sdl.ReleaseGPUShader(render_state.gpu, frag_shader)
}

pipeline_create_test :: proc() {
	vert_shader := shader_load(SHADER_DIR + "hlsl/default.vert.hlsl", 2, 0)
	frag_shader := shader_load(SHADER_DIR + "hlsl/test.frag.hlsl", 1, 0)
	if vert_shader == nil || frag_shader == nil {
		log.error("Failed to load test shaders")
		return
	}
	attributes := ATTRIBUTES_POS_COL_NORM
	pipeline_desc := sdl.GPUGraphicsPipelineCreateInfo {
		vertex_shader = vert_shader,
		fragment_shader = frag_shader,
		primitive_type = .TRIANGLELIST,
		vertex_input_state = {
			num_vertex_buffers = 1,
			vertex_buffer_descriptions = &(sdl.GPUVertexBufferDescription {
					slot = 0,
					pitch = size_of(Vertex_PosColNorm),
				}),
			num_vertex_attributes = u32(len(attributes)),
			vertex_attributes = &attributes[0],
		},
		depth_stencil_state = {
			compare_op = .LESS,
			enable_depth_test = true,
			enable_depth_write = true,
		},
		target_info = {
			num_color_targets = 1,
			color_target_descriptions = &(sdl.GPUColorTargetDescription {
					format = swapchain_texture_format,
				}),
			has_depth_stencil_target = true,
			depth_stencil_format = DEPTH_STENCIL_FORMAT,
		},
	}
	materials[.Test].pipeline = sdl.CreateGPUGraphicsPipeline(render_state.gpu, pipeline_desc)
	assert(materials[.Test].pipeline != nil, string(sdl.GetError()))

	sdl.ReleaseGPUShader(render_state.gpu, vert_shader)
	sdl.ReleaseGPUShader(render_state.gpu, frag_shader)
}

pipeline_create_mesh :: proc() {
	vert_shader := shader_load(SHADER_DIR + "hlsl/mesh.vert.hlsl", 2, 0)
	frag_shader := shader_load(SHADER_DIR + "hlsl/mesh.frag.hlsl", 0, 1)
	if vert_shader == nil || frag_shader == nil {
		log.error("Failed to load mesh shaders")
		return
	}
	attributes := ATTRIBUTES_POS_COL_NORM_UV
	pipeline_desc := sdl.GPUGraphicsPipelineCreateInfo {
		vertex_shader = vert_shader,
		fragment_shader = frag_shader,
		primitive_type = .TRIANGLELIST,
		vertex_input_state = {
			num_vertex_buffers = 1,
			vertex_buffer_descriptions = &(sdl.GPUVertexBufferDescription {
					slot = 0,
					pitch = size_of(Vertex_PosColNormUV),
				}),
			num_vertex_attributes = u32(len(attributes)),
			vertex_attributes = &attributes[0],
		},
		depth_stencil_state = {
			compare_op = .LESS,
			enable_depth_test = true,
			enable_depth_write = true,
		},
		target_info = {
			num_color_targets = 1,
			color_target_descriptions = &(sdl.GPUColorTargetDescription {
					format = swapchain_texture_format,
				}),
			has_depth_stencil_target = true,
			depth_stencil_format = DEPTH_STENCIL_FORMAT,
		},
	}
	materials[.Mesh].pipeline = sdl.CreateGPUGraphicsPipeline(render_state.gpu, pipeline_desc)
	assert(materials[.Mesh].pipeline != nil, string(sdl.GetError()))

	sdl.ReleaseGPUShader(render_state.gpu, vert_shader)
	sdl.ReleaseGPUShader(render_state.gpu, frag_shader)
}
