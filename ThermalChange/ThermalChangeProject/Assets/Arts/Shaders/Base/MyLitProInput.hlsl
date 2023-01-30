#ifndef My_LITPRO_INPUT_INCLUDED
#define My_LITPRO_INPUT_INCLUDED

// -------------------------------------
// 引用库文件
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ParallaxMapping.hlsl"

/// -------------------------------------
// Cbuffer
CBUFFER_START(UnityPerMaterial)
float4 _BaseMap_ST;
half4 _BaseColor;
half4 _SpecColor;
half4 _EmissionColor;
half _Cutoff;
half _Smoothness;
half _Metallic;
half _BumpScale;

half _ParallaxScale;
half _OcclusionStrength;
half _Anisotropy;
half _ClearCoat;
half _ClearCoatSmoothness;
half3 _SubsurfaceColor;
half _Thickness;
half _Surface;

float4 _FlowMap_ST;
half4 _FlowUVDir;
half _FlowSpeed;
half _RampStrength;
half _RampXAxisOffset;
half _RampXAxisNoiseStrength;
half _FresnelPower;
CBUFFER_END

// 采样贴图
// _BaseMap_TexelSize/_BaseMap_MipInfo,
// _BaseMap/_BumpMap/_EmissionMap 在SurfaceInput里采样
TEXTURE2D(_ParallaxMap);        SAMPLER(sampler_ParallaxMap);
TEXTURE2D(_OcclusionMap);       SAMPLER(sampler_OcclusionMap);
TEXTURE2D(_MetallicGlossMap);   SAMPLER(sampler_MetallicGlossMap);
TEXTURE2D(_SpecGlossMap);       SAMPLER(sampler_SpecGlossMap);
TEXTURE2D(_AnisotropyMap);      SAMPLER(sampler_AnisotropyMap);
TEXTURE2D(_DirectionMap);       SAMPLER(sampler_DirectionMap);
TEXTURE2D(_ClearCoatMap);       SAMPLER(sampler_ClearCoatMap);
TEXTURE2D(_SubsurfaceMap);      SAMPLER(sampler_SubsurfaceMap);
TEXTURE2D(_ThicknessMap);       SAMPLER(sampler_ThicknessMap);
TEXTURE2D(_FlowMap);       SAMPLER(sampler_FlowMap);
TEXTURE2D(_RampMap);       SAMPLER(sampler_RampMap);


// 工作流选择采样
#ifdef _SPECULAR_SETUP
    #define SAMPLE_METALLICSPECULAR(uv) SAMPLE_TEXTURE2D(_SpecGlossMap, sampler_SpecGlossMap, uv)
#else
    #define SAMPLE_METALLICSPECULAR(uv) SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, uv)
#endif


// -------------------------------------
// 拓展SurfaceData结构体
struct SurfaceDataExtended
{
    half3 albedo;
    half3 specular;
    half  metallic;
    half  smoothness;
    half3 normalTS;
    half3 emission;
    half  occlusion;
    half  alpha;
    #ifdef _ANISOTROPY
        half anisotropy;
        half3 direction;
    #endif
    #ifdef _CLEARCOAT
        half clearCoat;
        half clearCoatSmoothness;
    #endif
    #ifdef _SUBSURFACE
        half3 subsurfaceColor;
    #endif
    #ifdef _TRANSMISSION
        half thickness;
    #endif
};

// -------------------------------------
// 采样函数
// 采样金属/高光（RGB），光泽贴图（A）；或不使用贴图
half4 SampleMetallicSpecGloss(float2 uv, half albedoAlpha)
{
    half4 specGloss;

    #ifdef _METALLICSPECGLOSSMAP
        specGloss = half4(SAMPLE_METALLICSPECULAR(uv));
        #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            specGloss.a = albedoAlpha * _Smoothness;
        #else
            specGloss.a *= _Smoothness;
        #endif
    #else // _METALLICSPECGLOSSMAP
        #if _SPECULAR_SETUP
            specGloss.rgb = _SpecColor.rgb;
        #else
            specGloss.rgb = _Metallic.rrr;
        #endif

        #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            specGloss.a = albedoAlpha * _Smoothness;
        #else
            specGloss.a = _Smoothness;
        #endif
    #endif

    return specGloss;
}

// 采样环境光遮蔽贴图（R）；或不使用贴图
half SampleOcclusion(float2 uv)
{
    #ifdef _OCCLUSIONMAP
        // TODO：通过 SHADER_QUALITY 等级（低、中、高）来控制此类
        #if defined(SHADER_API_GLES)
            return SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g;
        #else
            half occ = SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g;
            return LerpWhiteTo(occ, _OcclusionStrength);
        #endif
    #else
        return half(1.0);
    #endif
}

// 采样各向异性贴图(R)
half SampleAnisotropy(float2 uv)
{
    #ifdef _ANISOTROPYMAP
        half anisotropy = SAMPLE_TEXTURE2D(_AnisotropyMap, sampler_AnisotropyMap, uv).r;
        return anisotropy * _Anisotropy;
    #else
        return _Anisotropy;
    #endif
}

// 采样方向贴图 / (1,0,0)
half3 SampleDirection(float2 uv)
{
    #ifdef _DIRECTIONMAP
        half3 direction = SAMPLE_TEXTURE2D(_DirectionMap, sampler_DirectionMap, uv).xyz;
        return direction;
    #else
        return half3(1, 0, 0);
    #endif
}

