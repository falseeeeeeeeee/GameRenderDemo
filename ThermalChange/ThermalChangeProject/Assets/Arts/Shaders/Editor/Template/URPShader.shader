Shader "URP/#NAME#"
{
    Properties 
    {
        [MainColor] _BaseColor ("Base Color", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseMap ("Base Map", 2D) = "white" {}

        [Enum(UnityEngine.Rendering.CullMode)] _CullMode ("Cull Mode", Float) = 2
    }
    SubShader 
    {
        Tags 
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
        }

        Pass {
            Name "FORWARD"
            Tags { "LightMode" = "UniversalForward" } 

            Cull [_CullMode]
            
			HLSLPROGRAM
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x	
            #pragma target 2.0

            #pragma multi_compile_instancing

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
			uniform half4 _BaseColor;
			uniform float4 _BaseMap_ST;
            CBUFFER_END
			
			TEXTURE2D(_BaseMap);	SAMPLER(sampler_BaseMap);
			
            struct Attributes
			{
                float4 positionOS : POSITION;
                float2 texcoord : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
			{
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            Varyings vert (Attributes input)
			{
                Varyings output;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);

                output.positionHCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);

                return output;
            }

            half4 frag(Varyings input) : SV_Target
			{
                UNITY_SETUP_INSTANCE_ID(input);

                float4 var_BaseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);                         
                half3 color =  var_BaseMap.rgb * _BaseColor.rgb;
                half alpha = var_BaseMap.a * _BaseColor.a;
                
                return half4(color, alpha);
            } 
            ENDHLSL
        }
    }
}
