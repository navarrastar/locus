package renderer

import "core:log"
import "core:math/linalg"
import "base:runtime"
import "core:fmt"
import "core:strings"
import "core:mem"

import wgpu "vendor:wgpu"

import "pkg:core/window"
import "pkg:core/filesystem/loader"
import "pkg:game/ecs"
import m "pkg:core/math"
import c "pkg:game/ecs/component"



Vertex :: struct {
    position: m.Vec3,
    normal: m.Vec3,
    tangent: m.Vec3,
    bitangent: m.Vec3,
    uv: m.Vec2,
    color: m.Vec4,
    joints: [4]u32,
    weights: m.Vec4,
}

Mesh :: struct {
    name: string,
    vertices: []Vertex,
    indices: []u32,
    vertex_buffer: wgpu.Buffer,
    index_buffer: wgpu.Buffer,
    primitives: []Primitive,
}

Primitive :: struct {
    pipeline_key: PipelineKey,
    index_count: []u32,
    first_index: u32,
    base_vertex: u32,
    bind_groups: []wgpu.BindGroup,
}

State :: struct {
    ctx: runtime.Context,
    
    instance: wgpu.Instance,
    surface: wgpu.Surface,
    adapter: wgpu.Adapter,
    device: wgpu.Device,
    config: wgpu.SurfaceConfiguration,
    queue: wgpu.Queue,
    
    // Current frame resources
    surface_texture: wgpu.SurfaceTexture,
    swapchain_view: wgpu.TextureView,
    command_encoder: wgpu.CommandEncoder,
    render_pass: wgpu.RenderPassEncoder,
    
    // Depth buffer resources
    depth_texture: wgpu.Texture,
    depth_texture_view: wgpu.TextureView,
    
    current_frame: u32,
    framebuffer_resized: bool,

    mesh_cache: map[string]Mesh,
    material_cache: map[string]Material,
    pipeline_cache: map[PipelineKey]wgpu.RenderPipeline,
    bind_group_layouts: map[MaterialType]wgpu.BindGroupLayout,
    pipeline_layouts: map[MaterialType]wgpu.PipelineLayout,
}

state: State

init :: proc() -> (success: bool) {
    state.ctx = context
    
    if state.instance = wgpu.CreateInstance(nil); state.instance == nil {
        panic("Failed to create WGPU Instance")
    }
    
    if state.surface = window.get_surface(state.instance); state.surface == nil {
        panic("Failed to get window surface")
    }
    
    options := wgpu.RequestAdapterOptions {
        compatibleSurface = state.surface,
    }
    wgpu.InstanceRequestAdapter(
    state.instance, 
    &options,
    { callback = on_adapter },
    )
   
    create_pbr_bind_group_layout()
    create_unlit_bind_group_layout()

    return true
}

cleanup :: proc() {
    // Clean up current frame resources first
    cleanup_frame_resources()
    
    // Clean up depth resources
    if state.depth_texture_view != nil {
        wgpu.TextureViewRelease(state.depth_texture_view)
        state.depth_texture_view = nil
    }
    
    if state.depth_texture != nil {
        wgpu.TextureRelease(state.depth_texture)
        state.depth_texture = nil
    }
    
    // Release WGPU resources in reverse order of creation
    for _, mesh in state.mesh_cache {
        wgpu.BufferRelease(mesh.vertex_buffer)
        wgpu.BufferRelease(mesh.index_buffer)
    }

    for _, pipeline in state.pipeline_cache {
        wgpu.RenderPipelineRelease(pipeline)
    }
    
    for _, pipeline_layout in state.pipeline_layouts {
        wgpu.PipelineLayoutRelease(pipeline_layout)
    }
    
    if state.queue != nil {
        wgpu.QueueRelease(state.queue)
    }
    
    if state.device != nil {
        wgpu.DeviceRelease(state.device)
    }
    
    if state.adapter != nil {
        wgpu.AdapterRelease(state.adapter)
    }
    
    if state.surface != nil {
        wgpu.SurfaceRelease(state.surface)
    }
    
    if state.instance != nil {
        wgpu.InstanceRelease(state.instance)
    }
}

