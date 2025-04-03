package vk

import "core:log"
import "core:math/linalg"
import "vendor:vulkan"

import "pkg:core/window"
import "pkg:core/filesystem/gltf"
import "pkg:game/ecs"
import m "pkg:core/math"
import c "pkg:game/ecs/component"

Renderer :: struct {
    instance: vulkan.Instance,
    device: vulkan.Device,
    physical_device: vulkan.PhysicalDevice,
    surface: vulkan.SurfaceKHR,
    
    graphics_queue: vulkan.Queue,
    present_queue: vulkan.Queue,
    
    swapchain: vulkan.SwapchainKHR,
    swapchain_images: []vulkan.Image,
    swapchain_image_views: []vulkan.ImageView,
    swapchain_framebuffers: []vulkan.Framebuffer,
    
    render_pass: vulkan.RenderPass,
    pipeline_layout: vulkan.PipelineLayout,
    graphics_pipeline: vulkan.Pipeline,
    
    descriptor_set_layout: vulkan.DescriptorSetLayout,
    descriptor_pool: vulkan.DescriptorPool,
    
    command_pool: vulkan.CommandPool,
    command_buffers: []vulkan.CommandBuffer,
    
    image_available_semaphores: []vulkan.Semaphore,
    render_finished_semaphores: []vulkan.Semaphore,
    in_flight_fences: []vulkan.Fence,
    
    mesh_collection: Mesh_Collection,
    models: map[string]gltf.Model,
    
    current_frame: u32,
    framebuffer_resized: bool,
    max_frames_in_flight: u32,
}

renderer: Renderer

// Initialize the Vulkan renderer
init :: proc() -> (success: bool) {
    renderer.max_frames_in_flight = 2
    renderer.current_frame = 0
    renderer.framebuffer_resized = false
    
    // Setup Vulkan instance
    renderer.instance = setup_instance()
    
    // Create surface for window
    w_handle := window.get_window_handle()
    
    // Platform-specific surface creation
    when ODIN_OS == .Darwin {
        // Use the GLFW helper which handles the platform-specific surface creation
        result := CreateGLFWSurfaceKHR(renderer.instance, rawptr(w_handle), nil, &renderer.surface)
        if result != .SUCCESS {
            log.error("Failed to create window surface")
            return false
        }
    } else {
        // On Linux use Xlib
        result := vulkan.CreateXlibSurfaceKHR(
            renderer.instance, 
            rawptr(w_handle), // This will need to be updated with proper Xlib creation info
            nil, 
            &renderer.surface,
        )
        if result != .SUCCESS {
            log.error("Failed to create window surface")
            return false
        }
    }
    
    // Select physical device (GPU)
    if !select_physical_device() {
        log.error("Failed to find a suitable GPU")
        return false
    }
    
    // Create logical device and queues
    if !create_logical_device() {
        log.error("Failed to create logical device")
        return false
    }
    
    // Create command pool for command buffers
    create_command_pool()
    
    // Initialize mesh renderer and descriptor set layout
    renderer.descriptor_set_layout, renderer.pipeline_layout = init_mesh_renderer(
        renderer.device,
        renderer.physical_device,
        renderer.command_pool,
        renderer.graphics_queue,
    )
    
    // Create descriptor pool
    create_descriptor_pool()
    
    // Create swapchain, render pass, and pipeline
    if !create_swapchain() {
        log.error("Failed to create swapchain")
        return false
    }
    
    if !create_render_pass() {
        log.error("Failed to create render pass")
        return false
    }
    
    if !create_graphics_pipeline() {
        log.error("Failed to create graphics pipeline")
        return false
    }
    
    if !create_framebuffers() {
        log.error("Failed to create framebuffers")
        return false
    }
    
    // Create synchronization objects
    create_sync_objects()
    
    // Initialize model storage
    renderer.models = make(map[string]gltf.Model)
    
    return true
}

