package gltf

import "core:log"
import "core:strings"
import "core:os"
import "core:path/filepath"
import "core:mem"
import "core:slice"
import m "pkg:core/math"
import "vendor:cgltf"

Error :: enum {
    None,
    Failed_To_Parse_File,
    Failed_To_Load_Buffers,
    Failed_To_Validate,
    Failed_To_Open_File,
    Invalid_File_Path,
}

Node :: struct {
    name: string,
    local_transform: m.Mat4,
    world_transform: m.Mat4,
    mesh_index: int,
    children: [dynamic]^Node,
    parent: ^Node,
    skin_index: int,
    has_light: bool,
    light_index: int,
}

Primitive :: struct {
    material_index: int,
    indices: []u32,
    positions: []m.Vec3,
    normals: []m.Vec3,
    tangents: []m.Vec4,
    texcoords0: []m.Vec2,
    texcoords1: []m.Vec2,
    colors: []m.Vec3,
    joints: []m.Vec4,
    weights: []m.Vec4,
}

Mesh :: struct {
    name: string,
    primitives: [dynamic]Primitive,
}

PBR_Material :: struct {
    name: string,
    base_color_factor: [4]f32,
    metallic_factor: f32,
    roughness_factor: f32,
    emissive_factor: [3]f32,
    alpha_mode: cgltf.alpha_mode,
    alpha_cutoff: f32,
    double_sided: bool,
    base_color_texture_index: int,
    metallic_roughness_texture_index: int,
    normal_texture_index: int,
    occlusion_texture_index: int,
    emissive_texture_index: int,
}

Image :: struct {
    name: string,
    uri: string,
    mime_type: string,
    buffer_view_index: int,
    data: []byte,
}

Texture :: struct {
    name: string,
    image_index: int,
    sampler_index: int,
}

Sampler :: struct {
    name: string,
    mag_filter: i32,
    min_filter: i32,
    wrap_s: i32,
    wrap_t: i32,
}

Light_Type :: enum {
    Directional,
    Point,
    Spot,
}

Light :: struct {
    name: string,
    type: Light_Type,
    color: [3]f32,
    intensity: f32,
    range: f32,
    spot_inner_cone_angle: f32,
    spot_outer_cone_angle: f32,
}

Animation_Channel_Path :: enum {
    Translation,
    Rotation,
    Scale,
    Weights,
}

Animation_Interpolation :: enum {
    Linear,
    Step,
    Cubic_Spline,
}

Animation_Sampler :: struct {
    interpolation: Animation_Interpolation,
    input_times: []f32,
    output_values: []f32,
    components_per_value: int,
}

Animation_Channel :: struct {
    node_index: int,
    path: Animation_Channel_Path,
    sampler_index: int,
}

Animation :: struct {
    name: string,
    samplers: [dynamic]Animation_Sampler,
    channels: [dynamic]Animation_Channel,
}

Skin :: struct {
    name: string,
    joints: []int,
    skeleton_root_index: int,
    inverse_bind_matrices: []m.Mat4,
}

Scene :: struct {
    name: string,
    node_indices: []int,
}

Model :: struct {
    nodes: [dynamic]Node,
    meshes: [dynamic]Mesh,
    materials: [dynamic]PBR_Material,
    textures: [dynamic]Texture,
    images: [dynamic]Image,
    samplers: [dynamic]Sampler,
    animations: [dynamic]Animation,
    skins: [dynamic]Skin,
    lights: [dynamic]Light,
    scenes: [dynamic]Scene,
    default_scene_index: int,
}

// Load a GLTF model from file
load :: proc(file_path: string) -> (model: Model, error: Error) {
    if file_path == "" {
        return model, .Invalid_File_Path
    }
    
    options := cgltf.options{
        type = .invalid, // Auto-detect
    }
    
    data: ^cgltf.data
    result: cgltf.result
    
    data, result = cgltf.parse_file(options, strings.clone_to_cstring(file_path, context.temp_allocator))
    if result != .success {
        log.error("Failed to parse GLTF file:", file_path, "with error:", result)
        return model, .Failed_To_Parse_File
    }
    defer cgltf.free(data)
    
    dir_path := filepath.dir(file_path, context.temp_allocator)
    
    // Load external buffers
    if result := cgltf.load_buffers(options, data, strings.clone_to_cstring(dir_path, context.temp_allocator));
       result != .success {
        log.error("Failed to load GLTF buffers with error:", result)
        return model, .Failed_To_Load_Buffers
    }
    
    // Validate the model
    if result := cgltf.validate(data); result != .success {
        log.error("Failed to validate GLTF model with error:", result)
        return model, .Failed_To_Validate
    }
    
    // Parse all data
    parse_model(data, &model)
    
    return model, .None
}