begin_frame :: proc() -> bool {
    cleanup_frame_resources()
    
    state.surface_texture = wgpu.SurfaceGetCurrentTexture(state.surface)
    
    switch state.surface_texture.status {
    case .SuccessOptimal, .SuccessSuboptimal:
        // continue
    case .Timeout, .Outdated, .Lost:
        // Skip this frame and reconfigure surface
        log.error("Surface texture status: %v", state.surface_texture.status)
        if state.surface_texture.texture != nil {
            wgpu.TextureRelease(state.surface_texture.texture)
            state.surface_texture.texture = nil
        }
        handle_resize()
        return false
    case .OutOfMemory, .DeviceLost, .Error:
        log.panic("Failed to get current texture")
    }

    state.swapchain_view = wgpu.TextureCreateView(state.surface_texture.texture, nil)
    
    // If we don't have a valid depth texture, create one
    if state.depth_texture_view == nil {
        create_depth_texture()
    }
    
    state.command_encoder = wgpu.DeviceCreateCommandEncoder(state.device, nil)
    
    state.render_pass = wgpu.CommandEncoderBeginRenderPass(
        state.command_encoder,
        &wgpu.RenderPassDescriptor{
            colorAttachmentCount = 1,
            colorAttachments = &wgpu.RenderPassColorAttachment{
                view = state.swapchain_view,
                loadOp = .Clear,
                storeOp = .Store,
                clearValue = {0.1, 0.2, 0.3, 1.0},
                depthSlice = wgpu.DEPTH_SLICE_UNDEFINED,
            },
            depthStencilAttachment = &wgpu.RenderPassDepthStencilAttachment{
                view = state.depth_texture_view,
                depthLoadOp = .Clear,
                depthStoreOp = .Store,
                depthClearValue = 1.0,
                depthReadOnly = false,
                stencilLoadOp = .Clear,
                stencilStoreOp = .Store,
                stencilClearValue = 0,
                stencilReadOnly = false,
             },
        },
    )
    return true
}

end_frame :: proc() {
    wgpu.RenderPassEncoderEnd(state.render_pass)
    wgpu.RenderPassEncoderRelease(state.render_pass)
    
    command_buffer := wgpu.CommandEncoderFinish(state.command_encoder, nil)
    
    wgpu.QueueSubmit(state.queue, {command_buffer})
    
    wgpu.CommandBufferRelease(command_buffer)
    
    wgpu.SurfacePresent(state.surface)
    
    state.current_frame += 1
    
    // Note: We do NOT release the resources here
    // They will be released at the start of the next frame or during cleanup
} 

render :: proc { draw_mesh }

draw_mesh :: proc(mesh: ^loader.Mesh) {
    if mesh == nil {
        return
    }

    if ok := mesh.name in state.mesh_cache; !ok { 
        cache_mesh(mesh)
    }

    cached_mesh := state.mesh_cache[mesh.name]
    
    // Set the vertex and index buffers
    wgpu.RenderPassEncoderSetVertexBuffer(state.render_pass, 0, cached_mesh.vertex_buffer, 0, wgpu.WHOLE_SIZE)
    wgpu.RenderPassEncoderSetIndexBuffer(state.render_pass, cached_mesh.index_buffer, .Uint32, 0, wgpu.WHOLE_SIZE)
    
    // Draw each primitive
    for primitive in cached_mesh.primitives {
        wgpu.RenderPassEncoderSetPipeline(state.render_pass, state.pipeline_cache[primitive.pipeline_key])

        for bind_group, i in primitive.bind_groups {
            wgpu.RenderPassEncoderSetBindGroup(state.render_pass, u32(i), bind_group) 
        }

        wgpu.RenderPassEncoderDrawIndexed(
            state.render_pass,
            primitive.index_count[0],
            1,  // instance count
            primitive.first_index,
            i32(primitive.base_vertex),
            0   // first instance
        )
    }
    
}

cleanup_frame_resources :: proc() {
    if state.swapchain_view != nil {
        wgpu.TextureViewRelease(state.swapchain_view)
        state.swapchain_view = nil
    }
    
    if state.command_encoder != nil {
        wgpu.CommandEncoderRelease(state.command_encoder)
        state.command_encoder = nil
    }
    
    state.surface_texture.texture = nil
}

handle_resize :: proc() {
    context = state.ctx
    
    width, height := window.get_window_size()
    state.config.width = width
    state.config.height = height
    wgpu.SurfaceConfigure(state.surface, &state.config)
    
    // Recreate the depth texture when the window is resized
    create_depth_texture()
}

