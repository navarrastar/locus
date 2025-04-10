package loader

import "core:log"
import "core:path/filepath"
import "core:strings"
import "core:mem"
import "core:fmt"

import "vendor:cgltf"

import m "pkg:core/math"



// Model represents a complete GLTF model
Model :: struct {
    name: string,

    // Core asset information
    asset: Asset,
    
    // Primary data arrays
    scenes: []Scene,
    nodes: []Node,
    meshes: []Mesh,
    materials: []Material,
    textures: []Texture,
    samplers: []Sampler,
    images: []Image,
    skins: []Skin,
    cameras: []Camera,
    lights: []Light,
    animations: []Animation,
    
    // Default scene
    default_scene: ^Scene,
    
    // Raw data buffers
    buffers: []Buffer,
    buffer_views: []BufferView,
    accessors: []Accessor,
}

Asset :: struct {
    version: string,
    generator: string,
    copyright: string,
}

Scene :: struct {
    name: string,
    nodes: [dynamic]^Node,
}

Node :: struct {
    name: string,
    parent: ^Node,
    children: [dynamic]^Node,
    
    // Node can have either a matrix or TRS properties
    has_matrix: bool,
    matrix_data: m.Mat4,
    
    has_transform: bool,
    translation: m.Vec3,
    rotation: m.Quat,
    scale: m.Vec3,
    
    // Node attachments (optional)
    mesh: ^Mesh,
    skin: ^Skin,
    camera: ^Camera,
    light: ^Light,
    
    // For morph targets
    weights: []f32,
}

Mesh :: struct {
    name: string,
    primitives: [dynamic]Primitive,
    weights: []f32,
    target_names: []string,
}

Primitive :: struct {
    type: cgltf.primitive_type,
    indices: ^Accessor,
    material: ^Material,
    attributes: map[string]^Accessor,
    targets: []map[string]^Accessor, // Morph targets
}

Material :: struct {
    name: string,
    
    // PBR Metallic Roughness
    pbr_metallic_roughness: PbrMetallicRoughness,
    
    // Normal texture
    normal_texture: TextureInfo,
    normal_scale: f32,
    
    // Occlusion texture
    occlusion_texture: TextureInfo,
    occlusion_strength: f32,
    
    // Emissive properties
    emissive_texture: TextureInfo,
    emissive_factor: m.Vec3,
    
    // Alpha properties
    alpha_mode: cgltf.alpha_mode,
    alpha_cutoff: f32,
    
    // Misc properties
    double_sided: bool,
    unlit: bool,
}

PbrMetallicRoughness :: struct {
    base_color_factor: m.Vec4,
    base_color_texture: TextureInfo,
    metallic_factor: f32,
    roughness_factor: f32,
    metallic_roughness_texture: TextureInfo,
}

TextureInfo :: struct {
    texture: ^Texture,
    tex_coord: i32,
    scale: f32,
    
    // Transform
    has_transform: bool,
    offset: m.Vec2,
    rotation: f32,
    scale_transform: m.Vec2,
}

Texture :: struct {
    name: string,
    sampler: ^Sampler,
    image: ^Image,
}

Sampler :: struct {
    name: string,
    mag_filter: i32,
    min_filter: i32,
    wrap_s: i32,
    wrap_t: i32,
}

Image :: struct {
    name: string,
    uri: string,
    mime_type: string,
    buffer_view: ^BufferView,
}

Skin :: struct {
    name: string,
    joints: []^Node,
    skeleton: ^Node,
    inverse_bind_matrices: ^Accessor,
}

Camera :: struct {
    name: string,
    type: cgltf.camera_type,
    
    // Perspective camera
    aspect_ratio: f32,
    yfov: f32,
    zfar: f32,
    znear: f32,
    
    // Orthographic camera
    xmag: f32,
    ymag: f32,
}

Light :: struct {
    name: string,
    type: cgltf.light_type,
    color: m.Vec3,
    intensity: f32,
    range: f32,
    spot_inner_cone_angle: f32,
    spot_outer_cone_angle: f32,
}

