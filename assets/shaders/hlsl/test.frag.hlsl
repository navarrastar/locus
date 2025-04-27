cbuffer Test : register(b0, space3) {
    float4 test;
}

struct Input {
    float4 position : SV_Position;
    float4 color    : TEXCOORD0;
    float3 normal   : TEXCOORD1;
    float3 fragPos  : TEXCOORD2;
};

float4 main(Input input) : SV_Target0 {
    float3 fragPos = normalize(input.fragPos);

    float3 col = 0.5 + 0.5 * cos(test.x+fragPos + float3(0, 2, 4));

    return float4(col, 1.0);
}