cache_mesh :: proc (mesh: ^loader.Mesh) {
    if mesh == nil {
        return
    }

    // Create our renderer mesh
    renderer_mesh := Mesh{
        name = strings.clone(mesh.name),
    }

    // Count total vertices and indices to allocate arrays
    total_vertices: int
    total_indices: int
    
    for primitive, _ in mesh.primitives {
        // Get position data to determine vertex count
        pos_accessor := primitive.attributes["POSITION"]
        if pos_accessor != nil {
            total_vertices += int(pos_accessor.count)
        }
        
        // Get index count if available
        if primitive.indices != nil {
            total_indices += int(primitive.indices.count)
        }
    }
    
    // Allocate arrays
    renderer_mesh.vertices = make([]Vertex, total_vertices)
    renderer_mesh.indices = make([]u32, total_indices)
    renderer_mesh.primitives = make([]Primitive, len(mesh.primitives))
    
    vertex_offset := 0
    index_offset := 0
    
    // Process each primitive
    for primitive_idx := 0; primitive_idx < len(mesh.primitives); primitive_idx += 1 {
        primitive := mesh.primitives[primitive_idx]
        pipeline_key := PipelineKey{}
        
        // Get position data (required)
        pos_accessor := primitive.attributes["POSITION"]
        if pos_accessor == nil {
            continue
        }
        
        vertex_count := int(pos_accessor.count)
        
        // Create primitive entry
        prim := &renderer_mesh.primitives[primitive_idx]
        prim.base_vertex = u32(vertex_offset)
        prim.first_index = u32(index_offset)
        prim.index_count = make([]u32, 1)        
        
        // Extract position data
        if pos_accessor != nil && pos_accessor.buffer_view != nil && pos_accessor.buffer_view.buffer != nil {
            buffer := pos_accessor.buffer_view.buffer.data
            elem_size := 3 * size_of(f32) // Vec3
            
            for i := 0; i < vertex_count; i += 1 {
                offset := int(pos_accessor.offset + pos_accessor.buffer_view.offset) + i * int(elem_size)
                if offset + int(elem_size) <= len(buffer) {
                    pos: m.Vec3
                    mem.copy(&pos, &buffer[offset], int(elem_size))
                    renderer_mesh.vertices[vertex_offset + i].position = pos
                }
            }
        }
        
        // Extract normal data
        normal_accessor := primitive.attributes["NORMAL"]
        if normal_accessor != nil && normal_accessor.buffer_view != nil && normal_accessor.buffer_view.buffer != nil {
            buffer := normal_accessor.buffer_view.buffer.data
            elem_size := 3 * size_of(f32) // Vec3
            
            for i := 0; i < vertex_count; i += 1 {
                offset := int(normal_accessor.offset + normal_accessor.buffer_view.offset) + i * int(elem_size)
                if offset + int(elem_size) <= len(buffer) {
                    normal: m.Vec3
                    mem.copy(&normal, &buffer[offset], int(elem_size))
                    renderer_mesh.vertices[vertex_offset + i].normal = normal
                }
            }
            pipeline_key.has_normals = true
        }
        
        // Extract tangent data
        tangent_accessor := primitive.attributes["TANGENT"]
        if tangent_accessor != nil && tangent_accessor.buffer_view != nil && tangent_accessor.buffer_view.buffer != nil {
            buffer := tangent_accessor.buffer_view.buffer.data
            elem_size := 3 * size_of(f32) // Vec3
            
            for i := 0; i < vertex_count; i += 1 {
                offset := int(tangent_accessor.offset + tangent_accessor.buffer_view.offset) + i * int(elem_size)
                if offset + int(elem_size) <= len(buffer) {
                    tangent: m.Vec3
                    mem.copy(&tangent, &buffer[offset], int(elem_size))
                    renderer_mesh.vertices[vertex_offset + i].tangent = tangent
                }
            }
            pipeline_key.has_tangents = true
        }
        
        // Extract UV data
        uv_accessor := primitive.attributes["TEXCOORD_0"]
        if uv_accessor != nil && uv_accessor.buffer_view != nil && uv_accessor.buffer_view.buffer != nil {
            buffer := uv_accessor.buffer_view.buffer.data
            elem_size := 2 * size_of(f32) // Vec2
            
            for i := 0; i < vertex_count; i += 1 {
                offset := int(uv_accessor.offset + uv_accessor.buffer_view.offset) + i * int(elem_size)
                if offset + int(elem_size) <= len(buffer) {
                    uv: m.Vec2
                    mem.copy(&uv, &buffer[offset], int(elem_size))
                    renderer_mesh.vertices[vertex_offset + i].uv = uv
                }
            }
            pipeline_key.has_uv = true
        }
        
        // Extract color data
        color_accessor := primitive.attributes["COLOR_0"]
        if color_accessor != nil && color_accessor.buffer_view != nil && color_accessor.buffer_view.buffer != nil {
            buffer := color_accessor.buffer_view.buffer.data
            elem_size := 4 * size_of(f32) // Vec4
            
            for i := 0; i < vertex_count; i += 1 {
                offset := int(color_accessor.offset + color_accessor.buffer_view.offset) + i * int(elem_size)
                if offset + int(elem_size) <= len(buffer) {
                    color: m.Vec4
                    mem.copy(&color, &buffer[offset], int(elem_size))
                    renderer_mesh.vertices[vertex_offset + i].color = color
                }
            }
            pipeline_key.has_vertex_colors = true
        }
        
        // Extract joints data
        joints_accessor := primitive.attributes["JOINTS_0"]
        if joints_accessor != nil && joints_accessor.buffer_view != nil && joints_accessor.buffer_view.buffer != nil {
            buffer := joints_accessor.buffer_view.buffer.data
            elem_size := 4 * size_of(u32) // [4]u32
            
            for i := 0; i < vertex_count; i += 1 {
                offset := int(joints_accessor.offset + joints_accessor.buffer_view.offset) + i * int(elem_size)
                if offset + int(elem_size) <= len(buffer) {
                    joints: [4]u32
                    mem.copy(&joints, &buffer[offset], int(elem_size))
                    renderer_mesh.vertices[vertex_offset + i].joints = joints
                }
            }
            pipeline_key.has_joints = true
        }
        
        // Extract weights data
        weights_accessor := primitive.attributes["WEIGHTS_0"]
        if weights_accessor != nil && weights_accessor.buffer_view != nil && weights_accessor.buffer_view.buffer != nil {
            buffer := weights_accessor.buffer_view.buffer.data
            elem_size := 4 * size_of(f32) // Vec4
            
            for i := 0; i < vertex_count; i += 1 {
                offset := int(weights_accessor.offset + weights_accessor.buffer_view.offset) + i * int(elem_size)
                if offset + int(elem_size) <= len(buffer) {
                    weights: m.Vec4
                    mem.copy(&weights, &buffer[offset], int(elem_size))
                    renderer_mesh.vertices[vertex_offset + i].weights = weights
                }
            }
            pipeline_key.has_weights = true
        }

        // Extract indices if available
        if primitive.indices != nil && primitive.indices.buffer_view != nil && primitive.indices.buffer_view.buffer != nil {
            buffer := primitive.indices.buffer_view.buffer.data
            index_count := int(primitive.indices.count)
            
            // Set the index count for this primitive
            prim.index_count[0] = u32(index_count)
            
            // Determine element size based on component type
            elem_size: int
            #partial switch primitive.indices.component_type {
                case .r_8u: elem_size = size_of(u8)
                case .r_16u: elem_size = size_of(u16)
                case .r_32u: elem_size = size_of(u32)
                case: elem_size = size_of(u32) // Default
            }
            
            for i := 0; i < index_count; i += 1 {
                src_offset := int(primitive.indices.offset + primitive.indices.buffer_view.offset) + i * elem_size
                
                // Convert index data based on component type and add base vertex
                #partial switch primitive.indices.component_type {
                    case .r_8u:
                        if src_offset + size_of(u8) <= len(buffer) {
                            index: u8
                            mem.copy(&index, &buffer[src_offset], size_of(u8))
                            renderer_mesh.indices[index_offset + i] = u32(index) + u32(vertex_offset)
                        }
                    case .r_16u:
                        if src_offset + size_of(u16) <= len(buffer) {
                            index: u16
                            mem.copy(&index, &buffer[src_offset], size_of(u16))
                            renderer_mesh.indices[index_offset + i] = u32(index) + u32(vertex_offset)
                        }
                    case .r_32u:
                        if src_offset + size_of(u32) <= len(buffer) {
                            mem.copy(&renderer_mesh.indices[index_offset + i], &buffer[src_offset], size_of(u32))
                            renderer_mesh.indices[index_offset + i] += u32(vertex_offset)
                        }
                    case:
                        // Skip unsupported index types
                }
            }
            
            index_offset += index_count
        }
        
        vertex_offset += vertex_count

        pipeline_key.material_type = .PBR_MetallicRoughness
        if primitive.material.alpha_mode == .mask {
            pipeline_key.alpha_mode = .Mask
        } else if primitive.material.alpha_mode == .blend {
            pipeline_key.alpha_mode = .Blend
        } else if primitive.material.alpha_mode == .opaque {
            pipeline_key.alpha_mode = .Opaque
        }
        pipeline_key.double_sided = primitive.material.double_sided

        prim.pipeline_key = pipeline_key
        create_pipeline(pipeline_key)
        
        // Create and set bind groups for this primitive
        create_bind_groups(prim, primitive.material)
    }

    // Create and upload vertex buffer
    vertex_buffer_size := len(renderer_mesh.vertices) * size_of(Vertex)
    vertex_buffer_desc := wgpu.BufferDescriptor{
        label = fmt.tprintf("Mesh Vertex Buffer: %s", mesh.name),
        usage = {.Vertex, .CopyDst},
        size = u64(vertex_buffer_size),
    }
    vertex_buffer := wgpu.DeviceCreateBuffer(state.device, &vertex_buffer_desc)
    
    // Copy vertex data to the buffer
    wgpu.QueueWriteBuffer(state.queue, vertex_buffer, 0, &renderer_mesh.vertices[0], uint(vertex_buffer_size))
    
    renderer_mesh.vertex_buffer = vertex_buffer

    // Create and upload index buffer
    index_buffer_size := len(renderer_mesh.indices) * size_of(u32)
    index_buffer_desc := wgpu.BufferDescriptor{
        label = fmt.tprintf("Mesh Index Buffer: %s", mesh.name),
        usage = {.Index, .CopyDst},
        size = u64(index_buffer_size),
    }
    index_buffer := wgpu.DeviceCreateBuffer(state.device, &index_buffer_desc)

    // Copy index data to the buffer
    wgpu.QueueWriteBuffer(state.queue, index_buffer, 0, &renderer_mesh.indices[0], uint(index_buffer_size))

    renderer_mesh.index_buffer = index_buffer

    // Store the mesh in the cache
    state.mesh_cache[mesh.name] = renderer_mesh
}

