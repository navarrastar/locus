package vk

import "vendor:vulkan"
import "core:log"
import "pkg:core/window"

setup_instance :: proc() -> (instance: vulkan.Instance) {
    if !window.vulkan_supported() {
        log.error("Vulkan is not supported")
        return
    }
    extensions := window.get_required_extensions()
    
    // On macOS, we need additional extensions for MoltenVK
    when ODIN_OS == .Darwin {
        // Add macOS-specific extensions
        mac_extensions := make([]cstring, len(extensions) + 2)
        defer delete(mac_extensions)
        
        copy(mac_extensions, extensions)
        
        // Required for macOS MoltenVK
        mac_extensions[len(extensions)] = "VK_KHR_portability_enumeration"
        
        extensions = mac_extensions
    }

    layers: []cstring

    when ODIN_DEBUG {
        layers = { "VK_LAYER_KHRONOS_validation" }
    }

    instance_create_info: vulkan.InstanceCreateInfo = {
        enabledLayerCount = cast(u32)len(layers),
        ppEnabledLayerNames = raw_data(layers),
        enabledExtensionCount = cast(u32)len(extensions),
        ppEnabledExtensionNames = raw_data(extensions),
    }
    
    // Enable portability enumeration flag on macOS
    when ODIN_OS == .Darwin {
        instance_create_info.flags = {.ENUMERATE_PORTABILITY_KHR}
    }

    vulkan.CreateInstance(&instance_create_info, nil, &instance)

    return instance
}







