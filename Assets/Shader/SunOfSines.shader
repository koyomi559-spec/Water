Shader "Water/SumOfSines"
{
    Properties
    {
        [MainTexture] _MainTex ("MainTexture", 2D) = "white" {}
        [MainColor] _MainColor ("Main Color", Color) = (1,1,1,1)
        _WaveInt ("Wave Intensity", Float) = 0.5
        _WaveFreq ("Wave Frequency", Float) = 2
        _WaveSpeed ("Wave Speed", Float) = 4
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
            Tags { "LightMode" = "UniversalForward" }

            ZWrite On
            ZTest LEqual
            Cull Back

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4 _MainColor;
                float4 _MainTex_ST;
                float _WaveInt;
                float _WaveFreq;
                float _WaveSpeed;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            struct Attributes
            {
                float3 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 positionOS = IN.positionOS;

                // 1. 正弦波位移：沿 X 取样，只改变 Y。
                float phase = positionOS.x * _WaveFreq + _Time.y * _WaveSpeed;
                positionOS.y += _WaveInt * sin(phase);

                // 2. X 方向的斜率决定坡面法线；Z 方向没有高度变化。
                float d_dx = _WaveInt * _WaveFreq * cos(phase);
                float3 normalOS = normalize(float3(-d_dx, 1.0, 0.0));

                OUT.positionCS = TransformObjectToHClip(positionOS);
                OUT.normalWS = TransformObjectToWorldNormal(normalOS);
                OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // 3. 用主光漫反射显示坡面朝向。
                float3 normalWS = normalize(IN.normalWS);
                Light light = GetMainLight();
                float nDotL = saturate(dot(normalWS, light.direction));

                half4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);
                half3 diffuse = _MainColor.rgb * texColor.rgb * light.color * nDotL;
                return half4(diffuse, texColor.a);
            }
            ENDHLSL
        }
    }
}