create_bind_groups :: proc(primitive: ^Primitive, material: ^loader.Material) {
    // Allocate space for bind groups
    bind_groups := make([dynamic]wgpu.BindGroup)
    
    // Different bind group creation based on material type
    switch primitive.pipeline_key.material_type {
    case .PBR_MetallicRoughness:
        // Create uniform buffer for material properties
        material_uniforms := struct {
            base_color_factor: m.Vec4,
            metallic_factor: f32,
            roughness_factor: f32,
            normal_scale: f32,
            emissive_factor: m.Vec3,
            alpha_cutoff: f32,
        }{
            base_color_factor = material.pbr_metallic_roughness.base_color_factor,
            metallic_factor = material.pbr_metallic_roughness.metallic_factor,
            roughness_factor = material.pbr_metallic_roughness.roughness_factor,
            normal_scale = material.normal_scale, 
            emissive_factor = material.emissive_factor,
            alpha_cutoff = material.alpha_cutoff,
        }
        
        // Create uniform buffer
        uniform_buffer_size := size_of(material_uniforms)
        uniform_buffer_desc := wgpu.BufferDescriptor{
            label = "Material Uniform Buffer",
            usage = {.Uniform, .CopyDst},
            size = u64(uniform_buffer_size),
        }
        uniform_buffer := wgpu.DeviceCreateBuffer(state.device, &uniform_buffer_desc)
        
        // Write data to uniform buffer
        wgpu.QueueWriteBuffer(state.queue, uniform_buffer, 0, &material_uniforms, uint(uniform_buffer_size))
        
        // Create default textures and samplers if needed
        default_white_texture, default_white_view := create_default_texture(1, 1, {1.0, 1.0, 1.0, 1.0})
        default_normal_texture, default_normal_view := create_default_texture(1, 1, {0.5, 0.5, 1.0, 1.0})
        default_black_texture, default_black_view := create_default_texture(1, 1, {0.0, 0.0, 0.0, 1.0})
        
        // Create default sampler
        sampler_desc := wgpu.SamplerDescriptor{
            addressModeU = .Repeat,
            addressModeV = .Repeat,
            magFilter = .Linear,
            minFilter = .Linear,
            mipmapFilter = .Linear,
            lodMinClamp = 0.0,
            lodMaxClamp = 1.0,
            maxAnisotropy = 1,
        }
        default_sampler := wgpu.DeviceCreateSampler(state.device, &sampler_desc)
        
        // Determine which textures to use (actual or default)
        base_color_view := default_white_view
        normal_map_view := default_normal_view
        metallic_roughness_view := default_black_view
        
        // Use actual textures if available
        if material.pbr_metallic_roughness.base_color_texture.texture != nil {
            base_color_view = create_texture_from_image(material.pbr_metallic_roughness.base_color_texture.texture.image)
        }
        
        if material.normal_texture.texture != nil {
            normal_map_view = create_texture_from_image(material.normal_texture.texture.image)
        }
        
        if material.pbr_metallic_roughness.metallic_roughness_texture.texture != nil {
            metallic_roughness_view = create_texture_from_image(material.pbr_metallic_roughness.metallic_roughness_texture.texture.image)
        }
        
        // Create bind group entries
        entries := [?]wgpu.BindGroupEntry{
            // Base color texture
            {binding = 0, textureView = base_color_view},
            // Base color sampler
            {binding = 1, sampler = default_sampler},
            // Normal texture
            {binding = 2, textureView = normal_map_view},
            // Normal sampler
            {binding = 3, sampler = default_sampler},
            // Metallic-roughness texture
            {binding = 4, textureView = metallic_roughness_view},
            // Metallic-roughness sampler
            {binding = 5, sampler = default_sampler},
            // Material uniform buffer
            {binding = 6, buffer = uniform_buffer},
        }
        
        // Create the bind group
        bind_group := wgpu.DeviceCreateBindGroup(state.device, &wgpu.BindGroupDescriptor{
            layout = state.bind_group_layouts[.PBR_MetallicRoughness],
            entryCount = len(entries),
            entries = &entries[0],
        })
        
        append(&bind_groups, bind_group)
        
    case .Unlit:
        // Create uniform buffer for material properties
        material_uniforms := struct {
            base_color_factor: m.Vec4,
            alpha_cutoff: f32,
        }{
            base_color_factor = material.pbr_metallic_roughness.base_color_factor,
            alpha_cutoff = material.alpha_cutoff,
        }
        
        // Create uniform buffer
        uniform_buffer_size := size_of(material_uniforms)
        uniform_buffer_desc := wgpu.BufferDescriptor{
            label = "Unlit Material Uniform Buffer",
            usage = {.Uniform, .CopyDst},
            size = u64(uniform_buffer_size),
        }
        uniform_buffer := wgpu.DeviceCreateBuffer(state.device, &uniform_buffer_desc)
        
        // Write data to uniform buffer
        wgpu.QueueWriteBuffer(state.queue, uniform_buffer, 0, &material_uniforms, uint(uniform_buffer_size))
        
        // Create default textures and samplers
        default_white_texture, default_white_view := create_default_texture(1, 1, {1.0, 1.0, 1.0, 1.0})
        
        // Create default sampler
        sampler_desc := wgpu.SamplerDescriptor{
            addressModeU = .Repeat,
            addressModeV = .Repeat,
            magFilter = .Linear,
            minFilter = .Linear,
            mipmapFilter = .Linear,
            lodMinClamp = 1.0,
            lodMaxClamp = 1.0,
            maxAnisotropy = 1,
        }
        default_sampler := wgpu.DeviceCreateSampler(state.device, &sampler_desc)
        
        // Determine which textures to use (actual or default)
        base_color_view := default_white_view

        // Create bind group entries
        entries := [?]wgpu.BindGroupEntry{
            // Base color texture
            {binding = 0, textureView = base_color_view},
            // Base color sampler
            {binding = 1, sampler = default_sampler},
            // Material uniform buffer
            {binding = 2, buffer = uniform_buffer},
        }
        
        // Create the bind group
        bind_group := wgpu.DeviceCreateBindGroup(state.device, &wgpu.BindGroupDescriptor{
            layout = state.bind_group_layouts[.Unlit],
            entryCount = len(entries),
            entries = &entries[0],
        })
        
        append(&bind_groups, bind_group)
        
    case .Toon, .Wireframe, .Custom:
        // Add similar implementations for other material types
        log.warn("Bind groups for material type %v not yet implemented", primitive.pipeline_key.material_type)
    }
    
    // Set the bind groups on the primitive
    primitive.bind_groups = bind_groups[:]
}

