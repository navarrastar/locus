package renderer

import "vendor:wgpu"
import "core:log"
import "core:strings"
import "core:fmt"


PipelineKey :: struct {
    material_type: MaterialType,
    alpha_mode: AlphaMode,
    double_sided: bool,
    has_vertex_colors: bool,
    has_normals: bool,
    has_tangents: bool,
    has_uv: bool,
    has_joints: bool,
    has_weights: bool,
}


create_pbr_bind_group_layout :: proc() {
    // Create bind group layout for PBR materials with all possible texture bindings
    entries := [?]wgpu.BindGroupLayoutEntry{
        // Base color texture
        {binding = 0, visibility = {.Fragment}, texture = {viewDimension = ._2D, sampleType = .Float}},
        // Base color sampler
        {binding = 1, visibility = {.Fragment}, sampler = {type = .Filtering}},
        // Normal texture
        {binding = 2, visibility = {.Fragment}, texture = {viewDimension = ._2D, sampleType = .Float}},
        // Normal sampler
        {binding = 3, visibility = {.Fragment}, sampler = {type = .Filtering}},
        // Metallic-roughness texture
        {binding = 4, visibility = {.Fragment}, texture = {viewDimension = ._2D, sampleType = .Float}},
        // Metallic-roughness sampler
        {binding = 5, visibility = {.Fragment}, sampler = {type = .Filtering}},
        // Material uniform buffer (pbr factors, etc)
        {binding = 6, visibility = {.Fragment}, buffer = {type = .Uniform}},
    }
    
    layout := wgpu.DeviceCreateBindGroupLayout(state.device, &wgpu.BindGroupLayoutDescriptor{
        entryCount = len(entries),
        entries = &entries[0],
    })
    
    state.bind_group_layouts[.PBR_MetallicRoughness] = layout
    
    // Create pipeline layout using this bind group layout
    pipeline_layout := wgpu.DeviceCreatePipelineLayout(state.device, &wgpu.PipelineLayoutDescriptor{
        bindGroupLayoutCount = 1,
        bindGroupLayouts = &state.bind_group_layouts[.PBR_MetallicRoughness],
    })
    
    state.pipeline_layouts[.PBR_MetallicRoughness] = pipeline_layout
}

create_unlit_bind_group_layout :: proc() {
    // Create bind group layout for unlit materials (simpler than PBR, only needs base color)
    entries := [?]wgpu.BindGroupLayoutEntry{
        // Base color texture
        {binding = 0, visibility = {.Fragment}, texture = {viewDimension = ._2D, sampleType = .Float}},
        // Base color sampler
        {binding = 1, visibility = {.Fragment}, sampler = {type = .Filtering}},
        // Material uniform buffer (factors, etc)
        {binding = 2, visibility = {.Fragment}, buffer = {type = .Uniform}},
    }
    
    layout := wgpu.DeviceCreateBindGroupLayout(state.device, &wgpu.BindGroupLayoutDescriptor{
        entryCount = len(entries),
        entries = &entries[0],
    })
    
    state.bind_group_layouts[.Unlit] = layout
    
    // Create pipeline layout using this bind group layout
    pipeline_layout := wgpu.DeviceCreatePipelineLayout(state.device, &wgpu.PipelineLayoutDescriptor{
        bindGroupLayoutCount = 1,
        bindGroupLayouts = &state.bind_group_layouts[.Unlit],
    })
    
    state.pipeline_layouts[.Unlit] = pipeline_layout
}

