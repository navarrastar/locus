package vk

import "core:log"
import "core:mem"
import "vendor:vulkan"

import "pkg:core/filesystem/gltf"
import m "pkg:core/math"

// GPU buffer representation of a mesh
Mesh_Buffer :: struct {
    vertex_buffer: vulkan.Buffer,
    vertex_buffer_memory: vulkan.DeviceMemory,
    index_buffer: vulkan.Buffer,
    index_buffer_memory: vulkan.DeviceMemory,
    index_count: u32,
}

// Collection of meshes on the GPU
Mesh_Collection :: struct {
    meshes: []Mesh_Buffer,
    materials: []Material_Buffer,
}

// GPU buffer representation of a material
Material_Buffer :: struct {
    uniform_buffer: vulkan.Buffer,
    uniform_buffer_memory: vulkan.DeviceMemory,
    descriptor_set: vulkan.DescriptorSet,
}

// Vertex structure for GPU
Vertex :: struct {
    position: m.Vec3,
    normal: m.Vec3,
    uv: m.Vec2,
    color: m.Vec3,
}

// Push constant structure for mesh rendering
Mesh_Push_Constants :: struct {
    model_matrix: m.Mat4,
    material_index: i32,
}

// Material uniform structure
Material_Uniform :: struct {
    base_color_factor: [4]f32,
    metallic_factor: f32,
    roughness_factor: f32,
    padding: [2]f32, // Padding for alignment
}

// Initialize GPU resources for mesh rendering
init_mesh_renderer :: proc(
    device: vulkan.Device,
    physical_device: vulkan.PhysicalDevice,
    command_pool: vulkan.CommandPool,
    queue: vulkan.Queue
) -> (descriptor_set_layout: vulkan.DescriptorSetLayout, pipeline_layout: vulkan.PipelineLayout) {
    // Create descriptor set layout for material uniforms
    ubo_binding := vulkan.DescriptorSetLayoutBinding {
        binding = 0,
        descriptorType = .UNIFORM_BUFFER,
        descriptorCount = 1,
        stageFlags = {.FRAGMENT},
    }
    
    sampler_binding := vulkan.DescriptorSetLayoutBinding {
        binding = 1,
        descriptorType = .COMBINED_IMAGE_SAMPLER,
        descriptorCount = 1,
        stageFlags = {.FRAGMENT},
    }
    
    bindings := []vulkan.DescriptorSetLayoutBinding{ubo_binding, sampler_binding}
    
    descriptor_set_layout_info := vulkan.DescriptorSetLayoutCreateInfo {
        bindingCount = u32(len(bindings)),
        pBindings = raw_data(bindings),
    }
    
    vulkan.CreateDescriptorSetLayout(device, &descriptor_set_layout_info, nil, &descriptor_set_layout)
    
    // Create pipeline layout with push constants for transform
    push_constant_range := vulkan.PushConstantRange {
        stageFlags = {.VERTEX},
        offset = 0,
        size = u32(size_of(Mesh_Push_Constants)),
    }
    
    set_layouts := []vulkan.DescriptorSetLayout{descriptor_set_layout}
    
    pipeline_layout_info := vulkan.PipelineLayoutCreateInfo {
        setLayoutCount = 1,
        pSetLayouts = &set_layouts[0],
        pushConstantRangeCount = 1,
        pPushConstantRanges = &push_constant_range,
    }
    
    vulkan.CreatePipelineLayout(device, &pipeline_layout_info, nil, &pipeline_layout)
    
    return descriptor_set_layout, pipeline_layout
}

// Upload mesh data to GPU
upload_mesh :: proc(
    device: vulkan.Device,
    physical_device: vulkan.PhysicalDevice,
    command_pool: vulkan.CommandPool,
    queue: vulkan.Queue,
    mesh: gltf.Mesh
) -> Mesh_Buffer {
    result: Mesh_Buffer
    
    for primitive in mesh.primitives {
        // We'll handle the first primitive for simplicity
        // In a full implementation, you might want to handle multiple primitives
        
        // Create vertices from the primitive data
        vertices := make([]Vertex, len(primitive.positions))
        for i := 0; i < len(primitive.positions); i += 1 {
            vertex: Vertex
            vertex.position = primitive.positions[i]
            
            if len(primitive.normals) > i {
                vertex.normal = primitive.normals[i]
            }
            
            if len(primitive.texcoords0) > i {
                vertex.uv = primitive.texcoords0[i]
            }
            
            if len(primitive.colors) > i {
                vertex.color = primitive.colors[i]
            } else {
                vertex.color = m.Vec3{1, 1, 1} // Default white
            }
            
            vertices[i] = vertex
        }
        
        // Upload vertices to GPU
        vertex_buffer_size := u64(len(vertices) * size_of(Vertex))
        result.vertex_buffer, result.vertex_buffer_memory = create_buffer(
            device,
            physical_device,
            vertex_buffer_size,
            {.VERTEX_BUFFER},
            {.DEVICE_LOCAL},
            vertices[:],
            command_pool,
            queue,
        )
        
        // Upload indices to GPU if they exist
        if len(primitive.indices) > 0 {
            index_buffer_size := u64(len(primitive.indices) * size_of(u32))
            result.index_buffer, result.index_buffer_memory = create_buffer(
                device,
                physical_device,
                index_buffer_size,
                {.INDEX_BUFFER},
                {.DEVICE_LOCAL},
                primitive.indices,
                command_pool,
                queue,
            )
            result.index_count = u32(len(primitive.indices))
        }
        
        // Only process the first primitive for simplicity
        break
    }
    
    return result
}