// Clean up all Vulkan resources
cleanup :: proc() {
    // Wait for device to finish operations
    vulkan.DeviceWaitIdle(renderer.device)
    
    // Free model resources
    for _, &model in renderer.models {
        gltf.free(&model)
    }
    delete(renderer.models)
    
    // Clean up mesh collection
    destroy_mesh_collection(renderer.device, renderer.mesh_collection)
    
    // Clean up synchronization objects
    for i := 0; i < int(renderer.max_frames_in_flight); i += 1 {
        vulkan.DestroySemaphore(renderer.device, renderer.image_available_semaphores[i], nil)
        vulkan.DestroySemaphore(renderer.device, renderer.render_finished_semaphores[i], nil)
        vulkan.DestroyFence(renderer.device, renderer.in_flight_fences[i], nil)
    }
    delete(renderer.image_available_semaphores)
    delete(renderer.render_finished_semaphores)
    delete(renderer.in_flight_fences)
    
    // Clean up framebuffers and images
    for framebuffer in renderer.swapchain_framebuffers {
        vulkan.DestroyFramebuffer(renderer.device, framebuffer, nil)
    }
    delete(renderer.swapchain_framebuffers)
    
    vulkan.FreeCommandBuffers(
        renderer.device,
        renderer.command_pool,
        u32(len(renderer.command_buffers)),
        &renderer.command_buffers[0],
    )
    delete(renderer.command_buffers)
    
    vulkan.DestroyPipeline(renderer.device, renderer.graphics_pipeline, nil)
    vulkan.DestroyPipelineLayout(renderer.device, renderer.pipeline_layout, nil)
    vulkan.DestroyRenderPass(renderer.device, renderer.render_pass, nil)
    
    for image_view in renderer.swapchain_image_views {
        vulkan.DestroyImageView(renderer.device, image_view, nil)
    }
    delete(renderer.swapchain_image_views)
    
    vulkan.DestroySwapchainKHR(renderer.device, renderer.swapchain, nil)
    delete(renderer.swapchain_images)
    
    vulkan.DestroyDescriptorPool(renderer.device, renderer.descriptor_pool, nil)
    vulkan.DestroyDescriptorSetLayout(renderer.device, renderer.descriptor_set_layout, nil)
    
    vulkan.DestroyCommandPool(renderer.device, renderer.command_pool, nil)
    
    vulkan.DestroyDevice(renderer.device, nil)
    vulkan.DestroySurfaceKHR(renderer.instance, renderer.surface, nil)
    vulkan.DestroyInstance(renderer.instance, nil)
}

// Select a suitable physical device (GPU)
select_physical_device :: proc() -> bool {
    device_count: u32
    vulkan.EnumeratePhysicalDevices(renderer.instance, &device_count, nil)
    
    if device_count == 0 {
        return false
    }
    
    devices := make([]vulkan.PhysicalDevice, device_count)
    defer delete(devices)
    vulkan.EnumeratePhysicalDevices(renderer.instance, &device_count, &devices[0])
    
    // For compatibility with all platforms
    renderer.physical_device = devices[0]
    
    // On macOS we might need additional checks, but for now use the first device
    // A more complete implementation would check for swapchain and portability subset support
    
    return true
}