parse_model :: proc(data: ^cgltf.data, model: ^Model) {
    // Initialize the model
    model^ = {}
    
    // Process scenes
    process_scenes(data, model)
    
    // Process samplers
    process_samplers(data, model)
    
    // Process images
    process_images(data, model)
    
    // Process textures
    process_textures(data, model)
    
    // Process materials
    process_materials(data, model)
    
    // Process meshes
    process_meshes(data, model)
    
    // Process lights (KHR_lights_punctual extension)
    process_lights(data, model)
    
    // Process skins
    process_skins(data, model)
    
    // Process nodes and build hierarchy
    process_nodes(data, model)
    
    // Process animations
    process_animations(data, model)
    
    // Set default scene
    model.default_scene_index = int(cgltf.scene_index(data, data.scene)) if data.scene != nil else 0
}

process_scenes :: proc(data: ^cgltf.data, model: ^Model) {
    if len(data.scenes) == 0 {
        return
    }
    
    resize(&model.scenes, len(data.scenes))
    
    for i in 0..<len(data.scenes) {
        scene := &model.scenes[i]
        cgltf_scene := &data.scenes[i]
        
        scene.name = strings.clone(string(cgltf_scene.name) if cgltf_scene.name != nil else "")
        
        if len(cgltf_scene.nodes) > 0 {
            scene.node_indices = make([]int, len(cgltf_scene.nodes))
            for j in 0..<len(cgltf_scene.nodes) {
                scene.node_indices[j] = int(cgltf.node_index(data, cgltf_scene.nodes[j]))
            }
        }
    }
}

process_samplers :: proc(data: ^cgltf.data, model: ^Model) {
    if len(data.samplers) == 0 {
        return
    }
    
    resize(&model.samplers, len(data.samplers))
    
    for i in 0..<len(data.samplers) {
        sampler := &model.samplers[i]
        cgltf_sampler := &data.samplers[i]
        
        sampler.name = strings.clone(string(cgltf_sampler.name) if cgltf_sampler.name != nil else "")
        sampler.mag_filter = cgltf_sampler.mag_filter
        sampler.min_filter = cgltf_sampler.min_filter
        sampler.wrap_s = cgltf_sampler.wrap_s
        sampler.wrap_t = cgltf_sampler.wrap_t
    }
}

process_images :: proc(data: ^cgltf.data, model: ^Model) {
    if len(data.images) == 0 {
        return
    }
    
    resize(&model.images, len(data.images))
    
    for i in 0..<len(data.images) {
        image := &model.images[i]
        cgltf_image := &data.images[i]
        
        image.name = strings.clone(string(cgltf_image.name) if cgltf_image.name != nil else "")
        image.uri = strings.clone(string(cgltf_image.uri) if cgltf_image.uri != nil else "")
        image.mime_type = strings.clone(string(cgltf_image.mime_type) if cgltf_image.mime_type != nil else "")
        
        if cgltf_image.buffer_view != nil {
            image.buffer_view_index = int(cgltf.buffer_view_index(data, cgltf_image.buffer_view))
            
            // Extract data from buffer view
            buffer_view := cgltf_image.buffer_view
            buffer_data := cgltf.buffer_view_data(buffer_view)
            if buffer_data != nil {
                image.data = make([]byte, buffer_view.size)
                mem.copy(&image.data[0], buffer_data, int(buffer_view.size))
            }
        }
    }
}

