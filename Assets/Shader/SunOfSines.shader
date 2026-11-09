Shader "Water/SumOfSines"
{
    Properties
    {
        [MainTexture] _MainTex ("MainTexture", 2D) = "white" {}
        [MainColor] _MainColor ("Main Color", Color) = (1,1,1,1)
        _WaveInt ("Wave Intensity", Float) = 0.5
        _WaveFreq ("Wave Frequency", Float) = 2
        _WaveSpeed ("Wave Speed", Float) = 4
        _WaveAmount ("Wave Amount", Integer) = 1
        _FBM_Int ("FBM Intensity", Range(0, 1)) = 0.82
        _FBM_Fre ("FBM Frequency", Range(1, 2)) = 1.18
        _SpecularStrength ("Specular Strength", Range(0, 1)) = 0.35
        _SpecularPower ("Specular Power", Range(1, 256)) = 64
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
                int _WaveAmount;
                float _FBM_Int;
                float _FBM_Fre;
                float _SpecularStrength;
                float _SpecularPower;
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
                float3 positionWS : TEXCOORD2;
            };

            float2 WaveDirection(int index)
            {
                // 只用波的编号作为种子，方向不随位置或时间变化。
                float2 seed = float2(index, index) * 0.2;
                float random01 = frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453);
                float angle = radians(random01 * 360.0);
                return float2(cos(angle), sin(angle));
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 positionOS = IN.positionOS;

                // 1. 沿各波的方向取样，累加高度和 XZ 坡度。
                float2 p = positionOS.xz;
                float time = _Time.y * _WaveSpeed;
                float amplitude = _WaveInt * 0.1;
                float frequency = _WaveFreq;
                float height = 0.0;
                float2 gradientXZ = 0.0;
                int count = clamp(_WaveAmount, 0, 128);

                for (int i = 1; i <= count; i++)
                {
                    float2 direction = WaveDirection(i);
                    float phase = frequency * dot(direction, p) + time;
                    height += amplitude * sin(phase);
                    gradientXZ += amplitude * frequency * cos(phase) * direction;

                    // 当前波计算完成后，再更新下一条波的参数。
                    amplitude *= _FBM_Int;
                    frequency *= _FBM_Fre;
                }

                // 2. 用叠加后的总高度移动顶点，并用总坡度重建法线。
                positionOS.y += height;
                float3 normalOS = normalize(float3(-gradientXZ.x, 1.0, -gradientXZ.y));

                OUT.positionWS = TransformObjectToWorld(positionOS);
                OUT.positionCS = TransformWorldToHClip(OUT.positionWS);
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

                // 4. 法线越接近光线与视线的半角方向，高光越强。
                float3 viewDirWS = GetWorldSpaceNormalizeViewDir(IN.positionWS);
                float3 halfDirWS = SafeNormalize(light.direction + viewDirWS);
                float nDotH = saturate(dot(normalWS, halfDirWS));
                half3 specular = light.color * (_SpecularStrength * pow(nDotH, _SpecularPower) * nDotL);

                return half4(diffuse + specular, texColor.a);
            }
            ENDHLSL
        }
    }
}