// Create logical device and queue families
create_logical_device :: proc() -> bool {
    // Find queue families
    queue_family_count: u32
    vulkan.GetPhysicalDeviceQueueFamilyProperties(renderer.physical_device, &queue_family_count, nil)
    
    queue_families := make([]vulkan.QueueFamilyProperties, queue_family_count)
    defer delete(queue_families)
    vulkan.GetPhysicalDeviceQueueFamilyProperties(renderer.physical_device, &queue_family_count, &queue_families[0])
    
    // For simplicity, use the first queue family that supports graphics
    graphics_queue_family: u32 = 0
    present_queue_family: u32 = 0
    
    for i: u32 = 0; i < queue_family_count; i += 1 {
        if .GRAPHICS in queue_families[i].queueFlags {
            graphics_queue_family = i
        }
        
        present_support: b32
        vulkan.GetPhysicalDeviceSurfaceSupportKHR(renderer.physical_device, i, renderer.surface, &present_support)
        
        if present_support {
            present_queue_family = i
        }
    }
    
    // Create device with required features
    queue_priority: f32 = 1.0
    queue_create_info := vulkan.DeviceQueueCreateInfo {
        queueFamilyIndex = graphics_queue_family,
        queueCount = 1,
        pQueuePriorities = &queue_priority,
    }
    
    device_features: vulkan.PhysicalDeviceFeatures
    
    // Required device extensions
    extensions: []cstring = {"VK_KHR_swapchain"}
    
    // On macOS, we need portability subset extension
    when ODIN_OS == .Darwin {
        mac_extensions := make([]cstring, len(extensions) + 1)
        defer delete(mac_extensions)
        
        copy(mac_extensions, extensions)
        mac_extensions[len(extensions)] = "VK_KHR_portability_subset"
        
        extensions = mac_extensions
    }
    
    device_create_info := vulkan.DeviceCreateInfo {
        queueCreateInfoCount = 1,
        pQueueCreateInfos = &queue_create_info,
        pEnabledFeatures = &device_features,
        enabledExtensionCount = u32(len(extensions)),
        ppEnabledExtensionNames = raw_data(extensions),
    }
    
    if vulkan.CreateDevice(renderer.physical_device, &device_create_info, nil, &renderer.device) != .SUCCESS {
        return false
    }
    
    // Get queue handles
    vulkan.GetDeviceQueue(renderer.device, graphics_queue_family, 0, &renderer.graphics_queue)
    vulkan.GetDeviceQueue(renderer.device, present_queue_family, 0, &renderer.present_queue)
    
    return true
}

// Create command pool for command buffers
create_command_pool :: proc() {
    // For simplicity using queue family 0
    // In a complete implementation, you would find the appropriate queue family
    pool_info := vulkan.CommandPoolCreateInfo {
        flags = {.RESET_COMMAND_BUFFER},
        queueFamilyIndex = 0,
    }
    
    vulkan.CreateCommandPool(renderer.device, &pool_info, nil, &renderer.command_pool)
}

// Create swapchain for rendering
create_swapchain :: proc() -> bool {
    // Query surface capabilities
    capabilities: vulkan.SurfaceCapabilitiesKHR
    vulkan.GetPhysicalDeviceSurfaceCapabilitiesKHR(renderer.physical_device, renderer.surface, &capabilities)
    
    // For simplicity, use the first available format and present mode
    format_count: u32
    vulkan.GetPhysicalDeviceSurfaceFormatsKHR(renderer.physical_device, renderer.surface, &format_count, nil)
    
    formats := make([]vulkan.SurfaceFormatKHR, format_count)
    defer delete(formats)
    vulkan.GetPhysicalDeviceSurfaceFormatsKHR(renderer.physical_device, renderer.surface, &format_count, &formats[0])
    
    present_mode_count: u32
    vulkan.GetPhysicalDeviceSurfacePresentModesKHR(renderer.physical_device, renderer.surface, &present_mode_count, nil)
    
    present_modes := make([]vulkan.PresentModeKHR, present_mode_count)
    defer delete(present_modes)
    vulkan.GetPhysicalDeviceSurfacePresentModesKHR(renderer.physical_device, renderer.surface, &present_mode_count, &present_modes[0])
    
    // Create swapchain
    width, height := window.get_window_size()
    
    image_count := capabilities.minImageCount + 1
    if capabilities.maxImageCount > 0 && image_count > capabilities.maxImageCount {
        image_count = capabilities.maxImageCount
    }
    
    create_info := vulkan.SwapchainCreateInfoKHR {
        surface = renderer.surface,
        minImageCount = image_count,
        imageFormat = formats[0].format,
        imageColorSpace = formats[0].colorSpace,
        imageExtent = {u32(width), u32(height)},
        imageArrayLayers = 1,
        imageUsage = {.COLOR_ATTACHMENT},
        imageSharingMode = .EXCLUSIVE,
        preTransform = capabilities.currentTransform,
        compositeAlpha = {.OPAQUE},
        presentMode = .FIFO, // Guaranteed to be available
        clipped = true,
    }
    
    if vulkan.CreateSwapchainKHR(renderer.device, &create_info, nil, &renderer.swapchain) != .SUCCESS {
        return false
    }
    
    // Get swapchain images
    vulkan.GetSwapchainImagesKHR(renderer.device, renderer.swapchain, &image_count, nil)
    renderer.swapchain_images = make([]vulkan.Image, image_count)
    vulkan.GetSwapchainImagesKHR(renderer.device, renderer.swapchain, &image_count, &renderer.swapchain_images[0])
    
    // Create image views
    renderer.swapchain_image_views = make([]vulkan.ImageView, image_count)
    
    for i: u32 = 0; i < image_count; i += 1 {
        view_create_info := vulkan.ImageViewCreateInfo {
            image = renderer.swapchain_images[i],
            viewType = .D2,
            format = formats[0].format,
            components = {
                r = .IDENTITY,
                g = .IDENTITY,
                b = .IDENTITY,
                a = .IDENTITY,
            },
            subresourceRange = {
                aspectMask = {.COLOR},
                baseMipLevel = 0,
                levelCount = 1,
                baseArrayLayer = 0,
                layerCount = 1,
            },
        }
        
        if vulkan.CreateImageView(renderer.device, &view_create_info, nil, &renderer.swapchain_image_views[i]) != .SUCCESS {
            return false
        }
    }
    
    return true
}