// Helper function to create a default texture with a solid color
create_default_texture :: proc(width, height: u32, color: [4]f32) -> (wgpu.Texture, wgpu.TextureView) {
    // Create a 1x1 texture with the specified color
    texture_desc := wgpu.TextureDescriptor{
        size = {width, height, 1},
        mipLevelCount = 1,
        sampleCount = 1,
        dimension = ._2D,
        format = .RGBA8Unorm,
        usage = {.TextureBinding, .CopyDst},
    }
    
    texture := wgpu.DeviceCreateTexture(state.device, &texture_desc)
    
    // Convert color from f32 to u8
    data := [4]u8{
        u8(color[0] * 255),
        u8(color[1] * 255),
        u8(color[2] * 255),
        u8(color[3] * 255),
    }
    
    // Create texture data
    texture_data := make([]u8, int(width * height * 4))
    defer delete(texture_data)
    
    // Fill the texture data with the color
    for i := 0; i < int(width * height); i += 1 {
        texture_data[i*4] = data[0]
        texture_data[i*4+1] = data[1]
        texture_data[i*4+2] = data[2]
        texture_data[i*4+3] = data[3]
    }
    
    // Write the data to the texture
    dest := wgpu.TexelCopyTextureInfo{
        texture = texture,
        mipLevel = 0,
        origin = {0, 0, 0},
        aspect = .All,
    }
    
    data_layout := wgpu.TexelCopyBufferLayout{
        offset = 0,
        bytesPerRow = 4 * width,
        rowsPerImage = height,
    }
    
    size := wgpu.Extent3D{
        width = width,
        height = height, 
        depthOrArrayLayers = 1,
    }
    
    wgpu.QueueWriteTexture(state.queue, &dest, &texture_data[0], uint(len(texture_data)), &data_layout, &size)
    
    // Create a view for the texture
    view := wgpu.TextureCreateView(texture, nil)
    
    return texture, view
}

