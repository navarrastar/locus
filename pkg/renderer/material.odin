// pkg/renderer/materials.odin
package renderer



import "pkg:core/filesystem/loader"
import m "pkg:core/math"

import "vendor:wgpu"

MaterialType :: enum {
    PBR_MetallicRoughness,
    Unlit,
    Toon,
    Wireframe,
    Custom,
}

Material :: struct {
    name: string,
    type: MaterialType,
    base_color: m.Vec4,
    base_color_texture: ^Texture,
    metallic_factor: f32,
    roughness_factor: f32,
    metallic_roughness_texture: ^Texture,
    normal_texture: ^Texture,
    occlusion_texture: ^Texture,
    emissive_texture: ^Texture,
    emissive_factor: m.Vec3,
    alpha_mode: AlphaMode,
    alpha_cutoff: f32,
    double_sided: bool,
    
    // Shader variants
    has_vertex_colors: bool,
    has_normals: bool,
    has_tangents: bool,
    has_uv: bool,
    has_joints: bool,
    has_weights: bool
}

Texture :: struct {
    name: string,
    texture_view: wgpu.TextureView,
    sampler: wgpu.Sampler,
}

AlphaMode :: enum {
    Opaque,
    Mask,
    Blend,
}


