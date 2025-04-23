static float4 in_var_TEXCOORD0;
static float3 in_var_TEXCOORD1;
static float4 out_var_SV_Target;

struct SPIRV_Cross_Input
{
    float4 in_var_TEXCOORD0 : TEXCOORD0;
    float3 in_var_TEXCOORD1 : TEXCOORD1;
};

struct SPIRV_Cross_Output
{
    float4 out_var_SV_Target : SV_Target0;
};

void main_inner()
{
    float2 _32 = step(abs(in_var_TEXCOORD1.xy - (round(in_var_TEXCOORD1.xy * 10.0f.xx) * 0.100000001490116119384765625f)), 0.004999999888241291046142578125f.xx);
    out_var_SV_Target = lerp(in_var_TEXCOORD0, float4(0.0f, 0.0f, 0.0f, 1.0f), max(_32.x, _32.y).xxxx);
}

SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
    in_var_TEXCOORD0 = stage_input.in_var_TEXCOORD0;
    in_var_TEXCOORD1 = stage_input.in_var_TEXCOORD1;
    main_inner();
    SPIRV_Cross_Output stage_output;
    stage_output.out_var_SV_Target = out_var_SV_Target;
    return stage_output;
}
