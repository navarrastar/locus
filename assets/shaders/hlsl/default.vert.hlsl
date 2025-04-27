cbuffer Object : register(b0, space1) {
    float4x4 model;
};

cbuffer World : register(b1, space1) {
    float4x4 view;
    float4x4 proj;
};

struct Input {
    float3 position : TEXCOORD0;
    float4 color    : TEXCOORD1;
    float3 normal   : TEXCOORD2;
};

struct Output {
    float4 position : SV_Position;
    float4 color    : TEXCOORD0;
    float3 normal   : TEXCOORD1;
    float3 fragPos  : TEXCOORD2;
};



Output main(Input input) {
    Output output;
    
    float4 worldPos = mul(model, float4(input.position, 1));
    
    float4x4 viewProj = mul(proj, view);
    float4x4 mvp = mul(viewProj, model);
    
    output.position = mul(mvp, float4(input.position, 1));
    output.color = input.color;
    output.fragPos = worldPos.xyz;
    output.normal = normalize(mul(model, float4(input.normal, 0)).xyz);
    return output;
}
