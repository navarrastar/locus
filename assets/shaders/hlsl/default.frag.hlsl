static float3 lightPos   = { -1, 2, 3 };
static float4 lightColor = { 1, 1, 1, 10 };

struct Input {
    float4 position : SV_Position;
    float4 color    : TEXCOORD0;
    float3 normal   : TEXCOORD1;
    float3 fragPos  : TEXCOORD2;
};

float4 main(Input input) : SV_Target0 {

    float3 lightDir = lightPos - input.fragPos.xyz;
    float distToLight = length(lightDir);
    lightDir /= distToLight;
    
    float3 normal = normalize(input.normal);

    float incidenceAngleFactor = dot(lightDir, normal);
    float3 reflectedRadiance;
    if (incidenceAngleFactor > 0) {
        float attenuationFactor = 1 / pow(distToLight, 2);
        float3 incomingRadiance = lightColor.xyz * lightColor.w;
        float3 irradiance = incomingRadiance * incidenceAngleFactor * attenuationFactor;
        float3 brdf = input.color;
        reflectedRadiance = irradiance * brdf;
    } else {
        reflectedRadiance = float3(0, 0, 0);
    }
    
    float3 emittedRadiance = float3(0, 0, 0);
    float3 outRadiance = emittedRadiance + reflectedRadiance;
    
    return float4(outRadiance, 1);
}
