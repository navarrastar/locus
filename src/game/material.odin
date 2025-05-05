package game

import "core:log"
import "core:mem"
import stbi "vendor:stb/image"

import sdl "vendor:sdl3"

import gltf "../../third_party/gltf2"

Texture :: struct {
    texture: ^sdl.GPUTexture,
    sampler: ^sdl.GPUSampler,
    width:    int,
    height:   int,
    channels: int
}

MaterialType :: enum {
    Default, // Vertex_PosColNorm
    Grid, // Vertex_PosCol
    Test, // Vertex_PosColNorm
    Mesh, // Vertex_PosColNormUVTanSkin
}

Material :: struct {
    type:      MaterialType,
    pipeline: ^sdl.GPUGraphicsPipeline,
}

material_create :: proc(type: MaterialType) {
    pipeline_create(type)
}


// Create a texture from GLTF image data
texture_create_from_gltf_image :: proc(model: ^gltf.Data, image_index: u32) -> ^Texture {
    if image_index < 0 || int(image_index) >= len(model.images) {
        log.errorf("Invalid GLTF image index: %d", image_index)
        return nil
    }
    
    image := model.images[image_index]
    
    // Get image data from URI or buffer view
    #partial switch uri in image.uri {
    case []byte:
        // Load from memory
        width, height, channels: i32
        data := stbi.load_from_memory(raw_data(uri), i32(len(uri)), &width, &height, &channels, 4) // Force RGBA
        if data == nil {
            log.errorf("Failed to load texture from GLTF image data")
            return nil
        }
        defer stbi.image_free(data)
        
        texture := texture_create_from_data(data, int(width), int(height), 4)
        return texture
    }
    
    // If we get here, try to load from buffer view
    if image.buffer_view != nil {
        buffer_view := model.buffer_views[image.buffer_view.?]
        buffer := model.buffers[buffer_view.buffer]
        
        // Get buffer data
        #partial switch uri in buffer.uri {
        case []byte:
            data_offset := buffer_view.byte_offset
            data_length := buffer_view.byte_length
            
            if data_offset+data_length > u32(len(uri)) {
                log.errorf("Invalid buffer view for image")
                return nil
            }
            
            image_data := uri[data_offset:data_offset+data_length]
            
            // Load image
            width, height, channels: i32
            data := stbi.load_from_memory(raw_data(image_data), i32(len(image_data)), &width, &height, &channels, 4)
            if data == nil {
                log.errorf("Failed to load texture from GLTF buffer view")
                return nil
            }
            defer stbi.image_free(data)
            
            texture := texture_create_from_data(data, int(width), int(height), 4)
            return texture
        }
    }
    
    log.errorf("Could not load texture from GLTF image")
    return nil
}

// Create a texture from raw image data
texture_create_from_data :: proc(data: [^]u8, width, height, channels: int) -> ^Texture {
    texture := new(Texture)
    texture.width = width
    texture.height = height
    texture.channels = channels
    
    // Create GPU texture
    texture_info := sdl.GPUTextureCreateInfo {
        type                 = .D2,
        format               = .R8G8B8A8_UNORM,
        usage                = {.SAMPLER},
        width                = u32(width),
        height               = u32(height),
        layer_count_or_depth = 1,
        num_levels           = 1,
    }
    
    texture.texture = sdl.CreateGPUTexture(render_state.gpu, texture_info)
    assert(texture.texture != nil, string(sdl.GetError()))
    
    // Create transfer buffer and upload data
    bytes_per_pixel := 4 // RGBA8
    data_size := u32(width * height * bytes_per_pixel)
    
    transfer_buffer := sdl.CreateGPUTransferBuffer(
        render_state.gpu, 
        {usage = .UPLOAD, size = data_size}
    )
    assert(transfer_buffer != nil, string(sdl.GetError()))
    
    transfer_mem := sdl.MapGPUTransferBuffer(render_state.gpu, transfer_buffer, false)
    mem.copy(transfer_mem, data, int(data_size))
    sdl.UnmapGPUTransferBuffer(render_state.gpu, transfer_buffer)
    
    copy_cmd_buf := sdl.AcquireGPUCommandBuffer(render_state.gpu)
    copy_pass := sdl.BeginGPUCopyPass(copy_cmd_buf)
    
    sdl.UploadToGPUTexture(
        copy_pass,
        {transfer_buffer = transfer_buffer},
        {texture = texture.texture, w = u32(width), h = u32(height), d = 1},
        false
    )
    
    sdl.EndGPUCopyPass(copy_pass)
    sdl.ReleaseGPUTransferBuffer(render_state.gpu, transfer_buffer)
    _ = sdl.SubmitGPUCommandBuffer(copy_cmd_buf)
    
    // Create sampler
    sampler_info := sdl.GPUSamplerCreateInfo {
        min_filter = .LINEAR,
        mag_filter = .LINEAR,
        address_mode_u  = .REPEAT,
        address_mode_v  = .REPEAT,
        address_mode_w  = .REPEAT,
    }
    
    texture.sampler = sdl.CreateGPUSampler(render_state.gpu, sampler_info)
    assert(texture.sampler != nil, string(sdl.GetError()))
    
    return texture
}