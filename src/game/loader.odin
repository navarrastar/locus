package game

// import "core:fmt"
import "core:log"
import "core:strings"

import gltf "../../third_party/gltf2"


gltf_load :: proc(name: string) -> ^gltf.Data {
	if model, ok := loaded_models[name]; ok {
		return model
	}

	log.infof("loading {}", name)
	path, _ := strings.concatenate({MODEL_DIR, name, ".glb"})

	model, _ := gltf.load_from_file(path)
	loader_validate(model, name)

	loaded_models[name] = model

	return model
}

loader_validate :: proc(model: ^gltf.Data, name: string) -> bool {
	// Each .glb file should only have one mesh.
	// You must split meshes into seperate .glb files
	// and load them seperately
	//
	// The mesh must meet the following requirements:
	// POSITION, COLOR_0, NORMAL, TEXCOORD_0, TANGENT, JOINTS_0, WEIGHTS_0 attributes
	// 16 bit indices
	// base_color_texture
	// Only one primitive on the mesh
	// At least one animation with the name "TPose"
	//
	// Note: This function now supports loading JOINTS_0 and WEIGHTS_0 attributes for skinning
	// The vertices will include 4 joint indices (as floats) and 4 weights,
	// but the shader needs to be updated to actually use them for skinning.

	assert(len(model.meshes) == 1)
	assert(len(model.meshes[0].primitives) == 1)

	primitive := model.meshes[0].primitives[0]
	
	// Validate indices
	assert(primitive.indices != nil)
	indices_buffer := gltf.buffer_slice(model, primitive.indices.?)
	_, indices_ok := indices_buffer.([]u16)
	assert(indices_ok)

	// Validate all required attributes
	pos_idx, pos_ok := primitive.attributes["POSITION"]
	_, norm_ok := primitive.attributes["NORMAL"]
	_, col_ok := primitive.attributes["COLOR_0"]
	_, uv_ok := primitive.attributes["TEXCOORD_0"]
	_, tan_ok := primitive.attributes["TANGENT"]
	_, joints_ok := primitive.attributes["JOINTS_0"]
	_, weights_ok := primitive.attributes["WEIGHTS_0"]

	assert(pos_ok)
	assert(norm_ok)
	assert(col_ok)
	assert(uv_ok)
	assert(tan_ok)
	assert(joints_ok)
	assert(weights_ok)

	// Validate position data format
	pos_buffer := gltf.buffer_slice(model, pos_idx)
	_, pos_type_ok := pos_buffer.([][3]f32)
	assert(pos_type_ok)
	
	// Validate material and textures
	assert(primitive.material != nil)
	mat_idx := primitive.material.?
	assert(int(mat_idx) < len(model.materials))
	
	mat := model.materials[mat_idx]
	assert(mat.metallic_roughness != nil)
	
	mr := mat.metallic_roughness.?
	assert(mr.base_color_texture != nil)
	
	bct_info := mr.base_color_texture.?
	assert(int(bct_info.index) < len(model.textures))
	
	bct := model.textures[bct_info.index]
	assert(bct.source != nil)
	
	bct_source_idx := bct.source.?
	assert(int(bct_source_idx) < len(model.images))
	
	// Validate skin and animations if present
	if len(model.skins) > 0 {
		for skin in model.skins {
			assert(len(skin.joints) > 0)
			
			// Validate inverse bind matrices if present
			if skin.inverse_bind_matrices != nil {
				ibm_idx := skin.inverse_bind_matrices.?
				ibm_data := gltf.buffer_slice(model, ibm_idx)
				_, ibm_ok := ibm_data.([]matrix[4, 4]f32)
				assert(ibm_ok)
			}
		}
	}
	
	// Validate animations
	if len(model.animations) > 0 {
		t_pose_found := false
		for anim in model.animations {
			if anim.name != nil && anim.name.? == "TPose" {
				t_pose_found = true
			}
			
			// Validate samplers
			for sampler in anim.samplers {
				assert(int(sampler.input) < len(model.accessors))
				assert(int(sampler.output) < len(model.accessors))
				
				// Validate input (timestamps) format
				input_data := gltf.buffer_slice(model, sampler.input)
				_, times_ok := input_data.([]f32)
				assert(times_ok)
				
				// Validate output (values) format
				output_data := gltf.buffer_slice(model, sampler.output)
				_, vec3_ok := output_data.([][3]f32)
				_, vec4_ok := output_data.([][4]f32)
				assert(vec3_ok || vec4_ok)
			}
			
			// Validate channels
			for channel in anim.channels {
				assert(int(channel.sampler) < len(anim.samplers))
				if channel.target.node != nil {
					target_node := channel.target.node.?
					assert(int(target_node) < len(model.nodes))
				}
			}
		}
		
		// Check for required TPose animation
		assert(t_pose_found)
	}

	return true
}
