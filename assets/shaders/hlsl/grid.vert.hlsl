struct VS_INPUT {
    float3 Position : POSITION;
    float4 Color : COLOR;
};

struct VS_OUTPUT {
    float4 Position : SV_POSITION;
    float4 Color : COLOR;
    float3 WorldPos : TEXCOORD0;
};

// Changed to use binding point 1 for Metal compatibility
cbuffer CameraConstants : register(b1, space1) {
    float4x4 ViewProjection;
};

VS_OUTPUT main(VS_INPUT input) {
    VS_OUTPUT output;
    
    // World position (assuming model matrix is identity)
    float4 worldPos = float4(input.Position, 1.0);
    
    // Transform to clip space
    output.Position = mul(worldPos, ViewProjection);
    output.Color = input.Color;
    output.WorldPos = worldPos.xyz;
    
    return output;
}