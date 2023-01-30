Shader "URP/Base/ShadowPlan"
{
    Properties
    {
        [HDR] _BaseColor("Shadow Color", Color) = (0.0, 0.0, 0.0, 0.8)
        //[Toggle] _UseAddLight("Use AddLight Shadows ?", Int) = 0
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode ("Cull Mode", Float) = 2
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Transparent" 
            "Queue" = "Transparent"
        }

        Pass
        {
            Name "Forward"
            Tags { "LightMode" = "UniversalForward" } 

            Blend SrcAlpha OneMinusSrcAlpha
            //Blend One OneMinusSrcAlpha
            Cull [_CullMode]

            HLSLPROGRAM
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x	
            #pragma target 2.0

            #pragma shader_feature _USEADDLIGHT_ON

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT

            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
             #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            CBUFFER_START(UnityPerMaterial)
            uniform float4 _BaseColor;
            uniform float4 _BaseMap_ST;
            CBUFFER_END

            TEXTURE2D(_BaseMap);        SAMPLER(sampler_BaseMap);

            struct Attributes
			{
                float4 positionOS : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
			{
                float4 positionCS  : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            Varyings vert (Attributes input)
            {
                Varyings output;

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                
                return output;
            }

            float4 frag(Varyings input) : SV_Target
            {
                float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS.xyz);
                
                Light mainlight = GetMainLight(shadowCoord);
                float3 mainlightColor = mainlight.color;  
                float3 mainlightDir = normalize(mainlight.direction);
                float mainlightShadow = mainlight.distanceAttenuation * mainlight.shadowAttenuation;
                /*
                #ifdef _USEADDLIGHT_ON
                    float addlightShadow = 0.0;
                    uint pixelLightCount = GetAdditionalLightsCount();
                    for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++ lightIndex)
                    {
                        Light addlight = GetAdditionalLight(lightIndex, shadowCoord);
                        float3 addlightColor = addlight.color;  
                        float3 addlightDir = normalize(addlight.direction);
                        addlightShadow = addlight.distanceAttenuation * addlight.shadowAttenuation;
                    }
                #endif
                float lightShadow = mainlightShadow + addlightShadow;
                float ShadowAlpha = 1 - saturate(lightShadow);
                */
                float ShadowAlpha = 1 - saturate(mainlightShadow);
                return float4(_BaseColor.rgb, _BaseColor.a * ShadowAlpha);
            }
            ENDHLSL
        }
        
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
        	
        	Cull Off
            
            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            #pragma vertex vert
            #pragma fragment frag
            
            float3 _LightDirection;
            float3 _LightPosition;

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
            };

            float4 GetShadowPositionHClip(Attributes input)
            {
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);

                #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                    float3 lightDirectionWS = normalize(_LightPosition - positionWS);
                #else
                    float3 lightDirectionWS = _LightDirection;
                #endif

                float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));

                #if UNITY_REVERSED_Z
                    positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #else
                    positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #endif

                return positionCS;
            }

            Varyings vert(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
            	
                output.positionCS = GetShadowPositionHClip(input);
                return output;
            }

            half4 frag(Varyings input) : SV_TARGET
            {
                return 0;
            }

            ENDHLSL
        }
    }
}
    
