cbuffer UBO : register(b0, space1)
{
    row_major float4x4 _19_mvp : packoffset(c0);
};


static float4 gl_Position;
static float3 in_position;
static float4 out_color;
static float4 in_color;

struct SPIRV_Cross_Input
{
    float3 in_position : TEXCOORD0;
    float4 in_color : TEXCOORD1;
};

struct SPIRV_Cross_Output
{
    float4 out_color : TEXCOORD0;
    float4 gl_Position : SV_Position;
};

void main_inner()
{
    gl_Position = mul(float4(in_position, 1.0f), _19_mvp);
    out_color = in_color;
}

SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
    in_position = stage_input.in_position;
    in_color = stage_input.in_color;
    main_inner();
    SPIRV_Cross_Output stage_output;
    stage_output.gl_Position = gl_Position;
    stage_output.out_color = out_color;
    return stage_output;
}
