cbuffer Object : register(b0, space1) {
    float4x4 model;
};

cbuffer World : register(b1, space1) {
    float4x4 view;
    float4x4 proj;
    float3   cameraPos;
};

struct Input {
    float3 position : TEXCOORD0;
    float4 color    : TEXCOORD1;
};

struct Output {
    float4 position  : SV_Position;
    float4 color     : TEXCOORD1;
    float2 uv        : TEXCOORD2;
};

Output main(Input input) {
    Output output;
    
    float4x4 mvp = mul(proj, mul(view, model));
    output.position = mul(mvp, float4(input.position, 1));
    output.color = input.color;
    output.uv    = max(input.position.xy, input.position.xz);
    
    return output;
}