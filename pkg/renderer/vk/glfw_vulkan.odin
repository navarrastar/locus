package vk

import "vendor:vulkan"
import "vendor:glfw"

// CreateGLFWSurfaceKHR creates a Vulkan surface for a GLFW window
CreateGLFWSurfaceKHR :: proc(instance: vulkan.Instance, window: rawptr, allocator: ^vulkan.AllocationCallbacks, surface: ^vulkan.SurfaceKHR) -> vulkan.Result {
    if result := glfw.CreateWindowSurface(instance, cast(glfw.WindowHandle)window, nil, surface); result != vulkan.Result.SUCCESS {
        return .ERROR_INITIALIZATION_FAILED
    }
    return .SUCCESS
} 