process_textures :: proc(data: ^cgltf.data, model: ^Model) {
    if len(data.textures) == 0 {
        return
    }
    
    resize(&model.textures, len(data.textures))
    
    for i in 0..<len(data.textures) {
        texture := &model.textures[i]
        cgltf_texture := &data.textures[i]
        
        texture.name = strings.clone(string(cgltf_texture.name) if cgltf_texture.name != nil else "")
        texture.image_index = int(cgltf.image_index(data, cgltf_texture.image_)) if cgltf_texture.image_ != nil else -1
        texture.sampler_index = int(cgltf.sampler_index(data, cgltf_texture.sampler)) if cgltf_texture.sampler != nil else -1
    }
}

process_materials :: proc(data: ^cgltf.data, model: ^Model) {
    if len(data.materials) == 0 {
        return
    }
    
    resize(&model.materials, len(data.materials))
    
    for i in 0..<len(data.materials) {
        material := &model.materials[i]
        cgltf_material := &data.materials[i]
        
        material.name = strings.clone(string(cgltf_material.name) if cgltf_material.name != nil else "")
        material.alpha_mode = cgltf_material.alpha_mode
        material.alpha_cutoff = cgltf_material.alpha_cutoff
        material.double_sided = bool(cgltf_material.double_sided)
        
        // Copy emissive factor
        copy(material.emissive_factor[:], cgltf_material.emissive_factor[:])
        
        // Process PBR material properties
        if cgltf_material.has_pbr_metallic_roughness {
            pbr := &cgltf_material.pbr_metallic_roughness
            
            // Copy base color factor
            copy(material.base_color_factor[:], pbr.base_color_factor[:])
            
            material.metallic_factor = pbr.metallic_factor
            material.roughness_factor = pbr.roughness_factor
            
            // Get texture indices
            material.base_color_texture_index = int(cgltf.texture_index(data, pbr.base_color_texture.texture)) if pbr.base_color_texture.texture != nil else -1
            
            material.metallic_roughness_texture_index = int(cgltf.texture_index(data, pbr.metallic_roughness_texture.texture)) if pbr.metallic_roughness_texture.texture != nil else -1
        } else {
            // Default values if no PBR info
            material.base_color_factor = {1, 1, 1, 1}
            material.metallic_factor = 1
            material.roughness_factor = 1
            material.base_color_texture_index = -1
            material.metallic_roughness_texture_index = -1
        }
        
        // Get other texture indices
        material.normal_texture_index = int(cgltf.texture_index(data, cgltf_material.normal_texture.texture)) if cgltf_material.normal_texture.texture != nil else -1
        
        material.occlusion_texture_index = int(cgltf.texture_index(data, cgltf_material.occlusion_texture.texture)) if cgltf_material.occlusion_texture.texture != nil else -1
        
        material.emissive_texture_index = int(cgltf.texture_index(data, cgltf_material.emissive_texture.texture)) if cgltf_material.emissive_texture.texture != nil else -1
    }
}

process_attribute_data :: proc(data: ^cgltf.data, accessor: ^cgltf.accessor, out_data: rawptr, component_count: int) -> bool {
    if accessor == nil {
        return false
    }
    
    element_count := int(accessor.count)
    float_count := element_count * component_count
    
    if accessor.component_type == .r_32f && accessor.type == .vec3 && component_count == 3 {
        _ = cgltf.accessor_unpack_floats(accessor, cast([^]f32)out_data, uint(float_count))
        return true
    } else {
        // General case - unpack floats and then copy to destination
        temp_data := make([]f32, float_count, context.temp_allocator)
        unpacked := cgltf.accessor_unpack_floats(accessor, &temp_data[0], uint(float_count))
        
        if unpacked > 0 {
            mem.copy(out_data, &temp_data[0], int(unpacked) * size_of(f32))
            return true
        }
    }
    
    return false
}

unpack_indices :: proc(data: ^cgltf.data, accessor: ^cgltf.accessor) -> []u32 {
    if accessor == nil {
        return nil
    }
    
    count := int(accessor.count)
    indices := make([]u32, count)
    
    component_size := size_of(u32)
    _ = cgltf.accessor_unpack_indices(accessor, &indices[0], uint(component_size), uint(count))
    
    return indices
}

