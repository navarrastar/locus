package game

import "core:fmt"
import "core:log"
import "core:strings"
import "core:time"

import os "core:os/os2"
import "core:path/filepath"

import sdl "vendor:sdl3"

when ODIN_OS == .Windows {
	SHADER_FORMAT: sdl.GPUShaderFormatFlag : .SPIRV
	SHADER_PATH_DST :: SHADER_DIR + "spirv/"
	
} else when ODIN_OS == .Darwin {
	SHADER_FORMAT: sdl.GPUShaderFormatFlag : .MSL
	SHADER_PATH_DST :: SHADER_DIR + "msl/"
}


ShaderInfo :: struct {
    name:                 string,
    num_samplers:         u32,
    num_storage_textures: u32,
    num_storage_buffers:  u32,
    num_uniform_buffers:  u32
}

shader_load :: proc(path_src: string) -> ^sdl.GPUShader {
    stage    := shader_determine_stage(path_src)
    path_dst := shader_determine_path_dst(path_src)
    
    status_code, _ := shader_process_start_shadercross(path_src, path_dst)
    if status_code != 0 do return nil
    
    byte_code, read_err := os.read_entire_file(path_dst, context.temp_allocator);
    if read_err != nil || byte_code == nil {
        log.errorf("Error reading shader file.\npath_src: {}\nError: {}", path_src, read_err)
    }

    create_info := sdl.GPUShaderCreateInfo {
        code_size            = len(byte_code),
        code                 = raw_data(byte_code),
        entrypoint           = "main0" when SHADER_FORMAT == .MSL else "main",
        format               = { SHADER_FORMAT },
        stage                = stage,
        num_samplers         = {},
        num_storage_textures = {},
        num_storage_buffers  = {},
        num_uniform_buffers  = 1
    }
    
    shader := sdl.CreateGPUShader(render_state.gpu, create_info)
    assert(shader != nil, string(sdl.GetError()))
    
    return shader
}

@(require_results)
shader_process_start_shadercross :: proc(path_src: string, path_dst: string) -> (exit_code: int, process_err: os.Error) {
    command := fmt.tprintf("shadercross {} -o {}", path_src, path_dst)
    fmt.println(command)
    command_split := strings.split(command, " ")
    
    process_desc := os.Process_Desc {
        command = command_split
    }
    
    process := os.process_start(process_desc) or_return
    state   := os.process_wait(process) or_return
    os.process_close(process) or_return
    return state.exit_code, nil
}

shader_determine_stage :: proc(path_src: string) -> sdl.GPUShaderStage {
    stage: sdl.GPUShaderStage
    switch filepath.long_ext(path_src) {
    case ".vert.hlsl", ".vert.spv":
        stage = .VERTEX
    case ".frag.hlsl", ".frag.spv":
        stage = .FRAGMENT
    case:
        fmt.panicf("Unkonwn shader stage:", path_src)
    }
    return stage
}

shader_determine_path_dst :: proc(path_src: string) -> string {
    path_dst: string
    stem := filepath.stem(path_src)
    when SHADER_FORMAT == .MSL {
        path_dst = strings.concatenate({ SHADER_PATH_DST, stem, ".msl"})
    } else
    when SHADER_FORMAT == .SPIRV {
        path_dst = strings.concatenate({ SHADER_PATH_DST, stem, ".spirv"})
    }
    
    return path_dst
}

shader_check_for_changes :: proc(time_last_checked: time.Time) {
    dir := SHADER_DIR + "hlsl/"
    f, oerr := os.open(dir)
	ensure(oerr == nil)
	defer os.close(f)
  
	it := os.read_directory_iterator_create(f)
	defer os.read_directory_iterator_destroy(&it)
  
	for info in os.read_directory_iterator(&it) {
		if path, err := os.read_directory_iterator_error(&it); err != nil {
			fmt.eprintfln("failed reading %s: %s", path, err)
			continue
		}
		
		time_last_modified := info.modification_time
		if time.diff(time_last_modified, time_last_checked) < 0 {
            material_type := shader_name_to_material_type[filepath.short_stem(info.name)]
            materials[material_type].pipeline = nil
		}
	}
  
    
}

shader_toggle_should_check_for_changes :: proc() {
    shader_should_check_for_changes = !shader_should_check_for_changes
}