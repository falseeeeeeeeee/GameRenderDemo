Shader "URP/Base/MyLitPro"
{
    Properties
    {
        // Surface Options
        [HideInInspector] _WorkflowMode("WorkflowMode", Float) = 1.0
        [HideInInspector] _Surface("__surface", Float) = 0.0
        [HideInInspector] _Blend("__blend", Float) = 0.0
        [HideInInspector] _SrcBlend("__src", Float) = 1.0
        [HideInInspector] _DstBlend("__dst", Float) = 0.0
        [HideInInspector] _ZWrite("__zw", Float) = 1.0
        [HideInInspector] _Cull("__cull", Float) = 2.0
        [HideInInspector] _AlphaClip("__clip", Float) = 0.0
        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

        // Default Surface Inputs
        _BaseMap("Albedo", 2D) = "white" {}
        _BaseColor("Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
        _MetallicGlossMap("Metallic(RRR) Gloss(A) Map", 2D) = "white" {}
        _SpecColor("Specular", Color) = (0.2, 0.2, 0.2)
        _SpecGlossMap("Specular(RGB) Gloss(A)", 2D) = "white" {}
        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5
        _BumpScale("Scale", Float) = 1.0
        _BumpMap("Normal Map", 2D) = "bump" {}
        _OcclusionStrength("Strength", Range(0.0, 1.0)) = 1.0
        _OcclusionMap("Occlusion(R)", 2D) = "white" {}
        [HDR] _EmissionColor("Color", Color) = (0,0,0)
        _EmissionMap("Emission", 2D) = "white" {}
        
        // Height
        [ToggleOff] _EnableParallax("Height", Float) = 0.0
        _ParallaxScale("Scale", Range(0.005, 0.08)) = 0.005
        _ParallaxMap("Height Map(G)", 2D) = "black" {}
        
        // Anisotropy
        [ToggleOff] _EnableAnisotropy("Anisotropy", Float) = 0.0
        _AnisotropyMap("Anisotropy(R)", 2D) = "white" {}
        _Anisotropy("Anisotropy", Range(-1.0, 1.0)) = 0.0
        _DirectionMap("Direction(XYZ)", 2D) = "white" {}

        // Clear Coat
        [ToggleOff] _EnableClearCoat("Clear Coat", Float) = 0.0
        _ClearCoatMap("Clear Coat", 2D) = "white" {}
        _ClearCoat("Clear Coat", Range(0.0, 1.0)) = 1.0
        _ClearCoatSmoothness("Clear Coat Smoothness", Range(0.0, 1.0)) = 0.5

        // Subsurface Scattering
        [ToggleOff] _EnableSubsurface("Enable Subsurface Scattering", Float) = 0.0
        _SubsurfaceMap("Subsurface Color", 2D) = "white" {}
        _SubsurfaceColor("Subsurface Color", Color) = (1,1,1,1)

        // Transmission
        [ToggleOff] _EnableTransmission("Enable Transmission", Float) = 0.0
        _ThicknessMap("Thickness", 2D) = "black" {}
        _Thickness("Thickness", Range(0.0, 1.0)) = 0.5
        
        // Ramp
        _FlowMap("FlowMap", 2D) = "white" {}
        _FlowSpeed ("Flow Speed", Float) = 1 
        _FlowUVDir ("Flow UV Dir", Vector) = (0.5, 0.1, 0.0, 0.0)
        [NoScaleOffset] _RampMap ("Ramp Map",2D) = "white" {}
        _RampStrength ("Ramp Strength", Float) = 1 
        _RampXAxisOffset ("Ramp X Axis Offset", Range(0, 1)) = 0.333
        _RampXAxisNoiseStrength("Ramp X Axis Noise Strength", Range(0, 1)) = 1.0
        _FresnelPower ("Fresnel Power", Float) = 1 

        // Advanced Options
        [ToggleUI] _ReceiveShadows("Receive Shadows", Float) = 1.0
        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [ToggleOff] _EnvironmentReflections("Environment Reflections", Float) = 1.0
        [HideInInspector] _QueueOffset("Queue offset", Float) = 0.0
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque" 
            "RenderPipeline" = "UniversalPipeline" 
            "UniversalMaterialType" = "Lit" 
            "IgnoreProjector" = "True" 
        }
        LOD 300
        
        // ------------------------------------------------------------------
        // Forward pass. Shades all light in a single pass. GI + emission + Fog
        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            // 自定义渲染命令
            Blend[_SrcBlend][_DstBlend]
            ZWrite[_ZWrite]
            Cull[_Cull]
            
            HLSLPROGRAM
            //--------------------------------------
            // 目标平台
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x	
            #pragma target 2.0
            
            //--------------------------------------
            // GPU合批
            #pragma multi_compile_instancing
            
            //--------------------------------------
            // 材质宏
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _EMISSION
            #pragma shader_feature_local _OCCLUSIONMAP
            #pragma shader_feature_local _METALLICSPECGLOSSMAP
            #pragma shader_feature_local _SPECULAR_SETUP
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local _ALPHAPREMULTIPLY_ON
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF
            #pragma shader_feature_local _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local _ENVIRONMENTREFLECTIONS_OFF

            // 费性能的材质宏
            #pragma shader_feature _PARALLAX
            #pragma shader_feature _PARALLAXMAP
            #pragma shader_feature _ANISOTROPY
            #pragma shader_feature _ANISOTROPYMAP
            #pragma shader_feature _DIRECTIONMAP
            #pragma shader_feature _CLEARCOAT
            #pragma shader_feature _CLEARCOATMAP
            #pragma shader_feature _SUBSURFACE
            #pragma shader_feature _SUBSURFACEMAP
            #pragma shader_feature _TRANSMISSION
            #pragma shader_feature _THICKNESSMAP
            
            //--------------------------------------
            // URP 宏
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

            // -------------------------------------
            // Unity 宏
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fog
            
            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment

            #include "MyLitProInput.hlsl"
            #include "MyLitProForwardPass.hlsl"

            ENDHLSL
        }
        
        // ------------------------------------------------------------------
        // ShadowCaster
        // UsePass "Universal Render Pipeline/Lit/ShadowCaster"
        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}
            
            // 自定义渲染命令
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            //--------------------------------------
            // 目标平台
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            //--------------------------------------
            // GPU合批
            #pragma multi_compile_instancing

            // -------------------------------------
            // 材质宏
            #pragma shader_feature_local_fragment _ALPHATEST_ON

            // -------------------------------------
            // URP宏

            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "MyLitProInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            
            float3 _LightDirection;
            float3 _LightPosition;

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float2 texcoord     : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float2 uv           : TEXCOORD0;
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

            Varyings ShadowPassVertex(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);

                output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                output.positionCS = GetShadowPositionHClip(input);
                return output;
            }

            half4 ShadowPassFragment(Varyings input) : SV_TARGET
            {
                Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
                return 0;
            }

            ENDHLSL
        }
        
        // ------------------------------------------------------------------
        // UsePass "Universal Render Pipeline/Lit/DepthOnly"
        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            //--------------------------------------
            // GPU 合批
            #pragma multi_compile_instancing

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // 材质宏
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            #include "MyLitProInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 position     : POSITION;
                float2 texcoord     : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float2 uv           : TEXCOORD0;
                float4 positionCS   : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings DepthOnlyVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                output.positionCS = TransformObjectToHClip(input.position.xyz);
                return output;
            }

            half4 DepthOnlyFragment(Varyings input) : SV_TARGET
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
                return 0;
            }

            ENDHLSL
        }
        
        // ------------------------------------------------------------------
        UsePass "Universal Render Pipeline/Lit/Meta"
       
    }
    FallBack "Universal Render Pipeline/Lit"
    CustomEditor "Feng.Shading.Editor.LitProGUI"
}