process_primitive :: proc(data: ^cgltf.data, cgltf_primitive: ^cgltf.primitive, primitive: ^Primitive) {
    // Get material index
    primitive.material_index = int(cgltf.material_index(data, cgltf_primitive.material)) if cgltf_primitive.material != nil else -1
    
    // Process indices
    primitive.indices = unpack_indices(data, cgltf_primitive.indices)
    
    // Process vertex attributes
    for i in 0..<len(cgltf_primitive.attributes){
        attribute := &cgltf_primitive.attributes[i]
        accessor := attribute.data
        
        if accessor == nil {
            continue
        }
        
        attribute_type := attribute.type
        vertex_count := int(accessor.count)
        
        #partial switch attribute_type {
            case .position:
                primitive.positions = make([]m.Vec3, vertex_count)
                process_attribute_data(data, accessor, &primitive.positions[0], 3)
                
            case .normal:
                primitive.normals = make([]m.Vec3, vertex_count)
                process_attribute_data(data, accessor, &primitive.normals[0], 3)
                
            case .tangent:
                primitive.tangents = make([]m.Vec4, vertex_count)
                process_attribute_data(data, accessor, &primitive.tangents[0], 4)
                
            case .texcoord:
                if attribute.index == 0 {
                    primitive.texcoords0 = make([]m.Vec2, vertex_count)
                    process_attribute_data(data, accessor, &primitive.texcoords0[0], 2)
                } else if attribute.index == 1 {
                    primitive.texcoords1 = make([]m.Vec2, vertex_count)
                    process_attribute_data(data, accessor, &primitive.texcoords1[0], 2)
                }
                
            case .color:
                primitive.colors = make([]m.Vec3, vertex_count)
                process_attribute_data(data, accessor, &primitive.colors[0], 3)
                
            case .joints:
                primitive.joints = make([]m.Vec4, vertex_count)
                process_attribute_data(data, accessor, &primitive.joints[0], 4)
                
            case .weights:
                primitive.weights = make([]m.Vec4, vertex_count)
                process_attribute_data(data, accessor, &primitive.weights[0], 4)
        }
    }
}

process_meshes :: proc(data: ^cgltf.data, model: ^Model) {
    if len(data.meshes) == 0 {
        return
    }
    
    resize(&model.meshes, len(data.meshes))
    
    for i in 0..<len(data.meshes) {
        mesh := &model.meshes[i]
        cgltf_mesh := &data.meshes[i]
        
        mesh.name = strings.clone(string(cgltf_mesh.name) if cgltf_mesh.name != nil else "")
        
        // Process primitives
        if len(cgltf_mesh.primitives) > 0 {
            resize(&mesh.primitives, len(cgltf_mesh.primitives))
            
            for j in 0..<len(cgltf_mesh.primitives) {
                primitive := &mesh.primitives[j]
                cgltf_primitive := &cgltf_mesh.primitives[j]
                
                process_primitive(data, cgltf_primitive, primitive)
            }
        }
    }
}

process_lights :: proc(data: ^cgltf.data, model: ^Model) {
    // Check for KHR_lights_punctual extension
    has_lights_extension := false
    
    for i in 0..<len(data.extensions_used) {
        if data.extensions_used[i] != nil && 
           strings.compare(string(data.extensions_used[i]), "KHR_lights_punctual") == 0 {
            has_lights_extension = true
            break
        }
    }
    
    if !has_lights_extension || len(data.lights) == 0 {
        return
    }
    
    resize(&model.lights, len(data.lights))
    
    for i in 0..<len(data.lights) {
        light := &model.lights[i]
        cgltf_light := &data.lights[i]
        
        light.name = strings.clone(string(cgltf_light.name) if cgltf_light.name != nil else "")
        
        // Copy light properties
        light.intensity = cgltf_light.intensity
        copy(light.color[:], cgltf_light.color[:])
        
        #partial switch cgltf_light.type {
            case .directional:
                light.type = .Directional
                light.range = 0 // Infinite range for directional lights
                
            case .point:
                light.type = .Point
                light.range = cgltf_light.range
                
            case .spot:
                light.type = .Spot
                light.range = cgltf_light.range
                light.spot_inner_cone_angle = cgltf_light.spot_inner_cone_angle
                light.spot_outer_cone_angle = cgltf_light.spot_outer_cone_angle
        }
    }
}