create_pipeline :: proc(key: PipelineKey) {
    if key in state.pipeline_cache {
        return
    }
    // Choose shader based on material type and features
    shader_code := get_shader_for_material(key)
    
    module := wgpu.DeviceCreateShaderModule(state.device, &wgpu.ShaderModuleDescriptor{
        nextInChain = &wgpu.ShaderSourceWGSL{
            chain = {sType = .ShaderSourceWGSL},
            code = shader_code,
        },
    })
    defer wgpu.ShaderModuleRelease(module)
    
    // Set up vertex attributes based on what the material needs
    vertex_attributes := get_vertex_attributes(key)
    
    vertex_buffer_layout := wgpu.VertexBufferLayout{
        arrayStride = size_of(Vertex),
        stepMode = .Vertex,
        attributeCount = uint(len(vertex_attributes)),
        attributes = raw_data(vertex_attributes),
    }
    
    // Choose pipeline layout based on material type
    pipeline_layout := state.pipeline_layouts[key.material_type]
    
    // Set up blend state based on alpha mode
    blend_state := get_blend_state(key.alpha_mode)
    blend_state_ptr := &blend_state
    
    // Set up primitive state (cull mode based on double_sided)
    primitive_state := wgpu.PrimitiveState{
        topology = .TriangleList,
        cullMode = key.double_sided ? .None : .Back,
        frontFace = .CCW,
    }
    
    pipeline := wgpu.DeviceCreateRenderPipeline(state.device, &wgpu.RenderPipelineDescriptor{
        label = fmt.tprintf("Pipeline for %v", key.material_type),
        layout = pipeline_layout,
        vertex = wgpu.VertexState{
            module = module,
            entryPoint = "vs_main",
            bufferCount = 1,
            buffers = &vertex_buffer_layout,
        },
        fragment = &wgpu.FragmentState{
            module = module,
            entryPoint = "fs_main",
            targetCount = 1,
            targets = &wgpu.ColorTargetState{
                format = .BGRA8Unorm,
                blend = blend_state_ptr,
                writeMask = wgpu.ColorWriteMaskFlags_All,
            },
        },
        primitive = primitive_state,
        depthStencil = &wgpu.DepthStencilState{
            format = .Depth24Plus,
            depthWriteEnabled = .True,
            depthCompare = .Less,
        },
        multisample = wgpu.MultisampleState{
            count = 1,
            mask = 0xFFFFFFFF,
        },
    })
    
    if pipeline == nil {
        log.error("Failed to create pipeline for material type %v", key.material_type)
        return
    }

    state.pipeline_cache[key] = pipeline
    if state.pipeline_cache[key] != nil {
        log.info(state.pipeline_cache[key])
        log.info("Created pipeline for material type %v", key.material_type)
    }
}

