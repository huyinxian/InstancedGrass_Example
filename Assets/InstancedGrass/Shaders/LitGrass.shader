Shader "LitGrass"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
            "RenderPipeline"="UniversalRenderPipeline"
        }

        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #define TRANSFORM_TEX(tex,name) (tex.xy * name##_ST.xy + name##_ST.zw)

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 worldNormal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                float4 shadowCoord : TEXCOORD3;
            };

            CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
            half4 _MainColor;
            half4 _ShadowColor;
            CBUFFER_END

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);

            v2f vert (appdata v)
            {
                v2f o;
                o.worldPos = TransformObjectToWorld(v.vertex);
                o.vertex = TransformWorldToHClip(o.worldPos);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldNormal = TransformObjectToWorldNormal(v.normal);
                // Shadows.GetShadowCoord
#if SHADOWS_SCREEN
                o.shadowCoord = ComputeScreenPos(o.vertex);
#else
                o.shadowCoord = TransformWorldToShadowCoord(o.worldPos);
#endif
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                Light mainLight = GetMainLight(i.shadowCoord);
                float3 lightDir = mainLight.direction;
                half4 color = half4(1, 1, 1, 1);
                // half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                half3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
                half3 worldNormal = normalize(i.worldNormal);
                // 半兰伯特，将光线与法线的点乘结果变化到[0,1]
                half halfLambert = dot(lightDir, worldNormal) * 0.5 + 0.5;
                half3 diffuse = halfLambert > 0.5 ? _MainColor : _ShadowColor;
                color.rgb *= mainLight.color * diffuse;

                return color;
            }
            ENDHLSL
        }
    }
}