process_skins :: proc(data: ^cgltf.data, model: ^Model) {
    if len(data.skins) == 0 {
        return
    }
    
    resize(&model.skins, len(data.skins))
    
    for i in 0..<len(data.skins) {
        skin := &model.skins[i]
        cgltf_skin := &data.skins[i]
        
        skin.name = strings.clone(string(cgltf_skin.name) if cgltf_skin.name != nil else "")
        
        // Get joints
        if len(cgltf_skin.joints) > 0 {
            skin.joints = make([]int, len(cgltf_skin.joints))
            
            for j in 0..<len(cgltf_skin.joints) {
                skin.joints[j] = int(cgltf.node_index(data, cgltf_skin.joints[j]))
            }
        }
        
        // Get skeleton root
        skin.skeleton_root_index = int(cgltf.node_index(data, cgltf_skin.skeleton)) if cgltf_skin.skeleton != nil else -1
        
        // Get inverse bind matrices
        if cgltf_skin.inverse_bind_matrices != nil {
            accessor := cgltf_skin.inverse_bind_matrices
            matrices_count := int(accessor.count)
            
            skin.inverse_bind_matrices = make([]m.Mat4, matrices_count)
            
            for j in 0..<matrices_count {
                mat: [16]f32
                _ = cgltf.accessor_read_float(accessor, uint(j), &mat[0], 16)
                
                // Copy to our matrix format
                skin.inverse_bind_matrices[j] = transmute(m.Mat4)mat
            }
        }
    }
}

process_node_transform :: proc(cgltf_node: ^cgltf.node, node: ^Node) {
    local_matrix: [16]f32
    cgltf.node_transform_local(cgltf_node, &local_matrix[0])
    
    // Copy to our matrix format
    node.local_transform = transmute(m.Mat4)local_matrix
    
    world_matrix: [16]f32
    cgltf.node_transform_world(cgltf_node, &world_matrix[0])
    
    // Copy to our matrix format
    node.world_transform = transmute(m.Mat4)world_matrix
}

process_nodes :: proc(data: ^cgltf.data, model: ^Model) {
    if len(data.nodes) == 0 {
        return
    }
    
    resize(&model.nodes, len(data.nodes))
    
    // First pass: create nodes and set basic properties
    for i in 0..<len(data.nodes) {
        node := &model.nodes[i]
        cgltf_node := &data.nodes[i]
        
        node.name = strings.clone(string(cgltf_node.name) if cgltf_node.name != nil else "")
        
        // Process transform
        process_node_transform(cgltf_node, node)
        
        // Get mesh index
        node.mesh_index = int(cgltf.mesh_index(data, cgltf_node.mesh)) if cgltf_node.mesh != nil else -1
        
        // Get skin index
        node.skin_index = int(cgltf.skin_index(data, cgltf_node.skin)) if cgltf_node.skin != nil else -1
        
        // Check for light (KHR_lights_punctual extension)
        node.has_light = cgltf_node.light != nil
        node.light_index = int(cgltf.light_index(data, cgltf_node.light)) if cgltf_node.light != nil else -1
        
        // Initialize children array
        if len(cgltf_node.children) > 0 {
            reserve(&node.children, len(cgltf_node.children))
        }
    }
    
    // Second pass: build hierarchy
    for i in 0..<len(data.nodes) {
        node := &model.nodes[i]
        cgltf_node := &data.nodes[i]
        
        // Add children
        for j in 0..<len(cgltf_node.children) {
            child_index := int(cgltf.node_index(data, cgltf_node.children[j]))
            child := &model.nodes[child_index]
            
            append(&node.children, child)
            
            // Set parent
            child.parent = node
        }
    }
}

