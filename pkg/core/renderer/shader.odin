#+private
package renderer

import "core:log"
import "core:os"
import "core:fmt"
import "core:path/filepath"
import "core:strings"
import "core:strconv"

import "vendor:wgpu"




shaders: map[string]Shader

Shader :: struct {
    module: wgpu.ShaderModule,
    vertex_entry: string,
    fragment_entry: string,
    bind_group_layouts: []wgpu.BindGroupLayout,
    pipeline_layout: wgpu.PipelineLayout,
    vertex_buffer_layout: wgpu.VertexBufferLayout
}

load_shaders :: proc() {
    shader_code: string
    filepath.walk("./assets/shaders", load_shader, &shader_code)
}

load_shader :: proc(info: os.File_Info, in_err: os.Error, user_data: rawptr) -> (err: os.Error, skip_dir: bool) {
    fmt.assertf(in_err == nil, "Error loading shader file:", info.name)
    if info.is_dir do return

    shader_name := strings.trim_suffix(info.name, filepath.ext(info.name))
    log.info("Loading shader:", shader_name)

    shader_code, ok := os.read_entire_file(info.fullpath)
    fmt.assertf(ok, "Error reading shader file:", info.name)
    shader_code_str := string(shader_code)

    shader_source_wgsl := wgpu.ShaderSourceWGSL {
        sType = .ShaderSourceWGSL,
        code = shader_code_str,
    }

    shader_module_desc := wgpu.ShaderModuleDescriptor {
        label = shader_name,
        nextInChain = &shader_source_wgsl,
    }

    shader_module := wgpu.DeviceCreateShaderModule(state.device, &shader_module_desc)
    bind_group_layouts := determine_bind_group_layouts(shader_code_str)
    pipeline_layout := determine_pipeline_layout(shader_code_str, bind_group_layouts)
    vertex_buffer_layout := determine_vertex_buffer_layout(shader_code_str)

    shaders[shader_name] = Shader {
        module = shader_module,
        vertex_entry = "vs_main",
        fragment_entry = "fs_main",
        bind_group_layouts = bind_group_layouts,
        pipeline_layout = pipeline_layout,
        vertex_buffer_layout = vertex_buffer_layout
    }
    return
}

