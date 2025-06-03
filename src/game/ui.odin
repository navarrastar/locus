package game

import "core:fmt"
import "core:strings"
import "core:log"

import sdl "vendor:sdl3"

import steam "../../third_party/steamworks"
import im "../../third_party/imgui"
import im_sdl "../../third_party/imgui/imgui_impl_sdl3"
import im_sdlgpu "../../third_party/imgui/imgui_impl_sdlgpu3"

MAX_SERVER_COUNT :: 64

UIPanel :: enum {
    None,
    Demo,
    General,
    Server
}

UIPanelSet :: bit_set[UIPanel]

ui_state: struct {
    visible_panels:   UIPanelSet,
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
    
    if .Server in ui_state.visible_panels {
        ui_show_server_panel()
    }
    
    im.Render()
    draw_data := im.GetDrawData()
    return draw_data
}

ui_toggle_visibility :: proc(panel: UIPanelSet) {
    ui_state.visible_panels ~= panel
}

ui_show_general_panel :: proc() {
    defer im.End()
    if im.Begin("General") {
        if im.CollapsingHeader("Entities") {
            for &e in world.entities {
                switch &v in e {
                case EntityBase:
                    
                case Entity_Player:
                    if im.CollapsingHeader("Player"){
                        eid := strings.clone_to_cstring(fmt.tprintf("eid:{}", v.eid), context.temp_allocator)
                        im.Text(eid)
                        im.DragFloat3("Position", &v.pos)
                        im.DragFloat3("Rotation", &v.rot)
                    }
                case Entity_Opp:
                    if v.name == "" do continue
                    if im.CollapsingHeader(strings.clone_to_cstring(v.name, context.temp_allocator)) {
                        eid := strings.clone_to_cstring(fmt.tprintf("eid:{}", v.eid), context.temp_allocator)
                        im.Text(eid)
                        im.DragFloat3("Position", &v.pos)
                        im.DragFloat3("Rotation", &v.rot)
                    }
                case Entity_Mesh:
                    if v.name == "" do continue
                    if im.CollapsingHeader(strings.clone_to_cstring(v.name, context.temp_allocator)) {
                        eid := strings.clone_to_cstring(fmt.tprintf("eid:{}", v.eid), context.temp_allocator)
                        im.Text(eid)
                        im.DragFloat3("Position", &v.pos)
                        im.DragFloat3("Rotation", &v.rot)
                    }
                case Entity_Camera:
                    if v.name == "" do continue
                    if im.CollapsingHeader(strings.clone_to_cstring(v.name, context.temp_allocator)){
                        eid := strings.clone_to_cstring(fmt.tprintf("eid:{}", v.eid), context.temp_allocator)
                        im.Text(eid)
                        im.DragFloat3("Position", &v.pos)
                        im.DragFloat3("Target", &v.target)
                    }
                case Entity_Projectile:
                
                }
            }
 

        }
    }
    
}

ui_show_server_panel :: proc() {
    defer im.End()
    if im.Begin("Server") {
        server_infos := client_serverlist_state.server_infos
        count := client_serverlist_state.server_info_count
        
        for i in 0..<count {
            button_name_buffer: [265]u8
            button_name := fmt.bprintf(button_name_buffer[:], "Connect to server %v", server_infos[i].steamID)
            if im.Button(strings.unsafe_string_to_cstring(button_name)) {
                user_connect_to_server_async(steam_user.user, server_infos[i].steamID)
            }
        }
    }
}