Animation :: struct {
    name: string,
    channels: []AnimationChannel,
    samplers: []AnimationSampler,
}

AnimationChannel :: struct {
    sampler: ^AnimationSampler,
    target_node: ^Node,
    target_path: cgltf.animation_path_type,
}

AnimationSampler :: struct {
    input: ^Accessor,  // Time keyframes
    output: ^Accessor, // Value keyframes
    interpolation: cgltf.interpolation_type,
}

Buffer :: struct {
    name: string,
    uri: string,
    data: []byte,
    size: uint,
}

BufferView :: struct {
    name: string,
    buffer: ^Buffer,
    offset: uint,
    size: uint,
    stride: uint,
    type: cgltf.buffer_view_type,
}

Accessor :: struct {
    name: string,
    buffer_view: ^BufferView,
    offset: uint,
    count: uint,
    component_type: cgltf.component_type,
    type: cgltf.type,
    normalized: bool,
    min: [16]f32,
    max: [16]f32,
    has_min_max: bool,
}

@(require_results)
load_gltf :: proc(path: string) -> (model: Model) {
    log.info("Loading gltf:", filepath.base(path)) 
    path_cstring, err := strings.clone_to_cstring(path)
    if err != nil {
        log.error("Error cloning string to cstring", err)
        return
    }
    defer delete(path_cstring)

    options := cgltf.options{}

    data, res := cgltf.parse_file(options, path_cstring) 
    if res != .success {
        log.error("Failed to parse GLTF file", res)
        return
    }
    defer cgltf.free(data)

    // Load buffer data
    res = cgltf.load_buffers(options, data, path_cstring)
    if res != .success {
        log.error("Failed to load GLTF buffers", res)
        return
    }

    model = create_model_from_data(data)

    model.name = filepath.stem(path)

    return model
}