// 采样清漆贴图(R：mask, G：smoothness)）；或不使用贴图
half2 SampleClearCoat(float2 uv)
{
    half2 clearCoatMaskSmoothness = half2(_ClearCoat, _ClearCoatSmoothness);

    #if defined(_CLEARCOAT)
        clearCoatMaskSmoothness *= SAMPLE_TEXTURE2D(_ClearCoatMap, sampler_ClearCoatMap, uv).rg;
    #endif

    return clearCoatMaskSmoothness;
}

// 采样SSS贴图
half3 SampleSubsurface(float2 uv)
{
    #ifdef _SUBSURFACEMAP
        half4 subsurface = SAMPLE_TEXTURE2D(_SubsurfaceMap, sampler_SubsurfaceMap, uv);
        return subsurface.rgb * _SubsurfaceColor.rgb;
    #else
        return _SubsurfaceColor;
    #endif
}

// 采样透射图
half SampleTransmission(float2 uv)
{
    #ifdef _THICKNESSMAP
        half thickness = SAMPLE_TEXTURE2D(_ThicknessMap, sampler_ThicknessMap, uv).r;
        return lerp(thickness, 1, _Thickness);
    #else
        return _Thickness;
    #endif
}

// 视差高度图（G）函数
void ApplyPerPixelDisplacement(half3 viewDirTS, inout float2 uv)
{
    #if defined(_PARALLAXMAP)
        uv += ParallaxMapping(TEXTURE2D_ARGS(_ParallaxMap, sampler_ParallaxMap), viewDirTS, _ParallaxScale, uv);
    #endif
}

// Ramp图
half4 SampleRamp(float2 uv, float normalTS, float3 normalWS, float3 positionWS)
{
    normalWS = normalize(normalWS);

    float3 viewDirWS = normalize(_WorldSpaceCameraPos.xyz - positionWS);
    float fresnel = pow(saturate(dot(normalWS, viewDirWS)), _FresnelPower);
    float fresnel2 = 1-pow(dot(normalize(normalWS), viewDirWS), 0.25);

    // FlowMap
    float2 flowUV  = (uv + _FlowUVDir.xy) * _FlowMap_ST.xy + _FlowMap_ST.zw;
    float3 flowDir = SAMPLE_TEXTURE2D(_FlowMap, sampler_FlowMap, flowUV).xyz * 2 - 1;
    flowDir *= _FlowSpeed;

    // Ramp
    float RampXAxis = fresnel + _RampXAxisOffset + normalWS * _RampXAxisNoiseStrength;
    //float RampYAxis = saturate(fresnel - fresnel2 * 0.95 + 0.4 -  flowDir.xy * 0.8);
    //float RampYAxis = saturate(0.4 - flowDir.xy * 0.8);
    float RampYAxis = saturate(flowDir.xy);

    float2 rampTexUV = float2(RampXAxis, RampYAxis);
    float4 rampColor = SAMPLE_TEXTURE2D(_RampMap, sampler_RampMap, rampTexUV) * _RampStrength;

    //float4 mask = lerp(rampColor, 1, fresnel2);
    return rampColor;
}


// -------------------------------------
// 初始化Surface属性函数
inline void InitializeSurfaceDataExtended(float3 normalWS, float3 positionWS, float2 uv, out SurfaceDataExtended outSurfaceData)
{
    outSurfaceData.normalTS = SampleNormal(uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);

    half4 rampColor = SampleRamp(uv, outSurfaceData.normalTS, normalWS, positionWS);
    half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
    outSurfaceData.alpha = Alpha(albedoAlpha.a, _BaseColor, _Cutoff);

    half4 specGloss = SampleMetallicSpecGloss(uv, albedoAlpha.a);
    outSurfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb * rampColor;
    //outSurfaceData.albedo = rampColor;

    #if _SPECULAR_SETUP
        outSurfaceData.metallic = half(1.0);
        outSurfaceData.specular = specGloss.rgb;
    #else
        outSurfaceData.metallic = specGloss.r;
        outSurfaceData.specular = half3(0.0, 0.0, 0.0);
    #endif

    outSurfaceData.smoothness = specGloss.a;
    outSurfaceData.occlusion = SampleOcclusion(uv);
    outSurfaceData.emission = SampleEmission(uv, _EmissionColor.rgb, TEXTURE2D_ARGS(_EmissionMap, sampler_EmissionMap));
    //outSurfaceData.emission += rampColor;
    #ifdef _ANISOTROPY
        outSurfaceData.anisotropy = SampleAnisotropy(uv);
        outSurfaceData.direction = SampleDirection(uv);
    #endif
    
    #if _CLEARCOAT
        half2 clearCoat = SampleClearCoat(uv);
        outSurfaceData.clearCoat       = clearCoat.r;
        outSurfaceData.clearCoatSmoothness = clearCoat.g;
    #endif
    
    #ifdef _SUBSURFACE
        outSurfaceData.subsurfaceColor = SampleSubsurface(uv);
    #endif
    #ifdef _TRANSMISSION
        outSurfaceData.thickness = SampleTransmission(uv);
    #endif
    
}

#endif