create_texture_from_image :: proc(image: ^loader.Image) -> wgpu.TextureView {
    if image == nil || len(image.data) == 0 {
        // Fall back to a default texture if image is invalid
        _, default_view := create_default_texture(1, 1, {1.0, 1.0, 1.0, 1.0})
        return default_view
    }

    // Determine image dimensions
    width := u32(len(image.data) / 4)
    height := u32(len(image.data) / 4)
    
    // Create the texture
    texture_desc := wgpu.TextureDescriptor{
        label = image.name,
        size = {width, height, 1},
        mipLevelCount = 1,
        sampleCount = 1,
        dimension = ._2D,
        format = .RGBA8Unorm,  // Assuming RGBA format
        usage = {.TextureBinding, .CopyDst},
    }
    
    texture := wgpu.DeviceCreateTexture(state.device, &texture_desc)
    
    // Upload the image data to the texture
    dest := wgpu.TexelCopyTextureInfo{
        texture = texture,
        mipLevel = 0,
        origin = {0, 0, 0},
        aspect = .All,
    }
    
    data_layout := wgpu.TexelCopyBufferLayout{
        offset = 0,
        bytesPerRow = 4 * width,  // 4 bytes per pixel (RGBA)
        rowsPerImage = height,
    }
    
    size := wgpu.Extent3D{
        width = width,
        height = height,
        depthOrArrayLayers = 1,
    }
    
    // Write the data to the texture
    wgpu.QueueWriteTexture(state.queue, &dest, &image.data[0], uint(len(image.data)), &data_layout, &size)
    
    // Create a view for the texture
    view := wgpu.TextureCreateView(texture, nil)
    
    return view
}