get_shader_for_material :: proc(key: PipelineKey) -> string {
    switch key.material_type {
        case .PBR_MetallicRoughness:
            // Build the shader string based on the key features
            vertex_input := `
struct VertexInput {
    @location(0) position: vec3<f32>,`
            
            if key.has_normals {
                vertex_input = strings.concatenate({vertex_input, `
    @location(1) normal: vec3<f32>,`})
            }
            
            if key.has_tangents {
                vertex_input = strings.concatenate({vertex_input, `
    @location(2) tangent: vec4<f32>,`})
            }
            
            if key.has_uv {
                vertex_input = strings.concatenate({vertex_input, `
    @location(3) uv: vec2<f32>,`})
            }
            
            if key.has_vertex_colors {
                vertex_input = strings.concatenate({vertex_input, `
    @location(4) color: vec4<f32>,`})
            }
            
            if key.has_joints {
                vertex_input = strings.concatenate({vertex_input, `
    @location(5) joints: vec4<u32>,`})
            }
            
            if key.has_weights {
                vertex_input = strings.concatenate({vertex_input, `
    @location(6) weights: vec4<f32>,`})
            }
            
            vertex_input = strings.concatenate({vertex_input, `
}`})

            vertex_output := `
struct VertexOutput {
    @builtin(position) position: vec4<f32>,`
            
            if key.has_normals {
                vertex_output = strings.concatenate({vertex_output, `
    @location(0) normal: vec3<f32>,`})
            }
            
            if key.has_tangents {
                vertex_output = strings.concatenate({vertex_output, `
    @location(1) tangent: vec4<f32>,`})
            }
            
            if key.has_uv {
                vertex_output = strings.concatenate({vertex_output, `
    @location(2) uv: vec2<f32>,`})
            }
            
            if key.has_vertex_colors {
                vertex_output = strings.concatenate({vertex_output, `
    @location(3) color: vec4<f32>,`})
            }
            
            vertex_output = strings.concatenate({vertex_output, `
    @location(4) world_pos: vec3<f32>,
}`})

            vs_main := `
@vertex
fn vs_main(input: VertexInput) -> VertexOutput {
    var output: VertexOutput;
    
    // TODO: Add model matrix transformation when available
    output.position = vec4<f32>(input.position, 1.0);
    output.world_pos = input.position;`
            
            if key.has_normals {
                vs_main = strings.concatenate({vs_main, `
    
    output.normal = input.normal;`})
            }
            
            if key.has_tangents {
                vs_main = strings.concatenate({vs_main, `
    
    output.tangent = input.tangent;`})
            }
            
            if key.has_uv {
                vs_main = strings.concatenate({vs_main, `
    
    output.uv = input.uv;`})
            }
            
            if key.has_vertex_colors {
                vs_main = strings.concatenate({vs_main, `
    
    output.color = input.color;`})
            }
            
            vs_main = strings.concatenate({vs_main, `
    
    return output;
}`})

            fs_main := `
@fragment
fn fs_main(input: VertexOutput) -> @location(0) vec4<f32> {
    var base_color = material.base_color_factor;`
            
            if key.has_uv {
                fs_main = strings.concatenate({fs_main, `
    
    // Sample base color texture if UVs are available
    let tex_color = textureSample(base_color_texture, base_color_sampler, input.uv);
    base_color = base_color * tex_color;`})
            }
            
            if key.has_vertex_colors {
                fs_main = strings.concatenate({fs_main, `
    
    // Multiply with vertex colors if available
    base_color = base_color * input.color;`})
            }
            
            fs_main = strings.concatenate({fs_main, `
    
    // PBR lighting calculation would go here
    // This is a simplified version for now
    var normal = vec3<f32>(0.0, 1.0, 0.0);`})
            
            if key.has_normals {
                normal_code := `
    
    normal = normalize(input.normal);`
                
                if key.has_uv && key.has_tangents {
                    normal_code = strings.concatenate({normal_code, `
    
    // Sample normal map and apply tangent space transform
    let tangent_normal = textureSample(normal_texture, normal_sampler, input.uv).xyz * 2.0 - 1.0;
    let N = normalize(input.normal);
    let T = normalize(input.tangent.xyz);
    let B = normalize(cross(N, T) * input.tangent.w);
    let TBN = mat3x3<f32>(T, B, N);
    normal = normalize(TBN * tangent_normal * vec3<f32>(material.normal_scale, material.normal_scale, 1.0));`})
                }
                
                fs_main = strings.concatenate({fs_main, normal_code})
            }
            
            mr_code := `
    
    // Metallic and roughness
    var metallic = material.metallic_factor;
    var roughness = material.roughness_factor;`
            
            if key.has_uv {
                mr_code = strings.concatenate({mr_code, `
    
    // Sample metallic-roughness texture if UVs are available
    let mr = textureSample(metallic_roughness_texture, metallic_roughness_sampler, input.uv);
    metallic = metallic * mr.b;  // Metallic is stored in blue channel
    roughness = roughness * mr.g;  // Roughness is stored in green channel`})
            }
            
            fs_main = strings.concatenate({fs_main, mr_code, `
    
    // Perform basic lighting with a directional light
    let light_dir = normalize(vec3<f32>(1.0, 1.0, 1.0));
    let view_dir = normalize(vec3<f32>(0.0, 0.0, 1.0) - input.world_pos);
    let half_dir = normalize(light_dir + view_dir);
    
    // Diffuse term (Lambert)
    let n_dot_l = max(dot(normal, light_dir), 0.0);
    
    // Specular term (GGX)
    let n_dot_h = max(dot(normal, half_dir), 0.0);
    let n_dot_v = max(dot(normal, view_dir), 0.0);
    
    // Simplified PBR without full Cook-Torrance BRDF
    let diffuse = base_color.rgb * (1.0 - metallic);
    let f0 = mix(vec3<f32>(0.04), base_color.rgb, metallic);
    let specular = f0 * pow(n_dot_h, (1.0 - roughness) * 100.0);
    
    let ambient = base_color.rgb * 0.2;
    let final_color = ambient + (diffuse + specular) * n_dot_l;
    
    return vec4<f32>(final_color, base_color.a);
}`})

            return strings.concatenate({`
struct MaterialUniforms {
    base_color_factor: vec4<f32>,
    metallic_factor: f32,
    roughness_factor: f32,
    normal_scale: f32,
    emissive_factor: vec3<f32>,
    alpha_cutoff: f32,
}

@group(0) @binding(0) var base_color_texture: texture_2d<f32>;
@group(0) @binding(1) var base_color_sampler: sampler;
@group(0) @binding(2) var normal_texture: texture_2d<f32>;
@group(0) @binding(3) var normal_sampler: sampler;
@group(0) @binding(4) var metallic_roughness_texture: texture_2d<f32>;
@group(0) @binding(5) var metallic_roughness_sampler: sampler;
@group(0) @binding(6) var<uniform> material: MaterialUniforms;`, 
                vertex_input, vertex_output, vs_main, fs_main})
                
        case .Unlit:
            vertex_input := `
struct VertexInput {
    @location(0) position: vec3<f32>,`
            
            if key.has_uv {
                vertex_input = strings.concatenate({vertex_input, `
    @location(3) uv: vec2<f32>,`})
            }
            
            if key.has_vertex_colors {
                vertex_input = strings.concatenate({vertex_input, `
    @location(4) color: vec4<f32>,`})
            }
            
            vertex_input = strings.concatenate({vertex_input, `
}`})

            vertex_output := `
struct VertexOutput {
    @builtin(position) position: vec4<f32>,`
            
            if key.has_uv {
                vertex_output = strings.concatenate({vertex_output, `
    @location(0) uv: vec2<f32>,`})
            }
            
            if key.has_vertex_colors {
                vertex_output = strings.concatenate({vertex_output, `
    @location(1) color: vec4<f32>,`})
            }
            
            vertex_output = strings.concatenate({vertex_output, `
}`})

            vs_main := `
@vertex
fn vs_main(input: VertexInput) -> VertexOutput {
    var output: VertexOutput;
    
    // TODO: Add model matrix transformation when available
    output.position = vec4<f32>(input.position, 1.0);`
            
            if key.has_uv {
                vs_main = strings.concatenate({vs_main, `
    
    output.uv = input.uv;`})
            }
            
            if key.has_vertex_colors {
                vs_main = strings.concatenate({vs_main, `
    
    output.color = input.color;`})
            }
            
            vs_main = strings.concatenate({vs_main, `
    
    return output;
}`})

            fs_main := `
@fragment
fn fs_main(input: VertexOutput) -> @location(0) vec4<f32> {
    var base_color = material.base_color_factor;`
            
            if key.has_uv {
                fs_main = strings.concatenate({fs_main, `
    
    // Sample base color texture if UVs are available
    let tex_color = textureSample(base_color_texture, base_color_sampler, input.uv);
    base_color = base_color * tex_color;`})
            }
            
            if key.has_vertex_colors {
                fs_main = strings.concatenate({fs_main, `
    
    // Multiply with vertex colors if available
    base_color = base_color * input.color;`})
            }
            
            fs_main = strings.concatenate({fs_main, `
    
    return base_color;
}`})

            return strings.concatenate({`
struct MaterialUniforms {
    base_color_factor: vec4<f32>,
    alpha_cutoff: f32,
}

@group(0) @binding(0) var base_color_texture: texture_2d<f32>;
@group(0) @binding(1) var base_color_sampler: sampler;
@group(0) @binding(2) var<uniform> material: MaterialUniforms;`, 
                vertex_input, vertex_output, vs_main, fs_main})
                
        case .Toon:
            vertex_input := `
struct VertexInput {
    @location(0) position: vec3<f32>,`
            
            if key.has_normals {
                vertex_input = strings.concatenate({vertex_input, `
    @location(1) normal: vec3<f32>,`})
            }
            
            if key.has_uv {
                vertex_input = strings.concatenate({vertex_input, `
    @location(3) uv: vec2<f32>,`})
            }
            
            if key.has_vertex_colors {
                vertex_input = strings.concatenate({vertex_input, `
    @location(4) color: vec4<f32>,`})
            }
            
            vertex_input = strings.concatenate({vertex_input, `
}`})

            vertex_output := `
struct VertexOutput {
    @builtin(position) position: vec4<f32>,`
            
            if key.has_normals {
                vertex_output = strings.concatenate({vertex_output, `
    @location(0) normal: vec3<f32>,`})
            }
            
            if key.has_uv {
                vertex_output = strings.concatenate({vertex_output, `
    @location(1) uv: vec2<f32>,`})
            }
            
            if key.has_vertex_colors {
                vertex_output = strings.concatenate({vertex_output, `
    @location(2) color: vec4<f32>,`})
            }
            
            vertex_output = strings.concatenate({vertex_output, `
    @location(3) world_pos: vec3<f32>,
}`})

            vs_main := `
@vertex
fn vs_main(input: VertexInput) -> VertexOutput {
    var output: VertexOutput;
    
    // TODO: Add model matrix transformation when available
    output.position = vec4<f32>(input.position, 1.0);
    output.world_pos = input.position;`
            
            if key.has_normals {
                vs_main = strings.concatenate({vs_main, `
    
    output.normal = input.normal;`})
            }
            
            if key.has_uv {
                vs_main = strings.concatenate({vs_main, `
    
    output.uv = input.uv;`})
            }
            
            if key.has_vertex_colors {
                vs_main = strings.concatenate({vs_main, `
    
    output.color = input.color;`})
            }
            
            vs_main = strings.concatenate({vs_main, `
    
    return output;
}`})

            fs_main := `
@fragment
fn fs_main(input: VertexOutput) -> @location(0) vec4<f32> {
    var base_color = material.base_color_factor;`
            
            if key.has_uv {
                fs_main = strings.concatenate({fs_main, `
    
    // Sample base color texture if UVs are available
    let tex_color = textureSample(base_color_texture, base_color_sampler, input.uv);
    base_color = base_color * tex_color;`})
            }
            
            if key.has_vertex_colors {
                fs_main = strings.concatenate({fs_main, `
    
    // Multiply with vertex colors if available
    base_color = base_color * input.color;`})
            }
            
            if key.has_normals {
                fs_main = strings.concatenate({fs_main, `
    
    // Toon shading with stepped lighting
    let normal = normalize(input.normal);
    let light_dir = normalize(vec3<f32>(1.0, 1.0, 1.0));
    let n_dot_l = dot(normal, light_dir);
    
    // Quantize the lighting into steps
    let steps = max(2.0, material.toon_steps);
    let toon_diffuse = floor(n_dot_l * steps) / steps;
    
    // Apply the toon lighting
    let final_color = base_color.rgb * mix(0.2, 1.0, toon_diffuse);
    
    // Simple rim lighting
    let view_dir = normalize(vec3<f32>(0.0, 0.0, 1.0) - input.world_pos);
    let rim = 1.0 - max(dot(view_dir, normal), 0.0);
    let rim_power = pow(rim, 4.0);
    let rim_color = vec3<f32>(1.0);
    
    return vec4<f32>(final_color + rim_power * rim_color * 0.3, base_color.a);`})
            } else {
                fs_main = strings.concatenate({fs_main, `
    
    // Without normals, just return the base color
    return base_color;`})
            }
            
            fs_main = strings.concatenate({fs_main, `
}`})

            return strings.concatenate({`
struct MaterialUniforms {
    base_color_factor: vec4<f32>,
    toon_steps: f32,  // Number of shading steps
    outline_thickness: f32,
    alpha_cutoff: f32,
}

@group(0) @binding(0) var base_color_texture: texture_2d<f32>;
@group(0) @binding(1) var base_color_sampler: sampler;
@group(0) @binding(2) var<uniform> material: MaterialUniforms;`, 
                vertex_input, vertex_output, vs_main, fs_main})
                
        case .Wireframe:
            vertex_input := `
struct VertexInput {
    @location(0) position: vec3<f32>,`
            
            if key.has_vertex_colors {
                vertex_input = strings.concatenate({vertex_input, `
    @location(4) color: vec4<f32>,`})
            }
            
            vertex_input = strings.concatenate({vertex_input, `
}`})

            vertex_output := `
struct VertexOutput {
    @builtin(position) position: vec4<f32>,`
            
            if key.has_vertex_colors {
                vertex_output = strings.concatenate({vertex_output, `
    @location(0) color: vec4<f32>,`})
            }
            
            vertex_output = strings.concatenate({vertex_output, `
    @location(1) barycentric: vec3<f32>,
}`})

            vs_main := `
@vertex
fn vs_main(input: VertexInput, @builtin(vertex_index) vertex_index: u32) -> VertexOutput {
    var output: VertexOutput;
    
    // TODO: Add model matrix transformation when available
    output.position = vec4<f32>(input.position, 1.0);
    
    // Compute barycentric coordinates for wireframe rendering
    // This assigns (1,0,0), (0,1,0), and (0,0,1) to the vertices of each triangle
    let triangle_index = vertex_index / 3u;
    let vertex_in_triangle = vertex_index % 3u;
    
    if (vertex_in_triangle == 0u) {
        output.barycentric = vec3<f32>(1.0, 0.0, 0.0);
    } else if (vertex_in_triangle == 1u) {
        output.barycentric = vec3<f32>(0.0, 1.0, 0.0);
    } else {
        output.barycentric = vec3<f32>(0.0, 0.0, 1.0);
    }`
            
            if key.has_vertex_colors {
                vs_main = strings.concatenate({vs_main, `
    
    output.color = input.color;`})
            }
            
            vs_main = strings.concatenate({vs_main, `
    
    return output;
}`})

            fs_main := `
@fragment
fn fs_main(input: VertexOutput) -> @location(0) vec4<f32> {
    // Calculate distance to the closest edge using barycentric coordinates
    let deltas = fwidth(input.barycentric);
    let smoothing = deltas * 1.0;
    let thickness = material.wire_thickness;
    
    // Calculate how far we are from an edge
    let edge_factor = smoothstep(vec3<f32>(0.0), smoothing * thickness, input.barycentric);
    let wire = 1.0 - min(min(edge_factor.x, edge_factor.y), edge_factor.z);
    
    // Wire color
    var color = material.wire_color;`
            
            if key.has_vertex_colors {
                fs_main = strings.concatenate({fs_main, `
    
    // Combine with vertex colors if available
    color = color * input.color;`})
            }
            
            fs_main = strings.concatenate({fs_main, `
    
    // Make interior transparent
    color.a = color.a * wire;
    
    return color;
}`})

            return strings.concatenate({`
struct MaterialUniforms {
    wire_color: vec4<f32>,
    wire_thickness: f32,
}

@group(0) @binding(0) var<uniform> material: MaterialUniforms;`, 
                vertex_input, vertex_output, vs_main, fs_main})
                
        case .Custom:
            vertex_input := `
// Custom shader - this is a placeholder that can be replaced with user-defined shaders
struct VertexInput {
    @location(0) position: vec3<f32>,`
            
            if key.has_normals {
                vertex_input = strings.concatenate({vertex_input, `
    @location(1) normal: vec3<f32>,`})
            }
            
            if key.has_tangents {
                vertex_input = strings.concatenate({vertex_input, `
    @location(2) tangent: vec4<f32>,`})
            }
            
            if key.has_uv {
                vertex_input = strings.concatenate({vertex_input, `
    @location(3) uv: vec2<f32>,`})
            }
            
            if key.has_vertex_colors {
                vertex_input = strings.concatenate({vertex_input, `
    @location(4) color: vec4<f32>,`})
            }
            
            vertex_input = strings.concatenate({vertex_input, `
}`})

            vertex_output := `
struct VertexOutput {
    @builtin(position) position: vec4<f32>,`
            
            if key.has_normals {
                vertex_output = strings.concatenate({vertex_output, `
    @location(0) normal: vec3<f32>,`})
            }
            
            if key.has_uv {
                vertex_output = strings.concatenate({vertex_output, `
    @location(1) uv: vec2<f32>,`})
            }
            
            if key.has_vertex_colors {
                vertex_output = strings.concatenate({vertex_output, `
    @location(2) color: vec4<f32>,`})
            }
            
            vertex_output = strings.concatenate({vertex_output, `
    @location(3) time_var: f32,
}`})

            vs_main := `
@vertex
fn vs_main(input: VertexInput) -> VertexOutput {
    var output: VertexOutput;
    
    // Custom animation or transformation could go here
    output.position = vec4<f32>(input.position, 1.0);`
            
            if key.has_normals {
                vs_main = strings.concatenate({vs_main, `
    
    output.normal = input.normal;`})
            }
            
            if key.has_uv {
                vs_main = strings.concatenate({vs_main, `
    
    output.uv = input.uv;`})
            }
            
            if key.has_vertex_colors {
                vs_main = strings.concatenate({vs_main, `
    
    output.color = input.color;`})
            }
            
            vs_main = strings.concatenate({vs_main, `
    
    // Example time variable passed to fragment shader
    output.time_var = 0.0; // Would be replaced with actual time
    
    return output;
}`})

            fs_main := `
@fragment
fn fs_main(input: VertexOutput) -> @location(0) vec4<f32> {
    var color = vec4<f32>(1.0, 0.5, 0.2, 1.0); // Default color`
            
            if key.has_uv {
                fs_main = strings.concatenate({fs_main, `
    
    // Example procedural pattern using UVs
    let pattern = sin(input.uv.x * 10.0) * sin(input.uv.y * 10.0) * 0.5 + 0.5;
    color = vec4<f32>(pattern, pattern * 0.5, 1.0 - pattern, 1.0);`})
            }
            
            if key.has_vertex_colors {
                fs_main = strings.concatenate({fs_main, `
    
    // Multiply with vertex colors if available
    color = color * input.color;`})
            }
            
            fs_main = strings.concatenate({fs_main, `
    
    // Animate with time
    color = color * (0.8 + 0.2 * sin(input.time_var));
    
    return color;
}`})

            return strings.concatenate({vertex_input, vertex_output, vs_main, fs_main})
                
        case:
            // Default fallback shader
            return `
struct VertexInput {
    @location(0) position: vec3<f32>,
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
}

@vertex
fn vs_main(input: VertexInput) -> VertexOutput {
    var output: VertexOutput;
    output.position = vec4<f32>(input.position, 1.0);
    return output;
}

@fragment
fn fs_main(input: VertexOutput) -> @location(0) vec4<f32> {
    // Checkerboard pattern as fallback
    let checkerSize = 8.0;
    let pos = vec2<u32>(u32(input.position.x) / u32(checkerSize), u32(input.position.y) / u32(checkerSize));
    let isEven = (pos.x + pos.y) % 2u == 0u;
    
    if (isEven) {
        return vec4<f32>(1.0, 0.0, 1.0, 1.0); // Magenta for errors
    } else {
        return vec4<f32>(0.0, 0.0, 0.0, 1.0); // Black
    }
}
`
    }
}

