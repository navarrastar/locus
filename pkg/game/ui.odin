package game

import sdl "vendor:sdl3"
import im "shared:imgui"
import im_sdl "shared:imgui/imgui_impl_sdl3"
import im_sdlgpu "shared:imgui/imgui_impl_sdlgpu3"



UIPanel :: enum {
    None,
    Demo,
    General
}

UIPanelSet :: bit_set[UIPanel]


UIState :: struct {
    visible_panels: UIPanelSet
}

ui_init :: proc() {
    im.CHECKVERSION()
    im.CreateContext()
    im_sdl.InitForSDLGPU(window)

    init_info := im_sdlgpu.InitInfo {
        Device = render_state.gpu,
        ColorTargetFormat = sdl.GetGPUSwapchainTextureFormat(render_state.gpu, window)
    }

    im_sdlgpu.Init(&{
            Device = render_state.gpu,
            ColorTargetFormat = sdl.GetGPUSwapchainTextureFormat(render_state.gpu, window)
        }
    )
    ui_toggle_visibility({ .None })
}
 
ui_update :: proc() -> ^im.DrawData {
    if .None in ui_state.visible_panels do return nil
    
    im_sdlgpu.NewFrame()
    im_sdl.NewFrame()
    im.NewFrame()
    
    style := im.GetStyle()
    
    im.StyleColorsLight(style)
    
    style.FrameBorderSize = 1
    style.WindowRounding = 4
    style.FrameRounding = 3
    
    if .Demo in ui_state.visible_panels {
        im.ShowDemoWindow()
    } 
    
    if .General in ui_state.visible_panels {
        ui_show_general_panel()
    }
    
    im.Render()
    draw_data := im.GetDrawData()
    return draw_data
}

ui_toggle_visibility :: proc(panel: UIPanelSet) {
    ui_state.visible_panels ~= panel
}

ui_show_general_panel :: proc() {
    if im.Begin("General") {
        im.DragFloat3("Camera Position", &world.cameras[0].pos)
        im.DragFloat3("Camera Target", &world.cameras[0].target)
    }
    im.End()
}