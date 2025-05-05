# Skinning Implementation Notes

## What's Been Implemented

1. **Joint and Weight Data Loading**
   - The `mesh` function now loads `JOINTS_0` and `WEIGHTS_0` attributes from GLTF files
   - Up to 4 joint indices and weights per vertex are supported
   - The data is stored in the vertex buffer when skinning data is present

2. **Vertex Structures**
   - A new `Vertex_PosColNormUVSkin` structure is defined which includes joint indices and weights
   - Added `ATTRIBUTES_POS_COL_NORM_UV_SKIN` for vertex attribute layout
   - Added `.MeshSkinned` material type to differentiate from regular meshes

3. **Animation Data Loading**
   - Skin, animation, joints, and transforms are already loaded correctly
   - The `animation_continue` function updates joint transforms based on animation data

## What You Need to Implement

1. **Update Pipeline Code**
   - Create a new pipeline for skinned meshes or update the existing mesh pipeline
   - Use `ATTRIBUTES_POS_COL_NORM_UV_SKIN` when the material type is `.MeshSkinned`
   - Example code to add to `pipeline.odin`:

   ```odin
   pipeline_create_mesh_skinned :: proc() {
       vert_shader := shader_load(SHADER_DIR + "hlsl/skin.vert.hlsl", 2, 0)
       frag_shader := shader_load(SHADER_DIR + "hlsl/mesh.frag.hlsl", 0, 1)
       if vert_shader == nil || frag_shader == nil {
           log.error("Failed to load skin shaders")
           return
       }
       attributes := ATTRIBUTES_POS_COL_NORM_UV_SKIN
       pipeline_desc := sdl.GPUGraphicsPipelineCreateInfo {
           // Same as mesh pipeline but with different attributes
           vertex_shader = vert_shader,
           fragment_shader = frag_shader,
           primitive_type = .TRIANGLELIST,
           vertex_input_state = {
               num_vertex_buffers = 1,
               vertex_buffer_descriptions = &(sdl.GPUVertexBufferDescription {
                   slot = 0,
                   pitch = size_of(Vertex_PosColNormUVSkin),
               }),
               num_vertex_attributes = u32(len(attributes)),
               vertex_attributes = &attributes[0],
           },
           // Rest of pipeline description
       }
       // Create pipeline and add to materials map
   }
   ```

2. **Create Skinning Shader**
   - Create a new vertex shader for skinned meshes (e.g., `skin.vert.hlsl`)
   - Update the input structure to include joint indices and weights
   - Example shader input structure:

   ```hlsl
   struct Input {
       float3 position : TEXCOORD0;
       float4 color    : TEXCOORD1;
       float3 normal   : TEXCOORD2;
       float2 uv       : TEXCOORD3;
       float4 joints   : TEXCOORD4; // Joint indices
       float4 weights  : TEXCOORD5; // Joint weights
   };
   ```

3. **Implement Skinning in Shader**
   - Create a uniform buffer for joint matrices
   - Apply skinning transformation to vertex positions and normals
   - Example skinning code for your shader:

   ```hlsl
   cbuffer Skinning : register(b2, space1) {
       float4x4 joint_matrices[100]; // Adjust size based on max joints
   };

   // In the main function:
   float4x4 skin_matrix = float4x4(0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0);
   
   // Sum weighted joint matrices
   skin_matrix += input.weights.x * joint_matrices[int(input.joints.x)];
   skin_matrix += input.weights.y * joint_matrices[int(input.joints.y)];
   skin_matrix += input.weights.z * joint_matrices[int(input.joints.z)];
   skin_matrix += input.weights.w * joint_matrices[int(input.joints.w)];
   
   // Apply skinning to position and normal
   float4 skinned_pos = mul(skin_matrix, float4(input.position, 1.0));
   float3 skinned_normal = normalize(mul(skin_matrix, float4(input.normal, 0.0)).xyz);
   
   // Use skinned_pos and skinned_normal in subsequent calculations instead of input.position and input.normal
   ```

4. **Update Render Code**
   - Calculate joint matrices for rendering
   - Upload joint matrices to the GPU before rendering skinned meshes
   - You'll need to calculate the final joint matrices by combining:
     - The current joint transform (from animation)
     - The inverse bind matrices (from skin.ibm)

## Testing

1. Load a model with skinning data
2. Verify that joint indices and weights are correctly loaded
3. Implement the shader and test that animations work correctly

Good luck with your implementation!