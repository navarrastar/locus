static float3 lightPos   = { -1, 2, 3 };
static float4 lightColor = { 1, 1, 1, 10 };

struct Input {
    float4 position : SV_Position;
    float4 color    : TEXCOORD0;
    float3 normal   : TEXCOORD1;
    float2 uv       : TEXCOORD2;
    float3 fragPos  : TEXCOORD3;
};

Texture2D<float4> diffuseTexture: register(t0, space2);
SamplerState      diffuseSampler: register(s0, space2);

float4 main(Input input) : SV_Target0 {
    float3 diffuse = diffuseTexture.Sample(diffuseSampler, input.uv);

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

    float3 outColor = outRadiance * diffuse;
    
    return float4(diffuse, 1);
    return float4(outColor, 1);
}
