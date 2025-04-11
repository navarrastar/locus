#+private
package renderer

import "core:fmt"

import "vendor:wgpu"
import "core:image"
import "core:image/png"
import "core:os"
import "core:bytes"
import "core:strings"
import "core:mem"

import m "pkg:core/math"
import "pkg:core/filesystem/loaded"
import "pkg:core/filesystem/loader"



materials: map[string]Material

Material :: struct {
    name: string,
    shader: ^Shader,
    bind_group: wgpu.BindGroup,
    pipeline: wgpu.RenderPipeline
}

MaterialProperties :: struct {
    albedo: m.Vec4,
    roughness: f32,
    metallic: f32,
    outline_width: f32,
    use_albedo_texture: u32,
}

load_materials :: proc() {
    shader, exists := shaders["default"]
    assert(exists, "Default shader doesn't exist")
    for name, material in loaded.materials {
        bind_group := create_bind_group(material, &shader)
        pipeline := create_pipeline(material, &shader)

        materials[name] = Material {
            name = name,
            shader = &shader,
            bind_group = bind_group,
            pipeline = pipeline,
        }
    }
}

create_bind_group :: proc(material: ^loader.Material, shader: ^Shader) -> wgpu.BindGroup {

    material_properties := create_properties_buffer(material)
    albedo_sampler := create_sampler(material)
    albedo_texture_view := create_albedo_texture_view(material)

    entries := [?]wgpu.BindGroupEntry {
        { binding = 0, textureView = albedo_texture_view }, // Hardcoded
        { binding = 1, sampler = albedo_sampler },          // Hardcoded
        { binding = 2, buffer = material_properties, size = size_of(MaterialProperties) },       // Hardcoded
    }

    bind_group_desc := wgpu.BindGroupDescriptor {
        label = fmt.tprintf("Material_%v", material.name),
        layout = shader.bind_group_layouts[1], // Material bind group is Hardcoded 1
        entryCount = len(entries),
        entries = &entries[0]
    }
    
    bind_group := wgpu.DeviceCreateBindGroup(state.device, &bind_group_desc)

    return bind_group
}

create_properties_buffer :: proc(material: ^loader.Material) -> wgpu.Buffer {
    // Pack material properties into a buffer
    props := MaterialProperties {
        albedo = material.pbr_metallic_roughness.base_color_factor,
        roughness = material.pbr_metallic_roughness.roughness_factor,
        metallic = material.pbr_metallic_roughness.metallic_factor,
        // ... other fields
    }
    
    props_data := make([]byte, size_of(props))
    mem.copy(&props_data[0], &props, size_of(props))
    
    buffer_desc := wgpu.BufferDescriptor {
        size = size_of(props),
        usage = {.Uniform, .CopyDst},
    }
    buffer := wgpu.DeviceCreateBuffer(state.device, &buffer_desc)
    
    wgpu.QueueWriteBuffer(state.queue, buffer, 0, &props, size_of(props))
    
    delete(props_data)
    return buffer
}

create_sampler :: proc(material: ^loader.Material) -> wgpu.Sampler {

    sampler_desc := wgpu.SamplerDescriptor {
        label = fmt.tprintf("Sampler_%v", material.name),
        addressModeU = .Repeat,
        addressModeV = .Repeat,
        addressModeW = .Repeat,
        magFilter = .Linear,
        minFilter = .Linear,
        mipmapFilter = .Linear,
        lodMinClamp = 0.0,
        lodMaxClamp = 32.0,
        compare = .Undefined,
        maxAnisotropy = 1,
    }

    return wgpu.DeviceCreateSampler(state.device, &sampler_desc)
}

create_albedo_texture_view :: proc(material: ^loader.Material) -> wgpu.TextureView {
    // Default size for a placeholder texture
    width, height: u32 = 16, 16
    
    // Create a simple placeholder white texture
    placeholder_data := make([]byte, width * height * 4)
    defer delete(placeholder_data)
    
    // Fill with white
    for i := 0; i < len(placeholder_data); i += 4 {
        placeholder_data[i] = 255     // R
        placeholder_data[i+1] = 255   // G
        placeholder_data[i+2] = 255   // B
        placeholder_data[i+3] = 255   // A
    }
    
    // Create the texture
    texture_desc := wgpu.TextureDescriptor {
        label = fmt.tprintf("Texture_Albedo_%v", material.name),
        size = wgpu.Extent3D {
            width = width,
            height = height,
            depthOrArrayLayers = 1,
        },
        mipLevelCount = 1,
        sampleCount = 1,
        dimension = ._2D,
        format = .RGBA8Unorm,
        usage = { .TextureBinding, .CopyDst },
    }
    
    texture := wgpu.DeviceCreateTexture(state.device, &texture_desc)
    
    // NOTE: Image loading will be implemented later
    // For now, just create a white texture as a placeholder
    
    // Create the texture view
    view_desc := wgpu.TextureViewDescriptor {
        label = fmt.tprintf("TextureView_Albedo_%v", material.name),
        format = .RGBA8Unorm,
        dimension = ._2D,
        baseMipLevel = 0,
        mipLevelCount = 1,
        baseArrayLayer = 0,
        arrayLayerCount = 1,
        aspect = .All,
    }
    
    return wgpu.TextureCreateView(texture, &view_desc)
}

// TODO: Implement proper image loading from GLTF
// This is a placeholder function that will be expanded later
load_texture_data :: proc(gltf_image: ^loader.Image) -> (rgba_data: []byte, width, height: u32) {
    // For now, we'll return nil to indicate we're not loading real data yet
    return nil, 0, 0
}

// This creates a pipeline for the given material
create_pipeline :: proc(material: ^loader.Material, shader: ^Shader) -> wgpu.RenderPipeline {
    color_target_state := wgpu.ColorTargetState {
        format = .BGRA8Unorm, // Match the surface format used in the renderer
        writeMask = wgpu.ColorWriteMaskFlags_All,
    }
    
    fragment_state := wgpu.FragmentState {
        module = shader.module,
        entryPoint = shader.fragment_entry,
        targetCount = 1,
        targets = &color_target_state,
    }
    
    vertex_state := wgpu.VertexState {
        module = shader.module,
        entryPoint = shader.vertex_entry,
        bufferCount = 1,
        buffers = &shader.vertex_buffer_layout,
    }
    
    primitive_state := wgpu.PrimitiveState {
        topology = .TriangleList,
        frontFace = .CCW,  // Counter-clockwise front face
        cullMode = .None,  // Cull back faces
    }
    
    multisample_state := wgpu.MultisampleState {
        count = 1,  // No multisampling for now
        mask = 0xFFFFFFFF,
    }
    
    pipeline_desc := wgpu.RenderPipelineDescriptor {
        label = fmt.tprintf("Pipeline_%v", material.name),
        layout = shader.pipeline_layout,
        vertex = vertex_state,
        primitive = primitive_state,
        fragment = &fragment_state,
        multisample = multisample_state,
    }
    
    return wgpu.DeviceCreateRenderPipeline(state.device, &pipeline_desc)
}