// Create buffer helper function
create_buffer :: proc(
    device: vulkan.Device,
    physical_device: vulkan.PhysicalDevice,
    size: u64,
    usage: vulkan.BufferUsageFlags,
    properties: vulkan.MemoryPropertyFlags,
    data: []$T,
    command_pool: vulkan.CommandPool,
    queue: vulkan.Queue,
) -> (buffer: vulkan.Buffer, memory: vulkan.DeviceMemory) {
    // Create buffer
    buffer_info := vulkan.BufferCreateInfo {
        size = vulkan.DeviceSize(size),
        usage = usage | {.TRANSFER_DST},
        sharingMode = .EXCLUSIVE,
    }
    
    vulkan.CreateBuffer(device, &buffer_info, nil, &buffer)
    
    // Allocate memory
    mem_requirements: vulkan.MemoryRequirements
    vulkan.GetBufferMemoryRequirements(device, buffer, &mem_requirements)
    
    memory_type_index := find_memory_type(
        physical_device,
        mem_requirements.memoryTypeBits,
        properties,
    )
    
    alloc_info := vulkan.MemoryAllocateInfo {
        allocationSize = mem_requirements.size,
        memoryTypeIndex = memory_type_index,
    }
    
    vulkan.AllocateMemory(device, &alloc_info, nil, &memory)
    vulkan.BindBufferMemory(device, buffer, memory, 0)
    
    // If we have data to upload, create a staging buffer and copy
    if len(data) > 0 {
        // Create staging buffer
        staging_buffer: vulkan.Buffer
        staging_memory: vulkan.DeviceMemory
        
        staging_buffer_info := vulkan.BufferCreateInfo {
            size = vulkan.DeviceSize(size),
            usage = {.TRANSFER_SRC},
            sharingMode = .EXCLUSIVE,
        }
        
        vulkan.CreateBuffer(device, &staging_buffer_info, nil, &staging_buffer)
        
        staging_requirements: vulkan.MemoryRequirements
        vulkan.GetBufferMemoryRequirements(device, staging_buffer, &staging_requirements)
        
        staging_memory_index := find_memory_type(
            physical_device,
            staging_requirements.memoryTypeBits,
            {.HOST_VISIBLE, .HOST_COHERENT},
        )
        
        staging_alloc_info := vulkan.MemoryAllocateInfo {
            allocationSize = staging_requirements.size,
            memoryTypeIndex = staging_memory_index,
        }
        
        vulkan.AllocateMemory(device, &staging_alloc_info, nil, &staging_memory)
        vulkan.BindBufferMemory(device, staging_buffer, staging_memory, 0)
        
        // Map memory and copy data
        mapped_memory: rawptr
        vulkan.MapMemory(device, staging_memory, 0, vulkan.DeviceSize(size), {}, &mapped_memory)
        mem.copy(mapped_memory, raw_data(data), int(size))
        vulkan.UnmapMemory(device, staging_memory)
        
        // Copy from staging buffer to device buffer
        copy_buffer(device, command_pool, queue, staging_buffer, buffer, size)
        
        // Cleanup staging resources
        vulkan.DestroyBuffer(device, staging_buffer, nil)
        vulkan.FreeMemory(device, staging_memory, nil)
    }
    
    return buffer, memory
}

// Helper to find a suitable memory type
find_memory_type :: proc(
    physical_device: vulkan.PhysicalDevice,
    type_filter: u32,
    properties: vulkan.MemoryPropertyFlags,
) -> u32 {
    mem_properties: vulkan.PhysicalDeviceMemoryProperties
    vulkan.GetPhysicalDeviceMemoryProperties(physical_device, &mem_properties)
    
    for i: u32 = 0; i < mem_properties.memoryTypeCount; i += 1 {
        if type_filter & (1 << i) != 0 &&
           (mem_properties.memoryTypes[i].propertyFlags & properties) == properties {
            return i
        }
    }
    
    log.error("Failed to find suitable memory type")
    return 0
}

// Copy buffer helper
copy_buffer :: proc(
    device: vulkan.Device,
    command_pool: vulkan.CommandPool,
    queue: vulkan.Queue,
    src_buffer: vulkan.Buffer,
    dst_buffer: vulkan.Buffer,
    size: u64,
) {
    command_buffer := begin_single_time_commands(device, command_pool)
    
    copy_region := vulkan.BufferCopy {
        srcOffset = 0,
        dstOffset = 0,
        size = vulkan.DeviceSize(size),
    }
    
    vulkan.CmdCopyBuffer(command_buffer, src_buffer, dst_buffer, 1, &copy_region)
    
    end_single_time_commands(device, command_pool, queue, command_buffer)
}

