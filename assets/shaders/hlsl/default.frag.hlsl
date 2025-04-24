static float3 lightPos   = { 0, 0.7, -0.2 };
static float4 lightColor = { 1, 0.7,  0.2, 1 };

struct Input {
    float4 position : SV_Position;
    float4 color    : TEXCOORD0;
    float3 normal   : TEXCOORD1;
};

float4 main(Input input) : SV_Target0 {
    return float4(input.normal, 1);
}