process_animations :: proc(data: ^cgltf.data, model: ^Model) {
    if len(data.animations) == 0 {
        return
    }
    
    resize(&model.animations, len(data.animations))
    
    for i in 0..<len(data.animations) {
        animation := &model.animations[i]
        cgltf_animation := &data.animations[i]
        
        animation.name = strings.clone(string(cgltf_animation.name) if cgltf_animation.name != nil else "")
        
        // Process samplers
        if len(cgltf_animation.samplers) > 0 {
            resize(&animation.samplers, len(cgltf_animation.samplers))
            
            for j in 0..<len(cgltf_animation.samplers) {
                sampler := &animation.samplers[j]
                cgltf_sampler := &cgltf_animation.samplers[j]
                
                // Set interpolation type
                #partial switch cgltf_sampler.interpolation {
                    case .linear:
                        sampler.interpolation = .Linear
                    case .step:
                        sampler.interpolation = .Step
                    case .cubic_spline:
                        sampler.interpolation = .Cubic_Spline
                }
                
                // Get input times
                if cgltf_sampler.input != nil {
                    input_accessor := cgltf_sampler.input
                    times_count := int(input_accessor.count)
                    
                    sampler.input_times = make([]f32, times_count)
                    _ = cgltf.accessor_unpack_floats(input_accessor, &sampler.input_times[0], uint(times_count))

                }
                
                // Get output values
                if cgltf_sampler.output != nil {
                    output_accessor := cgltf_sampler.output
                    
                    components_per_value := int(cgltf.num_components(output_accessor.type))
                    values_count := int(output_accessor.count) * components_per_value
                    
                    sampler.output_values = make([]f32, values_count)
                    _ = cgltf.accessor_unpack_floats(output_accessor, &sampler.output_values[0], uint(values_count))
                    
                    sampler.components_per_value = components_per_value
                }
            }
        }
        
        // Process channels
        if len(cgltf_animation.channels) > 0 {
            resize(&animation.channels, len(cgltf_animation.channels))
            
            for j in 0..<len(cgltf_animation.channels) {
                channel := &animation.channels[j]
                cgltf_channel := &cgltf_animation.channels[j]
                
                // Get target node
                channel.node_index = int(cgltf.node_index(data, cgltf_channel.target_node)) if cgltf_channel.target_node != nil else -1
                
                // Get sampler index
                channel.sampler_index = int(cgltf.animation_sampler_index(cgltf_animation, cgltf_channel.sampler)) if cgltf_channel.sampler != nil else -1
                
                // Set path type
                #partial switch cgltf_channel.target_path {
                    case .translation:
                        channel.path = .Translation
                    case .rotation:
                        channel.path = .Rotation
                    case .scale:
                        channel.path = .Scale
                    case .weights:
                        channel.path = .Weights
                }
            }
        }
    }
}

// Free all resources of a loaded model
free :: proc(model: ^Model) {
    // Free scenes
    for scene in &model.scenes {
        delete(scene.node_indices)
        delete(scene.name)
    }
    delete(model.scenes)
    
    // Free nodes
    for node in &model.nodes {
        delete(node.children)
        delete(node.name)
    }
    delete(model.nodes)
    
    // Free meshes
    for mesh in &model.meshes {
        for primitive in mesh.primitives {
            delete(primitive.indices)
            delete(primitive.positions)
            delete(primitive.normals)
            delete(primitive.tangents)
            delete(primitive.texcoords0)
            delete(primitive.texcoords1)
            delete(primitive.colors)
            delete(primitive.joints)
            delete(primitive.weights)
        }
        delete(mesh.primitives)
        delete(mesh.name)
    }
    delete(model.meshes)
    
    // Free materials
    for material in &model.materials {
        delete(material.name)
    }
    delete(model.materials)
    
    // Free textures
    for texture in &model.textures {
        delete(texture.name)
    }
    delete(model.textures)
    
    // Free images
    for image in &model.images {
        delete(image.name)
        delete(image.uri)
        delete(image.mime_type)
        delete(image.data)
    }
    delete(model.images)
    
    // Free samplers
    for sampler in &model.samplers {
        delete(sampler.name)
    }
    delete(model.samplers)
    
    // Free animations
    for animation in &model.animations {
        for sampler in animation.samplers {
            delete(sampler.input_times)
            delete(sampler.output_values)
        }
        delete(animation.samplers)
        delete(animation.channels)
        delete(animation.name)
    }
    delete(model.animations)
    
    // Free skins
    for skin in &model.skins {
        delete(skin.joints)
        delete(skin.inverse_bind_matrices)
        delete(skin.name)
    }
    delete(model.skins)
    
    // Free lights
    for light in &model.lights {
        delete(light.name)
    }
    delete(model.lights)
}