// Create render pass
create_render_pass :: proc() -> bool {
    // Simple render pass with one color attachment
    color_attachment := vulkan.AttachmentDescription {
        format = .B8G8R8A8_SRGB, // Match swapchain format
        samples = {._1},
        loadOp = .CLEAR,
        storeOp = .STORE,
        stencilLoadOp = .DONT_CARE,
        stencilStoreOp = .DONT_CARE,
        initialLayout = .UNDEFINED,
        finalLayout = .PRESENT_SRC_KHR,
    }
    
    color_attachment_ref := vulkan.AttachmentReference {
        attachment = 0,
        layout = .COLOR_ATTACHMENT_OPTIMAL,
    }
    
    subpass := vulkan.SubpassDescription {
        pipelineBindPoint = .GRAPHICS,
        colorAttachmentCount = 1,
        pColorAttachments = &color_attachment_ref,
    }
    
    dependency := vulkan.SubpassDependency {
        srcSubpass = vulkan.SUBPASS_EXTERNAL,
        dstSubpass = 0,
        srcStageMask = {.COLOR_ATTACHMENT_OUTPUT},
        dstStageMask = {.COLOR_ATTACHMENT_OUTPUT},
        dstAccessMask = {.COLOR_ATTACHMENT_WRITE},
    }
    
    render_pass_info := vulkan.RenderPassCreateInfo {
        attachmentCount = 1,
        pAttachments = &color_attachment,
        subpassCount = 1,
        pSubpasses = &subpass,
        dependencyCount = 1,
        pDependencies = &dependency,
    }
    
    if vulkan.CreateRenderPass(renderer.device, &render_pass_info, nil, &renderer.render_pass) != .SUCCESS {
        return false
    }
    
    return true
}