@(private)
create_model_from_data :: proc(data: ^cgltf.data) -> (model: Model) {
    // Load asset data
    if data.asset.version != nil {
        model.asset.version = strings.clone_from_cstring(data.asset.version)
    }
    if data.asset.generator != nil {
        model.asset.generator = strings.clone_from_cstring(data.asset.generator)
    }
    if data.asset.copyright != nil {
        model.asset.copyright = strings.clone_from_cstring(data.asset.copyright)
    }

    // Load buffers
    model.buffers = make([]Buffer, len(data.buffers))
    for i in 0..<len(data.buffers) {
        src := &data.buffers[i]
        dst := &model.buffers[i]
        
        if src.name != nil {
            dst.name = strings.clone_from_cstring(src.name)
        }
        if src.uri != nil {
            dst.uri = strings.clone_from_cstring(src.uri)
        }
        
        dst.size = src.size
        
        if src.data != nil {
            dst.data = make([]byte, src.size)
            mem.copy(&dst.data[0], src.data, int(src.size))
        }
    }
    
    // Load buffer views
    model.buffer_views = make([]BufferView, len(data.buffer_views))
    for i in 0..<len(data.buffer_views) {
        src := &data.buffer_views[i]
        dst := &model.buffer_views[i]
        
        if src.name != nil {
            dst.name = strings.clone_from_cstring(src.name)
        }
        
        if src.buffer != nil {
            buffer_index := cgltf.buffer_index(data, src.buffer)
            dst.buffer = &model.buffers[buffer_index]
        }
        
        dst.offset = src.offset
        dst.size = src.size
        dst.stride = src.stride
        dst.type = src.type
    }
    
    // Load accessors
    model.accessors = make([]Accessor, len(data.accessors))
    for i in 0..<len(data.accessors) {
        src := &data.accessors[i]
        dst := &model.accessors[i]
        
        if src.name != nil {
            dst.name = strings.clone_from_cstring(src.name)
        }
        
        if src.buffer_view != nil {
            buffer_view_index := cgltf.buffer_view_index(data, src.buffer_view)
            dst.buffer_view = &model.buffer_views[buffer_view_index]
        }
        
        dst.offset = src.offset
        dst.count = src.count
        dst.component_type = src.component_type
        dst.type = src.type
        dst.normalized = bool(src.normalized)
        
        dst.has_min_max = bool(src.has_min) && bool(src.has_max)
        if dst.has_min_max {
            for j in 0..<16 {
                dst.min[j] = src.min[j]
                dst.max[j] = src.max[j]
            }
        }
    }
    
    // Load images
    model.images = make([]Image, len(data.images))
    for i in 0..<len(data.images) {
        src := &data.images[i]
        dst := &model.images[i]
        
        if src.name != nil {
            dst.name = strings.clone_from_cstring(src.name)
        }
        if src.uri != nil {
            dst.uri = strings.clone_from_cstring(src.uri)
        }
        if src.mime_type != nil {
            dst.mime_type = strings.clone_from_cstring(src.mime_type)
        }
        
        if src.buffer_view != nil {
            buffer_view_index := cgltf.buffer_view_index(data, src.buffer_view)
            dst.buffer_view = &model.buffer_views[buffer_view_index]
        }
    }
    
    // Load samplers
    model.samplers = make([]Sampler, len(data.samplers))
    for i in 0..<len(data.samplers) {
        src := &data.samplers[i]
        dst := &model.samplers[i]
        
        if src.name != nil {
            dst.name = strings.clone_from_cstring(src.name)
        }
        
        dst.mag_filter = src.mag_filter
        dst.min_filter = src.min_filter
        dst.wrap_s = src.wrap_s
        dst.wrap_t = src.wrap_t
    }
    
    // Load textures
    model.textures = make([]Texture, len(data.textures))
    for i in 0..<len(data.textures) {
        src := &data.textures[i]
        dst := &model.textures[i]
        
        if src.name != nil {
            dst.name = strings.clone_from_cstring(src.name)
        }
        
        if src.image_ != nil {
            image_index := cgltf.image_index(data, src.image_)
            dst.image = &model.images[image_index]
        }
        
        if src.sampler != nil {
            sampler_index := cgltf.sampler_index(data, src.sampler)
            dst.sampler = &model.samplers[sampler_index]
        }
    }
    
    // Load materials
    model.materials = make([]Material, len(data.materials))
    for i in 0..<len(data.materials) {
        src := &data.materials[i]
        dst := &model.materials[i]
        
        if src.name != nil {
            dst.name = strings.clone_from_cstring(src.name)
        }
        
        if src.has_pbr_metallic_roughness {
            for j in 0..<4 {
                dst.pbr_metallic_roughness.base_color_factor[j] = src.pbr_metallic_roughness.base_color_factor[j]
            }
            
            dst.pbr_metallic_roughness.metallic_factor = src.pbr_metallic_roughness.metallic_factor
            dst.pbr_metallic_roughness.roughness_factor = src.pbr_metallic_roughness.roughness_factor
            
            // Base color texture
            if src.pbr_metallic_roughness.base_color_texture.texture != nil {
                texture_index := cgltf.texture_index(data, src.pbr_metallic_roughness.base_color_texture.texture)
                dst.pbr_metallic_roughness.base_color_texture.texture = &model.textures[texture_index]
                dst.pbr_metallic_roughness.base_color_texture.tex_coord = src.pbr_metallic_roughness.base_color_texture.texcoord
                
                // Transform
                if src.pbr_metallic_roughness.base_color_texture.has_transform {
                    transform := src.pbr_metallic_roughness.base_color_texture.transform
                    dst.pbr_metallic_roughness.base_color_texture.has_transform = true
                    dst.pbr_metallic_roughness.base_color_texture.offset = transform.offset
                    dst.pbr_metallic_roughness.base_color_texture.rotation = transform.rotation
                    dst.pbr_metallic_roughness.base_color_texture.scale_transform = transform.scale
                }
            }
            
            // Metallic roughness texture
            if src.pbr_metallic_roughness.metallic_roughness_texture.texture != nil {
                texture_index := cgltf.texture_index(data, src.pbr_metallic_roughness.metallic_roughness_texture.texture)
                dst.pbr_metallic_roughness.metallic_roughness_texture.texture = &model.textures[texture_index]
                dst.pbr_metallic_roughness.metallic_roughness_texture.tex_coord = src.pbr_metallic_roughness.metallic_roughness_texture.texcoord
                
                // Transform
                if src.pbr_metallic_roughness.metallic_roughness_texture.has_transform {
                    transform := src.pbr_metallic_roughness.metallic_roughness_texture.transform
                    dst.pbr_metallic_roughness.metallic_roughness_texture.has_transform = true
                    dst.pbr_metallic_roughness.metallic_roughness_texture.offset = transform.offset
                    dst.pbr_metallic_roughness.metallic_roughness_texture.rotation = transform.rotation
                    dst.pbr_metallic_roughness.metallic_roughness_texture.scale_transform = transform.scale
                }
            }
        }
        
        // Normal texture
        if src.normal_texture.texture != nil {
            texture_index := cgltf.texture_index(data, src.normal_texture.texture)
            dst.normal_texture.texture = &model.textures[texture_index]
            dst.normal_texture.tex_coord = src.normal_texture.texcoord
            dst.normal_scale = src.normal_texture.scale
            
            // Transform
            if src.normal_texture.has_transform {
                transform := src.normal_texture.transform
                dst.normal_texture.has_transform = true
                dst.normal_texture.offset = transform.offset
                dst.normal_texture.rotation = transform.rotation
                dst.normal_texture.scale_transform = transform.scale
            }
        }
        
        // Occlusion texture
        if src.occlusion_texture.texture != nil {
            texture_index := cgltf.texture_index(data, src.occlusion_texture.texture)
            dst.occlusion_texture.texture = &model.textures[texture_index]
            dst.occlusion_texture.tex_coord = src.occlusion_texture.texcoord
            dst.occlusion_strength = src.occlusion_texture.scale
            
            // Transform
            if bool(src.occlusion_texture.has_transform) {
                transform := src.occlusion_texture.transform
                dst.occlusion_texture.has_transform = true
                dst.occlusion_texture.offset = transform.offset
                dst.occlusion_texture.rotation = transform.rotation
                dst.occlusion_texture.scale_transform = transform.scale
            }
        }
        
        // Emissive texture
        if src.emissive_texture.texture != nil {
            texture_index := cgltf.texture_index(data, src.emissive_texture.texture)
            dst.emissive_texture.texture = &model.textures[texture_index]
            dst.emissive_texture.tex_coord = src.emissive_texture.texcoord
            
            // Transform
            if bool(src.emissive_texture.has_transform) {
                transform := src.emissive_texture.transform
                dst.emissive_texture.has_transform = true
                dst.emissive_texture.offset = transform.offset
                dst.emissive_texture.rotation = transform.rotation
                dst.emissive_texture.scale_transform = transform.scale
            }
        }
        
        // Emissive factor
        for j in 0..<3 {
            dst.emissive_factor[j] = src.emissive_factor[j]
        }
        
        // Alpha settings
        dst.alpha_mode = src.alpha_mode
        dst.alpha_cutoff = src.alpha_cutoff
        
        // Misc settings
        dst.double_sided = bool(src.double_sided)
        dst.unlit = bool(src.unlit)
    }
    
    // Load meshes
    model.meshes = make([]Mesh, len(data.meshes))
    for i in 0..<len(data.meshes) {
        src := &data.meshes[i]
        dst := &model.meshes[i]
        
        if src.name != nil {
            dst.name = strings.clone_from_cstring(src.name)
        }
        
        // Weights
        if len(src.weights) > 0 {
            dst.weights = make([]f32, len(src.weights))
            for j in 0..<len(src.weights) {
                dst.weights[j] = src.weights[j]
            }
        }
        
        // Target names
        if len(src.target_names) > 0 {
            dst.target_names = make([]string, len(src.target_names))
            for j in 0..<len(src.target_names) {
                if src.target_names[j] != nil {
                    dst.target_names[j] = strings.clone_from_cstring(src.target_names[j])
                }
            }
        }
        
        // Primitives
        if len(src.primitives) > 0 {
            for j in 0..<len(src.primitives) {
                primitive: Primitive
                primitive.type = src.primitives[j].type
                
                // Indices
                if src.primitives[j].indices != nil {
                    accessor_index := cgltf.accessor_index(data, src.primitives[j].indices)
                    primitive.indices = &model.accessors[accessor_index]
                }
                
                // Material
                if src.primitives[j].material != nil {
                    material_index := cgltf.material_index(data, src.primitives[j].material)
                    primitive.material = &model.materials[material_index]
                }
                
                // Attributes
                primitive.attributes = make(map[string]^Accessor)
                for k in 0..<len(src.primitives[j].attributes) {
                    attr := &src.primitives[j].attributes[k]
                    
                    attribute_name: string
                    if attr.name != nil {
                        attribute_name = strings.clone_from_cstring(attr.name)
                    } else {
                        // Use the default attribute type
                        switch attr.type {
                            case .position: attribute_name = "POSITION"
                            case .normal: attribute_name = "NORMAL"
                            case .tangent: attribute_name = "TANGENT"
                            case .texcoord: 
                                attribute_name = fmt.tprintf("TEXCOORD_%d", attr.index)
                            case .color: 
                                attribute_name = fmt.tprintf("COLOR_%d", attr.index)
                            case .joints: 
                                attribute_name = fmt.tprintf("JOINTS_%d", attr.index)
                            case .weights: 
                                attribute_name = fmt.tprintf("WEIGHTS_%d", attr.index)
                            case .custom: attribute_name = "CUSTOM"
                            case .invalid: attribute_name = "INVALID"
                        }
                    }

                    if attr.data != nil {
                        accessor_index := cgltf.accessor_index(data, attr.data)
                        primitive.attributes[attribute_name] = &model.accessors[accessor_index]
                    }
                }
                
                // Targets (morph targets)
                if len(src.primitives[j].targets) > 0 {
                    primitive.targets = make([]map[string]^Accessor, len(src.primitives[j].targets))
                    
                    for k in 0..<len(src.primitives[j].targets) {
                        target := make(map[string]^Accessor)
                        
                        for l in 0..<len(src.primitives[j].targets[k].attributes) {
                            target_attr := &src.primitives[j].targets[k].attributes[l]
                            
                            attribute_name: string
                            if target_attr.name != nil {
                                attribute_name = strings.clone_from_cstring(target_attr.name)
                            } else {
                                // Use the default attribute type
                                switch target_attr.type {
                                    case .position: attribute_name = "POSITION"
                                    case .normal: attribute_name = "NORMAL"
                                    case .tangent: attribute_name = "TANGENT"
                                    case .texcoord: 
                                        attribute_name = "TEXCOORD"
                                        if target_attr.index > 0 {
                                            attribute_name = fmt.tprintf("%s_%d", attribute_name, target_attr.index)
                                        }
                                    case .color: 
                                        attribute_name = "COLOR"
                                        if target_attr.index > 0 {
                                            attribute_name = fmt.tprintf("%s_%d", attribute_name, target_attr.index)
                                        }
                                    case .joints: 
                                        attribute_name = "JOINTS"
                                        if target_attr.index > 0 {
                                            attribute_name = fmt.tprintf("%s_%d", attribute_name, target_attr.index)
                                        }
                                    case .weights: 
                                        attribute_name = "WEIGHTS"
                                        if target_attr.index > 0 {
                                            attribute_name = fmt.tprintf("%s_%d", attribute_name, target_attr.index)
                                        }
                                    case .custom: 
                                        if target_attr.name != nil {
                                            attribute_name = strings.clone_from_cstring(target_attr.name)
                                        } else {
                                            attribute_name = "CUSTOM"
                                        }
                                    case .invalid:
                                        attribute_name = "INVALID"
                                }
                            }
                            
                            if target_attr.data != nil {
                                accessor_index := cgltf.accessor_index(data, target_attr.data)
                                target[attribute_name] = &model.accessors[accessor_index]
                            }
                        }
                        
                        primitive.targets[k] = target
                    }
                }
                
                append(&dst.primitives, primitive)
            }
        }
    }
    
    // Load cameras
    model.cameras = make([]Camera, len(data.cameras))
    for i in 0..<len(data.cameras) {
        src := &data.cameras[i]
        dst := &model.cameras[i]
        
        if src.name != nil {
            dst.name = strings.clone_from_cstring(src.name)
        }
        
        dst.type = src.type
        
        // Camera-type specific parameters
        if src.type == .perspective {
            dst.aspect_ratio = src.data.perspective.aspect_ratio
            dst.yfov = src.data.perspective.yfov
            dst.zfar = src.data.perspective.zfar
            dst.znear = src.data.perspective.znear
        } else if src.type == .orthographic {
            dst.xmag = src.data.orthographic.xmag
            dst.ymag = src.data.orthographic.ymag
            dst.zfar = src.data.orthographic.zfar
            dst.znear = src.data.orthographic.znear
        }
    }
    
    // Load lights
    model.lights = make([]Light, len(data.lights))
    for i in 0..<len(data.lights) {
        src := &data.lights[i]
        dst := &model.lights[i]
        
        if src.name != nil {
            dst.name = strings.clone_from_cstring(src.name)
        }
        
        dst.type = src.type
        dst.color = src.color
        dst.intensity = src.intensity
        dst.range = src.range
        dst.spot_inner_cone_angle = src.spot_inner_cone_angle
        dst.spot_outer_cone_angle = src.spot_outer_cone_angle
    }
    
    // Load skins
    model.skins = make([]Skin, len(data.skins))
    for i in 0..<len(data.skins) {
        src := &data.skins[i]
        dst := &model.skins[i]
        
        if src.name != nil {
            dst.name = strings.clone_from_cstring(src.name)
        }
        
        // Skeleton root
        if src.skeleton != nil {
            node_index := cgltf.node_index(data, src.skeleton)
            dst.skeleton = &model.nodes[node_index]
        }
        
        // Inverse bind matrices
        if src.inverse_bind_matrices != nil {
            accessor_index := cgltf.accessor_index(data, src.inverse_bind_matrices)
            dst.inverse_bind_matrices = &model.accessors[accessor_index]
        }
        
        // Joints
        if len(src.joints) > 0 {
            dst.joints = make([]^Node, len(src.joints))
            for j in 0..<len(src.joints) {
                if src.joints[j] != nil {
                    node_index := cgltf.node_index(data, src.joints[j])
                    dst.joints[j] = &model.nodes[node_index]
                }
            }
        }
    }
    
    // Load nodes
    model.nodes = make([]Node, len(data.nodes))
    for i in 0..<len(data.nodes) {
        src := &data.nodes[i]
        dst := &model.nodes[i]
        
        if src.name != nil {
            dst.name = strings.clone_from_cstring(src.name)
        }
        
        // Matrix
        dst.has_matrix = bool(src.has_matrix)
        if dst.has_matrix {
            for j in 0..<16 {
                dst.matrix_data[j] = src.matrix_[j]
            }
        }
        
        // Transform
        dst.has_transform = bool(src.has_translation) || bool(src.has_rotation) || bool(src.has_scale)
        if src.has_translation {
            dst.translation = src.translation
        }
        if src.has_rotation {
            dst.rotation = m.quat(src.rotation)
        }
        if src.has_scale {
            dst.scale = src.scale
        }
        
        // Mesh
        if src.mesh != nil {
            mesh_index := cgltf.mesh_index(data, src.mesh)
            dst.mesh = &model.meshes[mesh_index]
        }
        
        // Skin
        if src.skin != nil {
            skin_index := cgltf.skin_index(data, src.skin)
            dst.skin = &model.skins[skin_index]
        }
        
        // Camera
        if src.camera != nil {
            camera_index := cgltf.camera_index(data, src.camera)
            dst.camera = &model.cameras[camera_index]
        }
        
        // Light
        if src.light != nil {
            light_index := cgltf.light_index(data, src.light)
            dst.light = &model.lights[light_index]
        }
        
        // Weights
        if len(src.weights) > 0 {
            dst.weights = make([]f32, len(src.weights))
            for j in 0..<len(src.weights) {
                dst.weights[j] = src.weights[j]
            }
        }
    }
    
    // Update node hierarchy
    for i in 0..<len(data.nodes) {
        src := &data.nodes[i]
        dst := &model.nodes[i]
        
        // Parent
        if src.parent != nil {
            parent_index := cgltf.node_index(data, src.parent)
            dst.parent = &model.nodes[parent_index]
        }
        
        // Children
        if len(src.children) > 0 {
            for j in 0..<len(src.children) {
                if src.children[j] != nil {
                    child_index := cgltf.node_index(data, src.children[j])
                    append(&dst.children, &model.nodes[child_index])
                }
            }
        }
    }
    
    // Load animations
    model.animations = make([]Animation, len(data.animations))
    for i in 0..<len(data.animations) {
        src := &data.animations[i]
        dst := &model.animations[i]
        
        if src.name != nil {
            dst.name = strings.clone_from_cstring(src.name)
        }
        
        // Samplers
        if len(src.samplers) > 0 {
            dst.samplers = make([]AnimationSampler, len(src.samplers))
            
            for j in 0..<len(src.samplers) {
                sampler_src := &src.samplers[j]
                sampler_dst := &dst.samplers[j]
                
                sampler_dst.interpolation = sampler_src.interpolation
                
                // Input accessor (time keyframes)
                if sampler_src.input != nil {
                    accessor_index := cgltf.accessor_index(data, sampler_src.input)
                    sampler_dst.input = &model.accessors[accessor_index]
                }
                
                // Output accessor (value keyframes)
                if sampler_src.output != nil {
                    accessor_index := cgltf.accessor_index(data, sampler_src.output)
                    sampler_dst.output = &model.accessors[accessor_index]
                }
            }
        }
        
        // Channels
        if len(src.channels) > 0 {
            dst.channels = make([]AnimationChannel, len(src.channels))
            
            for j in 0..<len(src.channels) {
                channel_src := &src.channels[j]
                channel_dst := &dst.channels[j]
                
                channel_dst.target_path = channel_src.target_path
                
                // Target node
                if channel_src.target_node != nil {
                    node_index := cgltf.node_index(data, channel_src.target_node)
                    channel_dst.target_node = &model.nodes[node_index]
                }
                
                // Sampler
                if channel_src.sampler != nil {
                    sampler_index := cgltf.animation_sampler_index(src, channel_src.sampler)
                    channel_dst.sampler = &dst.samplers[sampler_index]
                }
            }
        }
    }
    
    // Load scenes
    model.scenes = make([]Scene, len(data.scenes))
    for i in 0..<len(data.scenes) {
        src := &data.scenes[i]
        dst := &model.scenes[i]
        
        if src.name != nil {
            dst.name = strings.clone_from_cstring(src.name)
        }
        
        // Nodes // The "root" Nodes, and should not have parents
        if len(src.nodes) > 0 {
            for j in 0..<len(src.nodes) {
                if src.nodes[j] != nil {
                    node_index := cgltf.node_index(data, src.nodes[j])
                    append(&dst.nodes, &model.nodes[node_index])
                }
            }
        }
    }
    
    // Default scene
    if data.scene != nil {
        scene_index := cgltf.scene_index(data, data.scene)
        model.default_scene = &model.scenes[scene_index]
    }
    
    return model
}

