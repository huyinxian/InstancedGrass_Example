Shader "StylizedLitGrass_Dynamic"
{
    Properties
    {
        _Color ("Color", color) = (1, 1, 1, 1)
        _Ambient ("Ambient", color) = (1, 1, 1, 1)
        _FresnelIntensity ("Fresnel Intensity", range(0, 1)) = 0.2
        _FresnelPow ("Fresnel Pow", range(1, 64)) = 20
        _Gloss ("Gloss", range(1, 64)) = 8
        _Spread ("Spread", range(0, 1)) = 1
        _WindFrecuency ("Wind Frecuency", Range(0.001, 100)) = 1
        _WindStrength ("Wind Strength", Range(0, 2)) = 0.3
        _StepGrassStrength ("Step Grass Strength", Range(0, 2)) = 1
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalRenderPipeline"
        }

        Cull Off

        Pass
        {
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_instancing
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                half4 color : COLOR;
                float2 uv0 : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
                half4 color : TEXCOORD0;
                half4 diffColor : TEXCOORD1;
                half4 specColor : TEXCOORD2;
                half3 fresnelColor : TEXCOORD3;
                float3 positionWS : TEXCOORD4;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            CBUFFER_START(UnityPerMaterial)
                half4 _Color;
                half4 _Ambient;
                float _FresnelIntensity;
                float _FresnelPow;
                float _Gloss;
                float _Spread;
                float _WindFrecuency;
                float _WindStrength;
                float _StepGrassStrength;
            CBUFFER_END

            TEXTURE2D(_InteractiveTex); SAMPLER(sampler_InteractiveTex);

            uniform float4 _InteractiveCamData;

            float rand(float2 n)
            {
                return frac(sin(dot(n, float2(12.9898, 4.1414))) * 43758.5453);
            }

            float noise2d(float2 p)
            {
                float2 ip = floor(p);
                float2 u = frac(p);
                u = u * u * (3.0 - 2.0 * u);
                
                float res = lerp(
                    lerp(rand(ip), rand(ip + float2(1.0, 0.0)), u.x),
                    lerp(rand(ip + float2(0.0, 1.0)), rand(ip + float2(1.0, 1.0)), u.x), u.y
                );
                return res * res;
            }

            v2f vert(appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);

                // uv1存储了每颗草的锚点
                float3 localPivot = 0;
                localPivot.xz = float2(-v.uv1.x, v.uv1.y);
                float3 worldPivot = TransformObjectToWorld(localPivot);
                // 根据草和RT相机的距离，计算出采样踩草RT的UV坐标：(草的位置 - RT相机位置) / 相机视野大小
                half4 interactive = SAMPLE_TEXTURE2D_LOD(_InteractiveTex, sampler_InteractiveTex, float2((worldPivot.xz - _InteractiveCamData.xz + _InteractiveCamData.y) / (2 * _InteractiveCamData.y)), 0);

                // 切草
                v.vertex.y *= interactive.a;
                
                float3 worldPos = TransformObjectToWorld(v.vertex);
                Light mainLight = GetMainLight();
                float3 worldLightDir = mainLight.direction;
                float3 worldViewDir = normalize(GetCameraPositionWS() - worldPos);
                float3 terrainNormal = TransformObjectToWorldNormal(float3(0, 1, 0));
                float3 worldNormal = TransformObjectToWorldNormal(v.normal);

                // Diffuse
                float NdotL = saturate(dot(terrainNormal, worldLightDir));
                o.diffColor = lerp(_Ambient, _Color * half4(mainLight.color, 1), NdotL);

                // Specular
                float3 halfDir = normalize(worldLightDir + worldViewDir);
                float NdotH = saturate(dot(halfDir, terrainNormal));
                o.specColor.rgb = mainLight.color * pow(NdotH, _Gloss) * 0.5;
                // 模型草的顶点法线一律朝向左边，因此法线与光源方向的点乘结果可以用来判断光源在草的左边还是右边
                o.specColor.a = dot(worldNormal, worldLightDir);

                // Fresnel
                float fresnel = 1 - saturate(dot(worldViewDir, terrainNormal));
                o.fresnelColor = mainLight.color * _FresnelIntensity * pow(fresnel, _FresnelPow);

                // 顶点xz偏移
                float2 offset = 0;
                // 踩草
                half2 interactiveDir = interactive.rg * 2 - 1;
                offset = interactiveDir * _StepGrassStrength;
                // uv0存储草的倾倒方向和强度
                offset += v.uv0.xy * _Spread;

                // 全局风场
                float windForce = cos(_WindFrecuency * _Time.y + worldPos.z) * 0.45 - sin(_Time.z + worldPos.z) * 0.45 + 0.55;
                float windDir = _WindStrength * windForce * 0.5;
                float3 dirPos = windDir;
                // 局部随机扰动
                float noise = noise2d(worldPivot.zx + 2 * _Time.y * v.color.a) * 2 - 1;
                float turbulenceSpeed = sin(noise);
                float3 turbulencePos = turbulenceSpeed * _WindStrength;
                // 合并风偏移（只保留xz）
                float3 windPos = (turbulencePos + dirPos) * float3(1, 0, 1);
                offset += windPos.xz;

                // 根据xz的偏移，计算草的高度
                float height = v.vertex.y;
                offset = clamp(offset, -1, 1);
                float yOffset = (1 - sqrt(1 - saturate(offset * offset))) * height;
                worldPos.xz += offset * height;
                worldPos.y -= yOffset;

                o.color = v.color;
                o.positionWS = worldPos;
                o.positionCS = TransformWorldToHClip(worldPos);
                
                return o;
            }

            half4 frag(v2f i): SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);

                // Diffuse
                half4 color = i.diffColor * i.color.r * i.color.a;

                // 烧草
                half4 interactive = SAMPLE_TEXTURE2D(_InteractiveTex, sampler_InteractiveTex, float2((i.positionWS.xz - _InteractiveCamData.xz + _InteractiveCamData.y) / (2 * _InteractiveCamData.y)));
                color *= (1 - interactive.b);

                // Specular
                // 根据顶点计算出来的结果来插值选择高光方向
                float specDir = lerp(i.color.b, i.color.g, smoothstep(-0.1, 0.1, i.specColor.a));
                // 使高光聚合
                specDir = smoothstep(0.7, 0.9, specDir);
                color.rgb += i.specColor.rgb * specDir;

                // Fresnel
                color.rgb += i.fresnelColor;

                return color;
            }
            ENDHLSL
        }
    }
}