// Create graphics pipeline
create_graphics_pipeline :: proc() -> bool {
    // In a complete implementation, you would load shader modules from files
    // For now, we'll use placeholder shader modules
    vertex_shader_module := create_dummy_shader_module(.VERTEX)
    fragment_shader_module := create_dummy_shader_module(.FRAGMENT)
    defer vulkan.DestroyShaderModule(renderer.device, vertex_shader_module, nil)
    defer vulkan.DestroyShaderModule(renderer.device, fragment_shader_module, nil)
    
    shader_stages := [2]vulkan.PipelineShaderStageCreateInfo {
        {
            stage = {.VERTEX},
            module = vertex_shader_module,
            pName = "main",
        },
        {
            stage = {.FRAGMENT},
            module = fragment_shader_module,
            pName = "main",
        },
    }
    
    binding_description := vulkan.VertexInputBindingDescription {
        binding = 0,
        stride = u32(size_of(Vertex)),
        inputRate = .VERTEX,
    }
    
    attribute_descriptions := [4]vulkan.VertexInputAttributeDescription {
        { // Position
            binding = 0,
            location = 0,
            format = .R32G32B32_SFLOAT,
            offset = u32(offset_of(Vertex, position)),
        },
        { // Normal
            binding = 0,
            location = 1,
            format = .R32G32B32_SFLOAT,
            offset = u32(offset_of(Vertex, normal)),
        },
        { // UV
            binding = 0,
            location = 2,
            format = .R32G32_SFLOAT,
            offset = u32(offset_of(Vertex, uv)),
        },
        { // Color
            binding = 0,
            location = 3,
            format = .R32G32B32_SFLOAT,
            offset = u32(offset_of(Vertex, color)),
        },
    }
    
    vertex_input_info := vulkan.PipelineVertexInputStateCreateInfo {
        vertexBindingDescriptionCount = 1,
        pVertexBindingDescriptions = &binding_description,
        vertexAttributeDescriptionCount = 4,
        pVertexAttributeDescriptions = &attribute_descriptions[0],
    }
    
    input_assembly := vulkan.PipelineInputAssemblyStateCreateInfo {
        topology = .TRIANGLE_LIST,
        primitiveRestartEnable = false,
    }
    
    width, height := window.get_window_size()
    viewport := vulkan.Viewport {
        x = 0.0,
        y = 0.0,
        width = f32(width),
        height = f32(height),
        minDepth = 0.0,
        maxDepth = 1.0,
    }
    
    scissor := vulkan.Rect2D {
        offset = {0, 0},
        extent = {u32(width), u32(height)},
    }
    
    viewport_state := vulkan.PipelineViewportStateCreateInfo {
        viewportCount = 1,
        pViewports = &viewport,
        scissorCount = 1,
        pScissors = &scissor,
    }
    
    rasterizer := vulkan.PipelineRasterizationStateCreateInfo {
        depthClampEnable = false,
        rasterizerDiscardEnable = false,
        polygonMode = .FILL,
        lineWidth = 1.0,
        cullMode = {.BACK},
        frontFace = .COUNTER_CLOCKWISE,
        depthBiasEnable = false,
    }
    
    multisampling := vulkan.PipelineMultisampleStateCreateInfo {
        sampleShadingEnable = false,
        rasterizationSamples = {._1},
    }
    
    color_blend_attachment := vulkan.PipelineColorBlendAttachmentState {
        colorWriteMask = {.R, .G, .B, .A},
        blendEnable = false,
    }
    
    color_blending := vulkan.PipelineColorBlendStateCreateInfo {
        logicOpEnable = false,
        attachmentCount = 1,
        pAttachments = &color_blend_attachment,
    }
    
    pipeline_info := vulkan.GraphicsPipelineCreateInfo {
        stageCount = 2,
        pStages = &shader_stages[0],
        pVertexInputState = &vertex_input_info,
        pInputAssemblyState = &input_assembly,
        pViewportState = &viewport_state,
        pRasterizationState = &rasterizer,
        pMultisampleState = &multisampling,
        pColorBlendState = &color_blending,
        layout = renderer.pipeline_layout,
        renderPass = renderer.render_pass,
        subpass = 0,
    }
    
    if vulkan.CreateGraphicsPipelines(
        renderer.device,
        0,
        1,
        &pipeline_info,
        nil,
        &renderer.graphics_pipeline,
    ) != .SUCCESS {
        return false
    }
    
    return true
}

// Create framebuffers
create_framebuffers :: proc() -> bool {
    width, height := window.get_window_size()
    renderer.swapchain_framebuffers = make([]vulkan.Framebuffer, len(renderer.swapchain_image_views))
    
    for i := 0; i < len(renderer.swapchain_image_views); i += 1 {
        attachments := []vulkan.ImageView{renderer.swapchain_image_views[i]}
        
        framebuffer_info := vulkan.FramebufferCreateInfo {
            renderPass = renderer.render_pass,
            attachmentCount = 1,
            pAttachments = &attachments[0],
            width = u32(width),
            height = u32(height),
            layers = 1,
        }
        
        if vulkan.CreateFramebuffer(renderer.device, &framebuffer_info, nil, &renderer.swapchain_framebuffers[i]) != .SUCCESS {
            return false
        }
    }
    
    return true
}