free_model :: proc(model: ^Model) {
    if model == nil do return
    
    // Free asset strings
    if model.asset.version != "" do delete(model.asset.version)
    if model.asset.generator != "" do delete(model.asset.generator)
    if model.asset.copyright != "" do delete(model.asset.copyright)
    
    for i in 0..<len(model.buffers) {
        buffer := &model.buffers[i]
        if buffer.name != "" do delete(buffer.name)
        if buffer.uri != "" do delete(buffer.uri)
        if len(buffer.data) > 0 do delete(buffer.data)
    }
    if len(model.buffers) > 0 do delete(model.buffers)
    
    for i in 0..<len(model.buffer_views) {
        buffer_view := &model.buffer_views[i]
        if buffer_view.name != "" do delete(buffer_view.name)
    }
    if len(model.buffer_views) > 0 do delete(model.buffer_views)
    
    for i in 0..<len(model.accessors) {
        accessor := &model.accessors[i]
        if accessor.name != "" do delete(accessor.name)
    }
    if len(model.accessors) > 0 do delete(model.accessors)
    
    for i in 0..<len(model.images) {
        image := &model.images[i]
        if image.name != "" do delete(image.name)
        if image.uri != "" do delete(image.uri)
        if image.mime_type != "" do delete(image.mime_type)
    }
    if len(model.images) > 0 do delete(model.images)
    
    for i in 0..<len(model.samplers) {
        sampler := &model.samplers[i]
        if sampler.name != "" do delete(sampler.name)
    }
    if len(model.samplers) > 0 do delete(model.samplers)
    
    for i in 0..<len(model.textures) {
        texture := &model.textures[i]
        if texture.name != "" do delete(texture.name)
    }
    if len(model.textures) > 0 do delete(model.textures)
    
    for i in 0..<len(model.materials) {
        material := &model.materials[i]
        if material.name != "" do delete(material.name)
    }
    if len(model.materials) > 0 do delete(model.materials)
    
    for i in 0..<len(model.meshes) {
        mesh := &model.meshes[i]
        if mesh.name != "" do delete(mesh.name)
        
        for primitive in mesh.primitives {
            if primitive.attributes != nil {
                // Free attribute name strings
                for name, _ in primitive.attributes {
                    delete(name)
                }
                delete(primitive.attributes)
            }
            
            for target in primitive.targets {
                if target != nil {
                    // Free target attribute name strings
                    for name, _ in target {
                        delete(name)
                    }
                    delete(target)
                }
            }
            if len(primitive.targets) > 0 do delete(primitive.targets)
        }
        
        if len(mesh.primitives) > 0 do delete(mesh.primitives)
        if len(mesh.weights) > 0 do delete(mesh.weights)
        
        for target_name in mesh.target_names {
            if target_name != "" do delete(target_name)
        }
        if len(mesh.target_names) > 0 do delete(mesh.target_names)
    }
    if len(model.meshes) > 0 do delete(model.meshes)
    
    for i in 0..<len(model.cameras) {
        camera := &model.cameras[i]
        if camera.name != "" do delete(camera.name)
    }
    if len(model.cameras) > 0 do delete(model.cameras)
    
    for i in 0..<len(model.lights) {
        light := &model.lights[i]
        if light.name != "" do delete(light.name)
    }
    if len(model.lights) > 0 do delete(model.lights)
    
    for i in 0..<len(model.skins) {
        skin := &model.skins[i]
        if skin.name != "" do delete(skin.name)
        if len(skin.joints) > 0 do delete(skin.joints)
    }
    if len(model.skins) > 0 do delete(model.skins)
    
    for i in 0..<len(model.animations) {
        animation := &model.animations[i]
        if animation.name != "" do delete(animation.name)
        if len(animation.channels) > 0 do delete(animation.channels)
        if len(animation.samplers) > 0 do delete(animation.samplers)
    }
    if len(model.animations) > 0 do delete(model.animations)
    
    for i in 0..<len(model.nodes) {
        node := &model.nodes[i]
        if node.name != "" do delete(node.name)
        if len(node.children) > 0 do delete(node.children)
        if len(node.weights) > 0 do delete(node.weights)
    }
    if len(model.nodes) > 0 do delete(model.nodes)
    
    for i in 0..<len(model.scenes) {
        scene := &model.scenes[i]
        if scene.name != "" do delete(scene.name)
        if len(scene.nodes) > 0 do delete(scene.nodes)
    }
    if len(model.scenes) > 0 do delete(model.scenes)
}