#ifndef MY_LITPRO_FORWARDPASS_INCLUDED
#define MY_LITPRO_FORWARDPASS_INCLUDED

// 引用库文件
#include "../HLSLInclude/LightingPro.hlsl"

// GLES2 具有有限数量的插值器，如果使用了视差贴图，并且在PC上运行（不是在移动设备上运行），则viewDirTS在顶点着色器中计算
#if defined(_PARALLAXMAP) && !defined(SHADER_API_GLES)
#define REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR
#endif

#if (defined(_NORMALMAP) || defined(_ANISOTROPY) || (defined(_PARALLAXMAP) && !defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR))) || defined(_DETAIL)
#define REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR
#endif

// -------------------------------------
// 属性结构体
struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT;
    float2 texcoord     : TEXCOORD0;
    float2 staticLightmapUV   : TEXCOORD1;
    float2 dynamicLightmapUV  : TEXCOORD2;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

// 变体结构体
struct Varyings
{
    float2 uv : TEXCOORD0;

    #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)  
    float3 positionWS                : TEXCOORD1;
    #endif

    half3 normalWS                  : TEXCOORD2;
    #if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
    half4 tangentWS                 : TEXCOORD3;    // xyz: tangent, w: sign
    #endif
    float3 viewDirWS                : TEXCOORD4;


    #ifdef _ADDITIONAL_LIGHTS_VERTEX
    half4 fogFactorAndVertexLight   : TEXCOORD5; // x: fogFactor, yzw: vertex light
    #else
    half  fogFactor                 : TEXCOORD5;
    #endif

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    float4 shadowCoord              : TEXCOORD6;
    #endif

    #if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
    half3 viewDirTS                 : TEXCOORD7;
    #endif

    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 8);
    #ifdef DYNAMICLIGHTMAP_ON
    float2  dynamicLightmapUV : TEXCOORD9; // Dynamic lightmap UVs
    #endif

    float4 positionCS               : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

// -------------------------------------
// 初始化输入数据函数
void InitializeInputDataExtended(Varyings input, half3 normalTS, out InputDataExtended inputData)
{
    inputData = (InputDataExtended)0;

    #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
        inputData.positionWS = input.positionWS;
    #endif

    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
    
    #if defined(_NORMALMAP) || defined(_ANISOTROPY)
        float sgn = input.tangentWS.w;      // should be either +1 or -1
        float3 bitangent = sgn * cross(input.normalWS.xyz, input.tangentWS.xyz);
        half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz);

        #ifdef _ANISOTROPY
            inputData.tangentWS = input.tangentWS.xyz;
            inputData.bitangentWS = bitangent;
        #endif
    
        #if defined(_NORMALMAP)
            inputData.tangentToWorld = tangentToWorld;
        #endif
            inputData.normalWS = TransformTangentToWorld(normalTS, tangentToWorld);
    #else
        inputData.normalWS = input.normalWS;
    #endif



    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    inputData.viewDirectionWS = viewDirWS;

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        inputData.shadowCoord = input.shadowCoord;
    #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
        inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
    #else
        inputData.shadowCoord = float4(0, 0, 0, 0);
    #endif
    
    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactorAndVertexLight.x);
        inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
    #else
        inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactor);
    #endif

    #if defined(DYNAMICLIGHTMAP_ON)
        inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.dynamicLightmapUV, input.vertexSH, inputData.normalWS);
    #else
        inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, inputData.normalWS);
    #endif

    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);

}

///////////////////////////////////////////////////////////////////////////////
//                  Vertex and Fragment functions                            //
///////////////////////////////////////////////////////////////////////////////

// Used in Standard (Physically Based) shader
Varyings LitPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
    
    // 准备：顶点信息 + 法线信息 + 顶点光照 + 全局雾效 + UV
    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
    
    half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
    
    half fogFactor = 0;
    #if !defined(_FOG_FRAGMENT)
        fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
    #endif

    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);

    // normalWS + tangentWS + viewDirTS
    output.normalWS = normalInput.normalWS;     //已归一化
    
    #if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR) || defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
        real sign = input.tangentOS.w * GetOddNegativeScale();
        half4 tangentWS = half4(normalInput.tangentWS.xyz, sign);
    #endif
    
    #if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
        output.tangentWS = tangentWS;
    #endif

    #if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
        half3 viewDirWS = GetWorldSpaceNormalizeViewDir(vertexInput.positionWS);
        half3 viewDirTS = GetViewDirectionTangentSpace(tangentWS, output.normalWS, viewDirWS);
        output.viewDirTS = viewDirTS;
    #endif

    // 静态光照 + 动态光照 + 球谐函数 + 额外光源 + 全局雾效
    OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);
    #ifdef DYNAMICLIGHTMAP_ON
        output.dynamicLightmapUV = input.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
    #endif
    OUTPUT_SH(output.normalWS.xyz, output.vertexSH);
    #ifdef _ADDITIONAL_LIGHTS_VERTEX
        output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
    #else
        output.fogFactor = fogFactor;
    #endif

    // positionWS + shadowCoord + positionCS
    #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
        output.positionWS = vertexInput.positionWS;
    #endif

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        output.shadowCoord = GetShadowCoord(vertexInput);
    #endif

    output.positionCS = vertexInput.positionCS;

    return output;
}

// Used in Standard (Physically Based) shader
half4 LitPassFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    // 视差高度图
    #if defined(_PARALLAXMAP) && defined(_PARALLAX)
        #if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
            half3 viewDirTS = input.viewDirTS;
        #else
            half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
            half3 viewDirTS = GetViewDirectionTangentSpace(input.tangentWS, input.normalWS, viewDirWS);
        #endif
        ApplyPerPixelDisplacement(viewDirTS, input.uv);
    #endif

    // 初始化Surface属性
    SurfaceDataExtended surfaceData;
    InitializeSurfaceDataExtended(input.normalWS, input.positionWS, input.uv, surfaceData);

    // 初始化初始化输入数据
    InputDataExtended inputData;
    InitializeInputDataExtended(input, surfaceData.normalTS, inputData);
    SETUP_DEBUG_TEXTURE_DATA(inputData, input.uv, _BaseMap);

    // BRDF函数
    half4 color = FragmentLitExtended(inputData, surfaceData);

    color.rgb = MixFog(color.rgb, inputData.fogCoord);
    color.a = OutputAlpha(color.a, _Surface);

    return color;
}
#endif