// Create command buffers
create_command_buffers :: proc() {
    renderer.command_buffers = make([]vulkan.CommandBuffer, len(renderer.swapchain_framebuffers))
    
    alloc_info := vulkan.CommandBufferAllocateInfo {
        commandPool = renderer.command_pool,
        level = .PRIMARY,
        commandBufferCount = u32(len(renderer.command_buffers)),
    }
    
    vulkan.AllocateCommandBuffers(renderer.device, &alloc_info, &renderer.command_buffers[0])
}

// Create synchronization objects
create_sync_objects :: proc() {
    renderer.image_available_semaphores = make([]vulkan.Semaphore, renderer.max_frames_in_flight)
    renderer.render_finished_semaphores = make([]vulkan.Semaphore, renderer.max_frames_in_flight)
    renderer.in_flight_fences = make([]vulkan.Fence, renderer.max_frames_in_flight)
    
    semaphore_info := vulkan.SemaphoreCreateInfo{}
    fence_info := vulkan.FenceCreateInfo {
        flags = {.SIGNALED},
    }
    
    for i := 0; i < int(renderer.max_frames_in_flight); i += 1 {
        vulkan.CreateSemaphore(renderer.device, &semaphore_info, nil, &renderer.image_available_semaphores[i])
        vulkan.CreateSemaphore(renderer.device, &semaphore_info, nil, &renderer.render_finished_semaphores[i])
        vulkan.CreateFence(renderer.device, &fence_info, nil, &renderer.in_flight_fences[i])
    }
}

// Create descriptor pool
create_descriptor_pool :: proc() {
    pool_sizes := [2]vulkan.DescriptorPoolSize {
        { // Uniform buffers
            type = .UNIFORM_BUFFER,
            descriptorCount = 100, // Support up to 100 materials
        },
        { // Combined image samplers
            type = .COMBINED_IMAGE_SAMPLER,
            descriptorCount = 100, // Support up to 100 textures
        },
    }
    
    pool_info := vulkan.DescriptorPoolCreateInfo {
        poolSizeCount = 2,
        pPoolSizes = &pool_sizes[0],
        maxSets = 100, // Support up to 100 descriptor sets
    }
    
    vulkan.CreateDescriptorPool(renderer.device, &pool_info, nil, &renderer.descriptor_pool)
}

// Create dummy shader module for placeholder
create_dummy_shader_module :: proc(stage: vulkan.ShaderStageFlag) -> vulkan.ShaderModule {
    // This is a placeholder; in a real implementation, you would load SPIR-V code from files
    // Here we're just creating an empty shader module
    dummy_code := []u32{0x07230203}
    
    create_info := vulkan.ShaderModuleCreateInfo {
        codeSize = size_of(u32) * len(dummy_code),
        pCode = &dummy_code[0],
    }
    
    shader_module: vulkan.ShaderModule
    vulkan.CreateShaderModule(renderer.device, &create_info, nil, &shader_module)
    
    return shader_module
}

// Load model from file and prepare it for rendering
load_model :: proc(model_path: string) -> bool {
    // Check if the model is already loaded
    if model_path in renderer.models {
        return true
    }
    
    // Load the model
    model, err := gltf.load(model_path)
    if err != .None {
        log.error("Failed to load model:", model_path, "error:", err)
        return false
    }
    
    // Store the model
    renderer.models[model_path] = model
    
    // Create GPU resources for the model's meshes and materials
    renderer.mesh_collection = create_mesh_collection(
        renderer.device,
        renderer.physical_device,
        renderer.command_pool,
        renderer.graphics_queue,
        renderer.descriptor_pool,
        renderer.descriptor_set_layout,
        model,
    )
    
    return true
}

