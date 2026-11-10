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
        [Toggle(_WATER_FRAGMENT_NORMALS)] _FragmentNormals ("Fragment Normals", Float) = 0
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
            #pragma target 5.0 _WATER_FRAGMENT_NORMALS
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature_local_fragment _ _WATER_FRAGMENT_NORMALS

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
                float _FragmentNormals;
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
                float2 waveXZ : TEXCOORD3;
            };

            float2 WaveDirection(int index)
            {
                // 只用波的编号作为种子，方向不随位置或时间变化。
                float2 seed = float2(index, index) * 0.2;
                // 在 D3D 的片元变体中约束哈希的浮点运算，保持顶点路径原样。
                #if defined(SHADER_API_D3D11) && defined(_WATER_FRAGMENT_NORMALS)
                    precise
                #endif
                float random01 = frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453);
                float angle = radians(random01 * 360.0);
                return float2(cos(angle), sin(angle));
            }

            void EvaluateWaves(float2 p, float time, out float height, out float2 gradientXZ)
            {
                float amplitude = _WaveInt * 0.1;
                float frequency = _WaveFreq;
                height = 0.0;
                gradientXZ = 0.0;
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
            }

            float3 WaveNormalWS(float2 gradientXZ)
            {
                float3 normalOS = normalize(float3(-gradientXZ.x, 1.0, -gradientXZ.y));
                return TransformObjectToWorldNormal(normalOS);
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 positionOS = IN.positionOS;

                // 1. 两种法线模式都使用相同的顶点位移。
                float height;
                float2 gradientXZ;
                EvaluateWaves(positionOS.xz, _Time.y * _WaveSpeed, height, gradientXZ);
                positionOS.y += height;

                OUT.positionWS = TransformObjectToWorld(positionOS);
                OUT.positionCS = TransformWorldToHClip(OUT.positionWS);
                // 2. 分别传递顶点法线和用于片元求导的物体空间 XZ。
                OUT.normalWS = WaveNormalWS(gradientXZ);
                OUT.waveXZ = IN.positionOS.xz;
                OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // 3. 对照：在片元位置重算坡度，或继续使用插值后的顶点法线。
                #if defined(_WATER_FRAGMENT_NORMALS)
                    float unusedHeight;
                    float2 gradientXZ;
                    EvaluateWaves(IN.waveXZ, _Time.y * _WaveSpeed, unusedHeight, gradientXZ);

                    float3 normalWS = WaveNormalWS(gradientXZ);
                #else
                    float3 normalWS = normalize(IN.normalWS);
                #endif

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