get_vertex_attributes :: proc(key: PipelineKey) -> [dynamic]wgpu.VertexAttribute {
    attributes := make([dynamic]wgpu.VertexAttribute)
    offset := u64(0)
    
    // Position is always included
    append(&attributes, wgpu.VertexAttribute{
        format = .Float32x3,
        offset = offset,
        shaderLocation = 0,
    })
    offset += size_of(f32) * 3
    
    // Normal vectors
    if key.has_normals {
        append(&attributes, wgpu.VertexAttribute{
            format = .Float32x3,
            offset = offset,
            shaderLocation = 1,
        })
        offset += size_of(f32) * 3
    }
    
    // Tangent vectors
    if key.has_tangents {
        append(&attributes, wgpu.VertexAttribute{
            format = .Float32x4,
            offset = offset,
            shaderLocation = 2,
        })
        offset += size_of(f32) * 4
    }
    
    // Texture coordinates
    if key.has_uv {
        append(&attributes, wgpu.VertexAttribute{
            format = .Float32x2,
            offset = offset,
            shaderLocation = 3,
        })
        offset += size_of(f32) * 2
    }
    
    // Vertex colors
    if key.has_vertex_colors {
        append(&attributes, wgpu.VertexAttribute{
            format = .Float32x4,
            offset = offset,
            shaderLocation = 4,
        })
        offset += size_of(f32) * 4
    }
    
    // Skeletal animation - joints
    if key.has_joints {
        append(&attributes, wgpu.VertexAttribute{
            format = .Uint16x4,
            offset = offset,
            shaderLocation = 5,
        })
        offset += size_of(u16) * 4
    }
    
    // Skeletal animation - weights
    if key.has_weights {
        append(&attributes, wgpu.VertexAttribute{
            format = .Float32x4,
            offset = offset,
            shaderLocation = 6,
        })
        offset += size_of(f32) * 4
    }
    
    return attributes
}

get_blend_state :: proc(alpha_mode: AlphaMode) -> wgpu.BlendState {
    // Static blend states for different alpha modes
    opaque_blend := wgpu.BlendState{
        color = {
            operation = .Add,
            srcFactor = .One,
            dstFactor = .Zero,
        },
        alpha = {
            operation = .Add,
            srcFactor = .One,
            dstFactor = .Zero,
        },
    }
    
    blend_blend := wgpu.BlendState{
        color = {
            operation = .Add,
            srcFactor = .SrcAlpha,
            dstFactor = .OneMinusSrcAlpha,
        },
        alpha = {
            operation = .Add,
            srcFactor = .One,
            dstFactor = .OneMinusSrcAlpha,
        },
    }
    
    mask_blend := wgpu.BlendState{
        color = {
            operation = .Add,
            srcFactor = .One,
            dstFactor = .Zero,
        },
        alpha = {
            operation = .Add,
            srcFactor = .One,
            dstFactor = .Zero,
        },
    }
    
    // Return appropriate blend state based on alpha mode
    switch alpha_mode {
        case .Opaque:
            return opaque_blend
        case .Mask:
            return mask_blend
        case .Blend:
            return blend_blend
        case:
            return opaque_blend  // Default to opaque
    }
}