on_adapter :: proc "c" (
    status: wgpu.RequestAdapterStatus, 
    adapter: wgpu.Adapter, 
    message: string, 
    userdata1: rawptr, 
    userdata2: rawptr,
) {
    context = state.ctx
    
    if status != .Success || adapter == nil {
        fmt.panicf("Request adapter failure: [%v] %s", status, message)
    }
    
    state.adapter = adapter
    
    device_desc := wgpu.DeviceDescriptor {
        label = "Renderer Device",
        deviceLostCallbackInfo = wgpu.DeviceLostCallbackInfo {
            callback = on_device_lost,
        },
        uncapturedErrorCallbackInfo = wgpu.UncapturedErrorCallbackInfo {
            callback = on_uncaptured_error,
        },
    }

    wgpu.AdapterRequestDevice(
        adapter, 
        &device_desc, 
        { callback = on_device },
    )
}

on_device :: proc "c" (
    status: wgpu.RequestDeviceStatus, 
    device: wgpu.Device, 
    message: string, 
    userdata1: rawptr, 
    userdata2: rawptr,
) {
    context = state.ctx
    
    if status != .Success || device == nil {
        fmt.panicf("Request device failure: [%v] %s", status, message)
    }
    
    state.device = device
    
    width, height := window.get_window_size()
    
    state.config = wgpu.SurfaceConfiguration{
        device = state.device,
        usage = {.RenderAttachment},
        format = .BGRA8Unorm,
        width = width,
        height = height,
        presentMode = .Fifo,
        alphaMode = .Opaque,
    }
    
    wgpu.SurfaceConfigure(state.surface, &state.config)
    
    state.queue = wgpu.DeviceGetQueue(state.device)
    
    // Create depth texture after device is initialized
    create_depth_texture()
    
    shader :: `
    struct VertexInput {
        @builtin(vertex_index) vertex_index: u32,
        @location(0) position: vec3<f32>,
        @location(1) normal: vec3<f32>,
        @location(2) tangent: vec3<f32>,
        @location(3) bitangent: vec3<f32>,
        @location(4) uv: vec2<f32>,
        @location(5) color: vec4<f32>,
        @location(6) joints: vec4<u32>,
        @location(7) weights: vec4<f32>,
    };

    struct VertexOutput {
        @builtin(position) position: vec4<f32>,
        @location(0) color: vec4<f32>,
    };

    @vertex
    fn vs_main(in: VertexInput) -> VertexOutput {
        var out: VertexOutput;
        // Simple transform that just passes through the position
        out.position = vec4<f32>(in.position, 1.0);
        out.color = in.color;
        return out;
    }

    @fragment
    fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
        // Use the interpolated color
        return in.color;
    }`
    
    module := wgpu.DeviceCreateShaderModule(state.device, &wgpu.ShaderModuleDescriptor{
        nextInChain = &wgpu.ShaderSourceWGSL{
            chain = {sType = .ShaderSourceWGSL},
            code = shader,
        },
    })
    
    // Define vertex buffer layout for the mesh rendering pipeline
    vertex_attributes := [?]wgpu.VertexAttribute{
        {format = .Float32x3, offset = 0, shaderLocation = 0},                                // position
        {format = .Float32x3, offset = u64(offset_of(Vertex, normal)), shaderLocation = 1},    // normal
        {format = .Float32x3, offset = u64(offset_of(Vertex, tangent)), shaderLocation = 2},   // tangent
        {format = .Float32x3, offset = u64(offset_of(Vertex, bitangent)), shaderLocation = 3}, // bitangent
        {format = .Float32x2, offset = u64(offset_of(Vertex, uv)), shaderLocation = 4},        // uv
        {format = .Float32x4, offset = u64(offset_of(Vertex, color)), shaderLocation = 5},     // color
        {format = .Uint32x4, offset = u64(offset_of(Vertex, joints)), shaderLocation = 6},     // joints
        {format = .Float32x4, offset = u64(offset_of(Vertex, weights)), shaderLocation = 7},   // weights
    }
    
    vertex_buffer_layout := wgpu.VertexBufferLayout{
        arrayStride = size_of(Vertex),
        stepMode = .Vertex,
        attributeCount = len(vertex_attributes),
        attributes = &vertex_attributes[0],
    }
    
    wgpu.ShaderModuleRelease(module)
}


