const static uint MAX_JOINTS = 100;

cbuffer Object : register(b0, space1) {
    float4x4 model;
};

cbuffer World : register(b1, space1) {
    float4x4 view;
    float4x4 proj;
};

cbuffer Skin : register(b2, space1) {
    float4x4 joint_matrices[MAX_JOINTS];
};

struct Input {
    float3 position : TEXCOORD0;
    float4 color    : TEXCOORD1;
    float3 normal   : TEXCOORD2;
    float2 uv       : TEXCOORD3;
    float3 tangent  : TEXCOORD4;
    float4 joints   : TEXCOORD5;
    float4 weights  : TEXCOORD6;
};

struct Output {
    float4 position : SV_Position;
    float4 color    : TEXCOORD0;
    float3 normal   : TEXCOORD1;
    float2 uv       : TEXCOORD2;
    float3 fragPos  : TEXCOORD3;
};

Output main(Input input) {
    Output output;
    
    // Initialize skin matrix with zeros
    float4x4 skin_matrix = {
        float4(0, 0, 0, 0),
        float4(0, 0, 0, 0),
        float4(0, 0, 0, 0),
        float4(0, 0, 0, 0)
    };
    
    skin_matrix += input.weights.x * joint_matrices[int(input.joints.x)];
    skin_matrix += input.weights.y * joint_matrices[int(input.joints.y)];
    skin_matrix += input.weights.z * joint_matrices[int(input.joints.z)];
    skin_matrix += input.weights.w * joint_matrices[int(input.joints.w)];
    
    float4 skinnedPos = mul(skin_matrix, float4(input.position, 1.0));
    float3 skinnedNormal = mul(skin_matrix, float4(input.normal, 0.0)).xyz;
    
    float4 worldPos = mul(model, skinnedPos);
    
    float4x4 viewProj = mul(proj, view);
    
    output.position = mul(viewProj, worldPos);
    output.color = input.color;
    output.normal = normalize(mul(model, float4(skinnedNormal, 0)).xyz);
    output.uv = input.uv;
    output.fragPos = worldPos.xyz;
    return output;
}