// Command buffer helpers
begin_single_time_commands :: proc(
    device: vulkan.Device,
    command_pool: vulkan.CommandPool,
) -> vulkan.CommandBuffer {
    alloc_info := vulkan.CommandBufferAllocateInfo {
        level = .PRIMARY,
        commandPool = command_pool,
        commandBufferCount = 1,
    }
    
    command_buffer: vulkan.CommandBuffer
    vulkan.AllocateCommandBuffers(device, &alloc_info, &command_buffer)
    
    begin_info := vulkan.CommandBufferBeginInfo {
        flags = {.ONE_TIME_SUBMIT},
    }
    
    vulkan.BeginCommandBuffer(command_buffer, &begin_info)
    
    return command_buffer
}

end_single_time_commands :: proc(
    device: vulkan.Device,
    command_pool: vulkan.CommandPool,
    queue: vulkan.Queue,
    command_buffer: vulkan.CommandBuffer,
) {
    vulkan.EndCommandBuffer(command_buffer)
    
    command_buffers := []vulkan.CommandBuffer{command_buffer}
    
    submit_info := vulkan.SubmitInfo {
        commandBufferCount = 1,
        pCommandBuffers = &command_buffers[0],
    }
    
    vulkan.QueueSubmit(queue, 1, &submit_info, 0)
    vulkan.QueueWaitIdle(queue)
    
    vulkan.FreeCommandBuffers(device, command_pool, 1, &command_buffers[0])
}

// Create a collection of meshes and materials from gltf model
create_mesh_collection :: proc(
    device: vulkan.Device,
    physical_device: vulkan.PhysicalDevice,
    command_pool: vulkan.CommandPool,
    queue: vulkan.Queue,
    descriptor_pool: vulkan.DescriptorPool,
    descriptor_set_layout: vulkan.DescriptorSetLayout,
    model: gltf.Model,
) -> Mesh_Collection {
    collection: Mesh_Collection
    
    // Create mesh buffers
    collection.meshes = make([]Mesh_Buffer, len(model.meshes))
    for i := 0; i < len(model.meshes); i += 1 {
        collection.meshes[i] = upload_mesh(device, physical_device, command_pool, queue, model.meshes[i])
    }
    
    // Create material buffers
    collection.materials = make([]Material_Buffer, len(model.materials))
    for i := 0; i < len(model.materials); i += 1 {
        material := model.materials[i]
        
        // Create uniform buffer for material data
        material_uniform := Material_Uniform {
            base_color_factor = material.base_color_factor,
            metallic_factor = material.metallic_factor,
            roughness_factor = material.roughness_factor,
        }
        
        uniform_buffer, uniform_memory := create_buffer(
            device,
            physical_device,
            size_of(Material_Uniform),
            {.UNIFORM_BUFFER},
            {.HOST_VISIBLE, .HOST_COHERENT},
            []Material_Uniform{material_uniform},
            command_pool,
            queue,
        )
        
        collection.materials[i].uniform_buffer = uniform_buffer
        collection.materials[i].uniform_buffer_memory = uniform_memory
        
        // Allocate descriptor set
        set_layouts := []vulkan.DescriptorSetLayout{descriptor_set_layout}
        
        alloc_info := vulkan.DescriptorSetAllocateInfo {
            descriptorPool = descriptor_pool,
            descriptorSetCount = 1,
            pSetLayouts = &set_layouts[0],
        }
        
        vulkan.AllocateDescriptorSets(device, &alloc_info, &collection.materials[i].descriptor_set)
        
        // Update descriptor set
        buffer_info := vulkan.DescriptorBufferInfo {
            buffer = uniform_buffer,
            offset = 0,
            range = vulkan.DeviceSize(size_of(Material_Uniform)),
        }
        
        write_descriptor := vulkan.WriteDescriptorSet {
            dstSet = collection.materials[i].descriptor_set,
            dstBinding = 0,
            dstArrayElement = 0,
            descriptorType = .UNIFORM_BUFFER,
            descriptorCount = 1,
            pBufferInfo = &buffer_info,
        }
        
        vulkan.UpdateDescriptorSets(device, 1, &write_descriptor, 0, nil)
        
        // In a complete implementation, you would also handle textures here
    }
    
    return collection
}

// Cleanup mesh collection resources
destroy_mesh_collection :: proc(device: vulkan.Device, collection: Mesh_Collection) {
    for mesh in collection.meshes {
        vulkan.DestroyBuffer(device, mesh.vertex_buffer, nil)
        vulkan.FreeMemory(device, mesh.vertex_buffer_memory, nil)
        
        if mesh.index_count > 0 {
            vulkan.DestroyBuffer(device, mesh.index_buffer, nil)
            vulkan.FreeMemory(device, mesh.index_buffer_memory, nil)
        }
    }
    
    for material in collection.materials {
        vulkan.DestroyBuffer(device, material.uniform_buffer, nil)
        vulkan.FreeMemory(device, material.uniform_buffer_memory, nil)
        // Note: Descriptor sets are freed when the pool is destroyed
    }
    
    delete(collection.meshes)
    delete(collection.materials)
} 