on_device_lost :: proc "c" (
    device: ^wgpu.Device,
    reason: wgpu.DeviceLostReason,
    message: string,
    userdata1: rawptr,
    userdata2: rawptr,
) {
    context = state.ctx
    log.error("Device lost:", reason, message)
}

on_uncaptured_error :: proc "c" (
    device: ^wgpu.Device,
    error: wgpu.ErrorType,
    message: string,
    userdata1: rawptr,
    userdata2: rawptr,
) {
    context = state.ctx
    log.error("Uncaptured error:", error, message)
}

create_depth_texture :: proc() {
    context = state.ctx
    
    width, height := window.get_window_size()
    
    // Clean up existing resources if they exist
    if state.depth_texture != nil {
        wgpu.TextureRelease(state.depth_texture)
        state.depth_texture = nil
    }
    
    if state.depth_texture_view != nil {
        wgpu.TextureViewRelease(state.depth_texture_view)
        state.depth_texture_view = nil
    }
    
    // Create a new depth texture
    depth_texture_desc := wgpu.TextureDescriptor{
        label = "Depth Texture",
        usage = {.RenderAttachment},
        dimension = ._2D,
        size = {width, height, 1},
        format = .Depth24Plus,
        mipLevelCount = 1,
        sampleCount = 1,
    }
    
    state.depth_texture = wgpu.DeviceCreateTexture(state.device, &depth_texture_desc)
    
    if state.depth_texture == nil {
        log.error("Failed to create depth texture")
        return
    }
    
    // Create the depth texture view
    depth_texture_view_desc := wgpu.TextureViewDescriptor{
        label = "Depth Texture View",
        format = .Depth24Plus,
        dimension = ._2D,
        baseMipLevel = 0,
        mipLevelCount = 1,
        baseArrayLayer = 0,
        arrayLayerCount = 1,
        aspect = .DepthOnly,
    }
    
    state.depth_texture_view = wgpu.TextureCreateView(state.depth_texture, &depth_texture_view_desc)
    
    if state.depth_texture_view == nil {
        log.error("Failed to create depth texture view")
        wgpu.TextureRelease(state.depth_texture)
        state.depth_texture = nil
    }
}