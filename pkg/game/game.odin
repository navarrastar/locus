package game

import "core:log"

import "pkg:core/window"
import "pkg:game/ecs"
import m "pkg:core/math"
import c "pkg:game/ecs/component"
import "pkg:game/event"
import "pkg:game/input"
import "pkg:core/filesystem/gltf"
import "pkg:renderer/vk"
import "core:os"



init :: proc() {
    ecs.init()
    
    // Initialize the Vulkan renderer
    if !vk.init() {
        log.error("Failed to initialize Vulkan renderer")
        return
    }
    
    e0 := ecs.spawn()

    camera: c.Camera = c.Perspective {
        near = 0.1,
        far = 100.0,
        fov = 103.0,
    };
    ecs.add_component(e0, camera)


    light: c.Light = c.Point {
        color = m.Vec3{0, 0, 0},
        intensity = 1.0,
        range = 10.0,
    };
    ecs.add_component(e0, light)

    e1 := ecs.spawn(name="test")

    w_press_event := event.Input_Event {
        key = input.KEY_W,
        action = input.ACTION_PRESS,
    }

    w_handler := event.Handler {
        callback = proc(e: event.Event) -> bool {
            log.debug(e)
            return true
        },
    }

    event.add_handler(w_press_event, w_handler)

    any_resize_handler := event.Handler {
        callback = proc(e: event.Event) -> bool {
            resize_data := e.(event.WindowResize_Event)
            log.debug("Any resize event handler triggered! New dimensions:", resize_data.width, "x", resize_data.height)
            return true
        },
    }

    event.add_handler(event.Event_Type.WindowResize, any_resize_handler)
    
    // Load model and create entities with mesh components
    model_path := "./assets/models/DamagedHelmet.glb"
    model, err := gltf.load(model_path)
    if err == .None {
        // Upload model data to GPU
        vk.load_model(model_path)
        
        // Spawn entities with mesh components
        ecs.spawn_from_model(model)
    } else {
        log.error("Failed to load model:", model_path)
    }
}

cleanup :: proc() {
    // Clean up the Vulkan renderer
    vk.cleanup()
    
    ecs.cleanup()
}

loop :: proc() {
    ecs.loop()
    for !window.should_close() {
        // Poll window events
        window.poll_events()
        
        // Update and render with Vulkan
        vk.update()
    }
}
