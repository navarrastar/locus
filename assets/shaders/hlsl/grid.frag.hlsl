struct PS_INPUT {
    float4 Position : SV_POSITION;
    float4 Color : COLOR;
    float3 WorldPos : TEXCOORD0;
};

float4 main(PS_INPUT input) : SV_TARGET {
    const float GRID_SIZE = 1.0;
    const float LINE_WIDTH = 0.02;
    
    // Calculate distance to nearest grid line
    float2 coord = input.WorldPos.xz / GRID_SIZE;
    float2 fraction = frac(coord);
    float2 distToLine = min(fraction, 1.0 - fraction) * GRID_SIZE;
    
    // Determine line visibility
    float2 lines = step(distToLine, float2(LINE_WIDTH, LINE_WIDTH));
    float gridFactor = max(lines.x, lines.y);
    
    // Apply alpha based on grid lines
    float4 color = input.Color;
    color.a = lerp(0.2, 1.0, gridFactor);
    
    return color;
}