// Update function to be called each frame
update :: proc() {
    // Wait for the previous frame to finish
    vulkan.WaitForFences(
        renderer.device,
        1,
        &renderer.in_flight_fences[renderer.current_frame],
        true,
        ~u64(0), // UINT64_MAX
    )
    
    // Acquire the next image from the swapchain
    image_index: u32
    result := vulkan.AcquireNextImageKHR(
        renderer.device,
        renderer.swapchain,
        ~u64(0), // UINT64_MAX
        renderer.image_available_semaphores[renderer.current_frame],
        0,
        &image_index,
    )
    
    // Check if swapchain needs to be recreated
    if result == .ERROR_OUT_OF_DATE_KHR || result == .SUBOPTIMAL_KHR || renderer.framebuffer_resized {
        recreate_swapchain()
        renderer.framebuffer_resized = false
        return
    } else if result != .SUCCESS {
        log.error("Failed to acquire swapchain image")
        return
    }
    
    // Reset the fence for this frame
    vulkan.ResetFences(renderer.device, 1, &renderer.in_flight_fences[renderer.current_frame])
    
    // Record command buffer
    command_buffer := renderer.command_buffers[image_index]
    vulkan.ResetCommandBuffer(command_buffer, {})
    
    record_command_buffer(command_buffer, image_index)
    
    // Submit the command buffer
    wait_stages := []vulkan.PipelineStageFlags{{.COLOR_ATTACHMENT_OUTPUT}}
    
    submit_info := vulkan.SubmitInfo {
        waitSemaphoreCount = 1,
        pWaitSemaphores = &renderer.image_available_semaphores[renderer.current_frame],
        pWaitDstStageMask = &wait_stages[0],
        commandBufferCount = 1,
        pCommandBuffers = &command_buffer,
        signalSemaphoreCount = 1,
        pSignalSemaphores = &renderer.render_finished_semaphores[renderer.current_frame],
    }
    
    if vulkan.QueueSubmit(
        renderer.graphics_queue,
        1,
        &submit_info,
        renderer.in_flight_fences[renderer.current_frame],
    ) != .SUCCESS {
        log.error("Failed to submit draw command buffer")
        return
    }
    
    // Present the image
    present_info := vulkan.PresentInfoKHR {
        waitSemaphoreCount = 1,
        pWaitSemaphores = &renderer.render_finished_semaphores[renderer.current_frame],
        swapchainCount = 1,
        pSwapchains = &renderer.swapchain,
        pImageIndices = &image_index,
    }
    
    result = vulkan.QueuePresentKHR(renderer.present_queue, &present_info)
    
    if result == .ERROR_OUT_OF_DATE_KHR || result == .SUBOPTIMAL_KHR {
        recreate_swapchain()
        renderer.framebuffer_resized = false
    } else if result != .SUCCESS {
        log.error("Failed to present swapchain image")
    }
    
    // Update the frame index
    renderer.current_frame = (renderer.current_frame + 1) % renderer.max_frames_in_flight
}

// Record commands for rendering
record_command_buffer :: proc(command_buffer: vulkan.CommandBuffer, image_index: u32) {
    begin_info := vulkan.CommandBufferBeginInfo {
        flags = {},
    }
    
    vulkan.BeginCommandBuffer(command_buffer, &begin_info)
    
    clear_color := vulkan.ClearValue {
        color = {float32 = {0.0, 0.0, 0.2, 1.0}},
    }
    
    width, height := window.get_window_size()
    
    render_pass_info := vulkan.RenderPassBeginInfo {
        renderPass = renderer.render_pass,
        framebuffer = renderer.swapchain_framebuffers[image_index],
        renderArea = {
            offset = {0, 0},
            extent = {u32(width), u32(height)},
        },
        clearValueCount = 1,
        pClearValues = &clear_color,
    }
    
    vulkan.CmdBeginRenderPass(command_buffer, &render_pass_info, .INLINE)
    
    vulkan.CmdBindPipeline(command_buffer, .GRAPHICS, renderer.graphics_pipeline)
    
    // Render meshes from ECS entities
    render_meshes(command_buffer)
    
    vulkan.CmdEndRenderPass(command_buffer)
    
    vulkan.EndCommandBuffer(command_buffer)
}