determine_bind_group_layouts :: proc(shader_str: string) -> []wgpu.BindGroupLayout {
    // Parse shader for @group and @binding annotations
    groups := make(map[int]map[int]string)
    defer delete(groups)

    lines := strings.split(shader_str, "\n")
    defer delete(lines) // Defer deletion of the lines slice itself

    log.info("Parsing shader for bind groups...")
    for line in lines {
        trimmed_line := strings.trim_space(line)

        // Skip commented lines
        if strings.has_prefix(trimmed_line, "//") {
            continue
        }

        g_idx := strings.index(trimmed_line, "@group(")
        b_idx := strings.index(trimmed_line, "@binding(")

        // Only process if both keywords are present
        if g_idx == -1 || b_idx == -1 {
            continue
        }

        // Extract group index
        group_idx := -1
        group_start := g_idx + 7 // length of "@group("
        group_end := strings.index_byte(trimmed_line[group_start:], ')')
        if group_end > 0 {
            group_str := trimmed_line[group_start : group_start+group_end]
            group, ok := strconv.parse_int(group_str)
            if ok { group_idx = int(group) }
        }

        // Extract binding index
        binding_idx := -1
        binding_start := b_idx + 9 // length of "@binding("
        binding_end := strings.index_byte(trimmed_line[binding_start:], ')')
        if binding_end > 0 {
            binding_str := trimmed_line[binding_start : binding_start+binding_end]
            binding, ok := strconv.parse_int(binding_str)
            if ok { binding_idx = int(binding) }
        }

        // If indices are invalid, skip
        if group_idx < 0 || binding_idx < 0 {
            log.warnf("Failed to parse group/binding index from line: %s", trimmed_line)
            continue
        }

        // Extract type
        var_type := ""
        if strings.contains(trimmed_line, "var<uniform>") {
            var_type = "uniform"
        } else if strings.contains(trimmed_line, "texture_2d") {
            var_type = "texture"
        } else if strings.contains(trimmed_line, "sampler") {
            var_type = "sampler"
        } else if strings.contains(trimmed_line, "var<storage>") {
            var_type = "storage"
        } else {
             log.warnf("Unknown binding type in line: %s", trimmed_line)
             continue // Skip if type unknown
        }

        // Store in map - FIX FOR MAP ISSUE
        log.infof("Found binding: group=%d, binding=%d, type=%s", group_idx, binding_idx, var_type)

        // First check if inner map exists
        if group_idx not_in groups {
            log.infof("Creating inner map for group %d", group_idx)
            groups[group_idx] = make(map[int]string)
        }

        // Now directly modify the map
        inner_map := groups[group_idx]
        inner_map[binding_idx] = var_type
        groups[group_idx] = inner_map // Update the outer map with modified inner map

        log.infof("-> Group %d map size after add: %d", group_idx, len(groups[group_idx]))
    } // End of line parsing loop

    // Log final map state for verification
    log.info("Finished parsing shader. Final groups map structure:")
    for g_idx, b_map in groups {
         log.infof("  Group %d: (size %d)", g_idx, len(b_map))
         for b_idx, v_type in b_map {
              log.infof("    Binding %d: %s", b_idx, v_type)
         }
    }

    // Find max group index to determine array size
    max_group_idx := -1
    for group_idx in groups {
        max_group_idx = max(max_group_idx, group_idx)
    }

    // Create bind group layouts based on parsed information
    // Use a fixed array indexed by group number to ensure consistent order
    layouts := make([]wgpu.BindGroupLayout, max_group_idx + 1)

    log.info("Creating bind group layouts...")
    for group_idx, bindings in groups {
        log.infof("Processing group %d, number of bindings reported by iterator: %d", group_idx, len(bindings))
        if len(bindings) == 0 {
            // If this happens, the parsing logs above should show if items were added or not.
            log.errorf("Internal check failed: Group %d exists but has 0 bindings during layout creation. Skipping.", group_idx)
            continue // Skip this group
        }

        // Create slice for entries for this group
        entries := make([]wgpu.BindGroupLayoutEntry, len(bindings))

        j := 0 // Counter for valid entries added
        for binding_idx, var_type in bindings {
            log.infof("  - Processing Binding %d: type=%s", binding_idx, var_type)
            entry := wgpu.BindGroupLayoutEntry {
                binding = u32(binding_idx),
                visibility = {.Vertex, .Fragment}, // Defaulting visibility
            }

            valid_entry := true
            switch var_type {
            case "uniform":
                entry.buffer = wgpu.BufferBindingLayout { type = .Uniform }
            case "texture":
                entry.texture = wgpu.TextureBindingLayout { sampleType = .Float, viewDimension = ._2D }
            case "sampler":
                entry.sampler = wgpu.SamplerBindingLayout { type = .Filtering }
            case "storage":
                entry.buffer = wgpu.BufferBindingLayout { type = .Storage }
            }

            entries[j] = entry
            j += 1

        } // End inner loop (bindings)

        // At this point, j should equal len(bindings) if all entries were processed
        if j != len(bindings) {
             log.warnf("Mismatch in entry count for group %d. Expected %d, processed %d. Using processed count.", group_idx, len(bindings), j)
        }

        // Create layout descriptor using the populated entries
        layout_desc := wgpu.BindGroupLayoutDescriptor {
            label = fmt.tprintf("BindGroupLayout_%d", group_idx),
            entryCount = uint(j), // Use actual number of entries processed (j)
            entries = raw_data(entries[:j]), // Pass potentially sliced raw data if j < len(bindings)
        }

        log.infof("Creating WGPU BindGroupLayout for group %d with %d entries", group_idx, j)
        layout := wgpu.DeviceCreateBindGroupLayout(state.device, &layout_desc)

        // Store layout at the correct index based on group_idx
        layouts[group_idx] = layout
        delete(entries) // Delete the temporary entries slice for this group

    } // End outer loop (groups)

    log.infof("Finished creating %d layouts.", max_group_idx + 1)

    return layouts
}

