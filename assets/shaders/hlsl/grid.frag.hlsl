static float lineWidth = 0.05;

struct Input {
    float4 position : SV_Position;
    float4 color    : TEXCOORD0;
    float2 fragPos  : TEXCOORD1;
};

float4 main(Input input) : SV_Target {
    float2 lineAA = fwidth(input.fragPos);
    float2 gridUV = abs(frac(input.fragPos) * 2 - 1);
    float2 grid2 = smoothstep(lineWidth + lineAA, lineWidth - lineAA, gridUV);
    float grid = lerp(grid2.x, 1, grid2.y);

    return input.color * grid;
}