// Render meshes from ECS components
render_meshes :: proc(command_buffer: vulkan.CommandBuffer) {
    entities := ecs.get_entities_with_mesh()
    
    for entity in entities {
        mesh_comp := ecs.get_mesh_component(entity)
        transform_comp := ecs.get_transform_component(entity)
        
        if mesh_comp == nil || !mesh_comp.visible || mesh_comp.mesh_index < 0 {
            continue
        }
        
        // Bind the mesh's vertex and index buffers
        if mesh_comp.mesh_index < len(renderer.mesh_collection.meshes) {
            mesh_buffer := renderer.mesh_collection.meshes[mesh_comp.mesh_index]
            
            if mesh_buffer.index_count > 0 {
                offsets := []vulkan.DeviceSize{0}
                vulkan.CmdBindVertexBuffers(command_buffer, 0, 1, &mesh_buffer.vertex_buffer, &offsets[0])
                vulkan.CmdBindIndexBuffer(command_buffer, mesh_buffer.index_buffer, 0, .UINT32)
                
                // Set push constants for transform matrix
                model_matrix := m.IDENTITY_MAT // Will be replaced with actual transform
                if transform_comp != nil {
                    // TODO: Calculate model matrix from transform component
                    // A simple implementation for now
                    position_matrix := linalg.matrix4_translate_f32(transform_comp.pos)
                    rotation_matrix := linalg.matrix4_from_quaternion_f32(transform_comp.rot)
                    scale_matrix := linalg.matrix4_scale_f32({transform_comp.scale, transform_comp.scale, transform_comp.scale})
                    
                    model_matrix = linalg.matrix_mul(position_matrix, linalg.matrix_mul(rotation_matrix, scale_matrix))
                }
                
                // For each primitive, bind its material and draw
                for i := 0; i < len(mesh_comp.material_indices); i += 1 {
                    material_index := mesh_comp.material_indices[i]
                    
                    if material_index >= 0 && material_index < len(renderer.mesh_collection.materials) {
                        // Bind material descriptor set
                        material_buffer := renderer.mesh_collection.materials[material_index]
                        vulkan.CmdBindDescriptorSets(
                            command_buffer,
                            .GRAPHICS,
                            renderer.pipeline_layout,
                            0,
                            1,
                            &material_buffer.descriptor_set,
                            0,
                            nil,
                        )
                        
                        // Set push constants
                        push_constants := Mesh_Push_Constants {
                            model_matrix = model_matrix,
                            material_index = i32(material_index),
                        }
                        
                        vulkan.CmdPushConstants(
                            command_buffer,
                            renderer.pipeline_layout,
                            {.VERTEX},
                            0,
                            size_of(Mesh_Push_Constants),
                            &push_constants,
                        )
                        
                        // Draw
                        vulkan.CmdDrawIndexed(command_buffer, mesh_buffer.index_count, 1, 0, 0, 0)
                    }
                }
            }
        }
    }
}

// Recreate the swapchain if the window is resized
recreate_swapchain :: proc() {
    width, height := window.get_window_size()
    if width == 0 || height == 0 {
        return // Window is minimized, wait until it's restored
    }
    
    vulkan.DeviceWaitIdle(renderer.device)
    
    // Clean up old swapchain resources
    for framebuffer in renderer.swapchain_framebuffers {
        vulkan.DestroyFramebuffer(renderer.device, framebuffer, nil)
    }
    delete(renderer.swapchain_framebuffers)
    
    for image_view in renderer.swapchain_image_views {
        vulkan.DestroyImageView(renderer.device, image_view, nil)
    }
    delete(renderer.swapchain_image_views)
    
    // Keep the old swapchain for proper resource handling
    old_swapchain := renderer.swapchain
    
    // Create new swapchain
    create_swapchain()
    create_framebuffers()
    
    // Destroy the old swapchain after the new one is created
    vulkan.DestroySwapchainKHR(renderer.device, old_swapchain, nil)
} 