determine_pipeline_layout :: proc(shader_str: string, bind_group_layouts: []wgpu.BindGroupLayout) -> wgpu.PipelineLayout {
    // Create pipeline layout using bind group layouts
    pipeline_layout_desc := wgpu.PipelineLayoutDescriptor {
        label = "Pipeline Layout",
        bindGroupLayoutCount = len(bind_group_layouts),
        bindGroupLayouts = len(bind_group_layouts) > 0 ? raw_data(bind_group_layouts) : nil,
    }

    return wgpu.DeviceCreatePipelineLayout(state.device, &pipeline_layout_desc)
}

determine_vertex_buffer_layout :: proc(shader_str: string) -> wgpu.VertexBufferLayout {
    // Parse shader for vertex attributes
    attributes: [dynamic]wgpu.VertexAttribute
    defer delete(attributes)

    vertex_input_start := strings.index(shader_str, "struct VertexInput")
    if vertex_input_start < 0 {
        fmt.panicf("Shader has no struct VertexInput\n%q", shader_str)
    }

    struct_start := strings.index_byte(shader_str[vertex_input_start:], '{')
    struct_end := strings.index_byte(shader_str[vertex_input_start+struct_start:], '}')

    struct_content := shader_str[vertex_input_start+struct_start+1:vertex_input_start+struct_start+struct_end]
    lines := strings.split(struct_content, "\n")
    defer delete(lines)

    // Parse attributes
    stride := u64(0)
    for line in lines {
        line := strings.trim_space(line)
        if strings.contains(line, "@location") {
            location_start := strings.index(line, "@location(") + 10
            if location_start == 10 {
                location_end := strings.index(line[location_start:], ")")
                if location_end > 0 {
                    location_str := line[location_start:location_start+location_end]
                    location, ok := strconv.parse_int(location_str)
                    if ok {
                        // Determine format based on type
                        format: wgpu.VertexFormat

                        if strings.contains(line, "vec4<f32>") {
                            format = .Float32x4
                            stride += 16  // 4 floats * 4 bytes
                        } else if strings.contains(line, "vec3<f32>") {
                            format = .Float32x3
                            stride += 12  // 3 floats * 4 bytes
                        } else if strings.contains(line, "vec2<f32>") {
                            format = .Float32x2
                            stride += 8   // 2 floats * 4 bytes
                        } else if strings.contains(line, "f32") {
                            format = .Float32
                            stride += 4   // 1 float * 4 bytes
                        }

                        attribute := wgpu.VertexAttribute {
                            format = format,
                            offset = 0,  // Will update later
                            shaderLocation = u32(location),
                        }

                        append(&attributes, attribute)
                    }
                }
            }
        }
    }

    // Update offsets
    offset := u64(0)
    for i := 0; i < len(attributes); i += 1 {
        attributes[i].offset = offset

        // Calculate next offset based on format
        #partial switch attributes[i].format {
        case .Float32x4:
            offset += 16
        case .Float32x3:
            offset += 12
        case .Float32x2:
            offset += 8
        case .Float32:
            offset += 4
        }
    }

    // Create attributes array for return
    attrs := make([]wgpu.VertexAttribute, len(attributes))
    for i := 0; i < len(attributes); i += 1 {
        attrs[i] = attributes[i]
    }

    return wgpu.VertexBufferLayout {
        arrayStride = stride,
        stepMode = .Vertex,
        attributeCount = len(attrs),
        attributes = raw_data(attrs),
    }
}