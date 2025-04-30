package game

import "core:fmt"
import "core:strings"

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

    im_sdlgpu.Init(&init_info)
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
        if im.CollapsingHeader("Entities") {
            for &e in world.entities {
                switch v in e {
                case EntityBase:
                    
                case Entity_Player:
                    player := &e.(Entity_Player)
                    if im.CollapsingHeader("Player"){
                        eid := strings.clone_to_cstring(fmt.tprintf("eid:{}", player.eid), context.temp_allocator)
                        im.Text(eid)
                        im.DragFloat3("Position", &player.pos)
                        im.DragFloat3("Rotation", &player.rot)
                    }
                case Entity_Opp:
                    opp := &e.(Entity_Opp)
                        if opp.name == "" do continue
                        if im.CollapsingHeader(strings.clone_to_cstring(opp.name, context.temp_allocator)) {
                            eid := strings.clone_to_cstring(fmt.tprintf("eid:{}", opp.eid), context.temp_allocator)
                            im.Text(eid)
                            im.DragFloat3("Position", &opp.pos)
                            im.DragFloat3("Rotation", &opp.rot)
                        }
                
                case Entity_Mesh:
                    mesh := &e.(Entity_Mesh)
                        if mesh.name == "" do continue
                        if im.CollapsingHeader(strings.clone_to_cstring(mesh.name, context.temp_allocator)) {
                            eid := strings.clone_to_cstring(fmt.tprintf("eid:{}", mesh.eid), context.temp_allocator)
                            im.Text(eid)
                            im.DragFloat3("Position", &mesh.pos)
                            im.DragFloat3("Rotation", &mesh.rot)
                        }
                case Entity_Camera:
                    cam := &e.(Entity_Camera)
                    if cam.name == "" do continue
                    if im.CollapsingHeader(strings.clone_to_cstring(cam.name, context.temp_allocator)){
                        eid := strings.clone_to_cstring(fmt.tprintf("eid:{}", cam.eid), context.temp_allocator)
                        im.Text(eid)
                        im.DragFloat3("Position", &cam.pos)
                        im.DragFloat3("Target", &cam.target)
                    }
                case Entity_Projectile:
                
                }
            }
 

        }
    }
    
    im.End()
}