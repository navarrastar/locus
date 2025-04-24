struct Input {
    float4 position : SV_Position;
    float4 color    : TEXCOORD1;
    float2 uv       : TEXCOORD2;
};


float draw_grid(float2 uv) {
    float2 grid_uv = cos(uv);
    return max(grid_uv.x, grid_uv.y); 
}

float4 main(Input input) : SV_Target {
    float thickness = 20 / 21;
    float3 color = smoothstep(0.99, 1, draw_grid(input.uv * 20)) * input.color; 
    return float4(color, 1);
}