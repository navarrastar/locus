package vk

import "vendor:vulkan"

import "pkg:core/window"

setup_instance :: proc() -> (instance: vulkan.Instance) {
    extensions := window.get_required_extensions()

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

    vulkan.CreateInstance(&instance_create_info, nil, &instance)

    return instance
}







